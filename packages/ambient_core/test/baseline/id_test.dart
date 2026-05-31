import 'package:ambient_core/ambient_core.dart';
import 'package:test/test.dart';

void main() {
  group('reactNativeBaseId', () {
    test('preserves the Storybook story id verbatim', () {
      expect(
        reactNativeBaseId('components-button--primary'),
        'components-button--primary',
      );
    });

    test('rejects a blank story id', () {
      expect(() => reactNativeBaseId(''), throwsArgumentError);
      expect(() => reactNativeBaseId('   '), throwsArgumentError);
    });
  });

  group('flutterBaseId', () {
    test('joins path::name::group', () {
      expect(
        flutterBaseId(
          path: 'lib/widgets/button.dart',
          name: 'ButtonPreview',
          group: 'Buttons',
        ),
        'lib/widgets/button.dart::ButtonPreview::Buttons',
      );
    });

    test('omits the group when absent or empty', () {
      const expected = 'lib/widgets/button.dart::ButtonPreview';
      expect(
        flutterBaseId(path: 'lib/widgets/button.dart', name: 'ButtonPreview'),
        expected,
      );
      expect(
        flutterBaseId(
          path: 'lib/widgets/button.dart',
          name: 'ButtonPreview',
          group: '',
        ),
        expected,
      );
    });

    test('rejects a blank path or name', () {
      expect(
        () => flutterBaseId(path: '', name: 'ButtonPreview'),
        throwsArgumentError,
      );
      expect(
        () => flutterBaseId(path: 'lib/x.dart', name: '  '),
        throwsArgumentError,
      );
    });
  });

  group('variant id segments', () {
    test('are empty for a null or empty variant', () {
      expect(variantIdSegments(null), isEmpty);
      expect(variantIdSegments(const Variant()), isEmpty);
    });

    test('emit only set dimensions in canonical (alphabetical) order', () {
      final segments = variantIdSegments(
        const Variant(
          theme: 'corporate',
          brightness: Brightness.dark,
          locale: 'en-US',
          sizeName: 'phone',
        ),
      );
      expect(segments, [
        'brightness=dark',
        'locale=en-US',
        'sizeName=phone',
        'theme=corporate',
      ]);
    });

    test('use the wire name for brightness', () {
      expect(variantIdSegments(const Variant(brightness: Brightness.light)), [
        'brightness=light',
      ]);
    });

    test(
      'are order-independent: insertion order does not change the result',
      () {
        final ordered = variantIdSegmentsFromMap({
          'brightness': 'dark',
          'locale': 'fr',
          'theme': 'dark',
        });
        final shuffled = variantIdSegmentsFromMap({
          'theme': 'dark',
          'brightness': 'dark',
          'locale': 'fr',
        });
        expect(ordered, shuffled);
        expect(ordered, ['brightness=dark', 'locale=fr', 'theme=dark']);
      },
    );
  });

  group('snapshotIdFromBase', () {
    test('appends the platform wire name', () {
      expect(
        snapshotIdFromBase(
          baseId: 'components-button--primary',
          platform: Platform.reactNative,
        ),
        'components-button--primary::react-native',
      );
    });

    test('appends platform then canonical variant segments', () {
      expect(
        snapshotIdFromBase(
          baseId: 'components-button--primary',
          platform: Platform.reactNative,
          variant: const Variant(brightness: Brightness.dark, theme: 'dark'),
        ),
        'components-button--primary::react-native::brightness=dark::theme=dark',
      );
    });

    test('rejects a blank base id', () {
      expect(
        () => snapshotIdFromBase(baseId: '  ', platform: Platform.flutter),
        throwsArgumentError,
      );
    });
  });

  group('determinism', () {
    test('same inputs produce the same id', () {
      String build() => flutterSnapshotId(
        path: 'lib/widgets/button.dart',
        name: 'ButtonPreview',
        group: 'Buttons',
        variant: const Variant(brightness: Brightness.dark),
      );
      expect(build(), build());
    });
  });

  group('flutterSnapshotId', () {
    test('derives id from path::name::group plus platform', () {
      expect(
        flutterSnapshotId(
          path: 'lib/widgets/button.dart',
          name: 'ButtonPreview',
          group: 'Buttons',
        ),
        'lib/widgets/button.dart::ButtonPreview::Buttons::flutter',
      );
    });

    test('light/dark variants get distinct, correctly-suffixed ids', () {
      final light = flutterSnapshotId(
        path: 'lib/widgets/button.dart',
        name: 'ButtonPreview',
        variant: const Variant(brightness: Brightness.light),
      );
      final dark = flutterSnapshotId(
        path: 'lib/widgets/button.dart',
        name: 'ButtonPreview',
        variant: const Variant(brightness: Brightness.dark),
      );
      expect(
        light,
        'lib/widgets/button.dart::ButtonPreview::flutter::brightness=light',
      );
      expect(
        dark,
        'lib/widgets/button.dart::ButtonPreview::flutter::brightness=dark',
      );
      expect(light, isNot(dark));
    });

    group('explicit override', () {
      test('wins over the path-derived base', () {
        expect(
          flutterSnapshotId(
            path: 'lib/widgets/button.dart',
            name: 'ButtonPreview',
            idOverride: 'stable-button',
          ),
          'stable-button::flutter',
        );
      });

      test('is rename-proof: a file move does not change the id', () {
        String build(String path) => flutterSnapshotId(
          path: path,
          name: 'ButtonPreview',
          group: 'Buttons',
          idOverride: 'stable-button',
          variant: const Variant(brightness: Brightness.dark),
        );
        // Same logical preview, moved to a different file/directory.
        expect(
          build('lib/widgets/button.dart'),
          build('lib/ui/components/big_button.dart'),
        );
      });

      test('a blank override falls back to the derived base', () {
        const empty = '';
        expect(
          flutterSnapshotId(
            path: 'lib/widgets/button.dart',
            name: 'ButtonPreview',
            idOverride: empty,
          ),
          'lib/widgets/button.dart::ButtonPreview::flutter',
        );
      });

      test('override still receives variant suffixing', () {
        expect(
          flutterSnapshotId(
            path: 'lib/x.dart',
            name: 'X',
            idOverride: 'stable-x',
            variant: const Variant(brightness: Brightness.dark),
          ),
          'stable-x::flutter::brightness=dark',
        );
      });
    });
  });

  group('reactNativeSnapshotId', () {
    test('preserves the story id verbatim as the base', () {
      expect(
        reactNativeSnapshotId(storyId: 'components-button--primary'),
        'components-button--primary::react-native',
      );
    });

    test('explicit override wins', () {
      expect(
        reactNativeSnapshotId(
          storyId: 'components-button--primary',
          idOverride: 'stable-button',
        ),
        'stable-button::react-native',
      );
    });

    test('applies canonical variant suffixing', () {
      expect(
        reactNativeSnapshotId(
          storyId: 'components-button--primary',
          variant: const Variant(theme: 'dark', brightness: Brightness.dark),
        ),
        'components-button--primary::react-native::brightness=dark::theme=dark',
      );
    });
  });
}
