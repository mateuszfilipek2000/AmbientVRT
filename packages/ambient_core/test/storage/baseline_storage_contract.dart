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
