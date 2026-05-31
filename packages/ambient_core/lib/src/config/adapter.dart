import '../manifest/platform.dart';
import 'config_reader.dart';
import 'errors.dart';

/// One capture adapter the run should invoke.
///
/// Mirrors the `adapter` definition in `config.schema.json`. The
/// platform-specific path is conditionally required: `flutter` needs
/// [projectPath]; `react-native` needs [storybookStaticDir].
class Adapter {
  /// Creates an adapter. Callers are responsible for supplying a path that
  /// matches the platform; [Adapter.fromReader] enforces this when parsing.
  const Adapter({
    required this.platform,
    this.projectPath,
    this.command,
    this.storybookStaticDir,
  });

  /// Reads an adapter from a config object via [reader], validating every
  /// field against the schema.
  factory Adapter.fromReader(ConfigReader reader) {
    reader.rejectUnknownKeys(const {
      'command',
      'platform',
      'projectPath',
      'storybookStaticDir',
    });

    final platform = reader.requireEnum('platform', Platform.byWireName);
    final command = reader.optionalStringList('command', minItemLength: 1);
    final projectPath = reader.optionalString('projectPath', minLength: 1);
    final storybookStaticDir = reader.optionalString(
      'storybookStaticDir',
      minLength: 1,
    );

    if (platform == Platform.flutter && projectPath == null) {
      throw ConfigFormatException(
        reader.childLocation('projectPath'),
        'is required when adapter platform is "flutter"',
      );
    }
    if (platform == Platform.reactNative && storybookStaticDir == null) {
      throw ConfigFormatException(
        reader.childLocation('storybookStaticDir'),
        'is required when adapter platform is "react-native"',
      );
    }

    return Adapter(
      command: command,
      platform: platform,
      projectPath: projectPath,
      storybookStaticDir: storybookStaticDir,
    );
  }

  /// Capture platform this adapter drives. Shares the manifest's [Platform]
  /// enum so config and emitted manifests speak the same wire names.
  final Platform platform;

  /// Project root for the Flutter adapter; `null` for other platforms.
  final String? projectPath;

  /// Optional adapter executable override, represented as executable + argv
  /// tokens to avoid shell parsing rules.
  final List<String>? command;

  /// Built Storybook static dir for the RN adapter; `null` for other
  /// platforms.
  final String? storybookStaticDir;

  /// Serializes to a JSON/YAML-encodable map, omitting unset paths.
  Map<String, Object?> toJson() => {
    'platform': platform.wireName,
    if (command != null) 'command': [...command!],
    if (projectPath != null) 'projectPath': projectPath,
    if (storybookStaticDir != null) 'storybookStaticDir': storybookStaticDir,
  };

  @override
  bool operator ==(Object other) =>
      other is Adapter &&
      _listEquals(other.command, command) &&
      other.platform == platform &&
      other.projectPath == projectPath &&
      other.storybookStaticDir == storybookStaticDir;

  @override
  int get hashCode => Object.hash(
    platform,
    Object.hashAll(command ?? const <String>[]),
    projectPath,
    storybookStaticDir,
  );

  @override
  String toString() => 'Adapter(platform: ${platform.wireName})';
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null || a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
