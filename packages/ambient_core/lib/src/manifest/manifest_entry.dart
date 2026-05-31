import 'json_reader.dart';
import 'platform.dart';
import 'variant.dart';

/// One captured snapshot's record within a manifest.
///
/// Mirrors the `entry` definition in `manifest.schema.json`.
class ManifestEntry {
  /// Creates a manifest entry. Callers are responsible for supplying values
  /// that satisfy the schema; [ManifestEntry.fromReader] enforces this when
  /// deserializing.
  const ManifestEntry({
    required this.id,
    required this.platform,
    required this.width,
    required this.height,
    required this.dpr,
    required this.contentHash,
    required this.envFingerprint,
    required this.imagePath,
    this.variant,
  });

  /// Reads an entry from a manifest object via [reader], validating every
  /// field against the schema.
  factory ManifestEntry.fromReader(JsonReader reader) {
    reader.rejectUnknownKeys(const {
      'id',
      'platform',
      'variant',
      'width',
      'height',
      'dpr',
      'contentHash',
      'envFingerprint',
      'imagePath',
    });

    final variantMap = reader.optionalMap('variant');
    return ManifestEntry(
      id: reader.requireString('id', minLength: 1),
      platform: reader.requireEnum('platform', Platform.byWireName),
      variant: variantMap == null
          ? null
          : Variant.fromReader(
              JsonReader(variantMap, reader.childLocation('variant')),
            ),
      width: reader.requirePositiveInt('width'),
      height: reader.requirePositiveInt('height'),
      dpr: reader.requirePositiveNum('dpr'),
      contentHash: reader.requireString(
        'contentHash',
        pattern: _contentHashPattern,
        patternDescription:
            'must be a 64-character lowercase hex SHA-256 digest',
      ),
      envFingerprint: reader.requireString('envFingerprint', minLength: 1),
      imagePath: reader.requireString(
        'imagePath',
        pattern: _imagePathPattern,
        patternDescription:
            'must be a relative path ending in ".png" with no ".." segments',
      ),
    );
  }

  /// SHA-256 lowercase hex.
  static final RegExp _contentHashPattern = RegExp(r'^[a-f0-9]{64}$');

  /// Relative path, no leading slash, no `..`, ending in `.png`.
  static final RegExp _imagePathPattern = RegExp(r'^(?!/)(?!.*\.\.).+\.png$');

  /// Stable, semantic, platform-derived snapshot ID. Never positional.
  final String id;

  /// Capture platform that produced this snapshot.
  final Platform platform;

  /// Structured variant dimensions, or `null` when there are none.
  final Variant? variant;

  /// Logical width in pixels (> 0).
  final int width;

  /// Logical height in pixels (> 0).
  final int height;

  /// Device pixel ratio used to render (> 0).
  final double dpr;

  /// SHA-256 (lowercase hex) of the PNG bytes.
  final String contentHash;

  /// Identifier of the capture environment.
  final String envFingerprint;

  /// Relative path to the PNG within the run dir.
  final String imagePath;

  /// Serializes to a JSON map, omitting [variant] when absent.
  Map<String, Object?> toJson() => {
    'id': id,
    'platform': platform.wireName,
    if (variant != null) 'variant': variant!.toJson(),
    'width': width,
    'height': height,
    'dpr': dpr,
    'contentHash': contentHash,
    'envFingerprint': envFingerprint,
    'imagePath': imagePath,
  };

  @override
  bool operator ==(Object other) =>
      other is ManifestEntry &&
      other.id == id &&
      other.platform == platform &&
      other.variant == variant &&
      other.width == width &&
      other.height == height &&
      other.dpr == dpr &&
      other.contentHash == contentHash &&
      other.envFingerprint == envFingerprint &&
      other.imagePath == imagePath;

  @override
  int get hashCode => Object.hash(
    id,
    platform,
    variant,
    width,
    height,
    dpr,
    contentHash,
    envFingerprint,
    imagePath,
  );

  @override
  String toString() => 'ManifestEntry(id: $id, platform: ${platform.wireName})';
}
