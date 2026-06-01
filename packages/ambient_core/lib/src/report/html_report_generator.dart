import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../compare/comparison_result.dart';
import '../manifest/variant.dart';
import '../run/compare_run_result.dart';

class HtmlReportOutput {
  const HtmlReportOutput({
    required this.reportPath,
    required this.assetsDirectoryPath,
  });

  final String reportPath;
  final String assetsDirectoryPath;
}

Future<HtmlReportOutput> generateHtmlReport({
  required CompareRunResult runResult,
  required String outputDirectoryPath,
}) async {
  final outputDirectory = Directory(outputDirectoryPath);
  await outputDirectory.create(recursive: true);

  final assetsDirectory = Directory.fromUri(
    outputDirectory.uri.resolve('assets/'),
  );
  if (await assetsDirectory.exists()) {
    await assetsDirectory.delete(recursive: true);
  }
  await assetsDirectory.create(recursive: true);

  final changedSnapshots = _sortSnapshots(
    runResult.snapshots.where(
      (snapshot) => snapshot.verdict == ComparisonVerdict.changed,
    ),
  );
  final newSnapshots = _sortSnapshots(
    runResult.snapshots.where(
      (snapshot) => snapshot.verdict == ComparisonVerdict.newSnapshot,
    ),
  );
  final sizeChangedSnapshots = _sortSnapshots(
    runResult.snapshots.where(
      (snapshot) => snapshot.verdict == ComparisonVerdict.sizeChanged,
    ),
  );
  final passedSnapshots = _sortSnapshots(
    runResult.snapshots.where(
      (snapshot) => snapshot.verdict == ComparisonVerdict.pass,
    ),
  );

  final changedCards = <String>[];
  for (final snapshot in changedSnapshots) {
    changedCards.add(
      await _renderChangedCard(
        snapshot: snapshot,
        outputDirectory: outputDirectory,
      ),
    );
  }

  final newCards = <String>[];
  for (final snapshot in newSnapshots) {
    newCards.add(
      await _renderCandidateCard(
        snapshot: snapshot,
        outputDirectory: outputDirectory,
        section: 'new',
      ),
    );
  }

  final sizeChangedCards = <String>[];
  for (final snapshot in sizeChangedSnapshots) {
    sizeChangedCards.add(
      await _renderSizeChangedCard(
        snapshot: snapshot,
        outputDirectory: outputDirectory,
      ),
    );
  }

  final html = _buildHtml(
    runResult: runResult,
    changedCards: changedCards,
    newCards: newCards,
    sizeChangedCards: sizeChangedCards,
    passedSnapshots: passedSnapshots,
  );

  final reportFile = File.fromUri(outputDirectory.uri.resolve('report.html'));
  await reportFile.writeAsString(html, flush: true);

  return HtmlReportOutput(
    reportPath: reportFile.path,
    assetsDirectoryPath: assetsDirectory.path,
  );
}

List<SnapshotRunResult> _sortSnapshots(Iterable<SnapshotRunResult> snapshots) {
  final sorted = snapshots.toList();
  sorted.sort((left, right) => left.id.compareTo(right.id));
  return sorted;
}

Future<String> _renderChangedCard({
  required SnapshotRunResult snapshot,
  required Directory outputDirectory,
}) async {
  final assetDirectory = 'assets/changed/${_snapshotSlug(snapshot)}/';
  final baselineSrc = await _writeAsset(
    outputDirectory: outputDirectory,
    relativePath: '${assetDirectory}baseline.png',
    bytes: snapshot.baselinePng,
  );
  final candidateSrc = await _writeAsset(
    outputDirectory: outputDirectory,
    relativePath: '${assetDirectory}candidate.png',
    bytes: snapshot.candidatePng,
  );
  final diffSrc = await _writeAsset(
    outputDirectory: outputDirectory,
    relativePath: '${assetDirectory}diff.png',
    bytes: snapshot.comparison.diffPng,
  );

  return '''
<article class="snapshot-card verdict-changed">
  ${_renderCardHeader(snapshot)}
  ${_renderMetadataList(snapshot)}
  <div class="image-grid triptych">
    ${_renderImagePanel(title: 'Baseline', src: baselineSrc, alt: '${snapshot.id} baseline')}
    ${_renderImagePanel(title: 'Candidate', src: candidateSrc, alt: '${snapshot.id} candidate')}
    ${_renderImagePanel(title: 'Diff', src: diffSrc, alt: '${snapshot.id} diff', placeholderTitle: 'Diff unavailable', placeholderDescription: 'The comparator did not provide a diff PNG for this snapshot.')}
  </div>
</article>''';
}

