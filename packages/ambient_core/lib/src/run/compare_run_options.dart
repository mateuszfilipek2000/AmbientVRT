import '../compare/compare.dart';

class CompareRunOptions {
  const CompareRunOptions({
    required this.runDirectoryPath,
    this.compareOptions = const CompareOptions(),
    this.comparator = const PixelmatchComparator(),
    this.branch,
    this.canonicalEnv,
  });

  final String runDirectoryPath;
  final CompareOptions compareOptions;
  final SnapshotComparator comparator;
  final String? branch;

  /// Expected canonical capture-env fingerprint (the canonical image digest or
  /// reference from `ambient.config.yaml`), or `null` when the project has not
  /// declared one.
  ///
  /// When set, every snapshot whose `envFingerprint` differs is flagged as a
  /// non-canonical capture in the run result (a non-blocking warning — it does
  /// not change verdicts or exit codes).
  final String? canonicalEnv;
}
