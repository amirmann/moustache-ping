import 'package:hive_ce/hive.dart';

part 'scan_snapshot.g.dart';

@HiveType(typeId: 0)
class ScanSnapshot extends HiveObject {
  @HiveField(0)
  final String subnet;

  @HiveField(1)
  final List<String> hosts;

  @HiveField(2)
  final DateTime timestamp;

  ScanSnapshot({
    required this.subnet,
    required this.hosts,
    required this.timestamp,
  });

  String get label =>
      '$subnet — ${hosts.length} host${hosts.length == 1 ? '' : 's'} @ ${_fmt(timestamp)}';

  static String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
