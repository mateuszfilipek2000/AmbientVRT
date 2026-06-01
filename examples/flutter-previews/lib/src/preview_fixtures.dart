import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class PreviewFixture {
  const PreviewFixture({
    required this.customerName,
    required this.pendingAlerts,
  });

  final String customerName;
  final int pendingAlerts;
}

class PreviewFixtureScope extends InheritedWidget {
  const PreviewFixtureScope({
    required this.fixture,
    required super.child,
    super.key,
  });

  final PreviewFixture fixture;

  static PreviewFixture of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PreviewFixtureScope>();
    if (scope == null) {
      throw StateError('PreviewFixtureScope is missing from the widget tree.');
    }

    return scope.fixture;
  }

  @override
  bool updateShouldNotify(PreviewFixtureScope oldWidget) {
    return fixture != oldWidget.fixture;
  }
}

Widget fixturePreviewHarness(Widget child) {
  return PreviewFixtureScope(
    fixture: const PreviewFixture(
      customerName: 'Ada Lovelace',
      pendingAlerts: 3,
    ),
    child: child,
  );
}

PreviewThemeData previewTheme() {
  return PreviewThemeData(
    materialLight: ThemeData(
      useMaterial3: true,
      fontFamily: 'AmbientPreviewSans',
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2F6FED),
        brightness: Brightness.light,
      ),
    ),
    materialDark: ThemeData(
      useMaterial3: true,
      fontFamily: 'AmbientPreviewSans',
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF84A9FF),
        brightness: Brightness.dark,
      ),
    ),
  );
}

PreviewLocalizationsData polishPreviewLocalizations() {
  return PreviewLocalizationsData(
    locale: const Locale('pl', 'PL'),
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
    supportedLocales: const <Locale>[Locale('pl', 'PL')],
  );
}

final class LightDarkProductPreviews extends MultiPreview {
  const LightDarkProductPreviews();

  @override
  List<Preview> get previews => const <Preview>[
        Preview(
          group: 'Variants',
          name: 'Light',
          brightness: Brightness.light,
          theme: previewTheme,
        ),
        Preview(
          group: 'Variants',
          name: 'Dark',
          brightness: Brightness.dark,
          theme: previewTheme,
        ),
      ];
}
