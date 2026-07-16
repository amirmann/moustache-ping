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
      final dns = await _readDnsServers();

      final wifiConnected = connectivity == ConnectivityResult.wifi ||
          connectivity == ConnectivityResult.ethernet;
      final cellularConnected = connectivity == ConnectivityResult.mobile;

      final wifi = await _loadWifiInfo(
        connected: wifiConnected,
        dns: dns,
        locationGranted: locationStatus.granted,
      );

      final cellular = await _loadCellularInfo(
        connected: cellularConnected,
        dns: dns,
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
    required String? dns,
    required bool locationGranted,
  }) async {
    final ssidRaw = await _networkInfo.getWifiName();
    final ssid = _cleanQuoted(ssidRaw);

    return InterfaceInfo(
      label: 'WiFi',
      connected: connected,
      networkType: connected ? 'WiFi' : 'Not connected',
      ssid: locationGranted ? ssid : 'Permission required',
      bssid: locationGranted ? await _networkInfo.getWifiBSSID() : 'Permission required',
      ipAddress: await _networkInfo.getWifiIP(),
      subnetMask: await _networkInfo.getWifiSubmask(),
      gateway: await _networkInfo.getWifiGatewayIP(),
      broadcast: await _networkInfo.getWifiBroadcast(),
      ipv6: await _networkInfo.getWifiIPv6(),
      dnsServers: dns,
    );
  }

  Future<InterfaceInfo> _loadCellularInfo({
    required bool connected,
    required String? dns,
    required ConnectivityResult connectivity,
  }) async {
    final cellularIp = await _findCellularIp();

    return InterfaceInfo(
      label: 'Cellular',
      connected: connected,
      networkType: _connectivityLabel(connectivity),
      ipAddress: cellularIp,
      subnetMask: connected ? 'Not available' : null,
      gateway: connected ? 'Not available' : null,
      dnsServers: dns,
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

  Future<String?> _findCellularIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (_isWifiInterface(name)) continue;
        if (!_isCellularInterface(name)) continue;

        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }

      // Fallback: any non-wifi IPv4 when on mobile data.
      for (final iface in interfaces) {
        if (_isWifiInterface(iface.name.toLowerCase())) continue;
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
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

  Future<String?> _readDnsServers() async {
    if (!Platform.isAndroid) return 'Not available';

    final servers = <String>[];
    for (var i = 1; i <= 4; i++) {
      try {
        final result = await Process.run('getprop', ['net.dns$i']);
        final value = (result.stdout as String).trim();
        if (value.isNotEmpty && value != 'null') {
          servers.add(value);
        }
      } catch (_) {}
    }

    if (servers.isEmpty) return 'Not available';
    return servers.join(', ');
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
