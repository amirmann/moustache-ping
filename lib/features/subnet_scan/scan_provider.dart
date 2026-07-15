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

class ScanState {
  final ScanStatus status;
  final String subnet;
  final List<ScanResult> hosts;
  final ScanSnapshot? baseline;
  final ScanDiff? diff;
  final double progress;
  final String? error;

  const ScanState({
    this.status = ScanStatus.idle,
    this.subnet = '',
    this.hosts = const [],
    this.baseline,
    this.diff,
    this.progress = 0,
    this.error,
  });

  ScanState copyWith({
    ScanStatus? status,
    String? subnet,
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
      subnet: subnet ?? this.subnet,
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
      final subnet = _deriveSubnet(ip, mask ?? '255.255.255.0');
      state = state.copyWith(status: ScanStatus.idle, subnet: subnet);
    } catch (e) {
      state = state.copyWith(status: ScanStatus.error, error: e.toString());
    }
  }

  void setSubnet(String subnet) {
    state = state.copyWith(subnet: subnet);
  }

  Future<void> startScan() async {
    _sub?.cancel();
    final subnet = state.subnet.trim();
    if (subnet.isEmpty) return;

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
            subnet,
            progressCallback: (p) {
              state = state.copyWith(progress: p / 100.0);
            },
          )
          .listen(
            (host) {
              final ip = host.internetAddress.address;
              hosts.add(ScanResult(ip));
              state = state.copyWith(hosts: List.from(hosts));
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
      subnet: state.subnet,
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

  ScanDiff? _computeDiff(List<ScanResult> current, ScanSnapshot? baseline) {
    if (baseline == null) return null;
    final currentIPs = current.map((h) => h.ip).toSet();
    final baselineIPs = baseline.hosts.toSet();
    return ScanDiff(
      currentIPs.difference(baselineIPs).toList()..sort(),
      baselineIPs.difference(currentIPs).toList()..sort(),
    );
  }

  String _deriveSubnet(String ip, String mask) {
    final ipParts = ip.split('.').map(int.parse).toList();
    final maskParts = mask.split('.').map(int.parse).toList();
    final netParts = List.generate(4, (i) => ipParts[i] & maskParts[i]);
    if (maskParts[3] == 0) {
      return '${netParts[0]}.${netParts[1]}.${netParts[2]}';
    }
    final parts = ip.split('.');
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }
}

final scanProvider =
    NotifierProvider.autoDispose<ScanNotifier, ScanState>(ScanNotifier.new);

final snapshotListProvider = Provider.autoDispose<List<ScanSnapshot>>(
  (ref) => HiveService.getAllSnapshots(),
);
