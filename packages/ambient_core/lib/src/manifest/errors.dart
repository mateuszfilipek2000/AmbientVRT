/// Errors raised while parsing or validating a capture manifest.
library;

/// Base type for every manifest-related failure.
///
/// Sealed so callers can exhaustively switch over the failure modes when they
/// need to react differently to a malformed document versus an incompatible
/// version.
sealed class ManifestException implements Exception {
  /// Human-readable description of what went wrong.
  String get message;
}

/// Thrown when a manifest does not conform to `manifest.schema.json`.
///
/// [location] is a dotted/bracketed path to the offending value within the
/// document (e.g. `entries[0].contentHash`), or an empty string for a failure
/// at the document root. [detail] explains the specific rule that was violated.
class ManifestFormatException implements ManifestException {
  /// Creates a located format error.
  ManifestFormatException(this.location, this.detail);

  /// Path to the offending value, e.g. `entries[2].width`. Empty for the root.
  final String location;

  /// Why the value at [location] is invalid.
  final String detail;

  @override
  String get message => location.isEmpty
      ? 'Invalid manifest: $detail'
      : 'Invalid manifest at "$location": $detail';

  @override
  String toString() => 'ManifestFormatException: $message';
}

/// Thrown when a manifest declares a major version this build cannot read.
///
/// Minor-version differences are tolerated (the format is forward-compatible
/// within a major); a differing major is a hard incompatibility.
class UnsupportedManifestVersionException implements ManifestException {
  /// Creates a version-incompatibility error.
  UnsupportedManifestVersionException({
    required this.requestedVersion,
    required this.requestedMajor,
    required this.supportedMajor,
  });

  /// The full `major.minor` string the manifest declared, e.g. `2.0`.
  final String requestedVersion;

  /// The major component parsed from [requestedVersion].
  final int requestedMajor;

  /// The major version this build of ambient_core understands.
  final int supportedMajor;

  @override
  String get message =>
      'Unsupported manifest version "$requestedVersion": this build of '
      'ambient_core reads manifest major version $supportedMajor.x only '
      '(got major $requestedMajor).';

  @override
  String toString() => 'UnsupportedManifestVersionException: $message';
}
