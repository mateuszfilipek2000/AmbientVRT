import 'dart:typed_data';

import 'package:ambient_core/ambient_core.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  const comparator = PixelmatchComparator();

  group('PixelmatchComparator', () {
    test('identical PNGs pass without a diff image', () {
      final baseline = _png(
        width: 4,
        height: 4,
        paint: (image) => _fill(image, 255, 255, 255),
      );

      final result = comparator.compare(
        baselinePng: baseline,
        candidatePng: baseline,
      );

      expect(result.verdict, ComparisonVerdict.pass);
      expect(result.changedPixels, 0);
      expect(result.totalPixels, 16);
      expect(result.changedRatio, 0);
      expect(result.diffPng, isNull);
      expect(result.baselineSize, const ImageSize(width: 4, height: 4));
      expect(result.candidateSize, const ImageSize(width: 4, height: 4));
    });

    test('changed PNGs emit a diff that highlights the changed region', () {
      final baseline = _png(
        width: 4,
        height: 4,
        paint: (image) => _fill(image, 255, 255, 255),
      );
      final candidate = _png(
        width: 4,
        height: 4,
        paint: (image) {
          _fill(image, 255, 255, 255);
          image.setPixelRgba(1, 2, 0, 0, 0, 255);
        },
      );

      final result = comparator.compare(
        baselinePng: baseline,
        candidatePng: candidate,
      );
      final diff = img.decodePng(result.diffPng!);

      expect(result.verdict, ComparisonVerdict.changed);
      expect(result.changedPixels, 1);
      expect(result.totalPixels, 16);
      expect(diff, isNotNull);

      final changedPixel = diff!.getPixel(1, 2);
      final unchangedPixel = diff.getPixel(0, 0);
      expect((changedPixel.r, changedPixel.g, changedPixel.b), (255, 0, 0));
      expect((
        unchangedPixel.r,
        unchangedPixel.g,
        unchangedPixel.b,
      ), isNot((255, 0, 0)));
    });

    test('missing baseline returns the new verdict', () {
      final candidate = _png(
        width: 3,
        height: 2,
        paint: (image) => _fill(image, 12, 34, 56),
      );

      final result = comparator.compare(candidatePng: candidate);

      expect(result.verdict, ComparisonVerdict.newSnapshot);
      expect(result.baselineSize, isNull);
      expect(result.candidateSize, const ImageSize(width: 3, height: 2));
      expect(result.changedPixels, isNull);
      expect(result.totalPixels, isNull);
      expect(result.diffPng, isNull);
    });

    test('dimension mismatches return size-changed without throwing', () {
      final baseline = _png(
        width: 4,
        height: 4,
        paint: (image) => _fill(image, 255, 255, 255),
      );
      final candidate = _png(
        width: 5,
        height: 4,
        paint: (image) => _fill(image, 255, 255, 255),
      );

      final result = comparator.compare(
        baselinePng: baseline,
        candidatePng: candidate,
      );

      expect(result.verdict, ComparisonVerdict.sizeChanged);
      expect(result.baselineSize, const ImageSize(width: 4, height: 4));
      expect(result.candidateSize, const ImageSize(width: 5, height: 4));
      expect(result.changedPixels, isNull);
      expect(result.totalPixels, isNull);
      expect(result.diffPng, isNull);
    });

    test('threshold overrides can change the verdict', () {
      final baseline = _png(
        width: 1,
        height: 1,
        paint: (image) => image.setPixelRgba(0, 0, 255, 255, 255, 255),
      );
      final candidate = _png(
        width: 1,
        height: 1,
        paint: (image) => image.setPixelRgba(0, 0, 245, 245, 245, 255),
      );

      final strict = comparator.compare(
        baselinePng: baseline,
        candidatePng: candidate,
        options: const CompareOptions(threshold: 0.01),
      );
      final lenient = comparator.compare(
        baselinePng: baseline,
        candidatePng: candidate,
        options: const CompareOptions(threshold: 0.2),
      );

      expect(strict.verdict, ComparisonVerdict.changed);
      expect(strict.changedPixels, 1);
      expect(lenient.verdict, ComparisonVerdict.pass);
      expect(lenient.changedPixels, 0);
    });

    test('invalid PNGs throw a typed decode error', () {
      expect(
        () => comparator.compare(
          baselinePng: Uint8List.fromList([1, 2, 3]),
          candidatePng: _png(
            width: 1,
            height: 1,
            paint: (image) => image.setPixelRgba(0, 0, 0, 0, 0, 255),
          ),
        ),
        throwsA(
          isA<CompareImageDecodeException>()
              .having((e) => e.label, 'label', 'baseline')
              .having((e) => e.byteLength, 'byteLength', 3),
        ),
      );
    });
  });
}

Uint8List _png({
  required int width,
  required int height,
  required void Function(img.Image image) paint,
}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  paint(image);
  return img.PngEncoder().encode(image);
}

void _fill(img.Image image, int red, int green, int blue) {
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, red, green, blue, 255);
    }
  }
}
