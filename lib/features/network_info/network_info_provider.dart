import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum NetworkInfoStatus { idle, loading, ready, error }

class InterfaceInfo {
  final String label;
  final String? ssid;
  final String? bssid;
  final String? ipAddress;
  final String? subnetMask;
  final String? gateway;
  final String? dnsServers;
  final String? ipv6;
  final String? broadcast;
  final String? networkType;
  final bool connected;

  const InterfaceInfo({
    required this.label,
    this.ssid,
    this.bssid,
    this.ipAddress,
    this.subnetMask,
    this.gateway,
    this.dnsServers,
    this.ipv6,
    this.broadcast,
    this.networkType,
    this.connected = false,
  });

  static const empty = InterfaceInfo(label: '');

  InterfaceInfo copyWith({
    String? label,
    String? ssid,
    String? bssid,
    String? ipAddress,
    String? subnetMask,
    String? gateway,
    String? dnsServers,
    String? ipv6,
    String? broadcast,
    String? networkType,
    bool? connected,
  }) {
    return InterfaceInfo(
      label: label ?? this.label,
      ssid: ssid ?? this.ssid,
      bssid: bssid ?? this.bssid,
      ipAddress: ipAddress ?? this.ipAddress,
      subnetMask: subnetMask ?? this.subnetMask,
      gateway: gateway ?? this.gateway,
      dnsServers: dnsServers ?? this.dnsServers,
      ipv6: ipv6 ?? this.ipv6,
      broadcast: broadcast ?? this.broadcast,
      networkType: networkType ?? this.networkType,
      connected: connected ?? this.connected,
    );
  }
}

class DeviceNetworkInfoState {
  final NetworkInfoStatus status;
  final InterfaceInfo wifi;
  final InterfaceInfo cellular;
  final String? locationNote;
  final String? error;

  const DeviceNetworkInfoState({
    this.status = NetworkInfoStatus.idle,
    this.wifi = const InterfaceInfo(label: 'WiFi'),
    this.cellular = const InterfaceInfo(label: 'Cellular'),
    this.locationNote,
    this.error,
  });

  DeviceNetworkInfoState copyWith({
    NetworkInfoStatus? status,
    InterfaceInfo? wifi,
    InterfaceInfo? cellular,
    String? locationNote,
    String? error,
  }) {
    return DeviceNetworkInfoState(
      status: status ?? this.status,
      wifi: wifi ?? this.wifi,
      cellular: cellular ?? this.cellular,
      locationNote: locationNote,
      error: error,
    );
  }
}

class DeviceNetworkInfoNotifier extends Notifier<DeviceNetworkInfoState> {
  final _networkInfo = NetworkInfo();
  final _connectivity = Connectivity();

  @override
  DeviceNetworkInfoState build() => const DeviceNetworkInfoState();

  Future<void> refresh() async {
    state = state.copyWith(status: NetworkInfoStatus.loading, error: null);

    try {
      final locationStatus = await _ensureLocationPermission();
      final connectivity = await _connectivity.checkConnectivity();
      final androidInfo = await _readAndroidNetworkInfo();

      final wifiConnected = connectivity == ConnectivityResult.wifi ||
          connectivity == ConnectivityResult.ethernet;
      final cellularConnected = connectivity == ConnectivityResult.mobile;

      final wifi = await _loadWifiInfo(
        connected: wifiConnected,
        androidInfo: androidInfo,
        locationGranted: locationStatus.granted,
      );

      final cellular = await _loadCellularInfo(
        connected: cellularConnected,
        androidInfo: androidInfo,
        connectivity: connectivity,
      );

      state = DeviceNetworkInfoState(
        status: NetworkInfoStatus.ready,
        wifi: wifi,
        cellular: cellular,
        locationNote: locationStatus.note,
      );
    } catch (e) {
      state = state.copyWith(
        status: NetworkInfoStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<({bool granted, String? note})> _ensureLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isGranted) {
      return (granted: true, note: null);
    }

    status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      return (granted: true, note: null);
    }

    return (
      granted: false,
      note: 'Location permission is required on Android 10+ to read WiFi SSID/BSSID.',
    );
  }

  Future<InterfaceInfo> _loadWifiInfo({
    required bool connected,
    required AndroidNetworkInfo androidInfo,
    required bool locationGranted,
  }) async {
    final ssidRaw = await _networkInfo.getWifiName();
    final ssid = _cleanQuoted(ssidRaw);
    final wifiSnapshot = androidInfo.wifi;

    return InterfaceInfo(
      label: 'WiFi',
      connected: connected || wifiSnapshot != null,
      networkType: connected || wifiSnapshot != null ? 'WiFi' : 'Not connected',
      ssid: locationGranted ? ssid : 'Permission required',
      bssid: locationGranted ? await _networkInfo.getWifiBSSID() : 'Permission required',
      ipAddress: await _networkInfo.getWifiIP() ?? wifiSnapshot?.ipv4,
      subnetMask: await _networkInfo.getWifiSubmask() ?? wifiSnapshot?.subnetMask,
      gateway: await _networkInfo.getWifiGatewayIP() ?? wifiSnapshot?.gateway,
      broadcast: await _networkInfo.getWifiBroadcast() ?? wifiSnapshot?.broadcast,
      ipv6: await _networkInfo.getWifiIPv6() ?? wifiSnapshot?.ipv6,
      dnsServers: _joinDns(wifiSnapshot?.dnsServers ?? androidInfo.fallbackDns),
    );
  }

