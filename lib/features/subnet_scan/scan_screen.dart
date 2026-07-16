import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/moustache_header.dart';
import 'scan_provider.dart';
import 'scan_snapshot.dart';

Future<void> _showHostCopySheet(BuildContext context, ScanResult host) async {
  final hasHostname = host.hostname?.isNotEmpty == true;
  final hasMac = host.mac?.isNotEmpty == true;
  final cs = Theme.of(context).colorScheme;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  hasHostname ? '${host.hostname}\n${host.ip}' : host.ip,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            if (hasHostname)
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Copy hostname'),
                subtitle: Text(host.hostname!, style: const TextStyle(fontSize: 12)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await Clipboard.setData(ClipboardData(text: host.hostname!));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hostname copied')),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.lan_outlined),
              title: const Text('Copy IP'),
              subtitle: Text(host.ip, style: const TextStyle(fontSize: 12)),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Clipboard.setData(ClipboardData(text: host.ip));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('IP copied')),
                  );
                }
              },
            ),
            ListTile(
              enabled: hasMac,
              leading: Icon(
                Icons.memory_rounded,
                color: hasMac ? null : cs.onSurface.withValues(alpha: 0.35),
              ),
              title: Text(
                'Copy MAC',
                style: TextStyle(
                  color: hasMac ? null : cs.onSurface.withValues(alpha: 0.35),
                ),
              ),
              subtitle: Text(
                hasMac ? host.mac! : 'Not available',
                style: TextStyle(
                  fontSize: 12,
                  color: hasMac
                      ? null
                      : cs.onSurface.withValues(alpha: 0.35),
                ),
              ),
              onTap: hasMac
                  ? () async {
                      Navigator.pop(sheetContext);
                      await Clipboard.setData(ClipboardData(text: host.mac!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('MAC copied')),
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  late final TextEditingController _cidrCtrl;
  bool _cidrEdited = false;

  @override
  void initState() {
    super.initState();
    _cidrCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detectSubnet();
    });
  }

  @override
  void dispose() {
    _cidrCtrl.dispose();
    super.dispose();
  }

  void _detectSubnet() async {
    await ref.read(scanProvider.notifier).detectSubnet();
    if (!_cidrEdited) {
      _cidrCtrl.text = ref.read(scanProvider).cidr;
    }
  }

  void _startScan() {
    FocusScope.of(context).unfocus();
    ref.read(scanProvider.notifier).setCidr(_cidrCtrl.text.trim());
    ref.read(scanProvider.notifier).startScan();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanProvider);
    final cs = Theme.of(context).colorScheme;
    final isScanning = state.status == ScanStatus.scanning;

    ref.listen(scanProvider, (prev, next) {
      if (prev?.cidr != next.cidr && !_cidrEdited) {
        _cidrCtrl.text = next.cidr;
      }
    });

    return Scaffold(
      appBar: const MoustacheHeader(title: 'Subnet Scan'),
      body: Column(
        children: [
          _SubnetInput(
            controller: _cidrCtrl,
            isScanning: isScanning,
            onEdited: () => _cidrEdited = true,
            onDetect: _detectSubnet,
            onScan: _startScan,
            onStop: () => ref.read(scanProvider.notifier).stopScan(),
          ),
          if (isScanning)
            LinearProgressIndicator(
              value: state.progress > 0 ? state.progress : null,
              backgroundColor: cs.surfaceContainerHighest,
              color: cs.primary,
            ),
          if (state.baseline != null)
            _BaselineBanner(
              baseline: state.baseline!,
              onClear: () => ref.read(scanProvider.notifier).clearBaseline(),
            ),
          if (state.status == ScanStatus.done &&
              state.diff == null &&
              state.hosts.isNotEmpty &&
              state.previousHosts != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.compare_arrows_rounded,
                      size: 16, color: cs.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Scan again to compare with this result',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (state.diff != null)
            _DiffCard(diff: state.diff!, source: state.diffSource),
          Expanded(
            child: _HostList(
              state: state,
              onSaveBaseline: state.status == ScanStatus.done && state.hosts.isNotEmpty
                  ? () async {
                      await ref.read(scanProvider.notifier).saveAsBaseline();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saved as baseline')),
                        );
                      }
                    }
                  : null,
              onLoadBaseline: () => _showSnapshotPicker(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnapshotPicker(BuildContext context, WidgetRef ref) {
    final snapshots = ref.read(snapshotListProvider);
    if (snapshots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved baselines yet')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => _SnapshotPicker(
        snapshots: snapshots,
        onSelected: (s) {
          ref.read(scanProvider.notifier).loadBaseline(s);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _SubnetInput extends StatelessWidget {
  const _SubnetInput({
    required this.controller,
    required this.isScanning,
    required this.onEdited,
    required this.onDetect,
    required this.onScan,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool isScanning;
  final VoidCallback onEdited;
  final VoidCallback onDetect;
  final VoidCallback onScan;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isScanning,
              onChanged: (_) => onEdited(),
              decoration: InputDecoration(
                labelText: 'Network (CIDR)',
                hintText: '192.168.1.0/24',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.wifi_find_rounded),
                  tooltip: 'Auto-detect',
                  onPressed: isScanning ? null : onDetect,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          isScanning
              ? OutlinedButton(onPressed: onStop, child: const Text('Stop'))
              : ElevatedButton(onPressed: onScan, child: const Text('Scan')),
        ],
      ),
    );
  }
}

class _BaselineBanner extends StatelessWidget {
  const _BaselineBanner({required this.baseline, required this.onClear});
  final ScanSnapshot baseline;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.primary.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.bookmark_rounded, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Baseline: ${baseline.label}',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: onClear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _DiffCard extends StatelessWidget {
  const _DiffCard({required this.diff, this.source});
  final ScanDiff diff;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (diff.added.isEmpty && diff.removed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                source == null
                    ? 'No changes since last scan'
                    : 'No changes since $source',
              ),
            ),
          ],
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              source == null
                  ? 'Changes since last scan'
                  : 'Changes since $source',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (diff.added.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Added (${diff.added.length})',
                style: TextStyle(
                  color: Colors.greenAccent.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ...diff.added.map((host) => _DiffRow(host: host, added: true)),
            ],
            if (diff.removed.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Removed (${diff.removed.length})',
                style: TextStyle(
                  color: Colors.redAccent.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ...diff.removed.map((host) => _DiffRow(host: host, added: false)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({required this.host, required this.added});
  final ScanResult host;
  final bool added;

  @override
  Widget build(BuildContext context) {
    final color = added ? Colors.greenAccent[400]! : Colors.redAccent[400]!;
    final hasName = host.hostname?.isNotEmpty == true;
    return InkWell(
      onLongPress: () => _showHostCopySheet(context, host),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                added ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
                size: 14,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasName ? host.hostname! : host.ip,
                    style: TextStyle(color: color, fontSize: 13),
                  ),
                  if (hasName)
                    Text(
                      host.ip,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostList extends StatelessWidget {
  const _HostList({
    required this.state,
    required this.onSaveBaseline,
    required this.onLoadBaseline,
  });

  final ScanState state;
  final VoidCallback? onSaveBaseline;
  final VoidCallback onLoadBaseline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (state.status == ScanStatus.idle || state.status == ScanStatus.detecting) {
      return Center(
        child: Text(
          state.status == ScanStatus.detecting
              ? 'Detecting network…'
              : 'Enter a network (e.g. 192.168.1.0/24) and tap Scan',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (state.status == ScanStatus.error) {
      return Center(
        child: Text(
          'Error: ${state.error}',
          style: TextStyle(color: cs.error),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        if (state.status == ScanStatus.done && state.hosts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                Text(
                  '${state.hosts.length} device${state.hosts.length == 1 ? '' : 's'} found',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onSaveBaseline,
                  icon: const Icon(Icons.bookmark_add_rounded),
                  tooltip: 'Save as baseline',
                  color: cs.primary,
                ),
                IconButton(
                  onPressed: onLoadBaseline,
                  icon: const Icon(Icons.bookmark_rounded),
                  tooltip: 'Load baseline',
                  color: cs.primary,
                ),
              ],
            ),
          ),
        Expanded(
          child: state.hosts.isEmpty
              ? Center(
                  child: state.status == ScanStatus.scanning
                      ? const Text('Scanning…')
                      : Text(
                          'No hosts found',
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
                        ),
                )
              : ListView.builder(
                  itemCount: state.hosts.length,
                  itemBuilder: (ctx, i) {
                    final host = state.hosts[i];
                    final isNew =
                        state.diff?.added.any((h) => h.ip == host.ip) ?? false;
                    return ListTile(
                      dense: true,
                      onLongPress: () => _showHostCopySheet(context, host),
                      leading: Icon(
                        Icons.devices_rounded,
                        size: 18,
                        color: isNew ? Colors.greenAccent[400] : cs.primary,
                      ),
                      title: Text(
                        host.hostname?.isNotEmpty == true ? host.hostname! : host.ip,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: host.hostname?.isNotEmpty == true
                          ? Text(host.ip, style: const TextStyle(fontSize: 11))
                          : null,
                      trailing: isNew
                          ? Chip(
                              label: const Text('NEW', style: TextStyle(fontSize: 10)),
                              backgroundColor: Colors.greenAccent[700],
                              padding: EdgeInsets.zero,
                            )
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SnapshotPicker extends StatelessWidget {
  const _SnapshotPicker({required this.snapshots, required this.onSelected});
  final List<ScanSnapshot> snapshots;
  final ValueChanged<ScanSnapshot> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Choose baseline',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...snapshots.take(10).map((s) => ListTile(
              leading: const Icon(Icons.bookmark_rounded),
              title: Text(s.label),
              onTap: () => onSelected(s),
            )),
        const SizedBox(height: 16),
      ],
    );
  }
}
