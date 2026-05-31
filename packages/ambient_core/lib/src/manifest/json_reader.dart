import 'errors.dart';

/// Reads and validates fields out of a decoded-JSON object, reporting every
/// failure as a [ManifestFormatException] that carries the offending path.
///
/// This is the single place where the structural rules of
/// `manifest.schema.json` (types, enums, patterns, bounds, no unknown keys)
/// are enforced, so deserialization failures always point at a concrete
/// location in the document.
class JsonReader {
  /// Wraps [_map], whose path within the document is [location] (empty at the
  /// root).
  JsonReader(this._map, this.location);

  final Map<String, Object?> _map;

  /// Dotted/bracketed path to [_map] within the document, e.g. `entries[0]`.
  final String location;

  String _child(String key) => location.isEmpty ? key : '$location.$key';

  Never _fail(String where, String message) =>
      throw ManifestFormatException(where, message);

  /// The path a child [key] would have; used to seed nested readers.
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

  /// Requires a string, optionally enforcing a [minLength] and a [pattern].
  String requireString(
    String key, {
    int minLength = 0,
    RegExp? pattern,
    String? patternDescription,
  }) {
    final value = _require(key);
    if (value is! String) {
      _fail(_child(key), 'expected a string, got ${jsonTypeName(value)}');
    }
    if (value.length < minLength) {
      _fail(
        _child(key),
        minLength == 1
            ? 'must not be empty'
            : 'must be at least $minLength characters long',
      );
    }
    if (pattern != null && !pattern.hasMatch(value)) {
      _fail(
        _child(key),
        patternDescription ?? 'does not match the required format',
      );
    }
    return value;
  }

  /// Like [requireString] but returns `null` when [key] is absent.
  String? optionalString(
    String key, {
    int minLength = 0,
    RegExp? pattern,
    String? patternDescription,
  }) {
    if (!_map.containsKey(key)) return null;
    return requireString(
      key,
      minLength: minLength,
      pattern: pattern,
      patternDescription: patternDescription,
    );
  }

  /// Requires an integer strictly greater than zero.
  int requirePositiveInt(String key) {
    final value = _require(key);
    if (value is! int) {
      _fail(_child(key), 'expected an integer, got ${jsonTypeName(value)}');
    }
    if (value <= 0) {
      _fail(_child(key), 'must be greater than 0, got $value');
    }
    return value;
  }

  /// Requires a number strictly greater than zero, returned as a [double].
  double requirePositiveNum(String key) {
    final value = _require(key);
    if (value is! num) {
      _fail(_child(key), 'expected a number, got ${jsonTypeName(value)}');
    }
    if (value <= 0) {
      _fail(_child(key), 'must be greater than 0, got $value');
    }
    return value.toDouble();
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

  /// Like [requireEnum] but returns `null` when [key] is absent.
  T? optionalEnum<T>(String key, Map<String, T> byWireName) {
    if (!_map.containsKey(key)) return null;
    return requireEnum(key, byWireName);
  }

  /// Requires an array of arbitrary items.
  List<Object?> requireList(String key) {
    final value = _require(key);
    if (value is! List) {
      _fail(_child(key), 'expected an array, got ${jsonTypeName(value)}');
    }
    return value;
  }

  /// Requires a nested object, returned as a string-keyed map.
  Map<String, Object?> requireMap(String key) {
    final value = _require(key);
    if (value is! Map) {
      _fail(_child(key), 'expected an object, got ${jsonTypeName(value)}');
    }
    return value.cast<String, Object?>();
  }

  /// Like [requireMap] but returns `null` when [key] is absent.
  Map<String, Object?>? optionalMap(String key) {
    if (!_map.containsKey(key)) return null;
    return requireMap(key);
  }
}

/// Names a decoded-JSON value's type for use in error messages.
String jsonTypeName(Object? value) {
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
