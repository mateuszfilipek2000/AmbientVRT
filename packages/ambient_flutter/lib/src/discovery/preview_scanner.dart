import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:path/path.dart' as p;

import '../models/discovered_preview.dart';

/// Discovers `@Preview` / `MultiPreview` targets in a Flutter project's `lib/`
/// using the analyzer.
///
/// Works at the AST level (so each target carries its defining file path and the
/// file's import scope) and reads annotation metadata from the resolved constant
/// value. The annotation text is preserved verbatim for the generated registry;
/// only the wrapper / theme / localizations callback *names* are resolved, as
/// cosmetic metadata.
class PreviewScanner {
  PreviewScanner({
    required this.projectPath,
    required this.packageName,
  });

  final String projectPath;
  final String packageName;

  Future<List<DiscoveredPreviewTarget>> scan() async {
    final libPath = p.join(projectPath, 'lib');
    final libDirectory = Directory(libPath);
    if (!libDirectory.existsSync()) {
      throw StateError('Flutter project at $projectPath has no lib/ directory.');
    }

    final dartFiles = libDirectory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('.g.dart'))
        .toList()
      ..sort((left, right) => left.path.compareTo(right.path));

    final collection = AnalysisContextCollection(
      includedPaths: <String>[libPath],
      // When this runs inside `flutter test`, Platform.resolvedExecutable points
      // at the Flutter engine (no Dart SDK alongside it), so the analyzer's
      // auto-detection fails. Resolve the real Dart SDK explicitly.
      sdkPath: _resolveDartSdkPath(),
    );
    final results = <DiscoveredPreviewTarget>[];
    for (final file in dartFiles) {
      final context = collection.contextFor(file.path);
      final resolvedResult = await context.currentSession.getResolvedUnit(
        file.path,
      );
      if (resolvedResult is! ResolvedUnitResult) {
        throw StateError('Unable to resolve ${file.path}.');
      }

      final relativePath = p.relative(file.path, from: projectPath);
      final libraryImportUri = _packageImportFor(relativePath);
      final visitor = _PreviewVisitor(
        sourcePath: relativePath,
        libraryImportUri: libraryImportUri,
        sourceImports: _collectImports(resolvedResult.unit, libraryImportUri),
      );
      resolvedResult.unit.visitChildren(visitor);
      results.addAll(visitor.results);
    }

    return results;
  }

  /// Reconstructs the file's `import` directives, rewriting relative URIs to
  /// `package:` form and preserving `as` prefixes and show/hide combinators.
  List<String> _collectImports(CompilationUnit unit, String fileLibraryUri) {
    final imports = <String>[];
    for (final directive in unit.directives) {
      if (directive is! ImportDirective) {
        continue;
      }
      final uri = directive.uri.stringValue;
      if (uri == null) {
        continue;
      }
      final resolved = _resolveDirectiveUri(uri, fileLibraryUri);
      final buffer = StringBuffer("import '$resolved'");
      final prefix = directive.prefix?.name;
      if (prefix != null) {
        buffer.write(' as $prefix');
      }
      for (final combinator in directive.combinators) {
        buffer.write(' ${combinator.toSource()}');
      }
      buffer.write(';');
      imports.add(buffer.toString());
    }
    return imports;
  }

  String _resolveDirectiveUri(String uri, String fileLibraryUri) {
    if (uri.startsWith('dart:') || uri.startsWith('package:')) {
      return uri;
    }
    return Uri.parse(fileLibraryUri).resolve(uri).toString();
  }

  String _packageImportFor(String relativePath) {
    final posixRelative = p.posix.joinAll(p.split(relativePath));
    const libPrefix = 'lib/';
    if (!posixRelative.startsWith(libPrefix)) {
      throw StateError('Only lib/ files can define previews: $relativePath');
    }
    return 'package:$packageName/${posixRelative.substring(libPrefix.length)}';
  }

  /// Resolves the Dart SDK directory for the analyzer.
  ///
  /// Under `flutter test` the SDK lives at `$FLUTTER_ROOT/bin/cache/dart-sdk`;
  /// under a plain `dart run` it sits two levels above the running executable.
  /// Returns null to let the analyzer auto-detect when neither is found.
  String? _resolveDartSdkPath() {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null && flutterRoot.isNotEmpty) {
      final candidate = p.join(flutterRoot, 'bin', 'cache', 'dart-sdk');
      if (_looksLikeDartSdk(candidate)) {
        return candidate;
      }
    }

    final fromExecutable = p.dirname(p.dirname(Platform.resolvedExecutable));
    if (_looksLikeDartSdk(fromExecutable)) {
      return fromExecutable;
    }

    return null;
  }

  bool _looksLikeDartSdk(String directory) {
    return File(p.join(directory, 'version')).existsSync() ||
        Directory(p.join(directory, 'lib', '_internal')).existsSync();
  }
}

