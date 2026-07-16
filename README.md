# Moustache Ping 🥸

A network utility Android app built with Flutter.

## Features

### 1. Ping
- Ping any IP address or hostname
- Continuous or fixed-count mode (10 packets)
- Live RTT display per packet with TTL
- Packet loss and average RTT summary

### 2. Subnet Scanner
- Auto-detects your current WiFi subnet (e.g. `192.168.1`)
- Editable subnet field — override with any subnet you like
- Concurrent ICMP scan of all 254 hosts
- Reverse-DNS hostname discovery (shown when the network provides PTR records)
- **Before/After diff**: save a scan as a baseline, plug or unplug a device, rescan, and see exactly which devices were added or removed (highlighted green/red)
- Persistent baseline history stored locally

### 3. Speed Test
- In-app speed test via **fast.com** servers
- Animated speed dial showing live download/upload progress
- Results: Download Mbps, Upload Mbps
- History of past tests with timestamp

### 4. Network Info
- WiFi and Cellular sections with connection status
- WiFi: SSID, BSSID, IP, subnet mask, gateway, DNS, broadcast, IPv6
- Cellular: network type, IP (when on mobile data), DNS
- Refresh button; location permission requested for SSID on Android 10+

## Tech Stack

| Concern | Package |
|---|---|
| UI / Framework | Flutter 3.44+ (Material 3, dark theme) |
| State management | Riverpod 3.x (`Notifier` + `NotifierProvider`) |
| ICMP Ping | `dart_ping` 9.x |
| Subnet scan | `network_tools` + `network_tools_flutter` |
| WiFi info | `network_info_plus` |
| Speed test | `flutter_internet_speed_test_pro` |
| Local storage | `hive_ce` + `hive_ce_flutter` |

## Permissions (Android)

```xml
INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE,
ACCESS_FINE_LOCATION, CHANGE_WIFI_MULTICAST_STATE
```

Location permission is required on Android 10+ to read the WiFi SSID for subnet auto-detection.

## Building

```bash
# Prerequisites: Flutter 3.44+, Android SDK, Java 17+
flutter pub get
dart run build_runner build
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

## Versioning

The version is tracked in `pubspec.yaml` (`version: X.Y.Z+build`).  
Each release on GitHub is tagged `vX.Y.Z` with an auto-generated changelog and the release APK attached.

## License

MIT
