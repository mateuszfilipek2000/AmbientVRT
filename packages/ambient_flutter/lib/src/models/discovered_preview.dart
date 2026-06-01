/// A single discovered preview target: a top-level function, public static
/// method, or public zero-argument constructor annotated with `@Preview` or a
/// `MultiPreview` subclass.
///
/// The annotation is captured **verbatim** ([annotationSource]) so the generated
/// registry can re-emit it unchanged. To make those verbatim references resolve,
/// the registry replicates the source file's import scope: it imports the source
/// library itself plus that file's own `import` directives ([sourceImports],
/// with relative URIs rewritten to `package:` form and prefixes/combinators
/// preserved).
class DiscoveredPreviewTarget {
  const DiscoveredPreviewTarget({
    required this.sourcePath,
    required this.targetName,
    required this.invocation,
    required this.libraryImportUri,
    required this.sourceImports,
    required this.annotationSource,
    required this.returnsWidgetBuilder,
    this.wrapperName,
    this.themeName,
    this.localizationsName,
  });

  /// Path of the defining file relative to the project root, e.g.
  /// `lib/src/previews.dart`. Used for snapshot-id derivation.
  final String sourcePath;

  /// Human-readable, stable label, e.g. `plainMessagePreview` or
  /// `SizedSummaryCard.preview`.
  final String targetName;

  /// The zero-argument invocation expression, e.g. `plainMessagePreview()`,
  /// `FixturePreviewFactory.build()`, `SizedSummaryCard.preview()`.
  final String invocation;

  /// The `package:` import URI of the library that declares the target.
  final String libraryImportUri;

  /// The reconstructed `import` directives of the source file (relative URIs
  /// resolved to `package:` form, prefixes/combinators preserved). Replicated
  /// into the registry so the verbatim annotation resolves.
  final List<String> sourceImports;

  /// The verbatim annotation source with the leading `@` stripped, e.g.
  /// `Preview(group: 'Basics', name: 'Plain card', theme: previewTheme)` or
  /// `LightDarkProductPreviews()`.
  final String annotationSource;

  /// True when the target returns a `WidgetBuilder` (or `Widget Function(
  /// BuildContext)`) rather than a `Widget` directly. The generated builder
  /// closure double-checks at runtime regardless.
  final bool returnsWidgetBuilder;

  /// Name of the `wrapper` callback, if any (display/grouping metadata only).
  final String? wrapperName;

  /// Name of the `theme` callback, if any (display/grouping metadata only).
  final String? themeName;

  /// Name of the `localizations` callback, if any (display/grouping metadata
  /// only).
  final String? localizationsName;
}