Future<String> _renderCandidateCard({
  required SnapshotRunResult snapshot,
  required Directory outputDirectory,
  required String section,
}) async {
  final assetDirectory = 'assets/$section/${_snapshotSlug(snapshot)}/';
  final candidateSrc = await _writeAsset(
    outputDirectory: outputDirectory,
    relativePath: '${assetDirectory}candidate.png',
    bytes: snapshot.candidatePng,
  );

  return '''
<article class="snapshot-card verdict-${_escapeAttribute(snapshot.verdict.label)}">
  ${_renderCardHeader(snapshot)}
  ${_renderMetadataList(snapshot)}
  <div class="image-grid">
    ${_renderImagePanel(title: 'Candidate', src: candidateSrc, alt: '${snapshot.id} candidate')}
  </div>
</article>''';
}

Future<String> _renderSizeChangedCard({
  required SnapshotRunResult snapshot,
  required Directory outputDirectory,
}) async {
  final assetDirectory = 'assets/size-changed/${_snapshotSlug(snapshot)}/';
  final baselineSrc = await _writeAsset(
    outputDirectory: outputDirectory,
    relativePath: '${assetDirectory}baseline.png',
    bytes: snapshot.baselinePng,
  );
  final candidateSrc = await _writeAsset(
    outputDirectory: outputDirectory,
    relativePath: '${assetDirectory}candidate.png',
    bytes: snapshot.candidatePng,
  );

  return '''
<article class="snapshot-card verdict-size-changed">
  ${_renderCardHeader(snapshot)}
  ${_renderMetadataList(snapshot)}
  <div class="image-grid">
    ${_renderImagePanel(title: 'Baseline', src: baselineSrc, alt: '${snapshot.id} baseline')}
    ${_renderImagePanel(title: 'Candidate', src: candidateSrc, alt: '${snapshot.id} candidate')}
  </div>
</article>''';
}

String _renderCardHeader(SnapshotRunResult snapshot) {
  final variantSummary = _variantSummary(snapshot.entry.variant);
  final subtitleParts = <String>[
    snapshot.entry.platform.wireName,
    '${snapshot.comparison.candidateSize} @ ${snapshot.entry.dpr}x',
    ...?_maybeSingleValue(variantSummary),
  ];
  final note = _renameNote(snapshot);

  return '''
<header class="snapshot-header">
  <div>
    <h3>${_escapeText(snapshot.id)}</h3>
    <p class="snapshot-subtitle">${_escapeText(subtitleParts.join(' • '))}</p>
  </div>
  <span class="verdict-badge">${_escapeText(_verdictTitle(snapshot.verdict))}</span>
</header>
${note == null ? '' : '<p class="snapshot-note">${_escapeText(note)}</p>'}''';
}

String _renderMetadataList(SnapshotRunResult snapshot) {
  final rows = <MapEntry<String, String>>[
    if (snapshot.baselineId case final baselineId?)
      MapEntry('Baseline ID', baselineId),
    MapEntry('Candidate size', snapshot.comparison.candidateSize.toString()),
    if (snapshot.comparison.baselineSize case final baselineSize?)
      MapEntry('Baseline size', baselineSize.toString()),
    if (snapshot.comparison.changedPixels case final changedPixels?)
      MapEntry(
        'Changed pixels',
        snapshot.comparison.changedRatio == null
            ? '$changedPixels'
            : '$changedPixels / ${snapshot.comparison.totalPixels} (${_formatPercent(snapshot.comparison.changedRatio!)})',
      ),
    MapEntry('Candidate image', snapshot.candidateImagePath),
    MapEntry('Environment', snapshot.entry.envFingerprint),
  ];

  return '''
<dl class="snapshot-metadata">
  ${rows.map((row) => '<div><dt>${_escapeText(row.key)}</dt><dd>${_escapeText(row.value)}</dd></div>').join()}
</dl>''';
}

