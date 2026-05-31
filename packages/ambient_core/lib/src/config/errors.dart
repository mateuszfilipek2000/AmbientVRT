/// Errors raised while parsing or validating an `ambient.config.yaml`.
library;

/// Base type for every config-related failure.
///
/// Sealed so callers can exhaustively switch over the failure modes when they
/// need to react differently to, say, malformed YAML versus a schema
/// violation.
sealed class ConfigException implements Exception {
  /// Human-readable description of what went wrong.
  String get message;
}

/// Thrown when a config does not conform to `config.schema.json`.
///
/// [location] is a dotted/bracketed path to the offending value within the
/// document (e.g. `adapters[1].projectPath`), or an empty string for a failure
/// at the document root. [detail] explains the specific rule that was violated.
class ConfigFormatException implements ConfigException {
  /// Creates a located format error.
  ConfigFormatException(this.location, this.detail);

  /// Path to the offending value, e.g. `storage.backend`. Empty for the root.
  final String location;

  /// Why the value at [location] is invalid.
  final String detail;

  @override
  String get message => location.isEmpty
      ? 'Invalid config: $detail'
      : 'Invalid config at "$location": $detail';

  @override
  String toString() => 'ConfigFormatException: $message';
}
