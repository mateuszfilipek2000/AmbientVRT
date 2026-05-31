class CompareException implements Exception {
  const CompareException(this.message);

  final String message;

  @override
  String toString() => 'CompareException: $message';
}

class CompareImageDecodeException extends CompareException {
  const CompareImageDecodeException({
    required this.label,
    required this.byteLength,
  }) : super('Could not decode $label PNG ($byteLength bytes).');

  final String label;
  final int byteLength;
}
