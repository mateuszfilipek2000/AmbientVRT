# `preview_snapshot` reuse plan (T4.0)

> **Status:** `preview_snapshot` is a gitignored package present only in local
> working trees. It is **reference material**, not a dependency. Anything reused
> must be **re-implemented inside the committed `ambient_flutter`** — it can
> never be imported, because CI and fresh clones do not have it. This document
> maps its modules to the Phase 4 tasks (T4.2 discovery, T4.3a/b
> rendering/harness, T4.4 capture/emit) with a port / adapt / drop decision for
> each.

## What `preview_snapshot` is

A codegen + runtime that turns Flutter `@Preview` / `MultiPreview` annotations
into screenshots, leaving **no committed artifacts** behind. Its pipeline:

1. **Scan** (`lib/src/scanner.dart`) — pure Dart, no Flutter imports. Walks an
   analyzer `LibraryElement`, finds every top-level function, public static
   method, and public zero-arg constructor annotated with `@Preview` or a
   `MultiPreview` subclass. Emits a flat `List<DiscoveredPreview>` where each
   entry carries the **verbatim annotation source text** (`ann.toSource()` with
   the leading `@` stripped), the zero-arg invocation expression
   (`fn`, `Class.staticMethod`, `Class` / `Class.ctor`), a human label, and a
   best-effort `returnsWidgetBuilder` flag.
2. **Generate part files** (`lib/src/registry_generator.dart`,
   `aggregate_builder.dart`) — `build_runner` builders. For each source library
   with previews, emits a `*.previews.g.dart` **`part of`** the source library.
   Using `part of` is the key trick: the re-emitted `const <annotationSource>`
   inherits the source library's import scope for free, so wrapper/theme/locale
   references (`previewHarness`, `m.Brightness.dark`, …) resolve **without any
   import-aliasing or symbol reconstruction**. An aggregate builder collects all
   per-library lists into `lib/all_previews.g.dart`.
3. **Temporary harness** (`lib/src/cli/temporary_preview_workspace.dart`) —
   writes a throwaway `flutter test` file that imports `all_previews.g.dart`,
   loads real fonts (`loadTestFonts`), sizes the surface per preview, pumps
   `buildSurface(preview)`, `pumpAndSettle`s, and `matchesGoldenFile`s each
   capture. All generated files (`*.previews.g.dart`, `all_previews.g.dart`, the
   harness) are deleted on exit.
4. **Runtime** (`lib/preview_snapshot.dart`) — `ResolvedPreview`, `buildSurface`,
   `loadTestFonts`, `slugFor`, and `MultiPreview` expansion. Reads metadata
   (group, name, size, brightness, textScaleFactor, wrapper, theme,
   localizations) **off the live `Preview` objects at render time** rather than
   statically.
5. **CLI plumbing** (`lib/src/cli/*`) — `update_previews` executable, staged-file
   detection for a git hook, commit-message rewriting, config
   (`preview_snapshot.yaml`). All product-specific to its git-hook workflow.

## Two architectural options it surfaces

`preview_snapshot` proves the **verbatim `part of`** approach: re-emit the
annotation source unchanged into a part file and read metadata at runtime. The
committed `ambient_flutter` instead chose an **isolated-workspace** approach: a
registry under `.dart_tool/` that imports the user package via `package:` URIs
and *reconstructs* each annotation (`const Preview(group: …, wrapper: iN.fn, …)`)
from parsed constant values + resolved symbol references. The isolated approach
never writes into the user's `lib/`, which is cleaner, but it pays for that with
symbol/import-alias reconstruction machinery.

**Decision:** keep `ambient_flutter`'s isolated-workspace architecture (it is
already written end-to-end and avoids mutating the user's `lib/`), but **port
its analyzer usage to the analyzer 8 element model using `preview_snapshot`'s
proven element-level patterns** (it compiles against this exact SDK). Where the
isolated approach needs a callback's symbol, resolve it from the annotation's
constant value via `DartObject.getField(...).toFunctionValue()` /
`toFunctionValue()` rather than walking the AST.

## Module-by-module mapping

