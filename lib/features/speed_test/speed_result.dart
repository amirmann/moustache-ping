import 'package:hive_ce/hive.dart';

part 'speed_result.g.dart';

@HiveType(typeId: 1)
class SpeedResult extends HiveObject {
  @HiveField(0)
  final double downloadMbps;

  @HiveField(1)
  final double uploadMbps;

  @HiveField(2)
  final int latencyMs;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String provider;

  SpeedResult({
    required this.downloadMbps,
    required this.uploadMbps,
    required this.latencyMs,
    required this.timestamp,
    required this.provider,
  });
}
