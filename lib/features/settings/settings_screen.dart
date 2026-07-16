import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/moustache_header.dart';
import 'theme_settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        ],
      ),
    );
  }
}
