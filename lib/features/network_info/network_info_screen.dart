import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/moustache_header.dart';
import 'network_info_provider.dart';

class NetworkInfoScreen extends ConsumerStatefulWidget {
  const NetworkInfoScreen({super.key});

  @override
  ConsumerState<NetworkInfoScreen> createState() => _NetworkInfoScreenState();
}

class _NetworkInfoScreenState extends ConsumerState<NetworkInfoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deviceNetworkInfoProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceNetworkInfoProvider);
    final cs = Theme.of(context).colorScheme;
    final isLoading = state.status == NetworkInfoStatus.loading;

    return Scaffold(
      appBar: MoustacheHeader(
        title: 'Network Info',
        actions: [
          IconButton(
            onPressed: isLoading
                ? null
                : () => ref.read(deviceNetworkInfoProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(deviceNetworkInfoProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (state.locationNote != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.locationNote!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (state.status == NetworkInfoStatus.error)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  state.error ?? 'Failed to load network info',
                  style: TextStyle(color: cs.error),
                ),
              ),
            _InfoCard(
              info: state.wifi,
              icon: Icons.wifi_rounded,
              isLoading: isLoading,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              info: state.cellular,
              icon: Icons.signal_cellular_alt_rounded,
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.info,
    required this.icon,
    required this.isLoading,
  });

  final InterfaceInfo info;
  final IconData icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  info.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  _StatusChip(connected: info.connected),
              ],
            ),
            const SizedBox(height: 12),
            if (info.label == 'WiFi') ...[
              _InfoRow('SSID', info.ssid),
              _InfoRow('BSSID', info.bssid),
            ],
            _InfoRow('Network type', info.networkType),
            _InfoRow('IP address', info.ipAddress),
            _InfoRow('Subnet mask', info.subnetMask),
            _InfoRow('Gateway', info.gateway),
            _InfoRow('DNS servers', info.dnsServers),
            if (info.label == 'WiFi') ...[
              _InfoRow('Broadcast', info.broadcast),
              _InfoRow('IPv6', info.ipv6),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? Colors.greenAccent.shade400 : Colors.grey;
    return Chip(
      label: Text(
        connected ? 'Connected' : 'Inactive',
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: color.withValues(alpha: 0.2),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final display = (value == null || value!.trim().isEmpty) ? '—' : value!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: Text(
              display,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
