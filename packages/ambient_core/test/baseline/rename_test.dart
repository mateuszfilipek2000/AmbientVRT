import 'package:ambient_core/ambient_core.dart';
import 'package:test/test.dart';

void main() {
  group('detectProbableRenames', () {
    test('reports an identical-hash old/new pair as a probable rename', () {
      final previousEntry = _entry(
        id: 'lib/widgets/old_button.dart::ButtonPreview::flutter',
        contentHash: _hash('a'),
      );
      final currentEntry = _entry(
        id: 'lib/ui/button.dart::ButtonPreview::flutter',
        contentHash: _hash('a'),
      );

      final result = detectProbableRenames(
        previousEntries: [
          previousEntry,
          _entry(id: 'unchanged', contentHash: _hash('b')),
        ],
        currentEntries: [
          currentEntry,
          _entry(id: 'unchanged', contentHash: _hash('b')),
        ],
      );

      expect(result.probableRenames, [
        ProbableRename(
          previousEntry: previousEntry,
          currentEntry: currentEntry,
        ),
      ]);
      expect(result.hasProbableRenames, isTrue);
      expect(result.newEntries, isEmpty);
      expect(result.vanishedEntries, isEmpty);
    });

    test('does not report a rename when the content differs', () {
      final previousEntry = _entry(
        id: 'lib/widgets/old_button.dart::ButtonPreview::flutter',
        contentHash: _hash('a'),
      );
      final currentEntry = _entry(
        id: 'lib/ui/button.dart::ButtonPreview::flutter',
        contentHash: _hash('b'),
      );

      final result = detectProbableRenames(
        previousEntries: [previousEntry],
        currentEntries: [currentEntry],
      );

      expect(result.probableRenames, isEmpty);
      expect(result.hasProbableRenames, isFalse);
      expect(result.newEntries, [currentEntry]);
      expect(result.vanishedEntries, [previousEntry]);
    });

    test('stays conservative when duplicate-content matches are ambiguous', () {
      final firstPreviousEntry = _entry(
        id: 'lib/widgets/first.dart::ButtonPreview::flutter',
        contentHash: _hash('a'),
      );
      final secondPreviousEntry = _entry(
        id: 'lib/widgets/second.dart::ButtonPreview::flutter',
        contentHash: _hash('a'),
      );
      final currentEntry = _entry(
        id: 'lib/ui/button.dart::ButtonPreview::flutter',
        contentHash: _hash('a'),
      );

      final result = detectProbableRenames(
        previousEntries: [secondPreviousEntry, firstPreviousEntry],
        currentEntries: [currentEntry],
      );

      expect(result.probableRenames, isEmpty);
      expect(result.newEntries, [currentEntry]);
      expect(result.vanishedEntries, [firstPreviousEntry, secondPreviousEntry]);
    });

    test(
      'does not match across platforms even when the content hash is identical',
      () {
        final previousEntry = _entry(
          id: 'lib/widgets/button.dart::ButtonPreview::flutter',
          contentHash: _hash('a'),
          platform: Platform.flutter,
        );
        final currentEntry = _entry(
          id: 'components-button--primary::react-native',
          contentHash: _hash('a'),
          platform: Platform.reactNative,
        );

        final result = detectProbableRenames(
          previousEntries: [previousEntry],
          currentEntries: [currentEntry],
        );

        expect(result.probableRenames, isEmpty);
        expect(result.newEntries, [currentEntry]);
        expect(result.vanishedEntries, [previousEntry]);
      },
    );
  });
}

ManifestEntry _entry({
  required String id,
  required String contentHash,
  Platform platform = Platform.flutter,
}) => ManifestEntry(
  id: id,
  platform: platform,
  width: 64,
  height: 32,
  dpr: 1,
  contentHash: contentHash,
  envFingerprint: 'test-env',
  imagePath: '${Uri.encodeComponent(id)}.png',
);

String _hash(String digit) => List.filled(64, digit).join();
