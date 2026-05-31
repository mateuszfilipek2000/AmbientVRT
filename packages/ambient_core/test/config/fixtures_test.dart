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
    test('config.valid.json parses into a typed model', () {
      // JSON is a subset of YAML, so the YAML parser reads the fixture as-is.
      final source =
          File('${fixtures.path}/config.valid.json').readAsStringSync();
      final config = Config.fromYamlString(source);

      expect(config.adapters, hasLength(2));
      expect(config.adapters[0].platform, Platform.flutter);
      expect(config.adapters[1].platform, Platform.reactNative);
      expect(config.storage.backend, StorageBackend.local);
      expect(config.compare?.threshold, 0.1);
      expect(config.variants, ['light', 'dark']);
    });

    test('config.valid.json round-trips deep-equal', () {
      final source =
          File('${fixtures.path}/config.valid.json').readAsStringSync();
      final config = Config.fromYamlString(source);
      expect(Config.fromYaml(config.toJson()), equals(config));
    });

    test('config.invalid.json fails with a located error', () {
      final source =
          File('${fixtures.path}/config.invalid.json').readAsStringSync();
      // This fixture violates several rules at once; all that matters for the
      // contract is that it fails with a *located* error.
      expect(
        () => Config.fromYamlString(source),
        throwsA(
          isA<ConfigFormatException>().having(
            (e) => e.location,
            'location',
            isNotEmpty,
          ),
        ),
      );
    });
  });
}
