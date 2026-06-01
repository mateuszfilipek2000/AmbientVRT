import React from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { useStrings, useTheme } from '../theme';
import { Button } from './Button';

export function Card(): React.ReactElement {
  const theme = useTheme();
  const strings = useStrings();
  return (
    <View
      style={[
        styles.card,
        { backgroundColor: theme.surface, borderColor: theme.border },
      ]}
    >
      <Text style={[styles.title, { color: theme.text }]}>{strings.greeting}</Text>
      <Text style={[styles.subtitle, { color: theme.textMuted }]}>
        {strings.subtitle}
      </Text>
      <View style={styles.actions}>
        <Button label={strings.cta} variant="primary" />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    width: 280,
    padding: 20,
    borderRadius: 12,
    borderWidth: 1,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
    marginBottom: 6,
  },
  subtitle: {
    fontSize: 14,
    marginBottom: 16,
  },
  actions: {
    flexDirection: 'row',
  },
});
