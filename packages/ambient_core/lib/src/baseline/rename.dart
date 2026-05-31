import '../manifest/manifest_entry.dart';
import '../manifest/platform.dart';

/// A content-stable rename from a vanished baseline ID to a new baseline ID.
class ProbableRename {
  const ProbableRename({
    required this.previousEntry,
    required this.currentEntry,
  });

  /// The prior accepted manifest entry whose ID disappeared.
  final ManifestEntry previousEntry;

  /// The current manifest entry whose ID is new.
  final ManifestEntry currentEntry;

  String get previousId => previousEntry.id;

  String get currentId => currentEntry.id;

  String get contentHash => currentEntry.contentHash;

  @override
  bool operator ==(Object other) =>
      other is ProbableRename &&
      other.previousEntry == previousEntry &&
      other.currentEntry == currentEntry;

  @override
  int get hashCode => Object.hash(previousEntry, currentEntry);

  @override
  String toString() => 'ProbableRename($previousId -> $currentId)';
}

/// Result of comparing prior accepted entries to a new manifest for renames.
class RenameDetectionResult {
  const RenameDetectionResult({
    this.probableRenames = const [],
    this.newEntries = const [],
    this.vanishedEntries = const [],
  });

  /// Unambiguous old/new pairs whose content hash stayed identical.
  final List<ProbableRename> probableRenames;

  /// Entries newly present in the current manifest that were not matched.
  final List<ManifestEntry> newEntries;

  /// Prior entries whose IDs disappeared and were not matched.
  final List<ManifestEntry> vanishedEntries;

  bool get hasProbableRenames => probableRenames.isNotEmpty;
}

/// Detects unambiguous content-hash-based renames between two manifest snapshots.
///
/// Only entries whose IDs changed are considered. Matching is conservative:
/// a hash is surfaced as a probable rename only when it yields exactly one
/// vanished entry and exactly one new entry on the same platform. Ambiguous
/// duplicate-content groups stay as unmatched new/vanished entries to avoid
/// false positives.
RenameDetectionResult detectProbableRenames({
  required Iterable<ManifestEntry> previousEntries,
  required Iterable<ManifestEntry> currentEntries,
}) {
  final previousById = {for (final entry in previousEntries) entry.id: entry};
  final currentById = {for (final entry in currentEntries) entry.id: entry};

  final vanishedEntries = [
    for (final entry in previousById.values)
      if (!currentById.containsKey(entry.id)) entry,
  ]..sort(_compareEntriesById);

  final newEntries = [
    for (final entry in currentById.values)
      if (!previousById.containsKey(entry.id)) entry,
  ]..sort(_compareEntriesById);

  final vanishedByKey = _groupByRenameKey(vanishedEntries);
  final newByKey = _groupByRenameKey(newEntries);
  final matchedVanishedIds = <String>{};
  final matchedNewIds = <String>{};
  final probableRenames = <ProbableRename>[];

  final sharedKeys = vanishedByKey.keys.where(newByKey.containsKey).toList()
    ..sort();
  for (final key in sharedKeys) {
    final vanishedGroup = vanishedByKey[key]!;
    final newGroup = newByKey[key]!;
    if (vanishedGroup.length != 1 || newGroup.length != 1) {
      continue;
    }

    final previousEntry = vanishedGroup.single;
    final currentEntry = newGroup.single;
    probableRenames.add(
      ProbableRename(previousEntry: previousEntry, currentEntry: currentEntry),
    );
    matchedVanishedIds.add(previousEntry.id);
    matchedNewIds.add(currentEntry.id);
  }

  probableRenames.sort((a, b) {
    final previousIdComparison = a.previousId.compareTo(b.previousId);
    if (previousIdComparison != 0) {
      return previousIdComparison;
    }
    return a.currentId.compareTo(b.currentId);
  });

  return RenameDetectionResult(
    probableRenames: probableRenames,
    newEntries: [
      for (final entry in newEntries)
        if (!matchedNewIds.contains(entry.id)) entry,
    ],
    vanishedEntries: [
      for (final entry in vanishedEntries)
        if (!matchedVanishedIds.contains(entry.id)) entry,
    ],
  );
}

Map<_RenameKey, List<ManifestEntry>> _groupByRenameKey(
  Iterable<ManifestEntry> entries,
) {
  final groups = <_RenameKey, List<ManifestEntry>>{};
  for (final entry in entries) {
    groups
        .putIfAbsent(
          _RenameKey(platform: entry.platform, contentHash: entry.contentHash),
          () => <ManifestEntry>[],
        )
        .add(entry);
  }
  for (final group in groups.values) {
    group.sort(_compareEntriesById);
  }
  return groups;
}

int _compareEntriesById(ManifestEntry a, ManifestEntry b) =>
    a.id.compareTo(b.id);

class _RenameKey implements Comparable<_RenameKey> {
  const _RenameKey({required this.platform, required this.contentHash});

  final Platform platform;
  final String contentHash;

  @override
  int compareTo(_RenameKey other) {
    final platformComparison = platform.wireName.compareTo(
      other.platform.wireName,
    );
    if (platformComparison != 0) {
      return platformComparison;
    }
    return contentHash.compareTo(other.contentHash);
  }

  @override
  bool operator ==(Object other) =>
      other is _RenameKey &&
      other.platform == platform &&
      other.contentHash == contentHash;

  @override
  int get hashCode => Object.hash(platform, contentHash);
}
