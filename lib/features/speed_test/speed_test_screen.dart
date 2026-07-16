import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/moustache_header.dart';
import 'speed_test_provider.dart';
import 'speed_result.dart';

class SpeedTestScreen extends ConsumerWidget {
  const SpeedTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(speedTestProvider);
    final cs = Theme.of(context).colorScheme;
    final isRunning = state.status == SpeedTestStatus.testingDownload ||
        state.status == SpeedTestStatus.testingUpload;

    return Scaffold(
      appBar: const MoustacheHeader(title: 'Speed Test'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Powered by fast.com',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            _SpeedDial(state: state),
            const SizedBox(height: 24),
            _Controls(
              isRunning: isRunning,
              isDone: state.status == SpeedTestStatus.done,
              onStart: () => ref.read(speedTestProvider.notifier).startTest(),
              onCancel: () => ref.read(speedTestProvider.notifier).cancel(),
              onReset: () => ref.read(speedTestProvider.notifier).reset(),
            ),
            if (state.status == SpeedTestStatus.error)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  state.error ?? 'Unknown error',
                  style: TextStyle(color: cs.error),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            if (state.history.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('History',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(height: 8),
              _HistoryList(results: state.history),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpeedDial extends StatelessWidget {
  const _SpeedDial({required this.state});
  final SpeedTestState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: CustomPaint(
            painter: _DialPainter(
              progress: state.progress,
              color: Theme.of(context).colorScheme.primary,
              bgColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Center(child: _DialCenter(state: state)),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _SpeedTile(
              label: 'Download',
              value: state.downloadMbps,
              icon: Icons.download_rounded,
              active: state.status == SpeedTestStatus.testingDownload,
            ),
            _SpeedTile(
              label: 'Upload',
              value: state.uploadMbps,
              icon: Icons.upload_rounded,
              active: state.status == SpeedTestStatus.testingUpload,
            ),
          ],
        ),
      ],
    );
  }
}

class _DialCenter extends StatelessWidget {
  const _DialCenter({required this.state});
  final SpeedTestState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (state.status) {
      case SpeedTestStatus.idle:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed_rounded, size: 40, color: cs.primary),
            const SizedBox(height: 4),
            Text('Ready', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
          ],
        );
      case SpeedTestStatus.done:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.downloadMbps.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: cs.primary),
            ),
            Text('Mbps down', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        );
      case SpeedTestStatus.testingDownload:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.downloadMbps > 0 ? state.downloadMbps.toStringAsFixed(1) : '…',
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: cs.primary),
            ),
            const Text('Mbps ↓'),
          ],
        );
      case SpeedTestStatus.testingUpload:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.uploadMbps > 0 ? state.uploadMbps.toStringAsFixed(1) : '…',
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: cs.primary),
            ),
            const Text('Mbps ↑'),
          ],
        );
      case SpeedTestStatus.error:
        return Icon(Icons.error_rounded, size: 40, color: cs.error);
    }
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.progress, required this.color, required this.bgColor});
  final double progress;
  final Color color;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(cx, cy) - 10;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    const startAngle = pi * 0.75;
    const sweepFull = pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle,
      sweepFull,
      false,
      bgPaint,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle,
        sweepFull * progress.clamp(0, 1),
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.progress != progress || old.color != color;
}

class _SpeedTile extends StatelessWidget {
  const _SpeedTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.active,
  });
  final String label;
  final double value;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.4), size: 20),
        const SizedBox(height: 4),
        Text(
          value > 0 ? value.toStringAsFixed(1) : '-',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: active ? cs.primary : cs.onSurface,
          ),
        ),
        Text('Mbps', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.isRunning,
    required this.isDone,
    required this.onStart,
    required this.onCancel,
    required this.onReset,
  });
  final bool isRunning;
  final bool isDone;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isRunning)
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Cancel'),
          )
        else
          ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.speed_rounded),
            label: const Text('Start Test'),
          ),
        if (isDone) ...[
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Again'),
          ),
        ],
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.results});
  final List<SpeedResult> results;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd/MM HH:mm');
    return Column(
      children: results.take(10).map((r) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.downloadMbps.toStringAsFixed(1)} ↓  ${r.uploadMbps.toStringAsFixed(1)} ↑  Mbps',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${r.provider} • ${fmt.format(r.timestamp)}',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
