/// Stable snapshot-ID derivation.
///
/// The snapshot ID is the baseline key: it must be **semantic and
/// platform-derived, never positional**, so it survives file moves and
/// reorders. Changing this derivation invalidates every stored baseline, so
/// this module is **frozen-by-default once shipped** — extend it additively,
/// never alter the output of an existing input.
///
/// ## ID shape
///
/// A full snapshot ID is a list of segments joined by [idSegmentSeparator]:
///
/// ```text
/// <base>::<platform>[::<key=value> for each set variant dimension]
/// ```
///
/// * **base** is platform-derived:
///   * React Native — the Storybook **story id** verbatim
///     (e.g. `components-button--primary`).
///   * Flutter — `path::name::group` (group omitted when absent).
///   An explicit **override** replaces the base and is therefore rename-proof.
/// * **platform** is the [Platform.wireName] (`flutter` / `react-native`).
/// * **variant** dimensions are appended as `key=value` pairs in a fixed
///   canonical (alphabetical-by-key) order, so suffixing is order-independent
///   and stable.
///
/// Example: `components-button--primary::react-native::brightness=dark`.
///
/// The structured [Variant] is *also* kept on the manifest entry for reporting
/// and grouping; embedding it here additionally guarantees a distinct baseline
/// key per variant.
library;

import '../manifest/platform.dart';
import '../manifest/variant.dart';

/// Separator between snapshot-ID segments.
///
/// Doubles as the Flutter `path::name::group` separator. Chosen to be visually
/// distinct and unlikely to collide with characters found in paths, widget
/// names, or Storybook ids.
const String idSegmentSeparator = '::';

/// Derives the platform-specific **base** ID for a React Native story.
///
/// The Storybook story id (derived from the story `title` + export name, e.g.
/// `components-button--primary`) is preserved **verbatim** — it is already
/// stable across file moves as long as the `title` holds.
///
/// Throws [ArgumentError] if [storyId] is blank.
String reactNativeBaseId(String storyId) {
  if (storyId.trim().isEmpty) {
    throw ArgumentError.value(storyId, 'storyId', 'must not be blank');
  }
  return storyId;
}

/// Derives the platform-specific **base** ID for a Flutter preview as
/// `path::name::group`.
///
/// [group] is omitted from the ID when null or empty, yielding `path::name`.
/// Because the [path] participates in the ID, moving the source file changes
/// the derived base — supply an explicit override (see [flutterSnapshotId]) to
/// keep an ID stable across moves.
///
/// Throws [ArgumentError] if [path] or [name] is blank.
String flutterBaseId({
  required String path,
  required String name,
  String? group,
}) {
  if (path.trim().isEmpty) {
    throw ArgumentError.value(path, 'path', 'must not be blank');
  }
  if (name.trim().isEmpty) {
    throw ArgumentError.value(name, 'name', 'must not be blank');
  }
  final segments = <String>[path, name];
  if (group != null && group.isNotEmpty) {
    segments.add(group);
  }
  return segments.join(idSegmentSeparator);
}

/// The canonical, order-independent variant `key=value` segments for [dims].
///
/// Keys are sorted so the result depends only on the *set* of dimensions, never
/// on their insertion order. Exposed (over the [Variant]-typed
/// [variantIdSegments]) so order-independence is directly testable.
List<String> variantIdSegmentsFromMap(Map<String, String> dims) {
  final keys = dims.keys.toList()..sort();
  return [for (final key in keys) '$key=${dims[key]}'];
}

/// The canonical variant `key=value` segments for [variant].
///
/// Returns an empty list for a null or empty variant. Only set dimensions are
/// emitted; ordering is canonical (see [variantIdSegmentsFromMap]).
List<String> variantIdSegments(Variant? variant) {
  if (variant == null) return const [];
  final dims = <String, String>{
    if (variant.brightness != null) 'brightness': variant.brightness!.wireName,
    if (variant.locale != null) 'locale': variant.locale!,
    if (variant.sizeName != null) 'sizeName': variant.sizeName!,
    if (variant.theme != null) 'theme': variant.theme!,
  };
  return variantIdSegmentsFromMap(dims);
}

/// Assembles a full snapshot ID from a pre-derived [baseId], [platform], and
/// optional [variant].
///
/// Prefer [flutterSnapshotId] / [reactNativeSnapshotId], which derive the base
/// and apply override handling for you.
///
/// Throws [ArgumentError] if [baseId] is blank.
String snapshotIdFromBase({
  required String baseId,
  required Platform platform,
  Variant? variant,
}) {
  if (baseId.trim().isEmpty) {
    throw ArgumentError.value(baseId, 'baseId', 'must not be blank');
  }
  final segments = <String>[
    baseId,
    platform.wireName,
    ...variantIdSegments(variant),
  ];
  return segments.join(idSegmentSeparator);
}

/// Derives the full snapshot ID for a Flutter preview.
///
/// When [idOverride] is non-blank it replaces the `path::name::group` base,
/// making the ID rename-proof: moving the source file (changing [path]) leaves
/// the ID unchanged. [variant] suffixing is applied either way.
String flutterSnapshotId({
  required String path,
  required String name,
  String? group,
  String? idOverride,
  Variant? variant,
}) {
  final base =
      _override(idOverride) ??
      flutterBaseId(path: path, name: name, group: group);
  return snapshotIdFromBase(
    baseId: base,
    platform: Platform.flutter,
    variant: variant,
  );
}

/// Derives the full snapshot ID for a React Native story.
///
/// When [idOverride] is non-blank it replaces the verbatim [storyId] base.
/// [variant] suffixing is applied either way.
String reactNativeSnapshotId({
  required String storyId,
  String? idOverride,
  Variant? variant,
}) {
  final base = _override(idOverride) ?? reactNativeBaseId(storyId);
  return snapshotIdFromBase(
    baseId: base,
    platform: Platform.reactNative,
    variant: variant,
  );
}

/// Normalizes an override: a null or blank override is treated as absent.
String? _override(String? idOverride) {
  if (idOverride == null || idOverride.trim().isEmpty) return null;
  return idOverride;
}
