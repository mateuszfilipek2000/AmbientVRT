import 'errors.dart';

/// A `major.minor` manifest format version.
///
/// The core refuses a manifest whose [major] it does not support; [minor]
/// differences within a supported major are tolerated for forward
/// compatibility.
class ManifestVersion {
  /// Creates a version from its parsed components.
  const ManifestVersion(this.major, this.minor);

  /// The major manifest version this build of ambient_core understands.
  static const int supportedMajor = 1;

  /// The version newly-written manifests should declare.
  static const ManifestVersion current = ManifestVersion(1, 0);

  static final RegExp _pattern = RegExp(r'^[0-9]+\.[0-9]+$');

  /// Parses a `major.minor` string.
  ///
  /// Throws [ManifestFormatException] (located at [location]) if [raw] is not
  /// of the form `<digits>.<digits>`.
  factory ManifestVersion.parse(String raw, {String location = 'manifestVersion'}) {
    if (!_pattern.hasMatch(raw)) {
      throw ManifestFormatException(
        location,
        'must be of the form "major.minor", got "$raw"',
      );
    }
    final parts = raw.split('.');
    return ManifestVersion(int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Major component; gates compatibility.
  final int major;

  /// Minor component; informational within a supported major.
  final int minor;

  /// Whether this build can read a manifest at this version.
  bool get isSupported => major == supportedMajor;

  /// Throws [UnsupportedManifestVersionException] unless [isSupported].
  void ensureSupported() {
    if (!isSupported) {
      throw UnsupportedManifestVersionException(
        requestedVersion: toString(),
        requestedMajor: major,
        supportedMajor: supportedMajor,
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ManifestVersion && other.major == major && other.minor == minor;

  @override
  int get hashCode => Object.hash(major, minor);

  @override
  String toString() => '$major.$minor';
}
