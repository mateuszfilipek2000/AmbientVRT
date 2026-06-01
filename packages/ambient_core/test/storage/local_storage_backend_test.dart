import 'dart:io';
import 'dart:io' as io show Platform;
import 'dart:typed_data';

import 'package:ambient_core/ambient_core.dart';
import 'package:test/test.dart';

import 'baseline_storage_contract.dart';

void main() {
  late Directory tempDirectory;

  defineBaselineStorageContractTests(
    name: 'LocalStorageBackend',
    createStorage: () async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'ambient-local-storage-backend-test-',
      );
      return LocalStorageBackend(directoryPath: tempDirectory.path);
    },
    cleanup: () async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    },
  );

  group('LocalStorageBackend', () {
    test('creates the root directory on first write', () async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'ambient-local-storage-root-',
      );
      await tempDirectory.delete(recursive: true);

      final storage = LocalStorageBackend(directoryPath: tempDirectory.path);
      await storage.putBaseline('button', _pngBytes);

      expect(await tempDirectory.exists(), isTrue);
      expect(await storage.getBaseline('button'), orderedEquals(_pngBytes));
    });

    test('stores non-default branches in their own namespace', () async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'ambient-local-storage-branch-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final storage = LocalStorageBackend(
        directoryPath: tempDirectory.path,
        defaultBranch: 'main',
      );
      await storage.putBaseline('button', _pngBytes, branch: 'feature/button');

      expect(
        await storage.getBaseline('button', branch: 'feature/button'),
        orderedEquals(_pngBytes),
      );
      expect(await storage.getBaseline('button', branch: 'main'), isNull);
      expect(await storage.getBaseline('button'), isNull);
      expect(
        await storage.listBaselines(branch: 'feature/button'),
        orderedEquals(['button']),
      );
      expect(await storage.listBaselines(branch: 'main'), isEmpty);
      expect(
        await File(
          '${tempDirectory.path}'
          '${io.Platform.pathSeparator}branches'
          '${io.Platform.pathSeparator}feature%2Fbutton'
          '${io.Platform.pathSeparator}button.png',
        ).exists(),
        isTrue,
      );
    });

    test('maps the configured default branch onto the root namespace', () async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'ambient-local-storage-default-branch-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final storage = LocalStorageBackend(
        directoryPath: tempDirectory.path,
        defaultBranch: 'main',
      );
      const manifest = Manifest(
        manifestVersion: ManifestVersion(1, 0),
        entries: [
          ManifestEntry(
            id: 'button',
            platform: Platform.flutter,
            width: 64,
            height: 32,
            dpr: 1,
            contentHash:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            envFingerprint: 'test-env',
            imagePath: 'captures/button.png',
          ),
        ],
      );

      await storage.putBaseline('button', _pngBytes, branch: 'main');
      await storage.putAcceptedManifest(manifest, branch: 'main');

      expect(await storage.getBaseline('button'), orderedEquals(_pngBytes));
      expect(
        await storage.getBaseline('button', branch: 'main'),
        orderedEquals(_pngBytes),
      );
      expect(
        await storage.listBaselines(branch: 'main'),
        orderedEquals(['button']),
      );
      expect(await storage.getAcceptedManifest(), equals(manifest));
      expect(
        await storage.getAcceptedManifest(branch: 'main'),
        equals(manifest),
      );
      expect(
        await File.fromUri(tempDirectory.uri.resolve('button.png')).exists(),
        isTrue,
      );
      expect(
        await File.fromUri(
          tempDirectory.uri.resolve('branches/main/button.png'),
        ).exists(),
        isFalse,
      );
    });
  });
}

final Uint8List _pngBytes = Uint8List.fromList([
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  4,
  5,
  6,
]);