| `preview_snapshot` module | Maps to | Decision | Notes |
| --- | --- | --- | --- |
| `lib/src/scanner.dart` | **T4.2** `preview_discovery/preview_scanner.dart` | **Adapt** | Port the element-model walk (`library.topLevelFunctions`, `library.classes` → `.methods`/`.constructors`, `formalParameters`, `metadata.annotations`, `computeConstantValue()`, `toSource()`). Reuse its zero-required-arg filter and `MultiPreview`/`Preview` type detection. Drop `source_gen`'s `TypeChecker` (keep `ambient_flutter` dependency-light) — match the `widget_previews.dart` library + class name directly. Extend beyond `preview_snapshot`: also extract structured metadata + resolve `wrapper`/`theme`/`localizations` to `SymbolRef`s for the isolated registry. |
| `lib/src/registry_generator.dart` + `aggregate_builder.dart` | **T4.3b** `golden_harness` / `discovery/generated_workspace.dart` | **Adapt (don't port)** | These rely on `build_runner` + `part of`. `ambient_flutter` instead generates a standalone registry + harness under `.dart_tool/ambient_flutter/<token>/`. Reuse the *idea* (one record list of `{annotation, builder, targetName, sourcePath}` entries) but emit an importing registry, not a part file. |
| `lib/src/cli/temporary_preview_workspace.dart` (`_buildHarness`) | **T4.3a/b**, **T4.4** generated harness | **Port the mechanics** | The harness shape — `TestWidgetsFlutterBinding.ensureInitialized()`, `setUpAll(loadTestFonts)`, per-preview `testWidgets` that sizes `tester.view`, pumps `buildSurface`, `pumpAndSettle`s, captures — is exactly what `generated_workspace.dart` emits. Swap `matchesGoldenFile` for a real `RepaintBoundary.toImage` → PNG write (`captureResolvedPreview`). |
| `lib/preview_snapshot.dart` runtime (`ResolvedPreview`, `buildSurface`, `loadTestFonts`, `MultiPreview` expansion, `slugFor`) | **T4.3a** `runtime/preview_runtime.dart` | **Port** | This is the part most worth keeping: real-font loading from `FontManifest.json`, the Material surface wrapper, reading metadata off live `Preview` objects, and `MultiPreview.transform()` expansion. `ambient_flutter` already mirrors this; the only gap is the actual **capture function** (`captureResolvedPreview`), which must be added. `slugFor` → AmbientVRT derives the filename from the `ambient_core` snapshot id instead. |
| `lib/src/cli/staged_preview_detector.dart`, `commit_message.dart`, `update_previews_cli.dart`, `preview_snapshot_config.dart`, `preview_source_analysis.dart`, `bin/update_previews.dart` | — | **Drop** | Git-hook/commit-message product workflow. AmbientVRT's entrypoint is `bin/capture.dart` conforming to the capture subprocess contract; none of this applies. |
| `preview_snapshot.yaml` config, `build.yaml` | — | **Drop** | AmbientVRT is configured by `ambient.config.yaml` (core contract); no `build_runner` config needed. |

## Tasks whose scope shrinks because the logic already exists

- **T4.3a (render-one spike):** `preview_snapshot`'s `buildSurface` +
  `loadTestFonts` are directly portable, so the "spike" is mostly a port plus a
  determinism check rather than new rendering research. The committed
  `ambient_flutter` already carries the ported runtime; the only missing piece is
  `captureResolvedPreview` (RepaintBoundary → PNG).
- **T4.3b (harness codegen):** the harness *body* is a near-copy of
  `temporary_preview_workspace._buildHarness`; only the surrounding
  generation/cleanup differs (isolated workspace vs. part files).
- **T4.2 (discovery):** the analyzer walk + zero-arg filtering +
  `Preview`/`MultiPreview` detection are reusable; only the extra structured
  metadata + `SymbolRef` resolution for the isolated registry is net-new.

## Re-implementation reminder

Because `preview_snapshot` is gitignored, every reused idea above is
**re-implemented from scratch in `packages/ambient_flutter/`** and adapted to
AmbientVRT contracts: snapshot ids come from `ambient_core`
(`flutterSnapshotId`), output is the core `manifest.json` (not
`preview_snapshot`'s screenshot/golden layout), and the entrypoint conforms to
the capture subprocess contract in `docs/contracts.md`. Nothing is imported from
the ignored path.
