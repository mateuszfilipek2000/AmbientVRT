/// The capture platform that produced a snapshot.
///
/// Wire values match `manifest.schema.json`'s `platform` enum exactly.
enum Platform {
  /// Flutter widget previews captured via the Flutter adapter.
  flutter('flutter'),

  /// React Native / Storybook stories captured via the RN adapter.
  reactNative('react-native');

  const Platform(this.wireName);

  /// The string form used in the manifest JSON (e.g. `react-native`).
  final String wireName;

  /// Lookup table from [wireName] to the enum value, for deserialization.
  static final Map<String, Platform> byWireName = {
    for (final platform in Platform.values) platform.wireName: platform,
  };
}