class _PreviewVisitor extends RecursiveAstVisitor<void> {
  _PreviewVisitor({
    required this.sourcePath,
    required this.libraryImportUri,
    required this.sourceImports,
  });

  final String sourcePath;
  final String libraryImportUri;
  final List<String> sourceImports;
  final List<DiscoveredPreviewTarget> results = <DiscoveredPreviewTarget>[];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final name = node.name.lexeme;
    if (!name.startsWith('_') &&
        _hasNoRequiredParameters(node.functionExpression.parameters)) {
      _collect(
        annotations: node.metadata,
        targetName: name,
        invocation: '$name()',
        returnsWidgetBuilder: _returnsWidgetBuilder(node.returnType),
      );
    }
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final parent = node.parent;
    final name = node.name.lexeme;
    if (node.isStatic &&
        !name.startsWith('_') &&
        parent is ClassDeclaration &&
        !parent.name.lexeme.startsWith('_') &&
        _hasNoRequiredParameters(node.parameters)) {
      final className = parent.name.lexeme;
      _collect(
        annotations: node.metadata,
        targetName: '$className.$name',
        invocation: '$className.$name()',
        returnsWidgetBuilder: _returnsWidgetBuilder(node.returnType),
      );
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final parent = node.parent;
    final constructorName = node.name?.lexeme ?? '';
    if (parent is ClassDeclaration &&
        !parent.name.lexeme.startsWith('_') &&
        !constructorName.startsWith('_') &&
        _hasNoRequiredParameters(node.parameters)) {
      final className = parent.name.lexeme;
      final targetName = constructorName.isEmpty
          ? className
          : '$className.$constructorName';
      _collect(
        annotations: node.metadata,
        targetName: targetName,
        invocation: '$targetName()',
        // Constructors always return their enclosing type, never a builder.
        returnsWidgetBuilder: false,
      );
    }
    super.visitConstructorDeclaration(node);
  }

  void _collect({
    required NodeList<Annotation> annotations,
    required String targetName,
    required String invocation,
    required bool returnsWidgetBuilder,
  }) {
    for (final annotation in annotations) {
      final constant = annotation.elementAnnotation?.computeConstantValue();
      final type = constant?.type;
      if (constant == null || type == null) {
        continue;
      }
      if (!_isPreviewType(type) && !_isMultiPreviewType(type)) {
        continue;
      }

      final source = annotation.toSource();
      final annotationSource = source.startsWith('@')
          ? source.substring(1)
          : source;

      results.add(
        DiscoveredPreviewTarget(
          sourcePath: sourcePath,
          targetName: targetName,
          invocation: invocation,
          libraryImportUri: libraryImportUri,
          sourceImports: sourceImports,
          annotationSource: annotationSource,
          returnsWidgetBuilder: returnsWidgetBuilder,
          wrapperName: _callbackName(constant, 'wrapper'),
          themeName: _callbackName(constant, 'theme'),
          localizationsName: _callbackName(constant, 'localizations'),
        ),
      );
    }
  }

  String? _callbackName(DartObject constant, String field) {
    return constant.getField(field)?.toFunctionValue()?.name;
  }

  bool _hasNoRequiredParameters(FormalParameterList? parameters) {
    if (parameters == null) {
      return true;
    }
    return parameters.parameters.every((parameter) => !parameter.isRequired);
  }

  bool _returnsWidgetBuilder(TypeAnnotation? returnType) {
    if (returnType == null) {
      return false;
    }
    final source = returnType.toSource();
    return source.contains('WidgetBuilder') ||
        source.startsWith('Widget Function');
  }

  bool _isPreviewType(DartType type) => _matchesWidgetPreview(type, 'Preview');

  bool _isMultiPreviewType(DartType type) =>
      _matchesWidgetPreview(type, 'MultiPreview');

  bool _matchesWidgetPreview(DartType type, String className) {
    if (type is! InterfaceType) {
      return false;
    }

    bool matches(InterfaceType candidate) {
      final element = candidate.element;
      return element.name == className &&
          element.library.uri.toString().contains('widget_previews');
    }

    if (matches(type)) {
      return true;
    }
    return type.allSupertypes.any(matches);
  }
}
