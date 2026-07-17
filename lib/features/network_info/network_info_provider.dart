import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final String? wifiPermissionNote;
  final String? error;

  const DeviceNetworkInfoState({
    this.status = NetworkInfoStatus.idle,
    this.wifi = const InterfaceInfo(label: 'WiFi'),
    this.cellular = const InterfaceInfo(label: 'Cellular'),
    this.wifiPermissionNote,
    this.error,
  });

  DeviceNetworkInfoState copyWith({
    NetworkInfoStatus? status,
    InterfaceInfo? wifi,
    InterfaceInfo? cellular,
    String? wifiPermissionNote,
    String? error,
  }) {
    return DeviceNetworkInfoState(
      status: status ?? this.status,
      wifi: wifi ?? this.wifi,
      cellular: cellular ?? this.cellular,
      wifiPermissionNote: wifiPermissionNote,
      error: error,
    );
  }
}

class DeviceNetworkInfoNotifier extends Notifier<DeviceNetworkInfoState> {
  final _networkInfo = NetworkInfo();
  final _connectivity = Connectivity();

  @override
  DeviceNetworkInfoState build() => const DeviceNetworkInfoState();

  Future<void> refresh({bool forceLocationForSsid = false}) async {
    state = state.copyWith(status: NetworkInfoStatus.loading, error: null);

    try {
      final permissionNote = Platform.isAndroid
          ? await _ensureWifiIdentityPermissions(
              forceLocation: forceLocationForSsid,
            )
          : null;

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

      var wifi = await _loadWifiInfo(
        connected: wifiConnected,
        native: nativeWifi,
      );

      // Android 10+: SSID is often still location-gated even with Nearby Wi-Fi.
      // Request location only when SSID is still blank (not on every app launch).
      var note = permissionNote;
      if (Platform.isAndroid &&
          wifiConnected &&
          _isMissingWifiIdentity(wifi.ssid) &&
          !forceLocationForSsid) {
        final fallbackNote = await _ensureLocationForSsid();
        if (Platform.isAndroid) {
          final native = await AndroidNetworkInfoBridge.fetch();
          nativeWifi = native.wifi;
        }
        wifi = await _loadWifiInfo(
          connected: wifiConnected,
          native: nativeWifi,
        );
        note = _isMissingWifiIdentity(wifi.ssid) ? fallbackNote ?? note : null;
      } else if (!_isMissingWifiIdentity(wifi.ssid)) {
        note = null;
      }

      final cellular = _loadCellularInfo(
        connected: cellularConnected,
        native: nativeCellular,
        connectivity: connectivity,
      );

      state = DeviceNetworkInfoState(
        status: NetworkInfoStatus.ready,
        wifi: wifi,
        cellular: cellular,
        wifiPermissionNote: note,
      );
    } catch (e) {
      state = state.copyWith(
        status: NetworkInfoStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Android 13+: request Nearby Wi-Fi Devices first (neverForLocation in manifest).
  /// Older Android: no-op for nearby; location is requested only if SSID is blank.
  Future<String?> _ensureWifiIdentityPermissions({
    required bool forceLocation,
  }) async {
    final sdk = await AndroidNetworkInfoBridge.sdkInt() ?? 0;

    if (sdk >= 33) {
      final nearby = await Permission.nearbyWifiDevices.status;
      if (!nearby.isGranted) {
        await Permission.nearbyWifiDevices.request();
      }
    }

    if (forceLocation) {
      return _ensureLocationForSsid();
    }
    return null;
  }

  Future<String?> _ensureLocationForSsid() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isGranted) {
      // Permission alone is not enough — Android also requires Location on.
      return 'Turn on device Location (system setting) to show Wi‑Fi name.';
    }

    status = await Permission.locationWhenInUse.request();
    if (status.isGranted) return null;

    return 'Location permission is only used to read your Wi‑Fi name (SSID), '
        'not for tracking. Tap refresh after allowing it.';
  }

  bool _isMissingWifiIdentity(String? ssid) {
    if (ssid == null) return true;
    final cleaned = ssid.trim();
    return cleaned.isEmpty ||
        cleaned == '<unknown ssid>' ||
        cleaned == 'Permission required';
  }

  Future<InterfaceInfo> _loadWifiInfo({
    required bool connected,
    required NativeInterfaceInfo native,
  }) async {
    final pluginSsid = _cleanQuoted(await _networkInfo.getWifiName());
    final pluginBssid = await _networkInfo.getWifiBSSID();
    final ssid = _cleanQuoted(native.ssid) ?? pluginSsid;
    final bssid = _cleanBssid(native.bssid) ?? _cleanBssid(pluginBssid);

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

  String? _cleanBssid(String? value) {
    if (value == null) return null;
    final cleaned = value.trim();
    if (cleaned.isEmpty) return null;
    final lower = cleaned.toLowerCase();
    if (lower == '02:00:00:00:00:00' || lower == '00:00:00:00:00:00') {
      return null;
    }
    return cleaned;
  }
}

final deviceNetworkInfoProvider =
    NotifierProvider.autoDispose<DeviceNetworkInfoNotifier, DeviceNetworkInfoState>(
  DeviceNetworkInfoNotifier.new,
);
