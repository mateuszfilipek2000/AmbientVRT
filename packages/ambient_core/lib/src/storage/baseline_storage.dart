import 'dart:typed_data';

/// Storage contract for baseline PNGs keyed by snapshot ID.
abstract interface class BaselineStorage {
  Future<Uint8List?> getBaseline(String id, {String? branch});

  Future<void> putBaseline(String id, Uint8List pngBytes, {String? branch});

  Future<List<String>> listBaselines({String? branch});
}
