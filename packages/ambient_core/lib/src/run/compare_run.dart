import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../baseline/rename.dart';
import '../manifest/manifest.dart';
import '../manifest/manifest_entry.dart';
import '../storage/baseline_storage.dart';
import 'compare_run_options.dart';
import 'compare_run_result.dart';
import 'errors.dart';

Future<CompareRunResult> compareRun({
  required Manifest manifest,
  required BaselineStorage storage,
  required CompareRunOptions options,
}) async {
  _ensureUniqueSnapshotIds(manifest.entries, source: 'current');

  final previousAcceptedManifest = await storage.getAcceptedManifest(
    branch: options.branch,
  );
  if (previousAcceptedManifest != null) {
    _ensureUniqueSnapshotIds(
      previousAcceptedManifest.entries,
      source: 'accepted',
    );
  }

  final renameDetection = detectProbableRenames(
    previousEntries:
        previousAcceptedManifest?.entries ?? const <ManifestEntry>[],
    currentEntries: manifest.entries,
  );
  final probableRenameByCurrentId = {
    for (final rename in renameDetection.probableRenames)
      rename.currentId: rename,
  };
  final previousAcceptedById = {
    for (final entry
        in previousAcceptedManifest?.entries ?? const <ManifestEntry>[])
      entry.id: entry,
  };
  final sortedEntries = [...manifest.entries]
    ..sort((a, b) => a.id.compareTo(b.id));
  final snapshots = <SnapshotRunResult>[];

  for (final entry in sortedEntries) {
    final probableRename = probableRenameByCurrentId[entry.id];
    final baselineEntry =
        previousAcceptedById[entry.id] ?? probableRename?.previousEntry;
    final candidateImagePath = _resolveImagePath(
      runDirectoryPath: options.runDirectoryPath,
      imagePath: entry.imagePath,
    );
    final candidatePng = await _readCandidatePng(
      snapshotId: entry.id,
      candidateImagePath: candidateImagePath,
    );
    _verifyContentHash(entry: entry, candidatePng: candidatePng);

    Uint8List? baselinePng;
    if (baselineEntry != null) {
      baselinePng = await storage.getBaseline(
        baselineEntry.id,
        branch: options.branch,
      );
      if (baselinePng == null) {
        throw AcceptedBaselineMissingException(
          snapshotId: entry.id,
          baselineId: baselineEntry.id,
        );
      }
    }

    snapshots.add(
      SnapshotRunResult(
        entry: entry,
        baselineEntry: baselineEntry,
        baselinePng: baselinePng,
        candidatePng: candidatePng,
        candidateImagePath: candidateImagePath,
        probableRename: probableRename,
        comparison: options.comparator.compare(
          baselinePng: baselinePng,
          candidatePng: candidatePng,
          options: options.compareOptions,
        ),
      ),
    );
  }

  return CompareRunResult(
    manifest: manifest,
    previousAcceptedManifest: previousAcceptedManifest,
    renameDetection: renameDetection,
    snapshots: snapshots,
    summary: CompareRunSummary.fromSnapshots(snapshots),
  );
}

Future<void> acceptRun(
  CompareRunResult runResult, {
  required BaselineStorage storage,
  Set<String>? ids,
  String? branch,
}) async {
  final idsToAccept =
      ids ?? {for (final snapshot in runResult.snapshots) snapshot.id};
  final availableIds = {
    for (final snapshot in runResult.snapshots) snapshot.id,
  };
  final unknownIds = [...idsToAccept.where((id) => !availableIds.contains(id))]
    ..sort();
  if (unknownIds.isNotEmpty) {
    throw UnknownSnapshotIdsException(unknownIds);
  }
  final acceptedEntriesById = {
    for (final entry
        in runResult.previousAcceptedManifest?.entries ??
            const <ManifestEntry>[])
      entry.id: entry,
  };

  for (final snapshot in runResult.snapshots) {
    if (!idsToAccept.contains(snapshot.id)) {
      continue;
    }

    if (snapshot.probableRename case final probableRename?) {
      acceptedEntriesById.remove(probableRename.previousId);
    }

    await storage.putBaseline(
      snapshot.id,
      snapshot.candidatePng,
      branch: branch,
    );
    acceptedEntriesById[snapshot.id] = snapshot.entry;
  }

  final acceptedEntries = acceptedEntriesById.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  await storage.putAcceptedManifest(
    Manifest(
      manifestVersion: runResult.manifest.manifestVersion,
      entries: acceptedEntries,
    ),
    branch: branch,
  );
}

void _ensureUniqueSnapshotIds(
  Iterable<ManifestEntry> entries, {
  required String source,
}) {
  final seenIds = <String>{};
  for (final entry in entries) {
    if (!seenIds.add(entry.id)) {
      throw DuplicateSnapshotIdException(id: entry.id, source: source);
    }
  }
}

String _resolveImagePath({
  required String runDirectoryPath,
  required String imagePath,
}) {
  return File.fromUri(Directory(runDirectoryPath).uri.resolve(imagePath)).path;
}

Future<Uint8List> _readCandidatePng({
  required String snapshotId,
  required String candidateImagePath,
}) async {
  final file = File(candidateImagePath);
  try {
    return await file.readAsBytes();
  } on FileSystemException catch (error) {
    throw CandidateImageReadException(
      snapshotId: snapshotId,
      imagePath: candidateImagePath,
      details: error.message,
    );
  }
}

void _verifyContentHash({
  required ManifestEntry entry,
  required Uint8List candidatePng,
}) {
  final actualHash = sha256.convert(candidatePng).toString();
  if (actualHash != entry.contentHash) {
    throw CandidateHashMismatchException(
      snapshotId: entry.id,
      expectedHash: entry.contentHash,
      actualHash: actualHash,
    );
  }
}
