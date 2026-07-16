import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/network_info/network_info_screen.dart';
import 'features/ping/ping_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/theme_settings_provider.dart';
import 'features/subnet_scan/scan_screen.dart';
import 'features/speed_test/speed_test_screen.dart';
import 'theme/app_theme.dart';

class MoustachePingApp extends ConsumerWidget {
  const MoustachePingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(darkModeProvider);

    return MaterialApp(
      title: 'Moustache Ping',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: const _Shell(),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _currentIndex = 0;

  static const _pages = [
    PingScreen(),
    ScanScreen(),
    SpeedTestScreen(),
    NetworkInfoScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radar_rounded),
            label: 'Ping',
          ),
          NavigationDestination(
            icon: Icon(Icons.lan_rounded),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.speed_rounded),
            label: 'Speed',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline_rounded),
            label: 'Info',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
