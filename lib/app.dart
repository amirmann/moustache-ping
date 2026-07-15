import 'package:flutter/material.dart';
import 'features/ping/ping_screen.dart';
import 'features/subnet_scan/scan_screen.dart';
import 'features/speed_test/speed_test_screen.dart';
import 'theme/app_theme.dart';

class MoustachePingApp extends StatelessWidget {
  const MoustachePingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moustache Ping',
      theme: AppTheme.dark,
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
        ],
      ),
    );
  }
}
