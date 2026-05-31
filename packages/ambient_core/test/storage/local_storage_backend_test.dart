import 'dart:io';
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

    test('ignores branch when storing and reading baselines', () async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'ambient-local-storage-branch-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final storage = LocalStorageBackend(directoryPath: tempDirectory.path);
      await storage.putBaseline('button', _pngBytes, branch: 'feature-branch');

      expect(
        await storage.getBaseline('button', branch: 'main'),
        orderedEquals(_pngBytes),
      );
      expect(
        await storage.listBaselines(branch: 'release'),
        orderedEquals(['button']),
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
