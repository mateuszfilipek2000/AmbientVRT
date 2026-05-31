import 'dart:io';
import 'dart:typed_data';

import '../manifest/manifest.dart';
import 'baseline_storage.dart';

/// Filesystem-backed baseline storage rooted at a single directory.
final class LocalStorageBackend implements BaselineStorage {
  LocalStorageBackend({required String directoryPath})
    : _rootDirectory = Directory(directoryPath);

  final Directory _rootDirectory;

  @override
  Future<Uint8List?> getBaseline(String id, {String? branch}) async {
    final file = File(_pathForId(id));
    if (!await file.exists()) {
      return null;
    }

    return file.readAsBytes();
  }

  @override
  Future<List<String>> listBaselines({String? branch}) async {
    if (!await _rootDirectory.exists()) {
      return const [];
    }

    final ids = <String>[];
    await for (final entity in _rootDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final fileName = entity.path.split(Platform.pathSeparator).last;
      if (!fileName.endsWith(_baselineExtension)) {
        continue;
      }

      final encodedId = fileName.substring(
        0,
        fileName.length - _baselineExtension.length,
      );
      ids.add(Uri.decodeComponent(encodedId));
    }

    ids.sort();
    return ids;
  }

  @override
  Future<Manifest?> getAcceptedManifest({String? branch}) async {
    final file = File(_acceptedManifestPath);
    if (!await file.exists()) {
      return null;
    }

    return Manifest.fromJsonString(await file.readAsString());
  }

  @override
  Future<void> putBaseline(
    String id,
    Uint8List pngBytes, {
    String? branch,
  }) async {
    await _rootDirectory.create(recursive: true);

    final encodedId = _encodedId(id);
    final tempFile = File(
      _filePathForName(
        '.$encodedId.${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    await tempFile.writeAsBytes(pngBytes, flush: true);
    await tempFile.rename(_pathForId(id));
  }

  @override
  Future<void> putAcceptedManifest(Manifest manifest, {String? branch}) async {
    await _rootDirectory.create(recursive: true);

    final tempFile = File(
      _filePathForName(
        '.$_acceptedManifestFileName.${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    await tempFile.writeAsString(manifest.toJsonString(), flush: true);
    await tempFile.rename(_acceptedManifestPath);
  }

  String get _acceptedManifestPath =>
      _filePathForName(_acceptedManifestFileName);

  String _pathForId(String id) {
    final encodedId = _encodedId(id);
    return _filePathForName('$encodedId$_baselineExtension');
  }

  String _encodedId(String id) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Baseline ID must not be empty.');
    }

    return Uri.encodeComponent(id);
  }

  String _filePathForName(String fileName) {
    final separator = Platform.pathSeparator;
    if (_rootDirectory.path.endsWith(separator)) {
      return '${_rootDirectory.path}$fileName';
    }

    return '${_rootDirectory.path}$separator$fileName';
  }
}

const String _baselineExtension = '.png';
const String _acceptedManifestFileName = '.accepted-manifest.json';
