class CompareRunException implements Exception {
  const CompareRunException(this.message);

  final String message;

  @override
  String toString() => 'CompareRunException: $message';
}

class DuplicateSnapshotIdException extends CompareRunException {
  DuplicateSnapshotIdException({required this.id, required this.source})
    : super('Duplicate snapshot ID "$id" found in $source manifest.');

  final String id;
  final String source;
}

class CandidateImageReadException extends CompareRunException {
  CandidateImageReadException({
    required this.snapshotId,
    required this.imagePath,
    required this.details,
  }) : super(
         'Failed to read candidate image for "$snapshotId" at "$imagePath": $details',
       );

  final String snapshotId;
  final String imagePath;
  final String details;
}

class CandidateHashMismatchException extends CompareRunException {
  CandidateHashMismatchException({
    required this.snapshotId,
    required this.expectedHash,
    required this.actualHash,
  }) : super(
         'Candidate image hash mismatch for "$snapshotId": expected '
         '$expectedHash but found $actualHash.',
       );

  final String snapshotId;
  final String expectedHash;
  final String actualHash;
}

class AcceptedBaselineMissingException extends CompareRunException {
  AcceptedBaselineMissingException({
    required this.snapshotId,
    required this.baselineId,
  }) : super(
         'Accepted manifest references baseline "$baselineId" for '
         '"$snapshotId", but no PNG was found in storage.',
       );

  final String snapshotId;
  final String baselineId;
}

class UnknownSnapshotIdsException extends CompareRunException {
  UnknownSnapshotIdsException(this.ids)
    : super('acceptRun received unknown snapshot IDs: ${ids.join(', ')}');

  final List<String> ids;
}
