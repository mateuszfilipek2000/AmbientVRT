final class AmbientExitCode {
  static const int success = 0;
  static const int comparisonFailed = 1;
  static const int notImplemented = 2;
  static const int usage = 64;
  static const int software = 70;
  static const int config = 78;
}

class AmbientCliException implements Exception {
  const AmbientCliException(
    this.message, {
    this.exitCode = AmbientExitCode.software,
  });

  final String message;
  final int exitCode;

  @override
  String toString() => message;
}

final class AmbientUsageException extends AmbientCliException {
  const AmbientUsageException(this.details, {required this.usage})
    : super(details, exitCode: AmbientExitCode.usage);

  final String details;
  final String usage;

  @override
  String toString() => '$details\n\n$usage';
}
