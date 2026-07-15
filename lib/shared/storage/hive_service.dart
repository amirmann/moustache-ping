import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../features/subnet_scan/scan_snapshot.dart';
import '../../features/speed_test/speed_result.dart';

class HiveService {
  static const _scanBox = 'scan_snapshots';
  static const _speedBox = 'speed_results';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ScanSnapshotAdapter());
    Hive.registerAdapter(SpeedResultAdapter());
    await Hive.openBox<ScanSnapshot>(_scanBox);
    await Hive.openBox<SpeedResult>(_speedBox);
  }

  static Box<ScanSnapshot> get scanBox => Hive.box<ScanSnapshot>(_scanBox);
  static Box<SpeedResult> get speedBox => Hive.box<SpeedResult>(_speedBox);

  static Future<void> saveScanSnapshot(ScanSnapshot snapshot) async {
    await scanBox.add(snapshot);
  }

  static List<ScanSnapshot> getAllSnapshots() {
    return scanBox.values.toList().reversed.toList();
  }

  static Future<void> saveSpeedResult(SpeedResult result) async {
    await speedBox.add(result);
  }

  static List<SpeedResult> getAllSpeedResults() {
    return speedBox.values.toList().reversed.toList();
  }
}
