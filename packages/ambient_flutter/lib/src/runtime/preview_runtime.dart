import 'dart:convert';
import 'dart:ui' as ui;

import 'package:ambient_core/ambient_core.dart' as ambient;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../models/flutter_preview.dart';

typedef PreviewEntry =
    ({
      Object annotation,
      Widget Function(BuildContext) builder,
      String targetName,
      String sourcePath,
      String? wrapperName,
      String? themeName,
      String? localizationsName,
    });

class ResolvedPreview {
  const ResolvedPreview({
    required this.builder,
    required this.targetName,
    required this.sourcePath,
    required this.group,
    required this.name,
    required this.size,
    required this.textScaleFactor,
    required this.wrapper,
    required this.theme,
    required this.brightness,
    required this.localizations,
    required this.wrapperName,
    required this.themeName,
    required this.localizationsName,
  });

  final Widget Function(BuildContext) builder;
  final String targetName;
  final String sourcePath;
  final String group;
  final String? name;
  final Size? size;
  final double? textScaleFactor;
  final WidgetWrapper? wrapper;
  final PreviewTheme? theme;
  final ui.Brightness? brightness;
  final PreviewLocalizations? localizations;
  final String? wrapperName;
  final String? themeName;
  final String? localizationsName;

  String get effectiveName => name?.trim().isNotEmpty == true ? name!.trim() : targetName;

  Size get logicalSize => size ?? const Size(800, 600);
}

bool _fontsLoaded = false;

List<ResolvedPreview> expandAllEntries(List<PreviewEntry> entries) {
  return <ResolvedPreview>[
    for (final entry in entries) ..._expandEntry(entry),
  ];
}

List<ResolvedPreview> _expandEntry(PreviewEntry entry) {
  final annotation = entry.annotation;
  if (annotation is Preview) {
    return <ResolvedPreview>[_resolvedPreviewFromPreview(entry, annotation)];
  }

  if (annotation is MultiPreview) {
    return <ResolvedPreview>[
      for (final preview in annotation.transform())
        _resolvedPreviewFromPreview(entry, preview),
    ];
  }

  throw StateError(
    'Unsupported preview annotation ${annotation.runtimeType} on '
    '${entry.sourcePath}::${entry.targetName}.',
  );
}

ResolvedPreview _resolvedPreviewFromPreview(
  PreviewEntry entry,
  Preview preview,
) {
  return ResolvedPreview(
    builder: entry.builder,
    targetName: entry.targetName,
    sourcePath: entry.sourcePath,
    group: preview.group,
    name: preview.name,
    size: preview.size,
    textScaleFactor: preview.textScaleFactor,
    wrapper: preview.wrapper,
    theme: preview.theme,
    brightness: preview.brightness,
    localizations: preview.localizations,
    wrapperName: entry.wrapperName,
    themeName: entry.themeName,
    localizationsName: entry.localizationsName,
  );
}

Future<void> loadTestFonts() async {
  if (_fontsLoaded) {
    return;
  }

  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<Object?>;
  for (final entry in manifest.cast<Map<Object?, Object?>>()) {
    final family = entry['family'] as String?;
    final fonts = entry['fonts'] as List<Object?>?;
    if (family == null || fonts == null || fonts.isEmpty) {
      continue;
    }

    final loader = FontLoader(family);
    for (final font in fonts.cast<Map<Object?, Object?>>()) {
      final asset = font['asset'] as String?;
      if (asset == null) {
        continue;
      }

      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  _fontsLoaded = true;
}

Widget buildSurface(
  ResolvedPreview preview, {
  required Key captureKey,
}) {
  Widget child = Builder(builder: preview.builder);
  if (preview.wrapper != null) {
    child = preview.wrapper!(child);
  }

  final appChild = _wrapInMaterialSurface(preview, child);
  return RepaintBoundary(
    key: captureKey,
    child: SizedBox.fromSize(
      size: preview.logicalSize,
      child: ClipRect(child: appChild),
    ),
  );
}

Widget _wrapInMaterialSurface(
  ResolvedPreview preview,
  Widget child,
) {
  final themeData = preview.theme?.call();
  final brightness = preview.brightness ?? ui.Brightness.light;
  final lightTheme =
      themeData?.materialLight ??
      ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
      );
  final darkTheme =
      themeData?.materialDark ??
      ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      );

  final localizationsData = preview.localizations?.call();
  final locale = localizationsData?.locale;
  final delegates =
      localizationsData?.localizationsDelegates ??
      const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ];
  final supportedLocales =
      localizationsData?.supportedLocales ??
      (locale == null ? const <Locale>[Locale('en')] : <Locale>[locale]);

  final surface = Align(
    alignment: Alignment.topLeft,
    child: MediaQuery(
      data: MediaQueryData(
        size: preview.logicalSize,
        textScaler: TextScaler.linear(preview.textScaleFactor ?? 1.0),
        platformBrightness: brightness,
      ),
      child: child,
    ),
  );

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    localizationsDelegates: delegates,
    supportedLocales: supportedLocales,
    theme: lightTheme,
    darkTheme: darkTheme,
    themeMode: brightness == ui.Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      body: SizedBox.fromSize(
        size: preview.logicalSize,
        child: surface,
      ),
    ),
  );
}

List<FlutterPreviewInfo> describeResolvedPreviews(
  List<ResolvedPreview> previews, {
  required double dpr,
}) {
  return <FlutterPreviewInfo>[
    for (final preview in previews) describeResolvedPreview(preview, dpr: dpr),
  ];
}

FlutterPreviewInfo describeResolvedPreview(
  ResolvedPreview preview, {
  required double dpr,
}) {
  final variant = _variantFor(preview);
  final id = ambient.flutterSnapshotId(
    path: preview.sourcePath,
    name: preview.effectiveName,
    group: preview.group,
    variant: variant,
  );

  return FlutterPreviewInfo(
    id: id,
    sourcePath: preview.sourcePath,
    targetName: preview.targetName,
    group: preview.group,
    name: preview.effectiveName,
    imagePath: plannedImagePathForSnapshotId(id),
    dpr: dpr,
    width: preview.logicalSize.width,
    height: preview.logicalSize.height,
    textScaleFactor: preview.textScaleFactor,
    variant: variant,
    wrapperName: preview.wrapperName,
    themeName: preview.themeName,
    localizationsName: preview.localizationsName,
  );
}

ambient.Variant? _variantFor(ResolvedPreview preview) {
  final brightness = switch (preview.brightness) {
    ui.Brightness.light => ambient.Brightness.light,
    ui.Brightness.dark => ambient.Brightness.dark,
    null => null,
  };
  final locale = preview.localizations?.call().locale?.toLanguageTag();

  if (brightness == null && locale == null) {
    return null;
  }

  return ambient.Variant(
    brightness: brightness,
    locale: locale,
  );
}

String plannedImagePathForSnapshotId(String snapshotId) {
  final safeBase = snapshotId
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '')
      .toLowerCase();
  final digest = sha256.convert(utf8.encode(snapshotId)).toString().substring(0, 12);
  return 'captures/$safeBase-$digest.png';
}
