import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'android_network_info.dart';

enum NetworkInfoStatus { idle, loading, ready, error }

class InterfaceInfo {
  final String label;
  final String? ssid;
  final String? bssid;
  final String? ipAddress;
  final String? subnetMask;
  final String? gateway;
  final List<String> dnsServers;
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
    this.dnsServers = const [],
    this.ipv6,
    this.broadcast,
    this.networkType,
    this.connected = false,
  });
}

class DeviceNetworkInfoState {
  final NetworkInfoStatus status;
  final InterfaceInfo wifi;
  final InterfaceInfo cellular;
  final String? error;

  const DeviceNetworkInfoState({
    this.status = NetworkInfoStatus.idle,
    this.wifi = const InterfaceInfo(label: 'WiFi'),
    this.cellular = const InterfaceInfo(label: 'Cellular'),
    this.error,
  });

  DeviceNetworkInfoState copyWith({
    NetworkInfoStatus? status,
    InterfaceInfo? wifi,
    InterfaceInfo? cellular,
    String? error,
  }) {
    return DeviceNetworkInfoState(
      status: status ?? this.status,
      wifi: wifi ?? this.wifi,
      cellular: cellular ?? this.cellular,
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
      final connectivity = await _connectivity.checkConnectivity();

      NativeInterfaceInfo nativeWifi = const NativeInterfaceInfo();
      NativeInterfaceInfo nativeCellular = const NativeInterfaceInfo();
      if (Platform.isAndroid) {
        final native = await AndroidNetworkInfoBridge.fetch();
        nativeWifi = native.wifi;
        nativeCellular = native.cellular;
      }

      final wifiConnected = connectivity == ConnectivityResult.wifi ||
          connectivity == ConnectivityResult.ethernet ||
          nativeWifi.connected;
      final cellularConnected =
          connectivity == ConnectivityResult.mobile || nativeCellular.connected;

      final wifi = await _loadWifiInfo(
        connected: wifiConnected,
        native: nativeWifi,
      );

      final cellular = _loadCellularInfo(
        connected: cellularConnected,
        native: nativeCellular,
        connectivity: connectivity,
      );

      state = DeviceNetworkInfoState(
        status: NetworkInfoStatus.ready,
        wifi: wifi,
        cellular: cellular,
      );
    } catch (e) {
      state = state.copyWith(
        status: NetworkInfoStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<InterfaceInfo> _loadWifiInfo({
    required bool connected,
    required NativeInterfaceInfo native,
  }) async {
    // SSID/BSSID may be null without location permission on Android 10+;
    // IP/mask/gateway still come from native LinkProperties (no location).
    final ssid = _cleanQuoted(await _networkInfo.getWifiName());
    final bssid = await _networkInfo.getWifiBSSID();

    return InterfaceInfo(
      label: 'WiFi',
      connected: connected,
      networkType: connected ? 'WiFi' : 'Not connected',
      ssid: ssid,
      bssid: bssid,
      ipAddress: native.ipv4 ?? await _networkInfo.getWifiIP(),
      subnetMask: native.subnetMask ?? await _networkInfo.getWifiSubmask(),
      gateway: native.gateway ?? await _networkInfo.getWifiGatewayIP(),
      broadcast: await _networkInfo.getWifiBroadcast(),
      ipv6: native.ipv6 ?? await _networkInfo.getWifiIPv6(),
      dnsServers: native.dnsServers,
    );
  }

  InterfaceInfo _loadCellularInfo({
    required bool connected,
    required NativeInterfaceInfo native,
    required ConnectivityResult connectivity,
  }) {
    return InterfaceInfo(
      label: 'Cellular',
      connected: connected,
      networkType: connected ? 'Mobile' : _connectivityLabel(connectivity),
      ipAddress: native.ipv4 ?? native.ipv6,
      subnetMask: native.subnetMask,
      gateway: native.gateway,
      ipv6: native.ipv6,
      dnsServers: native.dnsServers,
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
