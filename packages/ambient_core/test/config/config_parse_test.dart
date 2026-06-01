import 'package:ambient_core/ambient_core.dart';
import 'package:test/test.dart';

void main() {
  group('Config parses a valid ambient.config.yaml', () {
    test('a full config maps every section onto the typed model', () {
      final config = Config.fromYamlString('''
adapters:
  - platform: flutter
    projectPath: ./
    command:
      - ambient-flutter-capture
      - --profile
      - ci
  - platform: react-native
    storybookStaticDir: ./storybook-static
storage:
  backend: local
  path: .ambient/baselines
compare:
  threshold: 0.1
  perSnapshot:
    components-button--primary::react-native: 0.05
variants:
  - light
  - dark
canonicalEnv: ambient/capture-env@sha256:abc123
''');

      expect(config.adapters, hasLength(2));
      expect(config.adapters[0].platform, Platform.flutter);
      expect(config.adapters[0].projectPath, './');
      expect(config.adapters[0].command, [
        'ambient-flutter-capture',
        '--profile',
        'ci',
      ]);
      expect(config.adapters[1].platform, Platform.reactNative);
      expect(config.adapters[1].storybookStaticDir, './storybook-static');
      expect(config.adapters[1].command, isNull);

      expect(config.storage.backend, StorageBackend.local);
      expect(config.storage.path, '.ambient/baselines');

      expect(config.compare, isNotNull);
      expect(config.compare!.threshold, 0.1);
      expect(config.compare!.perSnapshot, {
        'components-button--primary::react-native': 0.05,
      });

      expect(config.variants, ['light', 'dark']);
      expect(config.canonicalEnv, 'ambient/capture-env@sha256:abc123');
    });

    test('a minimal config relies on documented defaults', () {
      final config = Config.fromYamlString('''
adapters:
  - platform: react-native
    storybookStaticDir: ./storybook-static
storage:
  backend: s3
  s3:
    endpoint: minio.lan
    bucket: ambient-baselines
''');

      expect(config.adapters.single.platform, Platform.reactNative);
      expect(config.storage.backend, StorageBackend.s3);
      expect(config.storage.path, isNull);
      final s3 = config.storage.s3!;
      expect(s3.endpoint, 'minio.lan');
      expect(s3.bucket, 'ambient-baselines');
      expect(s3.port, isNull);
      expect(s3.useSSL, isTrue);
      expect(s3.region, isNull);
      expect(s3.prefix, isNull);
      expect(s3.pathStyle, isNull);
      expect(s3.accessKeyEnv, 'AMBIENT_S3_ACCESS_KEY');
      expect(s3.secretKeyEnv, 'AMBIENT_S3_SECRET_KEY');
      expect(config.compare, isNull);
      expect(config.variants, isEmpty);
      expect(config.canonicalEnv, isNull);
      expect(config.adapters.single.command, isNull);
    });

    test('a full s3 config maps every connection field', () {
      final config = Config.fromYamlString('''
adapters:
  - platform: react-native
    storybookStaticDir: ./storybook-static
storage:
  backend: s3
  s3:
    endpoint: 10.0.0.5
    bucket: ambient-baselines
    port: 9000
    useSSL: false
    region: us-east-1
    prefix: baselines/
    pathStyle: true
    accessKeyEnv: MINIO_KEY
    secretKeyEnv: MINIO_SECRET
''');

      final s3 = config.storage.s3!;
      expect(s3.endpoint, '10.0.0.5');
      expect(s3.bucket, 'ambient-baselines');
      expect(s3.port, 9000);
      expect(s3.useSSL, isFalse);
      expect(s3.region, 'us-east-1');
      expect(s3.prefix, 'baselines/');
      expect(s3.pathStyle, isTrue);
      expect(s3.accessKeyEnv, 'MINIO_KEY');
      expect(s3.secretKeyEnv, 'MINIO_SECRET');
    });

    test('round-trips a parsed s3 config back through toJson()', () {
      final source = '''
adapters:
  - platform: react-native
    storybookStaticDir: ./storybook-static
storage:
  backend: s3
  s3:
    endpoint: 10.0.0.5
    bucket: ambient-baselines
    port: 9000
    useSSL: false
    region: us-east-1
    prefix: baselines/
    pathStyle: true
    accessKeyEnv: MINIO_KEY
    secretKeyEnv: MINIO_SECRET
''';
      final config = Config.fromYamlString(source);
      final reparsed = Config.fromYaml(config.toJson());
      expect(reparsed, equals(config));
    });

    test('an empty compare section yields default thresholds', () {
      final config = Config.fromYamlString('''
adapters:
  - platform: flutter
    projectPath: ./
    command:
      - ambient-flutter-capture
storage:
  backend: local
  path: baselines
compare: {}
''');

      expect(config.compare, isNotNull);
      expect(config.compare!.threshold, isNull);
      expect(config.compare!.perSnapshot, isEmpty);
    });

    test('round-trips a parsed config back through toJson()', () {
      final source = '''
adapters:
  - platform: flutter
    projectPath: ./
    command:
      - ambient-flutter-capture
storage:
  backend: local
  path: baselines
compare:
  threshold: 0.2
variants:
  - dark
canonicalEnv: ambient/capture-env@sha256:deadbeef
''';
      final config = Config.fromYamlString(source);
      final reparsed = Config.fromYaml(config.toJson());
      expect(reparsed, equals(config));
      expect(reparsed.adapters.single.command, ['ambient-flutter-capture']);
    });
  });
}
