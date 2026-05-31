import 'package:ambient_core/ambient_core.dart';
import 'package:test/test.dart';

/// Builds a minimal manifest JSON map at the given [version] string.
Map<String, Object?> manifestAt(String version) => {
  'manifestVersion': version,
  'entries': const <Object?>[],
};

void main() {
  group('ManifestVersion', () {
    test('parses major.minor', () {
      final version = ManifestVersion.parse('1.4');
      expect(version.major, 1);
      expect(version.minor, 4);
      expect(version.toString(), '1.4');
    });

    test('rejects malformed version strings with a located error', () {
      final error = _catchManifest(() => ManifestVersion.parse('v1'));
      expect(error, isA<ManifestFormatException>());
      expect((error as ManifestFormatException).location, 'manifestVersion');
    });

    test('the supported major is accepted with any minor', () {
      expect(const ManifestVersion(1, 0).isSupported, isTrue);
      expect(const ManifestVersion(1, 99).isSupported, isTrue);
    });

    test('a different major is unsupported', () {
      expect(const ManifestVersion(2, 0).isSupported, isFalse);
      expect(const ManifestVersion(0, 9).isSupported, isFalse);
    });
  });

  group('Manifest.fromJson version handling', () {
    test('accepts a forward-compatible minor bump', () {
      final manifest = Manifest.fromJson(manifestAt('1.7'));
      expect(manifest.manifestVersion, const ManifestVersion(1, 7));
    });

    test('a major mismatch throws a typed, descriptive error', () {
      final error = _catchManifest(() => Manifest.fromJson(manifestAt('2.0')));
      expect(error, isA<UnsupportedManifestVersionException>());
      final typed = error as UnsupportedManifestVersionException;
      expect(typed.requestedMajor, 2);
      expect(typed.supportedMajor, ManifestVersion.supportedMajor);
      expect(typed.message, contains('2.0'));
      expect(typed.message, contains('major version'));
    });

    test('a malformed version string fails before the version check', () {
      final error = _catchManifest(() => Manifest.fromJson(manifestAt('1')));
      expect(error, isA<ManifestFormatException>());
      expect((error as ManifestFormatException).location, 'manifestVersion');
    });
  });
}

/// Runs [body] and returns whatever [ManifestException] it throws.
Object _catchManifest(void Function() body) {
  try {
    body();
  } on ManifestException catch (e) {
    return e;
  }
  fail('expected a ManifestException to be thrown');
}
