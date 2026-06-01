import 'dart:io';

import 'package:ambient_core/ambient_core.dart' as ambient;
import 'package:ambient_flutter/ambient_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final repositoryRoot = p.normalize(
    p.join(Directory.current.path, '..', '..'),
  );
  final exampleProject = p.join(repositoryRoot, 'examples', 'flutter-previews');

  test(
    'discovers example previews across supported target kinds',
    () async {
      final previews = await discoverFlutterPreviews(
        projectPath: exampleProject,
      );
      expect(previews, hasLength(5));

      expect(
        previews.map((preview) => preview.name),
        containsAll(<String>[
          'Plain card',
          'Injected fixture',
          'Light',
          'Dark',
          'Sized summary',
        ]),
      );

      expect(
        previews.map((preview) => preview.targetName),
        containsAll(<String>[
          'plainMessagePreview',
          'FixturePreviewFactory.build',
          'productStatusPreview',
          'SizedSummaryCard.preview',
        ]),
      );

      final fixturePreview = previews.singleWhere(
        (preview) => preview.name == 'Injected fixture',
      );
      expect(fixturePreview.wrapperName, 'fixturePreviewHarness');

      final sizedPreview = previews.singleWhere(
        (preview) => preview.name == 'Sized summary',
      );
      expect(sizedPreview.localizationsName, 'polishPreviewLocalizations');
      expect(sizedPreview.width, 320);
      expect(sizedPreview.height, 180);

      final darkPreview = previews.singleWhere(
        (preview) => preview.name == 'Dark',
      );
      expect(darkPreview.variant?.brightness, ambient.Brightness.dark);
      expect(
        darkPreview.id,
        ambient.flutterSnapshotId(
          path: darkPreview.sourcePath,
          name: darkPreview.name,
          group: darkPreview.group,
          variant: darkPreview.variant,
        ),
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'captures example previews into a stable manifest',
    () async {
      // Two full captures, each spawning one nested `flutter test` per preview,
      // can exceed the default timeout in containerized CI.
      final firstRun = await Directory.systemTemp.createTemp(
        'ambient_flutter_capture_a',
      );
      final secondRun = await Directory.systemTemp.createTemp(
        'ambient_flutter_capture_b',
      );
      addTearDown(() async {
        await firstRun.delete(recursive: true);
        await secondRun.delete(recursive: true);
      });

      final firstManifest = await captureFlutterPreviews(
        projectPath: exampleProject,
        outputDirectory: firstRun.path,
        canonicalEnv: 'phase4-test-env',
      );
      final secondManifest = await captureFlutterPreviews(
        projectPath: exampleProject,
        outputDirectory: secondRun.path,
        canonicalEnv: 'phase4-test-env',
      );

      expect(firstManifest.entries, hasLength(5));
      expect(secondManifest.entries, hasLength(5));

      final firstPlain = firstManifest.entries.singleWhere(
        (entry) => entry.id.contains('plain_card'),
        orElse: () => firstManifest.entries.firstWhere(
          (entry) => entry.id.contains('Plain'),
        ),
      );
      final secondPlain = secondManifest.entries.singleWhere(
        (entry) => entry.id == firstPlain.id,
      );

      expect(
        File(p.join(firstRun.path, firstPlain.imagePath)).readAsBytesSync(),
        File(p.join(secondRun.path, secondPlain.imagePath)).readAsBytesSync(),
      );

      final sizedEntry = firstManifest.entries.singleWhere(
        (entry) => entry.id.contains('sized_summary'),
        orElse: () =>
            firstManifest.entries.firstWhere((entry) => entry.width == 320),
      );
      expect(sizedEntry.width, 320);
      expect(sizedEntry.height, 180);
      expect(sizedEntry.dpr, 1.0);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