  Future<InterfaceInfo> _loadCellularInfo({
    required bool connected,
    required AndroidNetworkInfo androidInfo,
    required ConnectivityResult connectivity,
  }) async {
    final cellularSnapshot = androidInfo.cellular;

    return InterfaceInfo(
      label: 'Cellular',
      connected: connected || cellularSnapshot != null,
      networkType: cellularSnapshot?.networkType ?? _connectivityLabel(connectivity),
      ipAddress: cellularSnapshot?.ipv4,
      subnetMask: cellularSnapshot?.subnetMask,
      gateway: cellularSnapshot?.gateway,
      dnsServers: _joinDns(cellularSnapshot?.dnsServers ?? androidInfo.fallbackDns),
    );
  }

  String _connectivityLabel(ConnectivityResult result) {
    return switch (result) {
      ConnectivityResult.mobile => 'Mobile',
      ConnectivityResult.wifi => 'WiFi (active)',
      ConnectivityResult.ethernet => 'Ethernet',
      ConnectivityResult.vpn => 'VPN',
      ConnectivityResult.bluetooth => 'Bluetooth',
      ConnectivityResult.other => 'Other',
      ConnectivityResult.none => 'Not connected',
    };
  }

  bool _isWifiInterface(String name) =>
      name.startsWith('wlan') || name.startsWith('wifi') || name == 'en0';

  bool _isCellularInterface(String name) =>
      name.contains('rmnet') ||
      name.contains('ccmni') ||
      name.contains('pdp') ||
      name.contains('wwan') ||
      name.startsWith('rmnet') ||
      name.contains('cell');

  Future<AndroidNetworkInfo> _readAndroidNetworkInfo() async {
    if (!Platform.isAndroid) return const AndroidNetworkInfo();

    final interfaces = <String, AndroidInterfaceSnapshot>{};

    try {
      final addrResult = await Process.run('ip', ['-o', 'addr', 'show']);
      final lines = const LineSplitter().convert('${addrResult.stdout}');
      for (final line in lines) {
        final ipv4Match = RegExp(r'^\d+:\s+(\S+)\s+inet\s+(\d+\.\d+\.\d+\.\d+)/(\d+)(?:\s+brd\s+(\d+\.\d+\.\d+\.\d+))?')
            .firstMatch(line);
        if (ipv4Match != null) {
          final name = ipv4Match.group(1)!;
          interfaces[name] = (interfaces[name] ?? AndroidInterfaceSnapshot(name: name)).copyWith(
            ipv4: ipv4Match.group(2),
            subnetMask: _prefixToMask(int.parse(ipv4Match.group(3)!)),
            broadcast: ipv4Match.group(4),
          );
          continue;
        }

        final ipv6Match =
            RegExp(r'^\d+:\s+(\S+)\s+inet6\s+([0-9a-fA-F:]+)/\d+').firstMatch(line);
        if (ipv6Match != null) {
          final name = ipv6Match.group(1)!;
          interfaces[name] = (interfaces[name] ?? AndroidInterfaceSnapshot(name: name)).copyWith(
            ipv6: ipv6Match.group(2),
          );
        }
      }
    } catch (_) {}

    try {
      final routeResult = await Process.run('ip', ['route', 'show']);
      final lines = const LineSplitter().convert('${routeResult.stdout}');
      for (final line in lines) {
        final defaultMatch =
            RegExp(r'^default via (\d+\.\d+\.\d+\.\d+) dev (\S+)').firstMatch(line);
        if (defaultMatch != null) {
          final gateway = defaultMatch.group(1)!;
          final name = defaultMatch.group(2)!;
          interfaces[name] = (interfaces[name] ?? AndroidInterfaceSnapshot(name: name)).copyWith(
            gateway: gateway,
          );
        }
      }
    } catch (_) {}

    final dnsByInterface = await _readDnsByInterface();
    final fallbackDns = <String>{};
    for (final entry in dnsByInterface.entries) {
      if (entry.key == '_fallback') {
        fallbackDns.addAll(entry.value);
        continue;
      }
      final existing = interfaces[entry.key];
      if (existing != null) {
        interfaces[entry.key] = existing.copyWith(dnsServers: entry.value);
      }
    }

    AndroidInterfaceSnapshot? wifi;
    AndroidInterfaceSnapshot? cellular;
    for (final entry in interfaces.entries) {
      final lower = entry.key.toLowerCase();
      if (wifi == null && _isWifiInterface(lower)) {
        wifi = entry.value.copyWith(networkType: 'WiFi');
      }
      if (cellular == null && _isCellularInterface(lower)) {
        cellular = entry.value.copyWith(networkType: 'Mobile');
      }
    }

    // Fallback: when mobile is active, take the first non-wifi non-loopback IPv4 interface.
    cellular ??= interfaces.values.where((iface) {
      final lower = iface.name.toLowerCase();
      return !_isWifiInterface(lower) &&
          lower != 'lo' &&
          (iface.ipv4?.isNotEmpty ?? false);
    }).cast<AndroidInterfaceSnapshot?>().firstWhere(
          (iface) => iface != null,
          orElse: () => null,
        );

    return AndroidNetworkInfo(
      wifi: wifi,
      cellular: cellular,
      fallbackDns: fallbackDns.toList(),
    );
  }

