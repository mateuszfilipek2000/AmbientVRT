# rn-storybook example

A minimal React Native + Storybook app (rendered on the web via
[`@storybook/react-native-web-vite`](https://storybook.js.org/docs/get-started/frameworks/react-native-web-vite))
used to exercise AmbientVRT's React Native capture adapter.

## Stories

Five stories across three component groups, all driven by two variant globals
(`theme`: `light`/`dark`, `locale`: `en`/`fr`) declared in
[`.storybook/preview.tsx`](.storybook/preview.tsx):

- `Components/Button` — Primary, Secondary, Disabled
- `Components/Card` — Default (exercises both theme + locale)
- `Foundations/Typography` — Greetings (locale-driven copy)

## Commands

```bash
npm install
npm run storybook        # interactive dev server on :6006
npm run build-storybook  # static build -> storybook-static/ (incl. index.json)
npm run typecheck
```

The static build's `index.json` enumerates stories; AmbientVRT filters
`type === 'story'` and uses each story `id` as the snapshot id.
