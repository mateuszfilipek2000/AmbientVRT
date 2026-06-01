import 'package:ambient_core/ambient_core.dart';
import 'package:test/test.dart';

/// A schema-valid config as a mutable map, to be perturbed per test.
Map<String, Object?> validConfig() => {
  'adapters': [
    {'platform': 'flutter', 'projectPath': './'},
  ],
  'storage': {'backend': 'local', 'path': 'baselines'},
};

/// Parses [data] and returns the [ConfigFormatException] it raises.
ConfigFormatException expectFormatError(Object? data) {
  try {
    Config.fromYaml(data);
  } on ConfigFormatException catch (e) {
    return e;
  }
  fail('expected a ConfigFormatException');
}

void main() {
  group('Config validation produces field-located errors', () {
    test('non-object root', () {
      final error = expectFormatError(const <Object?>[]);
      expect(error.location, isEmpty);
      expect(error.message, contains('object'));
    });

    test('missing adapters', () {
      final config = validConfig()..remove('adapters');
      final error = expectFormatError(config);
      expect(error.location, 'adapters');
      expect(error.detail, contains('required'));
    });

    test('empty adapters list', () {
      final config = validConfig()..['adapters'] = const <Object?>[];
      final error = expectFormatError(config);
      expect(error.location, 'adapters');
      expect(error.detail, contains('at least 1'));
    });

    test('missing storage', () {
      final config = validConfig()..remove('storage');
      final error = expectFormatError(config);
      expect(error.location, 'storage');
      expect(error.detail, contains('required'));
    });

    test('unknown top-level property', () {
      final config = validConfig()..['unknownTopLevel'] = true;
      final error = expectFormatError(config);
      expect(error.location, 'unknownTopLevel');
      expect(error.detail, contains('unknown property'));
    });

    test('invalid adapter platform names the field', () {
      final config = validConfig()
        ..['adapters'] = [
          {'platform': 'vue'},
        ];
      final error = expectFormatError(config);
      expect(error.location, 'adapters[0].platform');
      expect(error.detail, contains('one of'));
    });

    test('flutter adapter without projectPath', () {
      final config = validConfig()
        ..['adapters'] = [
          {'platform': 'flutter'},
        ];
      final error = expectFormatError(config);
      expect(error.location, 'adapters[0].projectPath');
      expect(error.detail, contains('flutter'));
    });

    test('react-native adapter without storybookStaticDir', () {
      final config = validConfig()
        ..['adapters'] = [
          {'platform': 'react-native'},
        ];
      final error = expectFormatError(config);
      expect(error.location, 'adapters[0].storybookStaticDir');
      expect(error.detail, contains('react-native'));
    });

    test('unknown property on an adapter', () {
      final config = validConfig()
        ..['adapters'] = [
          {'platform': 'flutter', 'projectPath': './', 'extra': 1},
        ];
      final error = expectFormatError(config);
      expect(error.location, 'adapters[0].extra');
    });

    test('the second adapter index appears in the location', () {
      final config = validConfig()
        ..['adapters'] = [
          {'platform': 'flutter', 'projectPath': './'},
          {'platform': 'flutter'},
        ];
      final error = expectFormatError(config);
      expect(error.location, 'adapters[1].projectPath');
    });

    test('command entries must be non-empty strings', () {
      final config = validConfig()
        ..['adapters'] = [
          {
            'platform': 'flutter',
            'projectPath': './',
            'command': ['ambient-flutter-capture', ''],
          },
        ];
      final error = expectFormatError(config);
      expect(error.location, 'adapters[0].command[1]');
      expect(error.detail, contains('empty'));
    });

    test('invalid storage backend names the field', () {
      final config = validConfig()..['storage'] = {'backend': 'gdrive'};
      final error = expectFormatError(config);
      expect(error.location, 'storage.backend');
      expect(error.detail, contains('one of'));
    });

    test('local storage without a path', () {
      final config = validConfig()..['storage'] = {'backend': 'local'};
      final error = expectFormatError(config);
      expect(error.location, 'storage.path');
      expect(error.detail, contains('local'));
    });

    test('empty storage path', () {
      final config = validConfig()
        ..['storage'] = {'backend': 'local', 'path': ''};
      final error = expectFormatError(config);
      expect(error.location, 'storage.path');
      expect(error.detail, contains('empty'));
    });

    test('s3 storage without an s3 section', () {
      final config = validConfig()..['storage'] = {'backend': 's3'};
      final error = expectFormatError(config);
      expect(error.location, 'storage.s3');
      expect(error.detail, contains('s3'));
    });

    test('s3 section without an endpoint', () {
      final config = validConfig()
        ..['storage'] = {
          'backend': 's3',
          's3': {'bucket': 'ambient-baselines'},
        };
      final error = expectFormatError(config);
      expect(error.location, 'storage.s3.endpoint');
      expect(error.detail, contains('required'));
    });

    test('s3 section without a bucket', () {
      final config = validConfig()
        ..['storage'] = {
          'backend': 's3',
          's3': {'endpoint': 'minio.lan'},
        };
      final error = expectFormatError(config);
      expect(error.location, 'storage.s3.bucket');
      expect(error.detail, contains('required'));
    });

    test('s3 port out of range', () {
      final config = validConfig()
        ..['storage'] = {
          'backend': 's3',
          's3': {
            'endpoint': 'minio.lan',
            'bucket': 'ambient-baselines',
            'port': 70000,
          },
        };
      final error = expectFormatError(config);
      expect(error.location, 'storage.s3.port');
      expect(error.detail, contains('between 1 and 65535'));
    });

    test('s3 useSSL of the wrong type', () {
      final config = validConfig()
        ..['storage'] = {
          'backend': 's3',
          's3': {
            'endpoint': 'minio.lan',
            'bucket': 'ambient-baselines',
            'useSSL': 'yes',
          },
        };
      final error = expectFormatError(config);
      expect(error.location, 'storage.s3.useSSL');
      expect(error.detail, contains('boolean'));
    });

    test('unknown property in the s3 section', () {
      final config = validConfig()
        ..['storage'] = {
          'backend': 's3',
          's3': {
            'endpoint': 'minio.lan',
            'bucket': 'ambient-baselines',
            'accessKey': 'leaked',
          },
        };
      final error = expectFormatError(config);
      expect(error.location, 'storage.s3.accessKey');
      expect(error.detail, contains('unknown property'));
    });

    test('compare threshold above the allowed range', () {
      final config = validConfig()..['compare'] = {'threshold': 1.5};
      final error = expectFormatError(config);
      expect(error.location, 'compare.threshold');
      expect(error.detail, contains('between 0 and 1'));
    });

    test('compare threshold of the wrong type', () {
      final config = validConfig()..['compare'] = {'threshold': 'high'};
      final error = expectFormatError(config);
      expect(error.location, 'compare.threshold');
      expect(error.detail, contains('number'));
    });

    test('per-snapshot override out of range locates the key', () {
      final config = validConfig()
        ..['compare'] = {
          'perSnapshot': {'button--primary': 2},
        };
      final error = expectFormatError(config);
      expect(error.location, 'compare.perSnapshot.button--primary');
      expect(error.detail, contains('between 0 and 1'));
    });

    test('unknown property in compare', () {
      final config = validConfig()..['compare'] = {'mode': 'strict'};
      final error = expectFormatError(config);
      expect(error.location, 'compare.mode');
    });

    test('duplicate variant is rejected with its index', () {
      final config = validConfig()..['variants'] = ['light', 'light'];
      final error = expectFormatError(config);
      expect(error.location, 'variants[1]');
      expect(error.detail, contains('duplicate'));
    });

    test('empty variant string', () {
      final config = validConfig()..['variants'] = ['light', ''];
      final error = expectFormatError(config);
      expect(error.location, 'variants[1]');
      expect(error.detail, contains('empty'));
    });

    test('empty canonicalEnv', () {
      final config = validConfig()..['canonicalEnv'] = '';
      final error = expectFormatError(config);
      expect(error.location, 'canonicalEnv');
      expect(error.detail, contains('empty'));
    });

    test('malformed YAML reports a root error', () {
      try {
        Config.fromYamlString('adapters: [unclosed');
      } on ConfigFormatException catch (e) {
        expect(e.location, isEmpty);
        expect(e.detail, contains('YAML'));
        return;
      }
      fail('expected a ConfigFormatException');
    });

    test('a valid config parses cleanly', () {
      final config = Config.fromYaml(validConfig());
      expect(config.adapters, hasLength(1));
      expect(config.storage.backend, StorageBackend.local);
    });
  });
}
