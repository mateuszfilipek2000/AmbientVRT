import '../compare/compare.dart';

class CompareRunOptions {
  const CompareRunOptions({
    required this.runDirectoryPath,
    this.compareOptions = const CompareOptions(),
    this.comparator = const PixelmatchComparator(),
    this.branch,
  });

  final String runDirectoryPath;
  final CompareOptions compareOptions;
  final SnapshotComparator comparator;
  final String? branch;
}
