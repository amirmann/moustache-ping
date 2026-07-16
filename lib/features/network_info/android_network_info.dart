import 'package:flutter/services.dart';

class NativeInterfaceInfo {
  const NativeInterfaceInfo({
    this.interfaceName,
    this.ipv4,
    this.ipv6,
    this.subnetMask,
    this.gateway,
    this.dnsServers = const [],
    this.connected = false,
  });

  final String? interfaceName;
  final String? ipv4;
  final String? ipv6;
  final String? subnetMask;
  final String? gateway;
  final List<String> dnsServers;
  final bool connected;

  factory NativeInterfaceInfo.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const NativeInterfaceInfo();
    return NativeInterfaceInfo(
      interfaceName: map['interfaceName'] as String?,
      ipv4: map['ipv4'] as String?,
      ipv6: map['ipv6'] as String?,
      subnetMask: map['subnetMask'] as String?,
      gateway: map['gateway'] as String?,
      dnsServers: _parseDns(map['dnsServers']),
      connected: map['connected'] == true,
    );
  }

  static List<String> _parseDns(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((e) => e.trim().substringBefore('%'))
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }
}

extension on String {
  String substringBefore(String sep) {
    final i = indexOf(sep);
    return i < 0 ? this : substring(0, i);
  }
}

class AndroidNetworkInfoBridge {
  static const _channel = MethodChannel('com.amirmann.moustache_ping/network_info');

  static Future<({NativeInterfaceInfo wifi, NativeInterfaceInfo cellular})> fetch() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getNetworkInterfaces');
    return (
      wifi: NativeInterfaceInfo.fromMap(result?['wifi'] as Map<dynamic, dynamic>?),
      cellular: NativeInterfaceInfo.fromMap(result?['cellular'] as Map<dynamic, dynamic>?),
    );
  }
}
