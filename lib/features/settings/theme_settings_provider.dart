import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/storage/hive_service.dart';

class ThemeSettingsNotifier extends Notifier<bool> {
  static const _darkModeKey = 'darkMode';

  @override
  bool build() => HiveService.getSetting<bool>(_darkModeKey) ?? false;

  Future<void> setDarkMode(bool enabled) async {
    state = enabled;
    await HiveService.setSetting(_darkModeKey, enabled);
  }

  Future<void> toggle() => setDarkMode(!state);
}

final darkModeProvider = NotifierProvider<ThemeSettingsNotifier, bool>(
  ThemeSettingsNotifier.new,
);
