import 'dart:convert';

import 'errors.dart';
import 'json_reader.dart';
import 'manifest_entry.dart';
import 'manifest_version.dart';

/// A capture manifest: the internal contract every adapter emits and the core
/// consumes.
///
/// See `schemas/manifest.schema.json` and `docs/contracts.md`.
class Manifest {
  /// Creates a manifest from a version and its entries.
  const Manifest({required this.manifestVersion, required this.entries});

  /// Parses a manifest from a JSON string.
  ///
  /// Throws [ManifestFormatException] for malformed input and
  /// [UnsupportedManifestVersionException] for an incompatible major version.
  factory Manifest.fromJsonString(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw ManifestFormatException('', 'is not valid JSON: ${e.message}');
    }
    return Manifest.fromJson(decoded);
  }

  /// Builds a manifest from already-decoded JSON.
  ///
  /// Throws [ManifestFormatException] if [json] violates the schema and
  /// [UnsupportedManifestVersionException] if the declared major version is not
  /// supported.
  factory Manifest.fromJson(Object? json) {
    if (json is! Map) {
      throw ManifestFormatException(
        '',
        'expected the manifest root to be an object, got ${jsonTypeName(json)}',
      );
    }
    final root = JsonReader(json.cast<String, Object?>(), '');
    root.rejectUnknownKeys(const {'manifestVersion', 'entries'});

    final version = ManifestVersion.parse(
      root.requireString('manifestVersion'),
      location: root.childLocation('manifestVersion'),
    )..ensureSupported();

    final rawEntries = root.requireList('entries');
    final entries = <ManifestEntry>[];
    for (var i = 0; i < rawEntries.length; i++) {
      final item = rawEntries[i];
      final location = 'entries[$i]';
      if (item is! Map) {
        throw ManifestFormatException(
          location,
          'expected an object, got ${jsonTypeName(item)}',
        );
      }
      entries.add(
        ManifestEntry.fromReader(JsonReader(item.cast<String, Object?>(), location)),
      );
    }

    return Manifest(manifestVersion: version, entries: entries);
  }

  /// Format version this manifest declares.
  final ManifestVersion manifestVersion;

  /// One record per captured snapshot.
  final List<ManifestEntry> entries;

  /// Serializes to a JSON-encodable map.
  Map<String, Object?> toJson() => {
    'manifestVersion': manifestVersion.toString(),
    'entries': [for (final entry in entries) entry.toJson()],
  };

  /// Serializes to a JSON string.
  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) {
    if (other is! Manifest) return false;
    if (other.manifestVersion != manifestVersion) return false;
    if (other.entries.length != entries.length) return false;
    for (var i = 0; i < entries.length; i++) {
      if (other.entries[i] != entries[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(manifestVersion, Object.hashAll(entries));

  @override
  String toString() =>
      'Manifest(manifestVersion: $manifestVersion, entries: ${entries.length})';
}
