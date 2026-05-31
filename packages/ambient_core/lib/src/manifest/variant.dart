import 'brightness.dart';
import 'json_reader.dart';

/// Structured variant dimensions for a snapshot.
///
/// These are kept out of the snapshot ID as structured data so reports can
/// group and filter by them. Every field is optional; an entry without a
/// `variant` key in the manifest has no [Variant] at all.
class Variant {
  /// Creates a variant from any subset of its dimensions.
  const Variant({this.theme, this.brightness, this.locale, this.sizeName});

  /// Reads a [Variant] from a nested manifest object via [reader].
  factory Variant.fromReader(JsonReader reader) {
    reader.rejectUnknownKeys(const {'theme', 'brightness', 'locale', 'sizeName'});
    return Variant(
      theme: reader.optionalString('theme', minLength: 1),
      brightness: reader.optionalEnum('brightness', Brightness.byWireName),
      locale: reader.optionalString('locale', minLength: 1),
      sizeName: reader.optionalString('sizeName', minLength: 1),
    );
  }

  /// Named theme this snapshot was rendered with.
  final String? theme;

  /// Light/dark brightness of this snapshot.
  final Brightness? brightness;

  /// Locale this snapshot was rendered with.
  final String? locale;

  /// Named size preset this snapshot was rendered at.
  final String? sizeName;

  /// Whether no dimension is set.
  bool get isEmpty =>
      theme == null && brightness == null && locale == null && sizeName == null;

  /// Serializes to a JSON map, omitting unset dimensions.
  Map<String, Object?> toJson() => {
    if (theme != null) 'theme': theme,
    if (brightness != null) 'brightness': brightness!.wireName,
    if (locale != null) 'locale': locale,
    if (sizeName != null) 'sizeName': sizeName,
  };

  @override
  bool operator ==(Object other) =>
      other is Variant &&
      other.theme == theme &&
      other.brightness == brightness &&
      other.locale == locale &&
      other.sizeName == sizeName;

  @override
  int get hashCode => Object.hash(theme, brightness, locale, sizeName);

  @override
  String toString() =>
      'Variant(theme: $theme, brightness: $brightness, locale: $locale, '
      'sizeName: $sizeName)';
}
