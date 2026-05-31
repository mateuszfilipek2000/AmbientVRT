import 'dart:typed_data';

import 'compare_options.dart';
import 'comparison_result.dart';

/// Internal name kept close to the backlog language; export [SnapshotComparator]
/// publicly to avoid colliding with `dart:core`'s `Comparator` typedef.
abstract interface class Comparator {
  ComparisonResult compare({
    Uint8List? baselinePng,
    required Uint8List candidatePng,
    CompareOptions options = const CompareOptions(),
  });
}

typedef SnapshotComparator = Comparator;
