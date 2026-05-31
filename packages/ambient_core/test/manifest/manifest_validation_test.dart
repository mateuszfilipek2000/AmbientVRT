import 'package:ambient_core/ambient_core.dart';
import 'package:test/test.dart';

/// A schema-valid entry as a mutable JSON map, to be perturbed per test.
Map<String, Object?> validEntry() => {
  'id': 'components-button--primary',
  'platform': 'flutter',
  'width': 320,
  'height': 240,
  'dpr': 2,
  'contentHash':
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
  'envFingerprint': 'ambient/capture-env@sha256:abc123',
  'imagePath': 'images/button.png',
};

/// Wraps a single [entry] in an otherwise-valid manifest.
Map<String, Object?> manifestWith(Map<String, Object?> entry) => {
  'manifestVersion': '1.0',
  'entries': [entry],
};

/// Parses [json] and returns the [ManifestFormatException] it raises.
ManifestFormatException expectFormatError(Object? json) {
  try {
    Manifest.fromJson(json);
  } on ManifestFormatException catch (e) {
    return e;
  }
  fail('expected a ManifestFormatException');
}

void main() {
  group('Manifest schema validation produces located errors', () {
    test('non-object root', () {
      final error = expectFormatError(const <Object?>[]);
      expect(error.location, isEmpty);
      expect(error.message, contains('object'));
    });

    test('missing entries', () {
      final error = expectFormatError({'manifestVersion': '1.0'});
      expect(error.location, 'entries');
      expect(error.detail, contains('required'));
    });

    test('unknown top-level property', () {
      final error = expectFormatError({
        'manifestVersion': '1.0',
        'entries': const <Object?>[],
        'extra': true,
      });
      expect(error.location, 'extra');
      expect(error.detail, contains('unknown property'));
    });

    test('entry is not an object', () {
      final error = expectFormatError({
        'manifestVersion': '1.0',
        'entries': ['nope'],
      });
      expect(error.location, 'entries[0]');
    });

    test('missing required field locates the field', () {
      final entry = validEntry()..remove('contentHash');
      final error = expectFormatError(manifestWith(entry));
      expect(error.location, 'entries[0].contentHash');
      expect(error.detail, contains('required'));
    });

    test('unknown property on an entry', () {
      final entry = validEntry()..['unexpected'] = 'nope';
      final error = expectFormatError(manifestWith(entry));
      expect(error.location, 'entries[0].unexpected');
    });

    test('invalid platform enum', () {
      final entry = validEntry()..['platform'] = 'windows';
      final error = expectFormatError(manifestWith(entry));
      expect(error.location, 'entries[0].platform');
      expect(error.detail, contains('one of'));
    });

    test('non-positive width', () {
      final entry = validEntry()..['width'] = 0;
      final error = expectFormatError(manifestWith(entry));
      expect(error.location, 'entries[0].width');
      expect(error.detail, contains('greater than 0'));
    });

    test('width must be an integer, not a number', () {
      final entry = validEntry()..['width'] = 1.5;
      final error = expectFormatError(manifestWith(entry));
      expect(error.location, 'entries[0].width');
      expect(error.detail, contains('integer'));
    });

    test('non-positive dpr', () {
      final entry = validEntry()..['dpr'] = 0;
      final error = expectFormatError(manifestWith(entry));
      expect(error.location, 'entries[0].dpr');
    });

    test('malformed contentHash', () {
      final entry = validEntry()..['contentHash'] = 'NOTHEX';
      final error = expectFormatError(manifestWith(entry));
      expect(error.location, 'entries[0].contentHash');
      expect(error.detail, contains('hex'));
    });

    test('empty envFingerprint', () {
      final entry = validEntry()..['envFingerprint'] = '';
      final error = expectFormatError(manifestWith(entry));
      expect(error.location, 'entries[0].envFingerprint');
    });

    test('absolute imagePath', () {
      final entry = validEntry()..['imagePath'] = '/abs/path.png';
      final error = expectFormatError(manifestWith(entry));
      expect(error.location, 'entries[0].imagePath');
    });

    test('imagePath with parent traversal', () {
      final entry = validEntry()..['imagePath'] = '../escape.png';
      final error = expectFormatError(manifestWith(entry));
      expect(error.location, 'entries[0].imagePath');
    });

    test('imagePath not ending in .png', () {
      final entry = validEntry()..['imagePath'] = 'images/button.jpg';
      final error = expectFormatError(manifestWith(entry));
      expect(error.location, 'entries[0].imagePath');
    });

    test('invalid brightness in variant locates the nested field', () {
      final entry = validEntry()..['variant'] = {'brightness': 'dim'};
      final error = expectFormatError(manifestWith(entry));
      expect(error.location, 'entries[0].variant.brightness');
    });

    test('unknown property in variant', () {
      final entry = validEntry()..['variant'] = {'mode': 'x'};
      final error = expectFormatError(manifestWith(entry));
      expect(error.location, 'entries[0].variant.mode');
    });

    test('a valid entry parses cleanly', () {
      final manifest = Manifest.fromJson(manifestWith(validEntry()));
      expect(manifest.entries, hasLength(1));
      expect(manifest.entries.single.platform, Platform.flutter);
    });

    test('the second entry index appears in the location', () {
      final bad = validEntry()..['width'] = -1;
      final error = expectFormatError({
        'manifestVersion': '1.0',
        'entries': [validEntry(), bad],
      });
      expect(error.location, 'entries[1].width');
    });
  });
}
