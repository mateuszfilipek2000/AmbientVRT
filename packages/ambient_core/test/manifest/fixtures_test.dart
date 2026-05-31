import 'dart:io';

import 'package:ambient_core/ambient_core.dart';
import 'package:test/test.dart';

/// Walks up from the current directory to find the repo's `schemas/fixtures`
/// dir, so the test works whether run from the package or the workspace root.
Directory findFixturesDir() {
  var dir = Directory.current.absolute;
  while (true) {
    final candidate = Directory('${dir.path}/schemas/fixtures');
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('could not locate schemas/fixtures from ${Directory.current.path}');
    }
    dir = parent;
  }
}

void main() {
  final fixtures = findFixturesDir();

  group('against the shared schema fixtures', () {
    test('manifest.valid.json deserializes', () {
      final source =
          File('${fixtures.path}/manifest.valid.json').readAsStringSync();
      final manifest = Manifest.fromJsonString(source);
      expect(manifest.manifestVersion, const ManifestVersion(1, 0));
      expect(manifest.entries, hasLength(2));
      // Fixture order: entry[0] is the react-native (no variant) record,
      // entry[1] is the flutter record carrying the full variant.
      expect(manifest.entries.first.platform, Platform.reactNative);
      expect(manifest.entries.first.variant, isNull);
      expect(manifest.entries[1].platform, Platform.flutter);
      expect(manifest.entries[1].variant?.brightness, Brightness.dark);
    });

    test('manifest.valid.json round-trips deep-equal', () {
      final source =
          File('${fixtures.path}/manifest.valid.json').readAsStringSync();
      final manifest = Manifest.fromJsonString(source);
      expect(Manifest.fromJson(manifest.toJson()), equals(manifest));
    });

    test('manifest.invalid.json fails with a located error', () {
      final source =
          File('${fixtures.path}/manifest.invalid.json').readAsStringSync();
      // This fixture violates several rules at once; the parser reports the
      // first it hits (the malformed "manifestVersion": "1"). All that matters
      // for the contract is that it fails with a *located* error.
      expect(
        () => Manifest.fromJsonString(source),
        throwsA(
          isA<ManifestFormatException>().having(
            (e) => e.location,
            'location',
            isNotEmpty,
          ),
        ),
      );
    });
  });
}
