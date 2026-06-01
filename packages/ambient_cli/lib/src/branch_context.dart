import 'dart:io' as io;

import 'ambient_environment.dart';

final class BaselineBranchContext {
  const BaselineBranchContext({
    required this.compareBranch,
    required this.writeBranch,
    required this.currentBranch,
    required this.defaultBranch,
  });

  final String? compareBranch;
  final String? writeBranch;
  final String? currentBranch;
  final String? defaultBranch;
}

Future<BaselineBranchContext> resolveBaselineBranchContext({
  required AmbientEnvironment environment,
  String? requestedCompareBranch,
  String? requestedWriteBranch,
}) async {
  final githubBaseRef = _normalizeBranch(
    environment.environmentVariables['GITHUB_BASE_REF'],
  );
  final githubHeadRef = _normalizeBranch(
    environment.environmentVariables['GITHUB_HEAD_REF'],
  );
  final githubRefName = _normalizeBranch(
    environment.environmentVariables['GITHUB_REF_NAME'],
  );
  final gitCurrentBranch = await _resolveGitCurrentBranch(
    environment.currentDirectoryPath,
  );
  final currentBranch = githubHeadRef ?? githubRefName ?? gitCurrentBranch;
  final defaultBranch =
      githubBaseRef ?? await _resolveGitDefaultBranch(environment);

  return BaselineBranchContext(
    compareBranch:
        _normalizeBranch(requestedCompareBranch) ??
        githubBaseRef ??
        _defaultCompareBranch(
          currentBranch: currentBranch,
          defaultBranch: defaultBranch,
        ),
    writeBranch: _normalizeBranch(requestedWriteBranch) ?? currentBranch,
    currentBranch: currentBranch,
    defaultBranch: defaultBranch,
  );
}

String? _defaultCompareBranch({
  required String? currentBranch,
  required String? defaultBranch,
}) {
  if (defaultBranch == null) {
    return currentBranch;
  }
  if (currentBranch == null || currentBranch == defaultBranch) {
    return defaultBranch;
  }

  return defaultBranch;
}

Future<String?> _resolveGitCurrentBranch(String workingDirectoryPath) async {
  final branchName = await _runGit(workingDirectoryPath, const [
    'rev-parse',
    '--abbrev-ref',
    'HEAD',
  ]);
  if (branchName == null || branchName == 'HEAD') {
    return null;
  }

  return branchName;
}

Future<String?> _resolveGitDefaultBranch(AmbientEnvironment environment) async {
  final originHead = await _runGit(environment.currentDirectoryPath, const [
    'symbolic-ref',
    '--quiet',
    '--short',
    'refs/remotes/origin/HEAD',
  ]);
  if (originHead case final String value
      when value.startsWith('origin/') && value.length > 'origin/'.length) {
    return value.substring('origin/'.length);
  }

  for (final candidate in const ['main', 'master']) {
    if (await _gitRefExists(
          environment.currentDirectoryPath,
          'refs/heads/$candidate',
        ) ||
        await _gitRefExists(
          environment.currentDirectoryPath,
          'refs/remotes/origin/$candidate',
        )) {
      return candidate;
    }
  }

  final currentBranch = await _resolveGitCurrentBranch(
    environment.currentDirectoryPath,
  );
  if (currentBranch == 'main' || currentBranch == 'master') {
    return currentBranch;
  }

  return null;
}

Future<bool> _gitRefExists(String workingDirectoryPath, String refName) async =>
    await _runGitSucceeds(workingDirectoryPath, [
      'show-ref',
      '--verify',
      '--quiet',
      refName,
    ]);

Future<String?> _runGit(
  String workingDirectoryPath,
  List<String> arguments,
) async {
  io.ProcessResult result;
  try {
    result = await io.Process.run(
      'git',
      arguments,
      workingDirectory: workingDirectoryPath,
      runInShell: false,
    );
  } on io.ProcessException {
    return null;
  }
  if (result.exitCode != 0) {
    return null;
  }

  final stdout = (result.stdout as String).trim();
  return stdout.isEmpty ? null : stdout;
}

Future<bool> _runGitSucceeds(
  String workingDirectoryPath,
  List<String> arguments,
) async {
  try {
    final result = await io.Process.run(
      'git',
      arguments,
      workingDirectory: workingDirectoryPath,
      runInShell: false,
    );
    return result.exitCode == 0;
  } on io.ProcessException {
    return false;
  }
}

String? _normalizeBranch(String? branch) {
  if (branch == null) {
    return null;
  }
  final trimmed = branch.trim();
  return trimmed.isEmpty ? null : trimmed;
}
