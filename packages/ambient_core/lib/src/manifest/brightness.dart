/// The brightness dimension of a snapshot variant.
///
/// Wire values match `manifest.schema.json`'s `variant.brightness` enum.
enum Brightness {
  /// Light theme / light mode.
  light('light'),

  /// Dark theme / dark mode.
  dark('dark');

  const Brightness(this.wireName);

  /// The string form used in the manifest JSON.
  final String wireName;

  /// Lookup table from [wireName] to the enum value, for deserialization.
  static final Map<String, Brightness> byWireName = {
    for (final brightness in Brightness.values) brightness.wireName: brightness,
  };
}
