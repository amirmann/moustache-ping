import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart';
import '../../shared/storage/hive_service.dart';
import 'scan_snapshot.dart';

enum ScanStatus { idle, detecting, scanning, done, error }

class ScanResult {
  final String ip;
  final String? hostname;
  ScanResult(this.ip, {this.hostname});
}

class ScanDiff {
  final List<String> added;
  final List<String> removed;
  ScanDiff(this.added, this.removed);
}

/// Parsed representation of a CIDR block, e.g. 192.168.1.0/24.
class CidrNetwork {
  final String networkAddress; // e.g. 192.168.1.0
  final int prefixLength;      // e.g. 24

  CidrNetwork(this.networkAddress, this.prefixLength);

  /// The subnet prefix passed to HostScannerService (e.g. "192.168.1").
  /// Only /8, /16 and /24 are natively supported by the scanner (last N octets
  /// are iterated). For all other masks we fall back to /24 behaviour and warn.
  String get scannerSubnet {
    final parts = networkAddress.split('.');
    if (prefixLength <= 8) return parts[0];
    if (prefixLength <= 16) return '${parts[0]}.${parts[1]}';
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  int get firstHost => 1;
  int get lastHost {
    if (prefixLength >= 24) return 254;
    if (prefixLength >= 16) return 254; // scanner handles last octet only
    return 254;
  }

  @override
  String toString() => '$networkAddress/$prefixLength';
}

class ScanState {
  final ScanStatus status;
  final String cidr;          // user-visible CIDR string, e.g. "192.168.1.0/24"
  final List<ScanResult> hosts;
  final ScanSnapshot? baseline;
  final ScanDiff? diff;
  final double progress;
  final String? error;

  const ScanState({
    this.status = ScanStatus.idle,
    this.cidr = '',
    this.hosts = const [],
    this.baseline,
    this.diff,
    this.progress = 0,
    this.error,
  });

  ScanState copyWith({
    ScanStatus? status,
    String? cidr,
    List<ScanResult>? hosts,
    ScanSnapshot? baseline,
    ScanDiff? diff,
    double? progress,
    String? error,
    bool clearDiff = false,
    bool clearBaseline = false,
  }) {
    return ScanState(
      status: status ?? this.status,
      cidr: cidr ?? this.cidr,
      hosts: hosts ?? this.hosts,
      baseline: clearBaseline ? null : (baseline ?? this.baseline),
      diff: clearDiff ? null : (diff ?? this.diff),
      progress: progress ?? this.progress,
      error: error,
    );
  }
}

class ScanNotifier extends Notifier<ScanState> {
  StreamSubscription<ActiveHost>? _sub;

  @override
  ScanState build() {
    ref.onDispose(() => _sub?.cancel());
    return const ScanState();
  }

  Future<void> detectSubnet() async {
    state = state.copyWith(status: ScanStatus.detecting);
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      final mask = await info.getWifiSubmask();
      if (ip == null) throw Exception('Could not read WiFi IP');
      final cidr = _ipMaskToCidr(ip, mask ?? '255.255.255.0');
      state = state.copyWith(status: ScanStatus.idle, cidr: cidr);
    } catch (e) {
      state = state.copyWith(status: ScanStatus.error, error: e.toString());
    }
  }

  void setCidr(String cidr) => state = state.copyWith(cidr: cidr);

  Future<void> startScan() async {
    _sub?.cancel();
    final cidrStr = state.cidr.trim();
    if (cidrStr.isEmpty) return;

    final network = _parseCidr(cidrStr);
    if (network == null) {
      state = state.copyWith(
        status: ScanStatus.error,
        error: 'Invalid network format. Use CIDR notation, e.g. 192.168.1.0/24',
      );
      return;
    }

    state = state.copyWith(
      status: ScanStatus.scanning,
      hosts: [],
      progress: 0,
      clearDiff: true,
    );

    final hosts = <ScanResult>[];

    try {
      _sub = HostScannerService.instance
          .getAllPingableDevices(
            network.scannerSubnet,
            firstHostId: network.firstHost,
            lastHostId: network.lastHost,
            progressCallback: (p) {
              state = state.copyWith(progress: p / 100.0);
            },
          )
          .listen(
            (host) {
              final ip = host.internetAddress.address;
              final index = hosts.length;
              // Show IP immediately, then fill in hostname when reverse DNS returns.
              hosts.add(ScanResult(ip));
              state = state.copyWith(hosts: List.from(hosts));
              _resolveHostname(host, ip).then((name) {
                if (name == null || !ref.mounted) return;
                if (index < hosts.length && hosts[index].ip == ip) {
                  hosts[index] = ScanResult(ip, hostname: name);
                  state = state.copyWith(hosts: List.from(hosts));
                }
              });
            },
            onDone: () {
              final diff = _computeDiff(hosts, state.baseline);
              state = state.copyWith(
                status: ScanStatus.done,
                hosts: List.from(hosts),
                progress: 1.0,
                diff: diff,
              );
            },
            onError: (e) {
              state = state.copyWith(
                status: ScanStatus.error,
                error: e.toString(),
              );
            },
          );
    } catch (e) {
      state = state.copyWith(status: ScanStatus.error, error: e.toString());
    }
  }