  Future<Map<String, List<String>>> _readDnsByInterface() async {
    final result = <String, Set<String>>{};

    try {
      final propResult = await Process.run('getprop', []);
      final lines = const LineSplitter().convert('${propResult.stdout}');
      for (final line in lines) {
        final match = RegExp(r'^\[([^\]]+)\]: \[([^\]]*)\]$').firstMatch(line.trim());
        if (match == null) continue;
        final key = match.group(1)!;
        final value = match.group(2)!.trim();
        if (!_looksLikeIp(value)) continue;

        if (key.startsWith('net.dns')) {
          (result['_fallback'] ??= <String>{}).add(value);
          continue;
        }

        final ifaceMatch = RegExp(r'net\.([A-Za-z0-9_.-]+)\.dns\d+$').firstMatch(key);
        if (ifaceMatch != null) {
          final iface = ifaceMatch.group(1)!;
          (result[iface] ??= <String>{}).add(value);
        }
      }
    } catch (_) {}

    return {
      for (final entry in result.entries) entry.key: entry.value.toList(),
    };
  }

  String? _joinDns(List<String> servers) {
    if (servers.isEmpty) return null;
    final unique = <String>[];
    for (final server in servers) {
      if (server.isEmpty || unique.contains(server)) continue;
      unique.add(server);
    }
    return unique.isEmpty ? null : unique.join(', ');
  }

  bool _looksLikeIp(String value) =>
      RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(value) ||
      value.contains(':');

  String _prefixToMask(int prefix) {
    final mask = <int>[];
    var remaining = prefix;
    for (var i = 0; i < 4; i++) {
      final bits = remaining >= 8 ? 8 : remaining;
      final octet = bits == 0 ? 0 : (0xff << (8 - bits)) & 0xff;
      mask.add(octet);
      remaining -= bits;
      if (remaining < 0) remaining = 0;
    }
    return mask.join('.');
  }

  String? _cleanQuoted(String? value) {
    if (value == null) return null;
    var cleaned = value.trim();
    if (cleaned.startsWith('"') && cleaned.endsWith('"') && cleaned.length >= 2) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    if (cleaned == '<unknown ssid>' || cleaned.isEmpty) return null;
    return cleaned;
  }
}

final deviceNetworkInfoProvider =
    NotifierProvider.autoDispose<DeviceNetworkInfoNotifier, DeviceNetworkInfoState>(
  DeviceNetworkInfoNotifier.new,
);

class AndroidNetworkInfo {
  final AndroidInterfaceSnapshot? wifi;
  final AndroidInterfaceSnapshot? cellular;
  final List<String> fallbackDns;

  const AndroidNetworkInfo({
    this.wifi,
    this.cellular,
    this.fallbackDns = const [],
  });
}

class AndroidInterfaceSnapshot {
  final String name;
  final String? ipv4;
  final String? subnetMask;
  final String? gateway;
  final List<String> dnsServers;
  final String? ipv6;
  final String? broadcast;
  final String? networkType;

  const AndroidInterfaceSnapshot({
    required this.name,
    this.ipv4,
    this.subnetMask,
    this.gateway,
    this.dnsServers = const [],
    this.ipv6,
    this.broadcast,
    this.networkType,
  });

  AndroidInterfaceSnapshot copyWith({
    String? name,
    String? ipv4,
    String? subnetMask,
    String? gateway,
    List<String>? dnsServers,
    String? ipv6,
    String? broadcast,
    String? networkType,
  }) {
    return AndroidInterfaceSnapshot(
      name: name ?? this.name,
      ipv4: ipv4 ?? this.ipv4,
      subnetMask: subnetMask ?? this.subnetMask,
      gateway: gateway ?? this.gateway,
      dnsServers: dnsServers ?? this.dnsServers,
      ipv6: ipv6 ?? this.ipv6,
      broadcast: broadcast ?? this.broadcast,
      networkType: networkType ?? this.networkType,
    );
  }
}
