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
  final String? mac;
  ScanResult(this.ip, {this.hostname, this.mac});
}

class ScanDiff {
  final List<ScanResult> added;
  final List<ScanResult> removed;
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
  final String cidr;
  final List<ScanResult> hosts;
  final ScanSnapshot? baseline;
  final List<ScanResult>? previousHosts;
  final String? diffSource;
  final ScanDiff? diff;
  final double progress;
  final String? error;

  const ScanState({
    this.status = ScanStatus.idle,
    this.cidr = '',
    this.hosts = const [],
    this.baseline,
    this.previousHosts,
    this.diffSource,
    this.diff,
    this.progress = 0,
    this.error,
  });

  ScanState copyWith({
    ScanStatus? status,
    String? cidr,
    List<ScanResult>? hosts,
    ScanSnapshot? baseline,
    List<ScanResult>? previousHosts,
    String? diffSource,
    ScanDiff? diff,
    double? progress,
    String? error,
    bool clearDiff = false,
    bool clearBaseline = false,
    bool clearPreviousHosts = false,
  }) {
    return ScanState(
      status: status ?? this.status,
      cidr: cidr ?? this.cidr,
      hosts: hosts ?? this.hosts,
      baseline: clearBaseline ? null : (baseline ?? this.baseline),
      previousHosts:
          clearPreviousHosts ? null : (previousHosts ?? this.previousHosts),
      diffSource: clearDiff ? null : (diffSource ?? this.diffSource),
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
              // Show IP immediately, then fill in hostname/MAC when available.
              hosts.add(ScanResult(ip));
              state = state.copyWith(hosts: List.from(hosts));
              _resolveHostname(host, ip).then((name) {
                if (name == null || !ref.mounted) return;
                if (index < hosts.length && hosts[index].ip == ip) {
                  hosts[index] = ScanResult(
                    ip,
                    hostname: name,
                    mac: hosts[index].mac,
                  );
                }
                _patchHost(ip, hostname: name);
              });
              _resolveMac(host).then((mac) {
                if (mac == null || !ref.mounted) return;
                if (index < hosts.length && hosts[index].ip == ip) {
                  hosts[index] = ScanResult(
                    ip,
                    hostname: hosts[index].hostname,
                    mac: mac,
                  );
                }
                _patchHost(ip, mac: mac);
              });
            },
            onDone: () {
              final currentHosts = List<ScanResult>.from(hosts);
              final comparison = _comparisonHosts();
              final diff = comparison == null
                  ? null
                  : _computeDiff(currentHosts, comparison.hosts);
              state = state.copyWith(
                status: ScanStatus.done,
                hosts: currentHosts,
                progress: 1.0,
                diff: diff,
                diffSource: comparison?.label,
                previousHosts: currentHosts,
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
    state = state.copyWith(
      baseline: snapshot,
      diffSource: 'saved baseline',
      clearDiff: true,
    );
  }

  void loadBaseline(ScanSnapshot snapshot) {
    state = state.copyWith(
      baseline: snapshot,
      diffSource: 'saved baseline',
      diff: state.hosts.isEmpty
          ? null
          : _computeDiff(
              state.hosts,
              snapshot.hosts.map((ip) => ScanResult(ip)).toList(),
            ),
    );
  }

  void clearBaseline() {
    state = state.copyWith(clearBaseline: true, clearDiff: true);
  }

  ({List<ScanResult> hosts, String label})? _comparisonHosts() {
    if (state.baseline != null) {
      return (
        hosts: state.baseline!.hosts.map((ip) => ScanResult(ip)).toList(),
        label: 'saved baseline',
      );
    }
    if (state.previousHosts != null && state.previousHosts!.isNotEmpty) {
      return (hosts: state.previousHosts!, label: 'previous scan');
    }
    return null;
  }

  /// Keep hostname/MAC in the live host list, previous-scan snapshot, and diff.
  void _patchHost(String ip, {String? hostname, String? mac}) {
    List<ScanResult>? updateList(List<ScanResult>? list) {
      if (list == null) return null;
      final i = list.indexWhere((h) => h.ip == ip);
      if (i < 0) return null;
      final existing = list[i];
      final updated = List<ScanResult>.from(list);
      updated[i] = ScanResult(
        ip,
        hostname: hostname ?? existing.hostname,
        mac: mac ?? existing.mac,
      );
      return updated;
    }

    final updatedHosts = updateList(state.hosts) ?? state.hosts;
    final updatedPrevious = updateList(state.previousHosts);

    ScanDiff? updatedDiff = state.diff;
    if (updatedDiff != null) {
      final added = updateList(updatedDiff.added);
      final removed = updateList(updatedDiff.removed);
      if (added != null || removed != null) {
        updatedDiff = ScanDiff(
          added ?? updatedDiff.added,
          removed ?? updatedDiff.removed,
        );
      }
    }

    state = state.copyWith(
      hosts: updatedHosts,
      previousHosts: updatedPrevious,
      diff: updatedDiff,
    );
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

  /// MAC via ARP — typically unavailable on Android/iOS.
  Future<String?> _resolveMac(ActiveHost host) async {
    try {
      final mac = await host.getMacAddress();
      if (mac == null) return null;
      final cleaned = mac.trim().toLowerCase();
      if (cleaned.isEmpty ||
          cleaned == ARPData.nullMacAddress ||
          cleaned == '(incomplete)' ||
          cleaned == '00:00:00:00:00:00') {
        return null;
      }
      return mac.trim();
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

  ScanDiff? _computeDiff(List<ScanResult> current, List<ScanResult> baseline) {
    final currentByIp = {for (final h in current) h.ip: h};
    final baselineByIp = {for (final h in baseline) h.ip: h};
    final added = currentByIp.keys
        .where((ip) => !baselineByIp.containsKey(ip))
        .map((ip) => currentByIp[ip]!)
        .toList()
      ..sort((a, b) => a.ip.compareTo(b.ip));
    final removed = baselineByIp.keys
        .where((ip) => !currentByIp.containsKey(ip))
        .map((ip) => baselineByIp[ip]!)
        .toList()
      ..sort((a, b) => a.ip.compareTo(b.ip));
    return ScanDiff(added, removed);
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

final scanProvider = NotifierProvider<ScanNotifier, ScanState>(ScanNotifier.new);

final snapshotListProvider = Provider.autoDispose<List<ScanSnapshot>>(
  (ref) => HiveService.getAllSnapshots(),
);
