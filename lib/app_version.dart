/// App version shown in Settings.
///
/// Keep in sync with `version:` in pubspec.yaml (name+build before the `+`).
class AppVersion {
  static const name = '1.0.11';
  static const build = '12';

  static String get label => '$name ($build)';
}
