import React, { createContext, useContext } from 'react';

export type ThemeName = 'light' | 'dark';
export type LocaleName = 'en' | 'fr';

export interface Theme {
  name: ThemeName;
  background: string;
  surface: string;
  text: string;
  textMuted: string;
  accent: string;
  accentText: string;
  border: string;
}

const lightTheme: Theme = {
  name: 'light',
  background: '#ffffff',
  surface: '#f3f4f6',
  text: '#111827',
  textMuted: '#6b7280',
  accent: '#2563eb',
  accentText: '#ffffff',
  border: '#d1d5db',
};

const darkTheme: Theme = {
  name: 'dark',
  background: '#0b1120',
  surface: '#1f2937',
  text: '#f9fafb',
  textMuted: '#9ca3af',
  accent: '#60a5fa',
  accentText: '#0b1120',
  border: '#374151',
};

export const themes: Record<ThemeName, Theme> = {
  light: lightTheme,
  dark: darkTheme,
};

const ThemeContext = createContext<Theme>(lightTheme);
const LocaleContext = createContext<LocaleName>('en');

export function useTheme(): Theme {
  return useContext(ThemeContext);
}

export function useLocale(): LocaleName {
  return useContext(LocaleContext);
}

const strings: Record<LocaleName, Record<string, string>> = {
  en: {
    greeting: 'Welcome back',
    subtitle: 'Your dashboard is ready.',
    cta: 'Get started',
  },
  fr: {
    greeting: 'Bon retour',
    subtitle: 'Votre tableau de bord est prêt.',
    cta: 'Commencer',
  },
};

export function useStrings(): Record<string, string> {
  return strings[useLocale()];
}

export function AppProviders({
  theme,
  locale,
  children,
}: {
  theme: ThemeName;
  locale: LocaleName;
  children: React.ReactNode;
}): React.ReactElement {
  return (
    <ThemeContext.Provider value={themes[theme]}>
      <LocaleContext.Provider value={locale}>{children}</LocaleContext.Provider>
    </ThemeContext.Provider>
  );
}
