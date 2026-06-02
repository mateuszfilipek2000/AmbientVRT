import '../compare/comparison_result.dart';
import '../run/compare_run_result.dart';

/// Builds a GitHub-flavoured Markdown summary of a compare run, suitable for
/// posting as a pull-request comment (see the CI Action's "Comment report on
/// PR" step). It mirrors the HTML report's verdict groups but stays terse: an
/// overall status line, a counts line, and a table of the snapshots that need a
/// human to look (changed / size-changed / new). The pixel-accurate
/// baseline/candidate/diff triptychs live in the HTML report artifact, which the
/// workflow links to beneath this body.
String buildMarkdownSummary(CompareRunResult runResult) {
  final summary = runResult.summary;
  final status = _overallStatus(summary);

  final buffer = StringBuffer()
    ..writeln('## ${status.emoji} ambient · visual regression')
    ..writeln()
    ..writeln('**${status.label}**')
    ..writeln()
    ..writeln(_countsLine(summary));

  final actionable = _actionableSnapshots(runResult);
  if (actionable.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('| Snapshot | Verdict | Mismatch | Size |')
      ..writeln('| --- | --- | --- | --- |');
    for (final snapshot in actionable) {
      buffer.writeln(_snapshotRow(snapshot));
    }
  }

  final nonCanonical = runResult.nonCanonicalCaptures;
  if (nonCanonical.isNotEmpty) {
    final expected = runResult.canonicalEnv;
    buffer
      ..writeln()
      ..writeln(
        '> ⚠️ ${nonCanonical.length} snapshot(s) were captured outside the '
        'canonical capture-env${expected == null ? '' : ' (`$expected`)'}. '
        'Their pixels may not be reproducible — capture inside the canonical '
        'image before accepting.',
      );
  }

  buffer
    ..writeln()
    ..writeln(
      '<sub>Baseline / candidate / diff images for every snapshot are in the '
      'HTML report attached to this run.</sub>',
    );

  return buffer.toString();
}

({String emoji, String label}) _overallStatus(CompareRunSummary summary) {
  if (summary.total == 0) {
    return (emoji: '✅', label: 'No snapshots in this run.');
  }
  if (summary.hasBlockingChanges) {
    final count = summary.changed + summary.sizeChanged;
    return (
      emoji: '❌',
      label: '$count visual ${count == 1 ? 'change' : 'changes'} detected — '
          'the gate is red until they are accepted.',
    );
  }
  if (summary.hasUnacceptedSnapshots) {
    return (
      emoji: '🟣',
      label: '${summary.newSnapshots} new '
          '${summary.newSnapshots == 1 ? 'snapshot' : 'snapshots'} pending '
          'acceptance.',
    );
  }
  return (
    emoji: '✅',
    label: 'All ${summary.passed} '
        '${summary.passed == 1 ? 'snapshot' : 'snapshots'} matched their '
        'accepted baselines.',
  );
}

String _countsLine(CompareRunSummary summary) {
  final parts = <String>[
    '🟠 ${summary.changed} changed',
    '🟡 ${summary.sizeChanged} size-changed',
    '🟣 ${summary.newSnapshots} new',
    '🟢 ${summary.passed} passed',
  ];
  return '${parts.join(' · ')} (${summary.total} total)';
}

/// Snapshots a reviewer needs to act on, ordered the way the HTML report groups
/// them: blocking changes first, then size changes, then unaccepted new ones.
List<SnapshotRunResult> _actionableSnapshots(CompareRunResult runResult) {
  List<SnapshotRunResult> withVerdict(ComparisonVerdict verdict) {
    final matching = runResult.snapshots
        .where((snapshot) => snapshot.verdict == verdict)
        .toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return matching;
  }

  return [
    ...withVerdict(ComparisonVerdict.changed),
    ...withVerdict(ComparisonVerdict.sizeChanged),
    ...withVerdict(ComparisonVerdict.newSnapshot),
  ];
}

String _snapshotRow(SnapshotRunResult snapshot) {
  final comparison = snapshot.comparison;
  final mismatch = comparison.changedRatio == null
      ? '—'
      : _formatPercent(comparison.changedRatio!);
  final size = snapshot.verdict == ComparisonVerdict.sizeChanged &&
          comparison.baselineSize != null
      ? '${comparison.baselineSize} → ${comparison.candidateSize}'
      : '${comparison.candidateSize}';
  return '| `${_escapeCell(snapshot.id)}` | ${_verdictLabel(snapshot.verdict)} '
      '| $mismatch | $size |';
}

String _verdictLabel(ComparisonVerdict verdict) => switch (verdict) {
      ComparisonVerdict.changed => '🟠 Changed',
      ComparisonVerdict.sizeChanged => '🟡 Size changed',
      ComparisonVerdict.newSnapshot => '🟣 New',
      ComparisonVerdict.pass => '🟢 Passed',
    };

String _formatPercent(double ratio) => '${(ratio * 100).toStringAsFixed(2)}%';

/// Escapes the characters that would break a Markdown table cell or be
/// interpreted as formatting inside one. Snapshot IDs are author-controlled
/// strings, so keep them literal.
String _escapeCell(String value) =>
    value.replaceAll('|', r'\|').replaceAll('`', r'\`');
