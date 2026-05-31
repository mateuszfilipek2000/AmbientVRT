import 'package:ambient_core/ambient_core.dart';
import 'package:test/test.dart';

void main() {
  group('Manifest round-trip', () {
    final manifest = Manifest(
      manifestVersion: ManifestVersion.current,
      entries: [
        ManifestEntry(
          id: 'components-button--primary::flutter::theme=dark',
          platform: Platform.flutter,
          variant: const Variant(theme: 'dark', brightness: Brightness.dark),
          width: 320,
          height: 240,
          dpr: 2,
          contentHash:
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          envFingerprint: 'ambient/capture-env@sha256:abc123',
          imagePath: 'images/components-button--primary.png',
        ),
        ManifestEntry(
          id: 'screens-home--default',
          platform: Platform.reactNative,
          width: 390,
          height: 844,
          dpr: 3,
          contentHash:
              '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae',
          envFingerprint: 'node20-playwright-chromium',
          imagePath: 'images/screens-home--default.png',
        ),
      ],
    );

    test('serialize -> deserialize is deep-equal to the original', () {
      final restored = Manifest.fromJson(manifest.toJson());
      expect(restored, equals(manifest));
    });

    test('round-trips through a JSON string', () {
      final restored = Manifest.fromJsonString(manifest.toJsonString());
      expect(restored, equals(manifest));
    });

    test('omits an absent variant from the serialized entry', () {
      final json = manifest.toJson();
      final entries = json['entries']! as List<Object?>;
      expect((entries[0]! as Map).containsKey('variant'), isTrue);
      expect((entries[1]! as Map).containsKey('variant'), isFalse);
    });

    test('equality is by value, not identity', () {
      final copy = Manifest.fromJson(manifest.toJson());
      expect(copy, equals(manifest));
      expect(copy.hashCode, equals(manifest.hashCode));
      expect(identical(copy, manifest), isFalse);
    });

    test('differing entries are not equal', () {
      final changed = Manifest.fromJson(manifest.toJson());
      final tweaked = Manifest(
        manifestVersion: changed.manifestVersion,
        entries: [
          changed.entries.first,
          // Drop the second entry.
        ],
      );
      expect(tweaked, isNot(equals(manifest)));
    });
  });
}
