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
  final sizeChangedSnapshots = _sortSnapshots(
    runResult.snapshots.where(
      (snapshot) => snapshot.verdict == ComparisonVerdict.sizeChanged,
    ),
  );
  final newSnapshots = _sortSnapshots(
    runResult.snapshots.where(
      (snapshot) => snapshot.verdict == ComparisonVerdict.newSnapshot,
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
      await _renderCase(snapshot: snapshot, outputDirectory: outputDirectory),
    );
  }
  final sizeChangedCards = <String>[];
  for (final snapshot in sizeChangedSnapshots) {
    sizeChangedCards.add(
      await _renderCase(snapshot: snapshot, outputDirectory: outputDirectory),
    );
  }
  final newCards = <String>[];
  for (final snapshot in newSnapshots) {
    newCards.add(
      await _renderCase(snapshot: snapshot, outputDirectory: outputDirectory),
    );
  }

  final html = _buildHtml(
    runResult: runResult,
    changedSnapshots: changedSnapshots,
    changedCards: changedCards,
    sizeChangedSnapshots: sizeChangedSnapshots,
    sizeChangedCards: sizeChangedCards,
    newSnapshots: newSnapshots,
    newCards: newCards,
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

// ---------------------------------------------------------------------------
// Case rendering (changed / size-changed / new)
// ---------------------------------------------------------------------------

Future<String> _renderCase({
  required SnapshotRunResult snapshot,
  required Directory outputDirectory,
}) async {
  final verdict = snapshot.verdict;
  final slug = _snapshotSlug(snapshot);
  final assetDirectory = 'assets/${verdict.label}/$slug/';

  final candidateSrc = await _writeAsset(
    outputDirectory: outputDirectory,
    relativePath: '${assetDirectory}candidate.png',
    bytes: snapshot.candidatePng,
  );

  String? baselineSrc;
  if (verdict == ComparisonVerdict.changed ||
      verdict == ComparisonVerdict.sizeChanged) {
    baselineSrc = await _writeAsset(
      outputDirectory: outputDirectory,
      relativePath: '${assetDirectory}baseline.png',
      bytes: snapshot.baselinePng,
    );
  }

  String? diffSrc;
  if (verdict == ComparisonVerdict.changed) {
    diffSrc = await _writeAsset(
      outputDirectory: outputDirectory,
      relativePath: '${assetDirectory}diff.png',
      bytes: snapshot.comparison.diffPng,
    );
  }

  final defaultMode = switch (verdict) {
    ComparisonVerdict.changed => 'slider',
    ComparisonVerdict.sizeChanged => 'side',
    _ => 'single',
  };

  // The fallback grid below renders the raw <img> tags. It is the no-JS view
  // and is also what JS replaces in-place with the interactive viewer.
  final panels = <String>[];
  if (baselineSrc != null) {
    panels.add(_imagePanel('Baseline', baselineSrc, '${snapshot.id} baseline'));
  }
  if (candidateSrc != null) {
    panels.add(
      _imagePanel('Candidate', candidateSrc, '${snapshot.id} candidate'),
    );
  }
  if (verdict == ComparisonVerdict.changed) {
    panels.add(
      diffSrc == null
          ? _placeholderPanel(
              'Diff',
              'Diff unavailable',
              'The comparator did not provide a diff image for this snapshot.',
            )
          : _imagePanel('Diff', diffSrc, '${snapshot.id} diff'),
    );
  }

  final dataAttributes = StringBuffer()
    ..write(' data-mode="$defaultMode"');
  if (baselineSrc != null) {
    dataAttributes.write(' data-baseline="${_escapeAttribute(baselineSrc)}"');
  }
  if (candidateSrc != null) {
    dataAttributes.write(' data-candidate="${_escapeAttribute(candidateSrc)}"');
  }
  if (diffSrc != null) {
    dataAttributes.write(' data-diff="${_escapeAttribute(diffSrc)}"');
  }

  final note = _renameNote(snapshot);

  return '''
<article class="case ${_verdictClass(verdict)}" id="case-$slug" data-id="${_escapeAttribute(snapshot.id)}">
  <div class="case-head">
    <p class="breadcrumb">${_escapeText(_breadcrumb(snapshot))}</p>
    <div class="case-title-row">
      <h2 class="case-title">${_escapeText(snapshot.id)}</h2>
      <span class="badge ${_verdictClass(verdict)}">${_verdictIcon(verdict)}${_escapeText(_verdictTitle(verdict))}</span>
    </div>
    ${note == null ? '' : '<p class="case-note">${_svg(_icInfo)}${_escapeText(note)}</p>'}
  </div>
  ${_renderChips(snapshot)}
  <div class="compare"$dataAttributes>
    <div class="image-grid">${panels.join()}</div>
  </div>
  ${_renderExecDetails(snapshot)}
</article>''';
}

String _imagePanel(String title, String src, String alt) => '''
<figure class="panel">
  <figcaption>${_escapeText(title)}</figcaption>
  <img src="${_escapeAttribute(src)}" alt="${_escapeAttribute(alt)}" loading="lazy" />
</figure>''';

String _placeholderPanel(String title, String heading, String description) => '''
<figure class="panel panel--placeholder">
  <figcaption>${_escapeText(title)}</figcaption>
  <div class="placeholder">
    <strong>${_escapeText(heading)}</strong>
    <span>${_escapeText(description)}</span>
  </div>
</figure>''';

String _renderChips(SnapshotRunResult snapshot) {
  final comparison = snapshot.comparison;
  final chips = <String>[
    _chip(_icMonitor, snapshot.entry.platform.wireName),
    _chip(
      _icExpand,
      snapshot.verdict == ComparisonVerdict.sizeChanged &&
              comparison.baselineSize != null
          ? '${comparison.baselineSize} → ${comparison.candidateSize}'
          : '${comparison.candidateSize}',
    ),
    _chip(_icLayers, '${snapshot.entry.dpr}×'),
    if (comparison.changedRatio case final ratio?)
      _chip(_icAlert, '${_formatPercent(ratio)} mismatch', cls: 'chip--warn'),
  ];

  final variant = snapshot.entry.variant;
  if (variant != null && !variant.isEmpty) {
    if (variant.theme case final theme?) {
      chips.add(_chip(_icTag, 'theme · $theme'));
    }
    if (variant.brightness case final brightness?) {
      chips.add(_chip(_icTag, brightness.wireName));
    }
    if (variant.locale case final locale?) {
      chips.add(_chip(_icTag, locale));
    }
    if (variant.sizeName case final sizeName?) {
      chips.add(_chip(_icTag, 'size · $sizeName'));
    }
  }

  chips.add(_chip(_icClock, snapshot.entry.envFingerprint, cls: 'chip--muted'));

  return '<div class="chips">${chips.join()}</div>';
}

String _chip(String icon, String text, {String cls = ''}) =>
    '<span class="chip $cls">${_svg(icon)}<span>${_escapeText(text)}</span></span>';

String _renderExecDetails(SnapshotRunResult snapshot) {
  final comparison = snapshot.comparison;
  final rows = <MapEntry<String, String>>[
    MapEntry('Snapshot ID', snapshot.id),
    if (snapshot.baselineId case final baselineId?)
      MapEntry('Baseline ID', baselineId),
    MapEntry('Candidate size', comparison.candidateSize.toString()),
    if (comparison.baselineSize case final baselineSize?)
      MapEntry('Baseline size', baselineSize.toString()),
    if (comparison.changedPixels case final changedPixels?)
      MapEntry(
        'Changed pixels',
        comparison.changedRatio == null
            ? '$changedPixels'
            : '$changedPixels / ${comparison.totalPixels} (${_formatPercent(comparison.changedRatio!)})',
      ),
    MapEntry('Candidate image', snapshot.candidateImagePath),
    MapEntry('Environment', snapshot.entry.envFingerprint),
  ];

  final body = rows
      .map(
        (row) =>
            '<div class="exec-row"><dt>${_escapeText(row.key)}</dt><dd>${_escapeText(row.value)}</dd></div>',
      )
      .join();

  return '''
<details class="exec">
  <summary>${_svg(_icList)}<span>Execution details</span></summary>
  <dl class="exec-grid">$body</dl>
</details>''';
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

// ---------------------------------------------------------------------------
// Page shell
// ---------------------------------------------------------------------------

String _buildHtml({
  required CompareRunResult runResult,
  required List<SnapshotRunResult> changedSnapshots,
  required List<String> changedCards,
  required List<SnapshotRunResult> sizeChangedSnapshots,
  required List<String> sizeChangedCards,
  required List<SnapshotRunResult> newSnapshots,
  required List<String> newCards,
  required List<SnapshotRunResult> passedSnapshots,
}) {
  final summary = runResult.summary;
  final status = _overallStatus(summary);

  final groups = <String>[
    _renderGroup(
      verdict: ComparisonVerdict.changed,
      title: 'Changed',
      icon: _icAlert,
      cards: changedCards,
    ),
    _renderGroup(
      verdict: ComparisonVerdict.sizeChanged,
      title: 'Size changed',
      icon: _icExpand,
      cards: sizeChangedCards,
    ),
    _renderGroup(
      verdict: ComparisonVerdict.newSnapshot,
      title: 'New',
      icon: _icPlus,
      cards: newCards,
    ),
  ].where((group) => group.isNotEmpty).toList();

  final hasVisualCases = groups.isNotEmpty;
  final mainBody = StringBuffer();
  if (!hasVisualCases) {
    mainBody.write(_renderHero(summary));
  } else {
    mainBody.writeAll(groups);
  }
  mainBody.write(_renderPassedSection(passedSnapshots));

  final nav = _renderNav(
    changed: changedSnapshots,
    sizeChanged: sizeChangedSnapshots,
    newSnapshots: newSnapshots,
    passed: passedSnapshots,
  );

  return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>ambient · Visual regression report</title>
  <style>$_styles</style>
</head>
<body>
  <header class="topbar">
    <div class="topbar-inner">
      <a class="brand" href="#top" id="top">
        <span class="brand-orb" aria-hidden="true"></span>
        <span class="brand-text">
          <span class="brand-name">ambient</span>
          <span class="brand-sub">Visual regression report</span>
        </span>
        <h1 class="sr-only">AmbientVRT Report</h1>
      </a>
      <div class="summary" data-total="${summary.total}" data-changed="${summary.changed}" data-size-changed="${summary.sizeChanged}" data-new="${summary.newSnapshots}" data-passed="${summary.passed}">
        <div class="status status--${status.tone}">${_svg(status.icon)}<span>${_escapeText(status.label)}</span></div>
        <div class="stats">
          ${_stat('changed', 'Changed', summary.changed)}
          ${_stat('size-changed', 'Size', summary.sizeChanged)}
          ${_stat('new', 'New', summary.newSnapshots)}
          ${_stat('pass', 'Passed', summary.passed)}
        </div>
      </div>
    </div>
  </header>

  ${_renderNonCanonicalNotice(runResult)}

  <div class="layout">
    <aside class="sidebar">
      <div class="search">
        ${_svg(_icSearch)}
        <input id="search" type="search" placeholder="Filter snapshots…" autocomplete="off" spellcheck="false" />
      </div>
      <nav class="nav">$nav</nav>
    </aside>
    <main class="main">$mainBody</main>
  </div>

  <script>$_script</script>
</body>
</html>''';
}

({String tone, String icon, String label}) _overallStatus(
  CompareRunSummary summary,
) {
  if (summary.total == 0) {
    return (tone: 'pass', icon: _icCheck, label: 'No snapshots');
  }
  if (summary.hasBlockingChanges) {
    final count = summary.changed + summary.sizeChanged;
    return (
      tone: 'changed',
      icon: _icAlert,
      label: '$count visual ${count == 1 ? 'change' : 'changes'} detected',
    );
  }
  if (summary.hasUnacceptedSnapshots) {
    return (
      tone: 'new',
      icon: _icPlus,
      label: '${summary.newSnapshots} new ${summary.newSnapshots == 1 ? 'snapshot' : 'snapshots'} pending',
    );
  }
  return (tone: 'pass', icon: _icCheck, label: 'All snapshots passed');
}

String _stat(String verdictLabel, String label, int value) => '''
<div class="stat v-$verdictLabel">
  <span class="stat-num">$value</span>
  <span class="stat-label">${_escapeText(label)}</span>
</div>''';

String _renderGroup({
  required ComparisonVerdict verdict,
  required String title,
  required String icon,
  required List<String> cards,
}) {
  if (cards.isEmpty) {
    return '';
  }
  return '''
<section class="group ${_verdictClass(verdict)}" id="group-${verdict.label}">
  <div class="group-head">
    <span class="group-icon">${_svg(icon)}</span>
    <h2 class="group-title">$title</h2>
    <span class="group-count">${cards.length}</span>
  </div>
  <div class="cards">${cards.join()}</div>
</section>''';
}

String _renderHero(CompareRunSummary summary) {
  final pending = summary.hasUnacceptedSnapshots;
  final heading = pending ? 'No regressions' : 'All clear';
  final message = pending
      ? 'No accepted baselines changed in this run. There are new snapshots awaiting acceptance below.'
      : 'Every snapshot matched its accepted baseline. Nothing to review here.';
  return '''
<section class="hero">
  <span class="hero-orb" aria-hidden="true">${_svg(_icCheck)}</span>
  <h2>$heading</h2>
  <p>${_escapeText(message)}</p>
</section>''';
}

String _renderPassedSection(List<SnapshotRunResult> passedSnapshots) {
  if (passedSnapshots.isEmpty) {
    return '';
  }
  final rows = passedSnapshots.map(_renderPassedRow).join();
  return '''
<section class="group v-pass" id="group-pass">
  <div class="group-head">
    <span class="group-icon">${_svg(_icCheck)}</span>
    <h2 class="group-title">Passed</h2>
    <span class="group-count">${passedSnapshots.length}</span>
  </div>
  <div class="panel passed-panel">
    <table class="passed-table">
      <thead>
        <tr><th>Snapshot</th><th>Baseline</th><th>Details</th></tr>
      </thead>
      <tbody>$rows</tbody>
    </table>
  </div>
</section>''';
}

String _renderPassedRow(SnapshotRunResult snapshot) {
  final slug = _snapshotSlug(snapshot);
  final details = <String>[
    _breadcrumb(snapshot),
    if (snapshot.probableRename case final probableRename?)
      'Probable rename from ${probableRename.previousId}',
  ];

  return '''
<tr class="passed-row" id="pass-$slug" data-id="${_escapeAttribute(snapshot.id)}">
  <td><span class="dot v-pass"></span>${_escapeText(snapshot.id)}</td>
  <td>${_escapeText(snapshot.baselineId ?? snapshot.id)}</td>
  <td class="passed-details">${_escapeText(details.join(' · '))}</td>
</tr>''';
}

String _renderNav({
  required List<SnapshotRunResult> changed,
  required List<SnapshotRunResult> sizeChanged,
  required List<SnapshotRunResult> newSnapshots,
  required List<SnapshotRunResult> passed,
}) {
  final groups = <String>[
    _navGroup('Changed', changed, idPrefix: 'case'),
    _navGroup('Size changed', sizeChanged, idPrefix: 'case'),
    _navGroup('New', newSnapshots, idPrefix: 'case'),
    _navGroup('Passed', passed, idPrefix: 'pass'),
  ].where((group) => group.isNotEmpty).toList();

  if (groups.isEmpty) {
    return '<p class="nav-empty">No snapshots in this run.</p>';
  }
  return groups.join();
}

String _navGroup(
  String title,
  List<SnapshotRunResult> snapshots, {
  required String idPrefix,
}) {
  if (snapshots.isEmpty) {
    return '';
  }
  final items = snapshots.map((snapshot) {
    final slug = _snapshotSlug(snapshot);
    final ratio = snapshot.comparison.changedRatio;
    final meta = ratio == null
        ? ''
        : '<span class="nav-meta">${_formatPercent(ratio)}</span>';
    return '''
<a class="nav-item ${_verdictClass(snapshot.verdict)}" href="#$idPrefix-$slug" data-target="$idPrefix-$slug">
  <span class="dot ${_verdictClass(snapshot.verdict)}"></span>
  <span class="nav-label">${_escapeText(snapshot.id)}</span>
  $meta
</a>''';
  }).join();

  return '''
<div class="nav-group">
  <p class="nav-group-head">$title<span class="nav-group-count">${snapshots.length}</span></p>
  $items
</div>''';
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
<aside class="notice" role="alert">
  <div class="notice-inner">
    ${_svg(_icAlert)}
    <div>
      <strong>Non-canonical capture environment</strong>
      <p>${nonCanonical.length} snapshot(s) were captured outside the canonical
      capture-env${expected == null ? '' : ' (<code>${_escapeText(expected)}</code>)'}.
      Their pixels may not be reproducible; capture inside the canonical image
      before accepting baselines.</p>
      <ul>$ids</ul>
    </div>
  </div>
</aside>''';
}

String _breadcrumb(SnapshotRunResult snapshot) {
  final variantSummary = _variantSummary(snapshot.entry.variant);
  final parts = <String>[
    snapshot.entry.platform.wireName,
    '${snapshot.comparison.candidateSize} @ ${snapshot.entry.dpr}x',
    ...?_maybeSingleValue(variantSummary),
  ];
  return parts.join(' • ');
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

String _verdictClass(ComparisonVerdict verdict) => 'v-${verdict.label}';

String _verdictTitle(ComparisonVerdict verdict) {
  switch (verdict) {
    case ComparisonVerdict.pass:
      return 'Passed';
    case ComparisonVerdict.changed:
      return 'Changed';
    case ComparisonVerdict.newSnapshot:
      return 'New';
    case ComparisonVerdict.sizeChanged:
      return 'Size changed';
  }
}

String _verdictIcon(ComparisonVerdict verdict) {
  final icon = switch (verdict) {
    ComparisonVerdict.pass => _icCheck,
    ComparisonVerdict.changed => _icAlert,
    ComparisonVerdict.newSnapshot => _icPlus,
    ComparisonVerdict.sizeChanged => _icExpand,
  };
  return _svg(icon);
}

String _formatPercent(double ratio) => '${(ratio * 100).toStringAsFixed(2)}%';

List<String>? _maybeSingleValue(String? value) =>
    value == null ? null : [value];

String _svg(String inner) =>
    '<svg class="ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">$inner</svg>';

const HtmlEscape _htmlTextEscape = HtmlEscape();
const HtmlEscape _htmlAttributeEscape = HtmlEscape(HtmlEscapeMode.attribute);

String _escapeText(String value) => _htmlTextEscape.convert(value);

String _escapeAttribute(String value) => _htmlAttributeEscape.convert(value);

// ---------------------------------------------------------------------------
// Inline icon paths (24x24, stroked)
// ---------------------------------------------------------------------------

const _icCheck = '<path d="M20 6 9 17l-5-5"/>';
const _icAlert =
    '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h16.9a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4"/><path d="M12 17h.01"/>';
const _icPlus = '<path d="M12 5v14"/><path d="M5 12h14"/>';
const _icExpand =
    '<path d="M15 3h6v6"/><path d="M9 21H3v-6"/><path d="M21 3l-7 7"/><path d="M3 21l7-7"/>';
const _icMonitor =
    '<rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8"/><path d="M12 17v4"/>';
const _icLayers =
    '<path d="m12 2 9 5-9 5-9-5 9-5z"/><path d="m3 12 9 5 9-5"/><path d="m3 17 9 5 9-5"/>';
const _icTag =
    '<path d="M20.6 13.4 12 22l-9-9V4a1 1 0 0 1 1-1h8z"/><circle cx="7.5" cy="7.5" r="1.5"/>';
const _icClock =
    '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>';
const _icSearch =
    '<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/>';
const _icList =
    '<path d="M8 6h13"/><path d="M8 12h13"/><path d="M8 18h13"/><path d="M3 6h.01"/><path d="M3 12h.01"/><path d="M3 18h.01"/>';
const _icInfo =
    '<circle cx="12" cy="12" r="9"/><path d="M12 16v-4"/><path d="M12 8h.01"/>';

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const _styles = r'''
*,*::before,*::after{box-sizing:border-box}
:root{
  --bg:#070b16;
  --bg-2:#0b1120;
  --surface:rgba(20,27,45,.66);
  --surface-solid:#121a2e;
  --hairline:rgba(148,170,214,.14);
  --hairline-strong:rgba(148,170,214,.26);
  --text:#eaf0fb;
  --muted:#94a3c4;
  --faint:#64708d;
  --aqua:#5eead4;
  --indigo:#818cf8;
  --c-changed:#fb923c;
  --c-new:#a78bfa;
  --c-size-changed:#fbbf24;
  --c-pass:#34d399;
  --shadow:0 24px 60px -24px rgba(0,0,0,.7);
}
html{scroll-behavior:smooth}
body{
  margin:0;
  font-family:'Inter',system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
  color:var(--text);
  background:var(--bg);
  -webkit-font-smoothing:antialiased;
  line-height:1.5;
}
body::before{
  content:'';
  position:fixed;
  inset:0;
  z-index:-1;
  background:
    radial-gradient(900px 600px at 12% -8%, rgba(94,234,212,.16), transparent 60%),
    radial-gradient(800px 600px at 92% 0%, rgba(129,140,248,.18), transparent 58%),
    radial-gradient(1000px 700px at 60% 110%, rgba(167,139,250,.10), transparent 60%),
    linear-gradient(180deg, var(--bg) 0%, var(--bg-2) 100%);
}
a{color:inherit;text-decoration:none}
h1,h2,h3,p{margin:0}
.sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap;border:0}
.ico{width:1.05em;height:1.05em;flex:none}

/* Topbar */
.topbar{
  position:sticky;top:0;z-index:30;
  backdrop-filter:saturate(150%) blur(16px);
  background:linear-gradient(180deg, rgba(7,11,22,.86), rgba(7,11,22,.62));
  border-bottom:1px solid var(--hairline);
}
.topbar-inner{
  max-width:1440px;margin:0 auto;
  padding:16px 28px;
  display:flex;align-items:center;justify-content:space-between;gap:24px;flex-wrap:wrap;
}
.brand{display:flex;align-items:center;gap:14px}
.brand-orb{
  width:36px;height:36px;border-radius:50%;
  background:radial-gradient(circle at 32% 30%, #aef7e6, #5eead4 38%, #6366f1 92%);
  box-shadow:0 0 26px rgba(94,234,212,.55),0 0 12px rgba(129,140,248,.7),inset 0 0 8px rgba(255,255,255,.5);
}
.brand-text{display:flex;flex-direction:column;line-height:1.15}
.brand-name{
  font-size:1.35rem;font-weight:700;letter-spacing:-.02em;
  background:linear-gradient(120deg,#d7fff6,#a5b4fc);
  -webkit-background-clip:text;background-clip:text;color:transparent;
}
.brand-sub{font-size:.72rem;color:var(--muted);letter-spacing:.06em;text-transform:uppercase}

.summary{display:flex;align-items:center;gap:20px;flex-wrap:wrap}
.status{
  display:inline-flex;align-items:center;gap:8px;
  padding:8px 14px;border-radius:999px;font-weight:600;font-size:.9rem;
  border:1px solid color-mix(in srgb, var(--tone) 55%, transparent);
  color:var(--tone);
  background:color-mix(in srgb, var(--tone) 16%, transparent);
}
.status--changed{--tone:var(--c-changed)}
.status--new{--tone:var(--c-new)}
.status--pass{--tone:var(--c-pass)}
.stats{display:flex;gap:8px}
.stat{
  min-width:60px;padding:7px 12px;border-radius:12px;
  display:flex;flex-direction:column;align-items:center;gap:1px;
  background:var(--surface);border:1px solid var(--hairline);
}
.stat-num{font-size:1.15rem;font-weight:700;line-height:1;color:var(--c)}
.stat-label{font-size:.68rem;color:var(--muted);text-transform:uppercase;letter-spacing:.05em}

.v-changed{--c:var(--c-changed)}
.v-new{--c:var(--c-new)}
.v-size-changed{--c:var(--c-size-changed)}
.v-pass{--c:var(--c-pass)}

/* Notice */
.notice{max-width:1440px;margin:18px auto 0;padding:0 28px}
.notice-inner{
  display:flex;gap:14px;
  padding:16px 18px;border-radius:14px;
  background:color-mix(in srgb, var(--c-size-changed) 14%, var(--surface-solid));
  border:1px solid color-mix(in srgb, var(--c-size-changed) 45%, transparent);
  color:#fde9c8;
}
.notice-inner .ico{color:var(--c-size-changed);width:20px;height:20px;margin-top:2px}
.notice-inner strong{display:block;margin-bottom:4px}
.notice-inner p{margin:0 0 6px;color:#f2e6cf;font-size:.9rem}
.notice-inner ul{margin:0;padding-left:18px;font-size:.85rem;color:#f2e6cf}
.notice-inner code{background:rgba(0,0,0,.3);padding:1px 5px;border-radius:5px}

/* Layout */
.layout{
  max-width:1440px;margin:0 auto;
  padding:24px 28px 96px;
  display:grid;grid-template-columns:288px minmax(0,1fr);gap:32px;
}
.sidebar{position:sticky;top:92px;align-self:start;max-height:calc(100vh - 116px);display:flex;flex-direction:column;gap:14px}
.search{position:relative;display:flex;align-items:center}
.search .ico{position:absolute;left:13px;color:var(--faint);width:16px;height:16px}
.search input{
  width:100%;padding:11px 14px 11px 38px;
  background:var(--surface);border:1px solid var(--hairline);border-radius:12px;
  color:var(--text);font-size:.9rem;outline:none;transition:border-color .15s, box-shadow .15s;
}
.search input::placeholder{color:var(--faint)}
.search input:focus{border-color:color-mix(in srgb,var(--aqua) 60%,transparent);box-shadow:0 0 0 3px rgba(94,234,212,.14)}
.nav{overflow-y:auto;padding-right:4px;display:flex;flex-direction:column;gap:14px}
.nav::-webkit-scrollbar{width:8px}
.nav::-webkit-scrollbar-thumb{background:var(--hairline-strong);border-radius:8px}
.nav-group-head{
  display:flex;align-items:center;justify-content:space-between;
  font-size:.72rem;text-transform:uppercase;letter-spacing:.08em;color:var(--faint);
  margin:0 4px 6px;font-weight:600;
}
.nav-group-count{background:var(--surface);border:1px solid var(--hairline);border-radius:999px;padding:1px 8px;color:var(--muted)}
.nav-item{
  display:flex;align-items:center;gap:9px;
  padding:8px 10px;border-radius:10px;margin-bottom:2px;
  border:1px solid transparent;color:var(--muted);font-size:.88rem;
  transition:background .15s,color .15s,border-color .15s;
}
.nav-item:hover{background:var(--surface);color:var(--text)}
.nav-item.is-active{
  background:color-mix(in srgb,var(--c) 16%,var(--surface-solid));
  border-color:color-mix(in srgb,var(--c) 45%,transparent);
  color:var(--text);
}
.nav-label{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.nav-meta{font-size:.74rem;color:var(--c);font-variant-numeric:tabular-nums}
.nav-empty{color:var(--faint);font-size:.88rem;padding:4px}
.dot{width:8px;height:8px;border-radius:50%;flex:none;background:var(--c);box-shadow:0 0 8px color-mix(in srgb,var(--c) 70%,transparent)}

/* Main */
.main{display:flex;flex-direction:column;gap:36px;min-width:0}
.group{display:flex;flex-direction:column;gap:18px;scroll-margin-top:96px}
.group-head{display:flex;align-items:center;gap:12px}
.group-icon{
  width:34px;height:34px;border-radius:10px;display:grid;place-items:center;
  color:var(--c);background:color-mix(in srgb,var(--c) 16%,transparent);
  border:1px solid color-mix(in srgb,var(--c) 38%,transparent);
}
.group-title{font-size:1.15rem;font-weight:650;letter-spacing:-.01em}
.group-count{
  font-size:.8rem;color:var(--muted);font-weight:600;
  background:var(--surface);border:1px solid var(--hairline);border-radius:999px;padding:2px 10px;
}
.cards{display:flex;flex-direction:column;gap:20px}

/* Case card */
.case{
  scroll-margin-top:96px;
  background:var(--surface);backdrop-filter:blur(8px);
  border:1px solid var(--hairline);border-radius:18px;
  padding:22px 22px 6px;box-shadow:var(--shadow);
  position:relative;overflow:hidden;
}
.case::before{
  content:'';position:absolute;top:0;left:0;right:0;height:3px;
  background:linear-gradient(90deg,var(--c),transparent 75%);
  opacity:.85;
}
.breadcrumb{color:var(--faint);font-size:.8rem;margin-bottom:6px;font-variant-numeric:tabular-nums}
.case-title-row{display:flex;align-items:center;gap:14px;flex-wrap:wrap}
.case-title{font-size:1.3rem;font-weight:650;letter-spacing:-.01em;word-break:break-word}
.badge{
  display:inline-flex;align-items:center;gap:6px;
  padding:5px 11px;border-radius:999px;font-size:.82rem;font-weight:600;
  color:var(--c);background:color-mix(in srgb,var(--c) 16%,transparent);
  border:1px solid color-mix(in srgb,var(--c) 45%,transparent);
}
.case-note{
  display:flex;align-items:center;gap:7px;margin-top:10px;
  color:var(--muted);font-size:.86rem;
}
.case-note .ico{color:var(--indigo);width:16px;height:16px;flex:none}

/* Chips */
.chips{display:flex;flex-wrap:wrap;gap:8px;margin:16px 0 18px}
.chip{
  display:inline-flex;align-items:center;gap:6px;
  padding:5px 10px;border-radius:9px;font-size:.8rem;
  background:rgba(8,13,26,.5);border:1px solid var(--hairline);color:var(--muted);
}
.chip .ico{width:14px;height:14px;color:var(--faint)}
.chip--warn{color:#fdd9b5;background:color-mix(in srgb,var(--c-changed) 16%,transparent);border-color:color-mix(in srgb,var(--c-changed) 45%,transparent)}
.chip--warn .ico{color:var(--c-changed)}
.chip--muted{color:var(--faint)}

/* Comparison viewer */
.compare{
  border:1px solid var(--hairline);border-radius:14px;overflow:hidden;
  background:rgba(4,8,18,.55);margin-bottom:18px;
}
.image-grid{display:grid;gap:1px;background:var(--hairline);grid-template-columns:repeat(auto-fit,minmax(220px,1fr))}
.panel{margin:0;background:rgba(4,8,18,.7);display:flex;flex-direction:column}
.panel figcaption{padding:10px 14px;font-size:.78rem;font-weight:600;color:var(--muted);text-transform:uppercase;letter-spacing:.06em}
.panel img{display:block;width:100%;height:auto;background:#05080f}
.panel--placeholder .placeholder{
  flex:1;min-height:180px;display:flex;flex-direction:column;justify-content:center;gap:6px;
  padding:18px;color:var(--muted);text-align:center;
}
.placeholder strong{color:var(--text);font-size:.95rem}
.placeholder span{font-size:.82rem}

.vs-bar{display:flex;gap:4px;padding:8px;background:rgba(8,13,26,.65);border-bottom:1px solid var(--hairline)}
.vs-tab{
  display:inline-flex;align-items:center;gap:7px;
  padding:7px 13px;border-radius:9px;border:1px solid transparent;
  background:transparent;color:var(--muted);font:inherit;font-size:.83rem;font-weight:500;
  cursor:pointer;transition:background .15s,color .15s,border-color .15s;
}
.vs-tab .ico{width:15px;height:15px}
.vs-tab:hover{color:var(--text);background:rgba(255,255,255,.04)}
.vs-tab.is-active{
  color:var(--text);background:color-mix(in srgb,var(--aqua) 14%,var(--surface-solid));
  border-color:color-mix(in srgb,var(--aqua) 40%,transparent);
}
.vs-stage{padding:16px;display:flex;flex-direction:column;gap:12px;align-items:center}
.vs-img{display:block;max-width:100%;border-radius:8px}

.vs-slider{position:relative;line-height:0;user-select:none;touch-action:none;max-width:100%;cursor:ew-resize;border-radius:8px;overflow:hidden}
.vs-slider .vs-base{width:100%}
.vs-top{position:absolute;inset:0;overflow:hidden}
.vs-top .vs-img{width:100%;height:100%;object-fit:cover;border-radius:0;max-width:none}
.vs-handle{position:absolute;top:0;bottom:0;width:2px;left:50%;transform:translateX(-1px);background:linear-gradient(180deg,var(--aqua),var(--indigo));box-shadow:0 0 12px rgba(94,234,212,.6)}
.vs-handle-grip{
  position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);
  width:34px;height:34px;border-radius:50%;
  background:rgba(10,15,28,.85);border:2px solid var(--aqua);
  box-shadow:0 4px 18px rgba(0,0,0,.5),0 0 14px rgba(94,234,212,.4);
}
.vs-handle-grip::before,.vs-handle-grip::after{content:'';position:absolute;top:50%;width:0;height:0;border:5px solid transparent}
.vs-handle-grip::before{left:6px;transform:translateY(-50%);border-right-color:var(--aqua)}
.vs-handle-grip::after{right:6px;transform:translateY(-50%);border-left-color:var(--aqua)}
.vs-tag{position:absolute;top:10px;padding:3px 9px;border-radius:7px;font-size:.72rem;font-weight:600;color:#fff;background:rgba(7,11,22,.7);backdrop-filter:blur(4px);line-height:1.3;letter-spacing:.02em}
.vs-tag-l{left:10px}
.vs-tag-r{right:10px}

.vs-side{display:grid;grid-template-columns:1fr 1fr;gap:14px;width:100%}
.vs-fig{margin:0;display:flex;flex-direction:column;gap:8px}
.vs-fig .vs-img{width:100%}
.vs-cap{font-size:.76rem;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);font-weight:600;text-align:center}

.vs-diff{position:relative;line-height:0;max-width:100%;border-radius:8px;overflow:hidden}
.vs-diff .vs-img{width:100%}
.vs-overlay{position:absolute;inset:0;height:100%;object-fit:cover;max-width:none}
.vs-ctrl{display:flex;align-items:center;gap:12px;width:100%;max-width:420px;color:var(--muted);font-size:.8rem}
.vs-ctrl-label{white-space:nowrap;font-weight:600}
.vs-range{flex:1;accent-color:var(--aqua);height:4px}

/* Execution details */
.exec{margin:0 -22px;border-top:1px solid var(--hairline)}
.exec summary{
  display:flex;align-items:center;gap:9px;cursor:pointer;list-style:none;
  padding:14px 22px;color:var(--muted);font-size:.85rem;font-weight:600;
}
.exec summary::-webkit-details-marker{display:none}
.exec summary .ico{width:16px;height:16px;color:var(--faint)}
.exec summary:hover{color:var(--text)}
.exec-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:1px;background:var(--hairline);margin:0;border-top:1px solid var(--hairline)}
.exec-row{background:rgba(8,13,26,.5);padding:12px 22px}
.exec-row dt{color:var(--faint);font-size:.74rem;text-transform:uppercase;letter-spacing:.05em;margin-bottom:3px}
.exec-row dd{margin:0;font-size:.86rem;word-break:break-word}

/* Passed table */
.passed-panel{background:var(--surface);border:1px solid var(--hairline);border-radius:16px;overflow:hidden;box-shadow:var(--shadow)}
.passed-table{width:100%;border-collapse:collapse;font-size:.88rem}
.passed-table th,.passed-table td{text-align:left;padding:13px 18px;border-bottom:1px solid var(--hairline);vertical-align:middle}
.passed-table th{color:var(--faint);font-weight:600;font-size:.74rem;text-transform:uppercase;letter-spacing:.06em}
.passed-table tr:last-child td{border-bottom:none}
.passed-row{scroll-margin-top:120px}
.passed-row td:first-child{display:flex;align-items:center;gap:9px;font-weight:500}
.passed-details{color:var(--muted);font-size:.83rem}

/* Hero */
.hero{
  text-align:center;padding:64px 24px;
  background:var(--surface);border:1px solid var(--hairline);border-radius:18px;box-shadow:var(--shadow);
}
.hero-orb{
  display:inline-grid;place-items:center;width:64px;height:64px;border-radius:50%;margin-bottom:18px;
  color:var(--c-pass);background:color-mix(in srgb,var(--c-pass) 16%,transparent);
  border:1px solid color-mix(in srgb,var(--c-pass) 40%,transparent);
}
.hero-orb .ico{width:30px;height:30px}
.hero h2{font-size:1.5rem;margin-bottom:8px}
.hero p{color:var(--muted);max-width:480px;margin:0 auto}

@media (max-width:960px){
  .layout{grid-template-columns:1fr;padding-inline:18px}
  .sidebar{position:static;max-height:none}
  .nav{max-height:280px}
  .topbar-inner{padding-inline:18px}
}
@media (max-width:600px){
  .vs-side{grid-template-columns:1fr}
  .summary{width:100%;justify-content:space-between}
  .stat{min-width:0;flex:1}
}
''';

// ---------------------------------------------------------------------------
// Script
// ---------------------------------------------------------------------------

const _script = r'''
(function(){
  var ICON = {
    slider:'<svg class="ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M12 4v16"/></svg>',
    side:'<svg class="ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="7" height="16" rx="1.5"/><rect x="14" y="4" width="7" height="16" rx="1.5"/></svg>',
    diff:'<svg class="ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v18"/><path d="M5 8h14"/><path d="M5 16h14"/><rect x="3" y="3" width="18" height="18" rx="2"/></svg>'
  };
  var LABELS = {slider:'Slider', side:'Side by side', diff:'Diff'};

  function el(tag, cls){ var e=document.createElement(tag); if(cls)e.className=cls; return e; }
  function imel(src, cls, alt){ var i=document.createElement('img'); i.src=src; if(cls)i.className=cls; i.alt=alt||''; i.loading='lazy'; return i; }

  function renderSlider(stage, leftSrc, rightSrc, leftLabel, rightLabel){
    var w = el('div','vs-slider');
    var base = imel(rightSrc,'vs-img vs-base', rightLabel);
    var top = el('div','vs-top'); top.appendChild(imel(leftSrc,'vs-img', leftLabel));
    var handle = el('div','vs-handle'); handle.innerHTML='<span class="vs-handle-grip"></span>';
    var tl = el('span','vs-tag vs-tag-l'); tl.textContent=leftLabel;
    var tr = el('span','vs-tag vs-tag-r'); tr.textContent=rightLabel;
    w.appendChild(base); w.appendChild(top); w.appendChild(handle); w.appendChild(tl); w.appendChild(tr);
    stage.appendChild(w);
    function set(p){ p=Math.max(2,Math.min(98,p)); top.style.clipPath='inset(0 '+(100-p)+'% 0 0)'; handle.style.left=p+'%'; }
    set(50);
    function move(x){ var r=w.getBoundingClientRect(); if(r.width) set((x-r.left)/r.width*100); }
    w.addEventListener('pointerdown', function(e){
      e.preventDefault(); move(e.clientX);
      var mv=function(ev){ move(ev.clientX); };
      var up=function(){ document.removeEventListener('pointermove',mv); document.removeEventListener('pointerup',up); };
      document.addEventListener('pointermove',mv); document.addEventListener('pointerup',up);
    });
  }

  function renderSide(stage, baseSrc, candSrc){
    var g = el('div','vs-side');
    [[baseSrc,'Baseline'],[candSrc,'Candidate']].forEach(function(pair){
      var f = el('figure','vs-fig');
      f.appendChild(imel(pair[0],'vs-img', pair[1]));
      var cap = el('figcaption','vs-cap'); cap.textContent=pair[1];
      f.appendChild(cap); g.appendChild(f);
    });
    stage.appendChild(g);
  }

  function renderDiff(stage, baseSrc, diffSrc){
    if(!baseSrc){ var only=el('div','vs-diff'); only.appendChild(imel(diffSrc,'vs-img','Diff')); stage.appendChild(only); return; }
    var w = el('div','vs-diff');
    w.appendChild(imel(baseSrc,'vs-img','Candidate'));
    var over = imel(diffSrc,'vs-img vs-overlay','Diff');
    w.appendChild(over);
    stage.appendChild(w);
    var ctrl = el('div','vs-ctrl');
    var lab = el('span','vs-ctrl-label'); lab.textContent='Diff overlay';
    var range = document.createElement('input');
    range.type='range'; range.min='0'; range.max='100'; range.value='100'; range.className='vs-range';
    range.addEventListener('input', function(){ over.style.opacity = (range.value/100); });
    ctrl.appendChild(lab); ctrl.appendChild(range);
    stage.appendChild(ctrl);
  }

  function initCompare(comp){
    var base = comp.getAttribute('data-baseline') || '';
    var cand = comp.getAttribute('data-candidate') || '';
    var diff = comp.getAttribute('data-diff') || '';
    var modes = [];
    if(base && cand){ modes.push('slider'); modes.push('side'); }
    if(diff){ modes.push('diff'); }
    if(modes.length === 0){ return; } // single image: keep the fallback grid

    comp.innerHTML = '';
    var bar = el('div','vs-bar');
    var stage = el('div','vs-stage');
    var want = comp.getAttribute('data-mode');
    var active = (modes.indexOf(want) >= 0) ? want : modes[0];

    function render(){
      Array.prototype.forEach.call(bar.children, function(b){ b.classList.toggle('is-active', b.getAttribute('data-mode')===active); });
      stage.innerHTML='';
      if(active==='slider') renderSlider(stage, base, cand, 'Baseline', 'Candidate');
      else if(active==='side') renderSide(stage, base, cand);
      else renderDiff(stage, cand || base, diff);
    }

    modes.forEach(function(m){
      var b = el('button','vs-tab'); b.type='button'; b.setAttribute('data-mode', m);
      b.innerHTML = ICON[m] + '<span>' + LABELS[m] + '</span>';
      b.addEventListener('click', function(){ active=m; render(); });
      bar.appendChild(b);
    });
    comp.appendChild(bar); comp.appendChild(stage);
    render();
  }

  Array.prototype.forEach.call(document.querySelectorAll('.compare'), initCompare);

  // Scroll-spy: highlight the nav item for the section in view.
  var items = Array.prototype.slice.call(document.querySelectorAll('.nav-item'));
  var byId = {};
  items.forEach(function(n){ byId[n.getAttribute('data-target')] = n; });
  if('IntersectionObserver' in window){
    var io = new IntersectionObserver(function(entries){
      entries.forEach(function(en){
        if(en.isIntersecting){
          items.forEach(function(n){ n.classList.remove('is-active'); });
          var n = byId[en.target.id];
          if(n) n.classList.add('is-active');
        }
      });
    }, {rootMargin:'-25% 0px -65% 0px', threshold:0});
    Object.keys(byId).forEach(function(id){ var t=document.getElementById(id); if(t) io.observe(t); });
  }

  // Search: filter sidebar items and the matching cases / rows.
  var search = document.getElementById('search');
  if(search){
    search.addEventListener('input', function(){
      var q = search.value.trim().toLowerCase();
      items.forEach(function(n){
        n.style.display = n.textContent.toLowerCase().indexOf(q) >= 0 ? '' : 'none';
      });
      Array.prototype.forEach.call(document.querySelectorAll('.case, .passed-row'), function(c){
        var id = (c.getAttribute('data-id')||'').toLowerCase();
        c.style.display = id.indexOf(q) >= 0 ? '' : 'none';
      });
      Array.prototype.forEach.call(document.querySelectorAll('.nav-group'), function(g){
        var any = Array.prototype.some.call(g.querySelectorAll('.nav-item'), function(n){ return n.style.display !== 'none'; });
        g.style.display = any ? '' : 'none';
      });
    });
  }
})();
''';
