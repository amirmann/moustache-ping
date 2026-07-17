/// App version shown in Settings.
///
/// Keep [name] in sync with the marketing version in pubspec.yaml
/// (`version: name+build` — only [name] is shown to users).
class AppVersion {
  static const name = '1.0.12';

  /// Display label for Settings — marketing version only (no build number).
  static String get label => name;
}
