import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/moustache_header.dart';
import 'ping_provider.dart';

class PingScreen extends ConsumerStatefulWidget {
  const PingScreen({super.key});

  @override
  ConsumerState<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends ConsumerState<PingScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _continuous = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPing() {
    final target = _controller.text.trim();
    if (target.isEmpty) return;
    FocusScope.of(context).unfocus();
    ref.read(pingProvider.notifier).start(target, continuous: _continuous);
  }

  void _stopPing() => ref.read(pingProvider.notifier).stop();
  void _reset() => ref.read(pingProvider.notifier).reset();

  void _clearInput() {
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pingProvider);
    final cs = Theme.of(context).colorScheme;

    ref.listen(pingProvider, (prev, next) {
      if (next.entries.length != (prev?.entries.length ?? 0) &&
          _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    final isRunning = state.status == PingStatus.running;

    return Scaffold(
      appBar: const MoustacheHeader(title: 'Ping'),
      body: Column(
        children: [
          _InputBar(
            controller: _controller,
            continuous: _continuous,
            isRunning: isRunning,
            onContinuousChanged: (v) => setState(() => _continuous = v),
            onStart: _startPing,
            onStop: _stopPing,
            onReset: _reset,
            onClearInput: _clearInput,
          ),
          if (state.status != PingStatus.idle) ...[
            _SummaryBar(state: state),
            Expanded(
              child: _ResultList(
                entries: state.entries,
                scrollController: _scrollController,
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Text(
                  'Enter an IP or hostname and tap Ping',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.continuous,
    required this.isRunning,
    required this.onContinuousChanged,
    required this.onStart,
    required this.onStop,
    required this.onReset,
    required this.onClearInput,
  });

  final TextEditingController controller;
  final bool continuous;
  final bool isRunning;
  final ValueChanged<bool> onContinuousChanged;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onReset;
  final VoidCallback onClearInput;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return TextField(
                controller: controller,
                enabled: !isRunning,
                decoration: InputDecoration(
                  labelText: 'IP or Hostname',
                  hintText: '8.8.8.8 or google.com',
                  prefixIcon: const Icon(Icons.computer_rounded),
                  suffixIcon: value.text.isNotEmpty && !isRunning
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          tooltip: 'Clear',
                          onPressed: onClearInput,
                        )
                      : null,
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => isRunning ? onStop() : onStart(),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Row(
                  children: [
                    Switch(
                      value: continuous,
                      onChanged: isRunning ? null : onContinuousChanged,
                    ),
                    const SizedBox(width: 4),
                    const Flexible(
                      child: Text(
                        'Continuous',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isRunning)
                OutlinedButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop'),
                )
              else
                ElevatedButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Ping'),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: isRunning ? null : onReset,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Clear results',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.state});
  final PingState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isRunning = state.status == PingStatus.running;
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (isRunning) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          _Stat('Sent', state.sent.toString()),
          const SizedBox(width: 16),
          _Stat('Recv', state.received.toString()),
          const SizedBox(width: 16),
          _Stat('Loss', '${state.lossPercent.toStringAsFixed(0)}%'),
          if (state.avgRtt != null) ...[
            const SizedBox(width: 16),
            _Stat('Avg', '${state.avgRtt!.toStringAsFixed(1)} ms'),
          ],
          const Spacer(),
          Text(
            state.target,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.entries,
    required this.scrollController,
  });
  final List<PingEntry> entries;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      controller: scrollController,
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        Color color;
        String label;
        if (e.error != null) {
          color = cs.error;
          label = 'Error: ${e.error}';
        } else if (e.timedOut) {
          color = Colors.orange;
          label = 'Request timeout';
        } else if (e.rttMs != null) {
          color = cs.primary;
          label = '${e.rttMs!.toStringAsFixed(1)} ms   TTL=${e.ttl ?? '-'}';
        } else {
          color = cs.onSurface.withValues(alpha: 0.4);
          label = '—';
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '${e.seq + 1}',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 12),
                ),
              ),
              Icon(
                e.success
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontSize: 13)),
            ],
          ),
        );
      },
    );
  }
}
