import 'dart:io';
import 'dart:typed_data';

import '../manifest/manifest.dart';
import 'baseline_storage.dart';

/// Filesystem-backed baseline storage rooted at a single directory.
final class LocalStorageBackend implements BaselineStorage {
  LocalStorageBackend({required String directoryPath, String? defaultBranch})
    : _rootDirectory = Directory(directoryPath),
      _defaultBranch = _normalizeBranch(defaultBranch);

  final Directory _rootDirectory;
  final String? _defaultBranch;

  @override
  Future<Uint8List?> getBaseline(String id, {String? branch}) async {
    final file = File(_pathForId(id, branch: branch));
    if (!await file.exists()) {
      return null;
    }

    return file.readAsBytes();
  }

  @override
  Future<List<String>> listBaselines({String? branch}) async {
    final directory = _directoryForBranch(branch);
    if (!await directory.exists()) {
      return const [];
    }

    final ids = <String>[];
    await for (final entity in directory.list(followLinks: false)) {
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
    final file = File(_acceptedManifestPath(branch: branch));
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
    final directory = _directoryForBranch(branch);
    await directory.create(recursive: true);

    final encodedId = _encodedId(id);
    final tempFile = File(
      _filePathForName(
        directory,
        '.$encodedId.${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    await tempFile.writeAsBytes(pngBytes, flush: true);
    await tempFile.rename(_pathForId(id, branch: branch));
  }

  @override
  Future<void> putAcceptedManifest(Manifest manifest, {String? branch}) async {
    final directory = _directoryForBranch(branch);
    await directory.create(recursive: true);

    final tempFile = File(
      _filePathForName(
        directory,
        '.$_acceptedManifestFileName.${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    await tempFile.writeAsString(manifest.toJsonString(), flush: true);
    await tempFile.rename(_acceptedManifestPath(branch: branch));
  }

  String _acceptedManifestPath({String? branch}) =>
      _filePathForName(_directoryForBranch(branch), _acceptedManifestFileName);

  String _pathForId(String id, {String? branch}) {
    final encodedId = _encodedId(id);
    return _filePathForName(
      _directoryForBranch(branch),
      '$encodedId$_baselineExtension',
    );
  }

  String _encodedId(String id) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Baseline ID must not be empty.');
    }

    return Uri.encodeComponent(id);
  }

  Directory _directoryForBranch(String? branch) {
    final normalizedBranch = _normalizeBranch(branch);
    if (normalizedBranch == null || normalizedBranch == _defaultBranch) {
      return _rootDirectory;
    }

    return Directory(
      _joinPath(
        _joinPath(_rootDirectory.path, 'branches'),
        Uri.encodeComponent(normalizedBranch),
      ),
    );
  }

  String _filePathForName(Directory directory, String fileName) =>
      _joinPath(directory.path, fileName);
}

String? _normalizeBranch(String? branch) {
  if (branch == null) {
    return null;
  }
  final trimmed = branch.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _joinPath(String directoryPath, String fileName) {
  final separator = Platform.pathSeparator;
  if (directoryPath.endsWith(separator)) {
    return '$directoryPath$fileName';
  }

  return '$directoryPath$separator$fileName';
}

const String _baselineExtension = '.png';
const String _acceptedManifestFileName = '.accepted-manifest.json';
