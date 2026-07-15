import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'shared/storage/hive_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  final appDocDir = await getApplicationDocumentsDirectory();
  await configureNetworkToolsFlutter(appDocDir.path);
  runApp(const ProviderScope(child: MoustachePingApp()));
}
