import 'errors.dart';

/// Reads and validates fields out of a decoded-config object (YAML normalized
/// to plain maps/lists), reporting every failure as a [ConfigFormatException]
/// that carries the offending path.
///
/// This is the config-side counterpart to the manifest's reader: the single
/// place where the structural rules of `config.schema.json` (types, enums,
/// bounds, uniqueness, no unknown keys) are enforced, so validation failures
/// always point at a concrete location in the document.
class ConfigReader {
  /// Wraps [_map], whose path within the document is [location] (empty at the
  /// root).
  ConfigReader(this._map, this.location);

  final Map<String, Object?> _map;

  /// Dotted/bracketed path to [_map] within the document, e.g. `adapters[0]`.
  final String location;

  String _child(String key) => location.isEmpty ? key : '$location.$key';

  Never _fail(String where, String message) =>
      throw ConfigFormatException(where, message);

  /// The path a child [key] would have; used to seed nested readers and to
  /// locate conditionally-required fields.
  String childLocation(String key) => _child(key);

  /// Whether [key] is present (even if its value is `null`).
  bool has(String key) => _map.containsKey(key);

  /// Rejects any key not in [allowed], mirroring `additionalProperties: false`.
  void rejectUnknownKeys(Set<String> allowed) {
    for (final key in _map.keys) {
      if (!allowed.contains(key)) {
        _fail(_child(key), 'unknown property "$key" is not allowed');
      }
    }
  }

  Object? _require(String key) {
    if (!_map.containsKey(key)) {
      _fail(_child(key), 'is required but missing');
    }
    return _map[key];
  }

  /// Requires a string, optionally enforcing a [minLength].
  String requireString(String key, {int minLength = 0}) =>
      _asString(_require(key), _child(key), minLength: minLength);

  /// Like [requireString] but returns `null` when [key] is absent.
  String? optionalString(String key, {int minLength = 0}) {
    if (!_map.containsKey(key)) return null;
    return requireString(key, minLength: minLength);
  }

  /// Requires the value to be one of [byWireName]'s keys.
  T requireEnum<T>(String key, Map<String, T> byWireName) {
    final raw = requireString(key);
    final value = byWireName[raw];
    if (value == null) {
      final allowed = byWireName.keys.map((k) => '"$k"').join(', ');
      _fail(_child(key), 'must be one of $allowed, got "$raw"');
    }
    return value;
  }

  /// Requires an array of arbitrary items, optionally enforcing [minItems].
  List<Object?> requireList(String key, {int minItems = 0}) {
    final value = _require(key);
    if (value is! List) {
      _fail(_child(key), 'expected an array, got ${configTypeName(value)}');
    }
    if (value.length < minItems) {
      _fail(
        _child(key),
        'must contain at least $minItems item(s), got ${value.length}',
      );
    }
    return value;
  }

  /// Requires a nested object, returned as a string-keyed map.
  Map<String, Object?> requireMap(String key) {
    final value = _require(key);
    if (value is! Map) {
      _fail(_child(key), 'expected an object, got ${configTypeName(value)}');
    }
    return value.cast<String, Object?>();
  }

  /// Like [requireMap] but returns `null` when [key] is absent.
  Map<String, Object?>? optionalMap(String key) {
    if (!_map.containsKey(key)) return null;
    return requireMap(key);
  }

  /// Requires a number within the inclusive range [[min], [max]].
  double requireNumberInRange(String key, {required num min, required num max}) =>
      _asNumberInRange(_require(key), _child(key), min: min, max: max);

  /// Like [requireNumberInRange] but returns `null` when [key] is absent.
  double? optionalNumberInRange(
    String key, {
    required num min,
    required num max,
  }) {
    if (!_map.containsKey(key)) return null;
    return requireNumberInRange(key, min: min, max: max);
  }

  /// Reads an optional array of strings, enforcing [minItemLength] per item and
  /// optional [unique]ness across items. Returns `null` when [key] is absent.
  List<String>? optionalStringList(
    String key, {
    int minItemLength = 0,
    bool unique = false,
  }) {
    if (!_map.containsKey(key)) return null;
    final raw = requireList(key);
    final result = <String>[];
    final seen = <String>{};
    for (var i = 0; i < raw.length; i++) {
      final itemLocation = '${_child(key)}[$i]';
      final value = _asString(raw[i], itemLocation, minLength: minItemLength);
      if (unique && !seen.add(value)) {
        _fail(itemLocation, 'duplicate value "$value"; items must be unique');
      }
      result.add(value);
    }
    return result;
  }

  /// Reads an optional map whose values are numbers within [[min], [max]].
  /// Returns `null` when [key] is absent.
  Map<String, double>? optionalNumberMap(
    String key, {
    required num min,
    required num max,
  }) {
    final map = optionalMap(key);
    if (map == null) return null;
    final result = <String, double>{};
    map.forEach((entryKey, value) {
      result[entryKey] = _asNumberInRange(
        value,
        '${_child(key)}.$entryKey',
        min: min,
        max: max,
      );
    });
    return result;
  }

  String _asString(Object? value, String where, {int minLength = 0}) {
    if (value is! String) {
      _fail(where, 'expected a string, got ${configTypeName(value)}');
    }
    if (value.length < minLength) {
      _fail(
        where,
        minLength == 1
            ? 'must not be empty'
            : 'must be at least $minLength characters long',
      );
    }
    return value;
  }

  double _asNumberInRange(
    Object? value,
    String where, {
    required num min,
    required num max,
  }) {
    if (value is! num) {
      _fail(where, 'expected a number, got ${configTypeName(value)}');
    }
    if (value < min || value > max) {
      _fail(where, 'must be between $min and $max, got $value');
    }
    return value.toDouble();
  }
}

/// Names a decoded-config value's type for use in error messages.
String configTypeName(Object? value) {
  return switch (value) {
    null => 'null',
    String() => 'a string',
    int() => 'an integer',
    double() => 'a number',
    bool() => 'a boolean',
    List() => 'an array',
    Map() => 'an object',
    _ => value.runtimeType.toString(),
  };
}
