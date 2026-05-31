import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pixelmatch/pixelmatch.dart' as pixelmatch;

import 'compare_options.dart';
import 'comparison_result.dart';
import 'comparator.dart';
import 'errors.dart';

class PixelmatchComparator implements Comparator {
  const PixelmatchComparator();

  @override
  ComparisonResult compare({
    Uint8List? baselinePng,
    required Uint8List candidatePng,
    CompareOptions options = const CompareOptions(),
  }) {
    final candidateImage = _decodePng(candidatePng, label: 'candidate');
    final candidateSize = ImageSize(
      width: candidateImage.width,
      height: candidateImage.height,
    );

    if (baselinePng == null) {
      return ComparisonResult(
        verdict: ComparisonVerdict.newSnapshot,
        candidateSize: candidateSize,
      );
    }

    final baselineImage = _decodePng(baselinePng, label: 'baseline');
    final baselineSize = ImageSize(
      width: baselineImage.width,
      height: baselineImage.height,
    );

    if (baselineSize != candidateSize) {
      return ComparisonResult(
        verdict: ComparisonVerdict.sizeChanged,
        baselineSize: baselineSize,
        candidateSize: candidateSize,
      );
    }

    final baselineRgba = baselineImage.getBytes(order: img.ChannelOrder.rgba);
    final candidateRgba = candidateImage.getBytes(order: img.ChannelOrder.rgba);
    final diffRgba = Uint8List(candidateRgba.length);
    final totalPixels = candidateSize.pixelCount;
    final changedPixels = pixelmatch.pixelmatch(
      baselineRgba,
      candidateRgba,
      diffRgba,
      candidateImage.width,
      candidateImage.height,
      options.toPixelmatchOptions(),
    );

    if (changedPixels == 0) {
      return ComparisonResult(
        verdict: ComparisonVerdict.pass,
        baselineSize: baselineSize,
        candidateSize: candidateSize,
        changedPixels: 0,
        totalPixels: totalPixels,
      );
    }

    final diffImage = img.Image.fromBytes(
      width: candidateImage.width,
      height: candidateImage.height,
      bytes: diffRgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

    return ComparisonResult(
      verdict: ComparisonVerdict.changed,
      baselineSize: baselineSize,
      candidateSize: candidateSize,
      changedPixels: changedPixels,
      totalPixels: totalPixels,
      diffPng: img.PngEncoder().encode(diffImage),
    );
  }
}

img.Image _decodePng(Uint8List bytes, {required String label}) {
  final decoded = img.decodePng(bytes);
  if (decoded == null) {
    throw CompareImageDecodeException(label: label, byteLength: bytes.length);
  }
  return decoded;
}
