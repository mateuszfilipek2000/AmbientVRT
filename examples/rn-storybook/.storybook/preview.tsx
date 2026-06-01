import React from 'react';
import { View } from 'react-native';
import type { Decorator, Preview } from '@storybook/react-native-web-vite';

import { AppProviders, themes, type LocaleName, type ThemeName } from '../src/theme';

// Variant-driving globals. The RN capture adapter sets these per variant via
// Storybook's `globals` URL param (e.g. `&globals=theme:dark;locale:fr`).
const withProviders: Decorator = (Story, context) => {
  const theme = (context.globals.theme as ThemeName) ?? 'light';
  const locale = (context.globals.locale as LocaleName) ?? 'en';
  return (
    <AppProviders theme={theme} locale={locale}>
      <View
        style={{
          padding: 16,
          backgroundColor: themes[theme].background,
          alignItems: 'flex-start',
        }}
      >
        <Story />
      </View>
    </AppProviders>
  );
};

const preview: Preview = {
  decorators: [withProviders],
  initialGlobals: {
    theme: 'light',
    locale: 'en',
  },
  globalTypes: {
    theme: {
      description: 'Color theme',
      defaultValue: 'light',
      toolbar: {
        title: 'Theme',
        items: [
          { value: 'light', title: 'Light' },
          { value: 'dark', title: 'Dark' },
        ],
      },
    },
    locale: {
      description: 'Locale',
      defaultValue: 'en',
      toolbar: {
        title: 'Locale',
        items: [
          { value: 'en', title: 'English' },
          { value: 'fr', title: 'Français' },
        ],
      },
    },
  },
  parameters: {
    layout: 'fullscreen',
  },
};

export default preview;
