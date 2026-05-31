import 'dart:io' as io;

final class AmbientEnvironment {
  const AmbientEnvironment({
    required this.stdout,
    required this.stderr,
    required this.currentDirectoryPath,
  });

  factory AmbientEnvironment.system({
    StringSink? stdout,
    StringSink? stderr,
    String? currentDirectoryPath,
  }) {
    return AmbientEnvironment(
      stdout: stdout ?? _IoStringSink(io.stdout),
      stderr: stderr ?? _IoStringSink(io.stderr),
      currentDirectoryPath: currentDirectoryPath ?? io.Directory.current.path,
    );
  }

  final StringSink stdout;
  final StringSink stderr;
  final String currentDirectoryPath;

  void writeOut(String message) => stdout.writeln(message);

  void writeErr(String message) => stderr.writeln(message);

  String resolveFromCurrentDirectory(String path) =>
      resolveFromDirectory(currentDirectoryPath, path);

  String resolveFromDirectory(String baseDirectoryPath, String path) {
    if (io.File(path).isAbsolute) {
      return path;
    }

    return io.File.fromUri(
      io.Directory(baseDirectoryPath).uri.resolve(path),
    ).path;
  }
}

final class _IoStringSink implements StringSink {
  const _IoStringSink(this._sink);

  final io.IOSink _sink;

  @override
  void write(Object? object) => _sink.write(object);

  @override
  void writeln([Object? object = '']) => _sink.writeln(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _sink.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _sink.writeCharCode(charCode);
}