String _renderImagePanel({
  required String title,
  required String? src,
  required String alt,
  String? placeholderTitle,
  String? placeholderDescription,
}) {
  final escapedTitle = _escapeText(title);
  if (src == null) {
    final safePlaceholderTitle = _escapeText(
      placeholderTitle ?? '$title unavailable',
    );
    final safeDescription = _escapeText(
      placeholderDescription ?? 'No image is available for this panel.',
    );
    return '''
<section class="image-panel image-panel--placeholder">
  <h4>$escapedTitle</h4>
  <div class="image-placeholder">
    <strong>$safePlaceholderTitle</strong>
    <span>$safeDescription</span>
  </div>
</section>''';
  }

  return '''
<section class="image-panel">
  <h4>$escapedTitle</h4>
  <img src="${_escapeAttribute(src)}" alt="${_escapeAttribute(alt)}" loading="lazy" />
</section>''';
}

Future<String?> _writeAsset({
  required Directory outputDirectory,
  required String relativePath,
  required List<int>? bytes,
}) async {
  if (bytes == null) {
    return null;
  }

  final file = File.fromUri(outputDirectory.uri.resolve(relativePath));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return relativePath;
}

String _buildHtml({
  required CompareRunResult runResult,
  required List<String> changedCards,
  required List<String> newCards,
  required List<String> sizeChangedCards,
  required List<SnapshotRunResult> passedSnapshots,
}) {
  final passedRows = passedSnapshots.map(_renderPassedRow).join();

  return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>AmbientVRT Report</title>
  <style>
    :root {
      color-scheme: light dark;
      --page-bg: #0f172a;
      --card-bg: #111827;
      --card-border: #334155;
      --muted: #cbd5e1;
      --text: #f8fafc;
      --accent: #38bdf8;
      --pass: #22c55e;
      --changed: #f97316;
      --new: #a855f7;
      --size-changed: #eab308;
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      font-family: Inter, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: linear-gradient(180deg, #020617 0%, var(--page-bg) 100%);
      color: var(--text);
    }

    main {
      max-width: 1280px;
      margin: 0 auto;
      padding: 32px 20px 64px;
    }

    h1,
    h2,
    h3,
    h4,
    p {
      margin-top: 0;
    }

    a {
      color: inherit;
    }

    .page-header {
      margin-bottom: 24px;
    }

    .page-header p {
      color: var(--muted);
      margin-bottom: 0;
    }

    .summary-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 16px;
      margin: 24px 0 40px;
    }

    .summary-card,
    .snapshot-card,
    .passed-card {
      background: color-mix(in srgb, var(--card-bg) 92%, black);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      box-shadow: 0 20px 40px rgba(15, 23, 42, 0.35);
    }

    .summary-card {
      padding: 16px;
    }

    .summary-card span {
      display: block;
      color: var(--muted);
      margin-bottom: 8px;
    }

    .summary-card strong {
      font-size: 2rem;
      line-height: 1;
    }

    .summary-card--changed strong {
      color: var(--changed);
    }

    .summary-card--new strong {
      color: var(--new);
    }

    .summary-card--size strong {
      color: var(--size-changed);
    }

    .summary-card--passed strong {
      color: var(--pass);
    }

    .notice {
      margin-top: 24px;
      padding: 16px 20px;
      border-radius: 8px;
    }

    .notice h2 {
      margin: 0 0 8px;
      font-size: 1rem;
    }

    .notice p {
      margin: 0 0 8px;
    }

    .notice ul {
      margin: 0;
      padding-left: 20px;
    }

    .notice--warning {
      background: #fff7ed;
      border: 1px solid #f59e0b;
      color: #7c2d12;
    }

    .notice--warning code {
      background: rgba(0, 0, 0, 0.06);
      padding: 1px 4px;
      border-radius: 4px;
    }

    .section {
      margin-top: 40px;
    }

    .section-header {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      gap: 16px;
      margin-bottom: 16px;
    }

    .section-header p {
      color: var(--muted);
      margin-bottom: 0;
    }

    .cards {
      display: grid;
      gap: 20px;
    }

    .snapshot-card {
      padding: 20px;
    }

    .snapshot-header {
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: flex-start;
      margin-bottom: 12px;
    }

    .snapshot-subtitle,
    .snapshot-note {
      color: var(--muted);
      margin-bottom: 0;
    }

    .snapshot-note {
      margin-bottom: 16px;
    }

    .verdict-badge {
      border-radius: 999px;
      border: 1px solid currentColor;
      padding: 6px 10px;
      font-size: 0.875rem;
      white-space: nowrap;
    }

    .verdict-changed .verdict-badge {
      color: var(--changed);
    }

    .verdict-new .verdict-badge {
      color: var(--new);
    }

    .verdict-size-changed .verdict-badge {
      color: var(--size-changed);
    }

    .snapshot-metadata {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 12px;
      margin: 0 0 20px;
    }

    .snapshot-metadata div {
      padding: 12px;
      border-radius: 12px;
      background: rgba(15, 23, 42, 0.55);
      border: 1px solid rgba(148, 163, 184, 0.2);
    }

    .snapshot-metadata dt {
      color: var(--muted);
      font-size: 0.875rem;
      margin-bottom: 4px;
    }

    .snapshot-metadata dd {
      margin: 0;
      word-break: break-word;
    }

    .image-grid {
      display: grid;
      gap: 16px;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    }

    .triptych {
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    }

    .image-panel {
      border: 1px solid rgba(148, 163, 184, 0.2);
      border-radius: 14px;
      overflow: hidden;
      background: rgba(2, 6, 23, 0.72);
    }

    .image-panel h4 {
      padding: 12px 14px 0;
      margin-bottom: 12px;
    }

    .image-panel img,
    .image-placeholder {
      display: block;
      width: 100%;
      background: #020617;
    }

    .image-panel img {
      padding: 0 14px 14px;
      object-fit: contain;
    }

    .image-placeholder {
      min-height: 220px;
      padding: 14px;
      color: var(--muted);
    }

    .image-placeholder strong,
    .image-placeholder span {
      display: block;
    }

    .image-placeholder strong {
      margin-bottom: 8px;
      color: var(--text);
    }

    .passed-card {
      padding: 8px 0;
      overflow: hidden;
    }

    .passed-table {
      width: 100%;
      border-collapse: collapse;
    }

    .passed-table th,
    .passed-table td {
      text-align: left;
      padding: 12px 16px;
      border-bottom: 1px solid rgba(148, 163, 184, 0.15);
      vertical-align: top;
    }

    .passed-table th {
      color: var(--muted);
      font-weight: 600;
    }

    .empty-state {
      padding: 20px;
      border: 1px dashed rgba(148, 163, 184, 0.3);
      border-radius: 16px;
      color: var(--muted);
      background: rgba(15, 23, 42, 0.35);
    }

    @media (max-width: 720px) {
      main {
        padding-inline: 16px;
      }

      .snapshot-header,
      .section-header {
        flex-direction: column;
      }
    }
  </style>
</head>
<body>
  <main>
    <header class="page-header">
      <h1>AmbientVRT Report</h1>
      <p>Standalone static report with relative image assets. Total snapshots: ${runResult.summary.total}</p>
    </header>

    ${_renderNonCanonicalNotice(runResult)}

    <section aria-labelledby="summary-heading">
      <h2 id="summary-heading">Summary</h2>
      <div class="summary-grid">
        <article class="summary-card summary-card--changed"><span>Changed</span><strong>${runResult.summary.changed}</strong></article>
        <article class="summary-card summary-card--new"><span>New</span><strong>${runResult.summary.newSnapshots}</strong></article>
        <article class="summary-card summary-card--size"><span>Size changed</span><strong>${runResult.summary.sizeChanged}</strong></article>
        <article class="summary-card summary-card--passed"><span>Passed</span><strong>${runResult.summary.passed}</strong></article>
      </div>
    </section>

    ${_renderSection(id: 'changed', title: 'Changed (${runResult.summary.changed})', description: 'Per-snapshot baseline, candidate, and diff triptychs.', content: changedCards.isEmpty ? _renderEmptyState('No changed snapshots in this run.') : '<div class="cards">${changedCards.join()}</div>')}

    ${_renderSection(id: 'new', title: 'New (${runResult.summary.newSnapshots})', description: 'Snapshots with no matching accepted baseline yet.', content: newCards.isEmpty ? _renderEmptyState('No new snapshots in this run.') : '<div class="cards">${newCards.join()}</div>')}

    ${_renderSection(id: 'size-changed', title: 'Size changed (${runResult.summary.sizeChanged})', description: 'Snapshots whose candidate dimensions differ from the accepted baseline.', content: sizeChangedCards.isEmpty ? _renderEmptyState('No size-changed snapshots in this run.') : '<div class="cards">${sizeChangedCards.join()}</div>')}

    ${_renderSection(id: 'passed', title: 'Passed (${runResult.summary.passed})', description: 'Snapshots that matched an accepted baseline.', content: passedSnapshots.isEmpty ? _renderEmptyState('No passed snapshots in this run.') : '''
<div class="passed-card">
  <table class="passed-table">
    <thead>
      <tr><th>Snapshot</th><th>Baseline</th><th>Details</th></tr>
    </thead>
    <tbody>$passedRows</tbody>
  </table>
</div>''')}
  </main>
</body>
</html>''';
}

String _renderNonCanonicalNotice(CompareRunResult runResult) {
  final nonCanonical = runResult.nonCanonicalCaptures;
  if (nonCanonical.isEmpty) {
    return '';
  }
  final ids = (nonCanonical.map((snapshot) => snapshot.id).toList()..sort())
      .map((id) => '<li>${_escapeText(id)}</li>')
      .join();
  final expected = runResult.canonicalEnv;
  return '''
<aside class="notice notice--warning" role="alert">
  <h2>⚠ Non-canonical capture environment</h2>
  <p>${nonCanonical.length} snapshot(s) were captured outside the canonical
  capture-env${expected == null ? '' : ' (<code>${_escapeText(expected)}</code>)'}.
  Their pixels may not be reproducible; capture inside the canonical image
  before accepting baselines.</p>
  <ul>$ids</ul>
</aside>''';
}

String _renderSection({
  required String id,
  required String title,
  required String description,
  required String content,
}) {
  return '''
<section class="section" aria-labelledby="$id-heading">
  <header class="section-header">
    <h2 id="$id-heading">$title</h2>
    <p>${_escapeText(description)}</p>
  </header>
  $content
</section>''';
}

String _renderEmptyState(String message) =>
    '<div class="empty-state">${_escapeText(message)}</div>';

String _renderPassedRow(SnapshotRunResult snapshot) {
  final variantSummary = _variantSummary(snapshot.entry.variant);
  final subtitleParts = <String>[
    snapshot.entry.platform.wireName,
    '${snapshot.comparison.candidateSize} @ ${snapshot.entry.dpr}x',
    ...?_maybeSingleValue(variantSummary),
  ];
  final details = <String>[
    subtitleParts.join(' • '),
    if (snapshot.probableRename case final probableRename?)
      'Probable rename from ${probableRename.previousId}',
  ];

  return '''
<tr>
  <td>${_escapeText(snapshot.id)}</td>
  <td>${_escapeText(snapshot.baselineId ?? snapshot.id)}</td>
  <td>${_escapeText(details.join(' | '))}</td>
</tr>''';
}

String _snapshotSlug(SnapshotRunResult snapshot) {
  final digest = sha256.convert(
    utf8.encode('${snapshot.verdict.label}:${snapshot.id}'),
  );
  return digest.toString();
}

String? _variantSummary(Variant? variant) {
  if (variant == null || variant.isEmpty) {
    return null;
  }

  final parts = <String>[
    if (variant.theme case final theme?) 'theme=$theme',
    if (variant.brightness case final brightness?)
      'brightness=${brightness.wireName}',
    if (variant.locale case final locale?) 'locale=$locale',
    if (variant.sizeName case final sizeName?) 'size=$sizeName',
  ];
  return parts.join(', ');
}

String? _renameNote(SnapshotRunResult snapshot) {
  if (snapshot.probableRename case final probableRename?) {
    return 'Probable rename from ${probableRename.previousId}';
  }
  if (snapshot.baselineId case final baselineId?
      when baselineId != snapshot.id) {
    return 'Compared against accepted baseline $baselineId';
  }
  return null;
}

String _verdictTitle(ComparisonVerdict verdict) {
  switch (verdict) {
    case ComparisonVerdict.pass:
      return 'Passed';
    case ComparisonVerdict.changed:
      return 'Changed';
    case ComparisonVerdict.newSnapshot:
      return 'New snapshot';
    case ComparisonVerdict.sizeChanged:
      return 'Size changed';
  }
}

String _formatPercent(double ratio) => '${(ratio * 100).toStringAsFixed(2)}%';

List<String>? _maybeSingleValue(String? value) =>
    value == null ? null : [value];

const HtmlEscape _htmlTextEscape = HtmlEscape();
const HtmlEscape _htmlAttributeEscape = HtmlEscape(HtmlEscapeMode.attribute);

String _escapeText(String value) => _htmlTextEscape.convert(value);

String _escapeAttribute(String value) => _htmlAttributeEscape.convert(value);
