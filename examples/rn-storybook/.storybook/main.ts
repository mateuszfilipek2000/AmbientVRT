import type { StorybookConfig } from '@storybook/react-native-web-vite';

const config: StorybookConfig = {
  stories: ['../src/**/*.stories.@(ts|tsx)'],
  addons: [],
  framework: {
    name: '@storybook/react-native-web-vite',
    options: {},
  },
  // Deterministic captures: no telemetry network calls during build/serve.
  core: {
    disableTelemetry: true,
  },
};

export default config;
