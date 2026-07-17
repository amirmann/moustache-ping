import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moustache_ping/features/network_info/network_info_provider.dart';
import 'package:moustache_ping/features/network_info/network_info_screen.dart';
import 'package:moustache_ping/features/ping/ping_provider.dart';
import 'package:moustache_ping/features/ping/ping_screen.dart';
import 'package:moustache_ping/features/settings/settings_screen.dart';
import 'package:moustache_ping/features/settings/theme_settings_provider.dart';
import 'package:moustache_ping/features/speed_test/speed_result.dart';
import 'package:moustache_ping/features/speed_test/speed_test_provider.dart';
import 'package:moustache_ping/features/speed_test/speed_test_screen.dart';
import 'package:moustache_ping/features/subnet_scan/scan_provider.dart';
import 'package:moustache_ping/features/subnet_scan/scan_screen.dart';
import 'package:moustache_ping/theme/app_theme.dart';

/// Captures phone screenshots for the GitHub README (light + dark).
///
/// Uses **fictional demo data only** (DemoNet, 192.168.1.x, 2001:db8::/32).
/// Never includes real SSIDs, BSSIDs, or personal network details.
///
/// Fonts are loaded from [test/fonts] so text/icons render (headless Linux
/// otherwise draws empty tofu rectangles).
///
/// Generate / refresh PNGs:
///   ./tool/capture_screenshots.sh
///   # or:
///   flutter test test/screenshot_capture_test.dart --update-goldens
///
/// Output:
///   docs/screenshots/light/*.png
///   docs/screenshots/dark/*.png
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadScreenshotFonts();
  });

  const phone = Size(420, 912);

  for (final dark in [false, true]) {
    final themeName = dark ? 'dark' : 'light';
    final screens = <String, Widget>{
      '01-ping': const PingScreen(),
      '02-scan': const ScanScreen(),
      '03-speed': const SpeedTestScreen(),
      '04-info': const NetworkInfoScreen(),
      '05-settings': const SettingsScreen(),
    };

    for (final entry in screens.entries) {
      testWidgets(
        '$themeName ${entry.key}',
        (tester) async {
          final binding = TestWidgetsFlutterBinding.ensureInitialized();
          addTearDown(() async {
            await binding.setSurfaceSize(null);
            binding.platformDispatcher.views.first.resetPhysicalSize();
            binding.platformDispatcher.views.first.resetDevicePixelRatio();
          });
          await binding.setSurfaceSize(phone);
          binding.platformDispatcher.views.first.physicalSize =
              Size(phone.width * 3, phone.height * 3);
          binding.platformDispatcher.views.first.devicePixelRatio = 3;

          Directory('docs/screenshots/$themeName').createSync(recursive: true);

          final baseTheme = dark ? AppTheme.dark : AppTheme.light;
          final themed = _screenshotTheme(baseTheme);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                pingProvider.overrideWith(_DemoPingNotifier.new),
                scanProvider.overrideWith(_DemoScanNotifier.new),
                speedTestProvider.overrideWith(_DemoSpeedNotifier.new),
                deviceNetworkInfoProvider
                    .overrideWith(_DemoNetworkInfoNotifier.new),
                darkModeProvider.overrideWith(
                  () => _DemoThemeNotifier(dark),
                ),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: themed,
                darkTheme: themed,
                themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                builder: (context, child) {
                  return DefaultTextStyle(
                    style: const TextStyle(
                      fontFamily: 'ScreenshotSans',
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                home: MediaQuery(
                  data: const MediaQueryData(
                    size: phone,
                    devicePixelRatio: 3,
                    padding: EdgeInsets.only(top: 24, bottom: 16),
                  ),
                  child: SizedBox(
                    width: phone.width,
                    height: phone.height,
                    child: Scaffold(
                      body: entry.value,
                      bottomNavigationBar: NavigationBar(
                        selectedIndex: _navIndexFor(entry.key),
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
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));

          final fields = find.byType(TextField);
          if (tester.any(fields)) {
            if (entry.key == '01-ping') {
              await tester.enterText(fields.first, '8.8.8.8');
            } else if (entry.key == '02-scan') {
              await tester.enterText(fields.first, '192.168.1.0/24');
            }
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
          }

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../docs/screenshots/$themeName/${entry.key}.png',
            ),
          );
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    }
  }
}

/// Load a dedicated screenshot font family (avoids empty system "Roboto").
///
/// AppBar/button styles that request bold weights are mapped onto this single
/// Regular face via [_screenshotTheme] so glyphs never become tofu boxes.
Future<void> _loadScreenshotFonts() async {
  Future<ByteData> bytes(String path) async {
    final data = await File(path).readAsBytes();
    return ByteData.sublistView(Uint8List.fromList(data));
  }

  // Register each face; the TTF OS/2 weight table selects the right file.
  const family = 'ScreenshotSans';
  for (final path in [
    'assets/fonts/Roboto-Regular.ttf',
    'assets/fonts/Roboto-Medium.ttf',
    'assets/fonts/Roboto-Bold.ttf',
  ]) {
    final loader = FontLoader(family)..addFont(bytes(path));
    await loader.load();
  }

  final icons = FontLoader('MaterialIcons')
    ..addFont(bytes('assets/fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

/// Theme tuned for headless goldens: one loaded face, every style uses it.
ThemeData _screenshotTheme(ThemeData base) {
  const family = 'ScreenshotSans';

  TextStyle regularize(TextStyle? style) {
    final baseStyle = style ?? const TextStyle();
    return baseStyle.copyWith(
      fontFamily: family,
      fontWeight: FontWeight.w400,
      fontFamilyFallback: const [family],
      // Prevent "bold" synthesis from selecting a missing face.
      fontVariations: const [],
    );
  }

  TextTheme regularizeTheme(TextTheme theme) => TextTheme(
        displayLarge: regularize(theme.displayLarge),
        displayMedium: regularize(theme.displayMedium),
        displaySmall: regularize(theme.displaySmall),
        headlineLarge: regularize(theme.headlineLarge),
        headlineMedium: regularize(theme.headlineMedium),
        headlineSmall: regularize(theme.headlineSmall),
        titleLarge: regularize(theme.titleLarge),
        titleMedium: regularize(theme.titleMedium),
        titleSmall: regularize(theme.titleSmall),
        bodyLarge: regularize(theme.bodyLarge),
        bodyMedium: regularize(theme.bodyMedium),
        bodySmall: regularize(theme.bodySmall),
        labelLarge: regularize(theme.labelLarge),
        labelMedium: regularize(theme.labelMedium),
        labelSmall: regularize(theme.labelSmall),
      );

  return base.copyWith(
    textTheme: regularizeTheme(base.textTheme),
    primaryTextTheme: regularizeTheme(base.primaryTextTheme),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: regularize(base.appBarTheme.titleTextStyle).copyWith(
            fontSize: 20,
            color: base.appBarTheme.titleTextStyle?.color ??
                base.colorScheme.onSurface,
          ),
      toolbarTextStyle: regularize(base.appBarTheme.toolbarTextStyle),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: base.colorScheme.primary,
        foregroundColor: base.colorScheme.onPrimary,
        textStyle: const TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w400,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: base.colorScheme.primary,
        textStyle: const TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: regularize(base.chipTheme.labelStyle),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: regularize(base.inputDecorationTheme.labelStyle),
      hintStyle: regularize(base.inputDecorationTheme.hintStyle),
      floatingLabelStyle:
          regularize(base.inputDecorationTheme.floatingLabelStyle),
    ),
  );
}

int _navIndexFor(String name) {
  return switch (name) {
    '01-ping' => 0,
    '02-scan' => 1,
    '03-speed' => 2,
    '04-info' => 3,
    '05-settings' => 4,
    _ => 0,
  };
}

/// Fictional demo data for public screenshots — not a real network.
class _DemoPingNotifier extends PingNotifier {
  @override
  PingState build() {
    return PingState(
      status: PingStatus.stopped,
      target: '8.8.8.8',
      entries: [
        PingEntry(seq: 0, rttMs: 13.2, ttl: 118),
        PingEntry(seq: 1, rttMs: 12.8, ttl: 118),
        PingEntry(seq: 2, rttMs: 14.1, ttl: 118),
        PingEntry(seq: 3, rttMs: 13.0, ttl: 118),
        PingEntry(seq: 4, rttMs: 15.2, ttl: 118),
        PingEntry(seq: 5, timedOut: true),
        PingEntry(seq: 6, rttMs: 12.5, ttl: 118),
        PingEntry(seq: 7, rttMs: 13.9, ttl: 118),
      ],
    );
  }
}

class _DemoScanNotifier extends ScanNotifier {
  @override
  ScanState build() {
    final hosts = [
      ScanResult('192.168.1.1', hostname: 'gateway'),
      ScanResult('192.168.1.10', hostname: 'chromecast'),
      ScanResult('192.168.1.20', hostname: 'desktop-pc'),
      ScanResult('192.168.1.42', hostname: 'media-pc'),
      ScanResult('192.168.1.55'),
      ScanResult('192.168.1.77', hostname: 'guest-phone'),
    ];
    return ScanState(
      status: ScanStatus.done,
      cidr: '192.168.1.0/24',
      hosts: hosts,
      previousHosts: [
        ScanResult('192.168.1.1', hostname: 'gateway'),
        ScanResult('192.168.1.10', hostname: 'chromecast'),
        ScanResult('192.168.1.20', hostname: 'desktop-pc'),
        ScanResult('192.168.1.33', hostname: 'old-laptop'),
      ],
      diffSource: 'previous scan',
      diff: ScanDiff(
        [
          ScanResult('192.168.1.42', hostname: 'media-pc'),
          ScanResult('192.168.1.55'),
          ScanResult('192.168.1.77', hostname: 'guest-phone'),
        ],
        [
          ScanResult('192.168.1.33', hostname: 'old-laptop'),
        ],
      ),
      progress: 1,
    );
  }

  @override
  Future<void> detectSubnet() async {}
}

class _DemoSpeedNotifier extends SpeedTestNotifier {
  @override
  SpeedTestState build() {
    return SpeedTestState(
      status: SpeedTestStatus.done,
      downloadMbps: 120.5,
      uploadMbps: 35.2,
      progress: 1,
      history: [
        SpeedResult(
          downloadMbps: 120.5,
          uploadMbps: 35.2,
          latencyMs: 0,
          timestamp: DateTime(2026, 1, 15, 18, 30),
          provider: 'fast.com',
        ),
        SpeedResult(
          downloadMbps: 98.0,
          uploadMbps: 32.1,
          latencyMs: 0,
          timestamp: DateTime(2026, 1, 14, 21, 5),
          provider: 'fast.com',
        ),
      ],
    );
  }
}

class _DemoNetworkInfoNotifier extends DeviceNetworkInfoNotifier {
  @override
  DeviceNetworkInfoState build() {
    return const DeviceNetworkInfoState(
      status: NetworkInfoStatus.ready,
      wifi: InterfaceInfo(
        label: 'WiFi',
        connected: true,
        networkType: 'WiFi',
        ssid: 'DemoNet',
        bssid: 'aa:bb:cc:dd:ee:ff',
        ipAddress: '192.168.1.42',
        subnetMask: '255.255.255.0',
        gateway: '192.168.1.1',
        dnsServers: ['192.168.1.1', '1.1.1.1'],
        broadcast: '192.168.1.255',
        ipv6: '2001:db8::42',
      ),
      cellular: InterfaceInfo(
        label: 'Cellular',
        connected: false,
        networkType: 'Not connected',
      ),
    );
  }

  @override
  Future<void> refresh() async {}
}

class _DemoThemeNotifier extends ThemeSettingsNotifier {
  _DemoThemeNotifier(this._dark);
  final bool _dark;

  @override
  bool build() => _dark;

  @override
  Future<void> setDarkMode(bool enabled) async {
    state = enabled;
  }
}
