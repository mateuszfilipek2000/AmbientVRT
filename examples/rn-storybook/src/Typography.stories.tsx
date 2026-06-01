import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { Meta, StoryObj } from '@storybook/react-native-web-vite';

import { useStrings, useTheme } from './theme';

function Greeting(): React.ReactElement {
  const theme = useTheme();
  const strings = useStrings();
  return (
    <View>
      <Text style={[styles.heading, { color: theme.text }]}>{strings.greeting}</Text>
      <Text style={[styles.body, { color: theme.textMuted }]}>{strings.subtitle}</Text>
    </View>
  );
}

const meta: Meta<typeof Greeting> = {
  title: 'Foundations/Typography',
  component: Greeting,
};

export default meta;

type Story = StoryObj<typeof Greeting>;

export const Greetings: Story = {};

const styles = StyleSheet.create({
  heading: {
    fontSize: 28,
    fontWeight: '700',
    marginBottom: 8,
  },
  body: {
    fontSize: 16,
  },
});
