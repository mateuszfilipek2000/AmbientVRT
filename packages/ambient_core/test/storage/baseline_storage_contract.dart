import 'dart:async';
import 'dart:typed_data';

import 'package:ambient_core/ambient_core.dart';
import 'package:test/test.dart';

typedef BaselineStorageFactory = Future<BaselineStorage> Function();
typedef AsyncVoidCallback = Future<void> Function();

void defineBaselineStorageContractTests({
  required String name,
  required BaselineStorageFactory createStorage,
  AsyncVoidCallback? cleanup,
}) {
  group(name, () {
    late BaselineStorage storage;

    setUp(() async {
      storage = await createStorage();
    });

    tearDown(() async {
      if (cleanup != null) {
        await cleanup();
      }
    });

    test('returns null for a missing baseline', () async {
      expect(await storage.getBaseline(_flutterStyleId), isNull);
    });

    test('round-trips stored PNG bytes', () async {
      await storage.putBaseline(_flutterStyleId, _pngBytesA);

      expect(
        await storage.getBaseline(_flutterStyleId),
        orderedEquals(_pngBytesA),
      );
    });

    test('lists stored baseline IDs in sorted order', () async {
      await storage.putBaseline('z-last', _pngBytesA);
      await storage.putBaseline(_flutterStyleId, _pngBytesB);
      await storage.putBaseline('a-first', _pngBytesA);

      expect(
        await storage.listBaselines(),
        orderedEquals(['a-first', _flutterStyleId, 'z-last']),
      );
    });

    test('round-trips the accepted manifest sidecar', () async {
      await storage.putAcceptedManifest(_acceptedManifest);

      expect(await storage.getAcceptedManifest(), equals(_acceptedManifest));
    });

    test(
      'accepted manifest sidecar does not appear in baseline listings',
      () async {
        await storage.putBaseline(_flutterStyleId, _pngBytesA);
        await storage.putAcceptedManifest(_acceptedManifest);

        expect(await storage.listBaselines(), orderedEquals([_flutterStyleId]));
      },
    );
  });
}

const String _flutterStyleId =
    'lib/widgets/button.dart::ButtonPreview::flutter::brightness=dark';
final Uint8List _pngBytesA = Uint8List.fromList([
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  1,
  2,
  3,
]);
final Uint8List _pngBytesB = Uint8List.fromList([
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  9,
  8,
  7,
]);
final Manifest _acceptedManifest = Manifest(
  manifestVersion: const ManifestVersion(1, 0),
  entries: [
    ManifestEntry(
      id: _flutterStyleId,
      platform: Platform.flutter,
      width: 120,
      height: 48,
      dpr: 2,
      contentHash:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      envFingerprint: 'test-env',
      imagePath: 'captures/button.png',
    ),
  ],
);
