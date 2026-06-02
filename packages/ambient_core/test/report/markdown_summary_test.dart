import 'dart:typed_data';

import 'package:ambient_core/ambient_core.dart';
import 'package:test/test.dart';

void main() {
  group('buildMarkdownSummary', () {
    test('reports a red gate with a table of actionable snapshots', () {
      final runResult = _runResult([
        _snapshot(
          id: 'button-changed',
          verdict: ComparisonVerdict.changed,
          candidateSize: const ImageSize(width: 320, height: 240),
          baselineSize: const ImageSize(width: 320, height: 240),
          changedPixels: 768,
          totalPixels: 76800,
        ),
        _snapshot(
          id: 'card-size',
          verdict: ComparisonVerdict.sizeChanged,
          candidateSize: const ImageSize(width: 400, height: 240),
          baselineSize: const ImageSize(width: 320, height: 240),
        ),
        _snapshot(
          id: 'badge-new',
          verdict: ComparisonVerdict.newSnapshot,
          candidateSize: const ImageSize(width: 80, height: 24),
        ),
        _snapshot(
          id: 'button-pass',
          verdict: ComparisonVerdict.pass,
          candidateSize: const ImageSize(width: 320, height: 240),
        ),
      ]);

      final markdown = buildMarkdownSummary(runResult);

      expect(markdown, contains('## ❌ ambient · visual regression'));
      expect(markdown, contains('2 visual changes detected'));
      expect(
        markdown,
        contains('🟠 1 changed · 🟡 1 size-changed · 🟣 1 new · 🟢 1 passed '
            '(4 total)'),
      );
      // Actionable rows, ordered changed -> size-changed -> new. Passed is
      // counted but not listed.
      expect(markdown, contains('| `button-changed` | 🟠 Changed | 1.00% |'));
      expect(markdown, contains('| `card-size` | 🟡 Size changed | — '
          '| 320x240 → 400x240 |'));
      expect(markdown, contains('| `badge-new` | 🟣 New | — | 80x24 |'));
      expect(markdown, isNot(contains('button-pass')));
    });

    test('reports an all-green gate without a table', () {
      final runResult = _runResult([
        _snapshot(
          id: 'button-pass',
          verdict: ComparisonVerdict.pass,
          candidateSize: const ImageSize(width: 320, height: 240),
        ),
      ]);

      final markdown = buildMarkdownSummary(runResult);

      expect(markdown, contains('## ✅ ambient · visual regression'));
      expect(markdown, contains('All 1 snapshot matched'));
      expect(markdown, isNot(contains('| Snapshot |')));
    });

    test('flags non-canonical captures', () {
      final runResult = _runResult(
        [
          _snapshot(
            id: 'button-new',
            verdict: ComparisonVerdict.newSnapshot,
            candidateSize: const ImageSize(width: 320, height: 240),
            isCanonicalEnv: false,
          ),
        ],
        canonicalEnv: 'ambient-flutter-local',
      );

      final markdown = buildMarkdownSummary(runResult);

      expect(
        markdown,
        contains('1 snapshot(s) were captured outside the canonical '
            'capture-env (`ambient-flutter-local`)'),
      );
    });

    test('escapes pipe characters in snapshot ids', () {
      final runResult = _runResult([
        _snapshot(
          id: 'Button | primary',
          verdict: ComparisonVerdict.changed,
          candidateSize: const ImageSize(width: 10, height: 10),
          baselineSize: const ImageSize(width: 10, height: 10),
          changedPixels: 1,
          totalPixels: 100,
        ),
      ]);

      final markdown = buildMarkdownSummary(runResult);

      expect(markdown, contains(r'`Button \| primary`'));
    });
  });
}

CompareRunResult _runResult(
  List<SnapshotRunResult> snapshots, {
  String? canonicalEnv,
}) {
  return CompareRunResult(
    manifest: Manifest(
      manifestVersion: const ManifestVersion(1, 0),
      entries: [for (final snapshot in snapshots) snapshot.entry],
    ),
    snapshots: snapshots,
    summary: CompareRunSummary.fromSnapshots(snapshots),
    canonicalEnv: canonicalEnv,
  );
}

SnapshotRunResult _snapshot({
  required String id,
  required ComparisonVerdict verdict,
  required ImageSize candidateSize,
  ImageSize? baselineSize,
  int? changedPixels,
  int? totalPixels,
  bool isCanonicalEnv = true,
}) {
  final entry = ManifestEntry(
    id: id,
    platform: Platform.flutter,
    width: candidateSize.width,
    height: candidateSize.height,
    dpr: 1,
    contentHash: 'hash-$id',
    envFingerprint: 'env',
    imagePath: 'current/$id.png',
  );
  return SnapshotRunResult(
    entry: entry,
    candidatePng: Uint8List(0),
    candidateImagePath: entry.imagePath,
    comparison: ComparisonResult(
      verdict: verdict,
      candidateSize: candidateSize,
      baselineSize: baselineSize,
      changedPixels: changedPixels,
      totalPixels: totalPixels,
    ),
    isCanonicalEnv: isCanonicalEnv,
  );
}
