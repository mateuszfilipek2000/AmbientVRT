import 'package:ambient_core/ambient_core.dart';
import 'package:test/test.dart';

void main() {
  group('Config parses a valid ambient.config.yaml', () {
    test('a full config maps every section onto the typed model', () {
      final config = Config.fromYamlString('''
adapters:
  - platform: flutter
    projectPath: ./
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
      expect(config.adapters[1].platform, Platform.reactNative);
      expect(config.adapters[1].storybookStaticDir, './storybook-static');

      expect(config.storage.backend, StorageBackend.local);
      expect(config.storage.path, '.ambient/baselines');

      expect(config.compare, isNotNull);
      expect(config.compare!.threshold, 0.1);
      expect(
        config.compare!.perSnapshot,
        {'components-button--primary::react-native': 0.05},
      );

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
''');

      expect(config.adapters.single.platform, Platform.reactNative);
      expect(config.storage.backend, StorageBackend.s3);
      expect(config.storage.path, isNull);
      expect(config.compare, isNull);
      expect(config.variants, isEmpty);
      expect(config.canonicalEnv, isNull);
    });

    test('an empty compare section yields default thresholds', () {
      final config = Config.fromYamlString('''
adapters:
  - platform: flutter
    projectPath: ./
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
    });
  });
}
