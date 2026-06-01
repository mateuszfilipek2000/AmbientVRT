import 'dart:io';

import 'package:ambient_cli/src/ambient_environment.dart';
import 'package:ambient_cli/src/branch_context.dart';
import 'package:test/test.dart';

void main() {
  group('resolveBaselineBranchContext', () {
    late Directory workspaceDirectory;

    setUp(() async {
      workspaceDirectory = await Directory.systemTemp.createTemp(
        'ambient-branch-context-',
      );
    });

    tearDown(() async {
      if (await workspaceDirectory.exists()) {
        await workspaceDirectory.delete(recursive: true);
      }
    });

    test('prefers GitHub pull request refs when they are present', () async {
      final context = await resolveBaselineBranchContext(
        environment: AmbientEnvironment.system(
          currentDirectoryPath: workspaceDirectory.path,
          environmentVariables: const {
            'GITHUB_BASE_REF': 'main',
            'GITHUB_HEAD_REF': 'feature/login',
            'GITHUB_REF_NAME': 'feature/login',
          },
        ),
      );

      expect(context.compareBranch, 'main');
      expect(context.writeBranch, 'feature/login');
      expect(context.currentBranch, 'feature/login');
      expect(context.defaultBranch, 'main');
    });

    test(
      'uses the local default branch when running from a feature branch',
      () async {
        await _runGit(workspaceDirectory, ['init', '--initial-branch=main']);
        await _runGit(workspaceDirectory, [
          'config',
          'user.name',
          'Ambient CLI',
        ]);
        await _runGit(workspaceDirectory, [
          'config',
          'user.email',
          'ambient@example.com',
        ]);
        await File.fromUri(
          workspaceDirectory.uri.resolve('.gitkeep'),
        ).writeAsString('workspace\n', flush: true);
        await _runGit(workspaceDirectory, ['add', '.gitkeep']);
        await _runGit(workspaceDirectory, ['commit', '-m', 'Initial commit']);
        await _runGit(workspaceDirectory, ['switch', '-c', 'feature/button']);

        final context = await resolveBaselineBranchContext(
          environment: AmbientEnvironment.system(
            currentDirectoryPath: workspaceDirectory.path,
            environmentVariables: const {},
          ),
        );

        expect(context.compareBranch, 'main');
        expect(context.writeBranch, 'feature/button');
        expect(context.currentBranch, 'feature/button');
        expect(context.defaultBranch, 'main');
      },
    );

    test('respects explicit branch overrides', () async {
      final context = await resolveBaselineBranchContext(
        environment: AmbientEnvironment.system(
          currentDirectoryPath: workspaceDirectory.path,
          environmentVariables: const {
            'GITHUB_BASE_REF': 'main',
            'GITHUB_HEAD_REF': 'feature/login',
          },
        ),
        requestedCompareBranch: 'release/1.0',
        requestedWriteBranch: 'release/1.0',
      );

      expect(context.compareBranch, 'release/1.0');
      expect(context.writeBranch, 'release/1.0');
      expect(context.defaultBranch, 'main');
    });
  });
}

Future<void> _runGit(
  Directory workspaceDirectory,
  List<String> arguments,
) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: workspaceDirectory.path,
    runInShell: false,
  );
  expect(
    result.exitCode,
    0,
    reason:
        'git ${arguments.join(' ')} failed:\n'
        'stdout: ${result.stdout}\n'
        'stderr: ${result.stderr}',
  );
}