  void stopScan() {
    _sub?.cancel();
    if (state.status == ScanStatus.scanning) {
      state = state.copyWith(status: ScanStatus.done);
    }
  }

  Future<void> saveAsBaseline() async {
    final snapshot = ScanSnapshot(
      subnet: state.cidr,
      hosts: state.hosts.map((h) => h.ip).toList(),
      timestamp: DateTime.now(),
    );
    await HiveService.saveScanSnapshot(snapshot);
    state = state.copyWith(baseline: snapshot, clearDiff: true);
  }

  void loadBaseline(ScanSnapshot snapshot) {
    state = state.copyWith(baseline: snapshot);
  }

  void clearBaseline() {
    state = state.copyWith(clearBaseline: true, clearDiff: true);
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  /// Prefer reverse-DNS hostname; fall back to deviceName when useful.
  Future<String?> _resolveHostname(ActiveHost host, String ip) async {
    try {
      var name = await host.hostName;
      name = _cleanHostname(name, ip);
      if (name != null) return name;

      final device = await host.deviceName;
      return _cleanHostname(device, ip);
    } catch (_) {
      return null;
    }
  }

  String? _cleanHostname(String? name, String ip) {
    if (name == null) return null;
    var cleaned = name.trim();
    if (cleaned.endsWith('.')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (cleaned.isEmpty ||
        cleaned == ip ||
        cleaned == ActiveHost.generic) {
      return null;
    }
    return cleaned;
  }

  ScanDiff? _computeDiff(List<ScanResult> current, ScanSnapshot? baseline) {
    if (baseline == null) return null;
    final currentIPs = current.map((h) => h.ip).toSet();
    final baselineIPs = baseline.hosts.toSet();
    return ScanDiff(
      currentIPs.difference(baselineIPs).toList()..sort(),
      baselineIPs.difference(currentIPs).toList()..sort(),
    );
  }

  /// Convert an IP + dotted-decimal mask into CIDR string.
  String _ipMaskToCidr(String ip, String mask) {
    final maskParts = mask.split('.').map(int.parse).toList();
    final ipParts = ip.split('.').map(int.parse).toList();

    // Count prefix bits
    int prefix = 0;
    for (final b in maskParts) {
      prefix += _popcount(b);
    }

    // Compute network address by ANDing IP and mask
    final netParts = List.generate(4, (i) => ipParts[i] & maskParts[i]);
    return '${netParts.join('.')}/$prefix';
  }

  int _popcount(int byte) {
    int count = 0;
    int b = byte;
    while (b != 0) {
      count += b & 1;
      b >>= 1;
    }
    return count;
  }

  /// Parse "a.b.c.d/prefix" → CidrNetwork, or null on error.
  CidrNetwork? _parseCidr(String cidr) {
    final parts = cidr.trim().split('/');
    if (parts.length != 2) return null;
    final prefix = int.tryParse(parts[1]);
    if (prefix == null || prefix < 1 || prefix > 32) return null;
    final ipParts = parts[0].split('.');
    if (ipParts.length != 4) return null;
    for (final p in ipParts) {
      final v = int.tryParse(p);
      if (v == null || v < 0 || v > 255) return null;
    }
    return CidrNetwork(parts[0], prefix);
  }
}

final scanProvider =
    NotifierProvider.autoDispose<ScanNotifier, ScanState>(ScanNotifier.new);

final snapshotListProvider = Provider.autoDispose<List<ScanSnapshot>>(
  (ref) => HiveService.getAllSnapshots(),
);
