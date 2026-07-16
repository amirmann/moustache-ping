import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../shared/widgets/moustache_header.dart';
import 'theme_settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _versionLabel = '…';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = '${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _versionLabel = 'Unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = ref.watch(darkModeProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const MoustacheHeader(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              secondary: Icon(
                darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: cs.primary,
              ),
              title: const Text('Dark theme'),
              subtitle: Text(
                darkMode ? 'On' : 'Off — light theme is the default',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              value: darkMode,
              onChanged: (value) =>
                  ref.read(darkModeProvider.notifier).setDarkMode(value),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded, color: cs.primary),
              title: const Text('App version'),
              subtitle: Text(
                _versionLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
