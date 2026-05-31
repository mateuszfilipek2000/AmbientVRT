import 'dart:typed_data';

enum ComparisonVerdict {
  pass('pass'),
  changed('changed'),
  newSnapshot('new'),
  sizeChanged('size-changed');

  const ComparisonVerdict(this.label);

  final String label;

  @override
  String toString() => label;
}

class ImageSize {
  const ImageSize({required this.width, required this.height});

  final int width;
  final int height;

  int get pixelCount => width * height;

  @override
  bool operator ==(Object other) =>
      other is ImageSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => '${width}x$height';
}

class ComparisonResult {
  const ComparisonResult({
    required this.verdict,
    required this.candidateSize,
    this.baselineSize,
    this.changedPixels,
    this.totalPixels,
    this.diffPng,
  });

  final ComparisonVerdict verdict;
  final ImageSize? baselineSize;
  final ImageSize candidateSize;
  final int? changedPixels;
  final int? totalPixels;
  final Uint8List? diffPng;

  double? get changedRatio {
    if (changedPixels == null || totalPixels == null || totalPixels == 0) {
      return null;
    }
    return changedPixels! / totalPixels!;
  }
}
