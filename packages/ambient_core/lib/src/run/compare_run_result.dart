import 'dart:typed_data';

import '../baseline/rename.dart';
import '../compare/comparison_result.dart';
import '../manifest/manifest.dart';
import '../manifest/manifest_entry.dart';

class SnapshotRunResult {
  const SnapshotRunResult({
    required this.entry,
    required this.candidatePng,
    required this.candidateImagePath,
    required this.comparison,
    this.baselineEntry,
    this.baselinePng,
    this.probableRename,
    this.isCanonicalEnv = true,
  });

  final ManifestEntry entry;
  final Uint8List candidatePng;
  final String candidateImagePath;
  final ComparisonResult comparison;
  final ManifestEntry? baselineEntry;
  final Uint8List? baselinePng;
  final ProbableRename? probableRename;

  /// Whether this snapshot's `envFingerprint` matched the configured canonical
  /// capture-env. `true` when the run had no canonical env to check against.
  final bool isCanonicalEnv;

  String get id => entry.id;

  ComparisonVerdict get verdict => comparison.verdict;

  String? get baselineId => baselineEntry?.id;
}

class CompareRunSummary {
  const CompareRunSummary({
    this.passed = 0,
    this.changed = 0,
    this.newSnapshots = 0,
    this.sizeChanged = 0,
  });

  factory CompareRunSummary.fromSnapshots(
    Iterable<SnapshotRunResult> snapshots,
  ) {
    var passed = 0;
    var changed = 0;
    var newSnapshots = 0;
    var sizeChanged = 0;

    for (final snapshot in snapshots) {
      switch (snapshot.verdict) {
        case ComparisonVerdict.pass:
          passed++;
          break;
        case ComparisonVerdict.changed:
          changed++;
          break;
        case ComparisonVerdict.newSnapshot:
          newSnapshots++;
          break;
        case ComparisonVerdict.sizeChanged:
          sizeChanged++;
          break;
      }
    }

    return CompareRunSummary(
      passed: passed,
      changed: changed,
      newSnapshots: newSnapshots,
      sizeChanged: sizeChanged,
    );
  }

  final int passed;
  final int changed;
  final int newSnapshots;
  final int sizeChanged;

  int get total => passed + changed + newSnapshots + sizeChanged;

  bool get hasBlockingChanges => changed > 0 || sizeChanged > 0;

  bool get hasUnacceptedSnapshots => newSnapshots > 0;

  bool get isSuccessful => !hasBlockingChanges;
}

class CompareRunResult {
  CompareRunResult({
    required this.manifest,
    required List<SnapshotRunResult> snapshots,
    required this.summary,
    this.previousAcceptedManifest,
    this.renameDetection = const RenameDetectionResult(),
    this.canonicalEnv,
  }) : snapshots = List.unmodifiable(snapshots);

  final Manifest manifest;
  final List<SnapshotRunResult> snapshots;
  final CompareRunSummary summary;
  final Manifest? previousAcceptedManifest;
  final RenameDetectionResult renameDetection;

  /// The canonical capture-env fingerprint the run was checked against, or
  /// `null` when the project declared none.
  final String? canonicalEnv;

  List<ProbableRename> get probableRenames => renameDetection.probableRenames;

  /// Snapshots whose `envFingerprint` did not match [canonicalEnv]. Empty when
  /// no canonical env was configured.
  List<SnapshotRunResult> get nonCanonicalCaptures => [
    for (final snapshot in snapshots)
      if (!snapshot.isCanonicalEnv) snapshot,
  ];

  /// Whether any snapshot was captured outside the configured canonical
  /// capture-env.
  bool get hasNonCanonicalCaptures => nonCanonicalCaptures.isNotEmpty;
}
