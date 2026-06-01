/**
 * Builds the Storybook iframe URL for a single story in isolation.
 *
 * Storybook renders one story at `iframe.html?id=<id>&viewMode=story&nav=0`.
 * Variant globals are appended as `&globals=key:value;key2:value2` — the
 * `key:value;...` form Storybook itself uses, so the `:` / `;` delimiters are
 * intentionally left unencoded.
 */
export function buildStoryUrl(
  baseUrl: string,
  id: string,
  globals: Record<string, string> = {},
): string {
  const base = baseUrl.replace(/\/+$/, '');
  const params = new URLSearchParams({
    id,
    viewMode: 'story',
    nav: '0',
  });
  let url = `${base}/iframe.html?${params.toString()}`;

  const globalsValue = Object.entries(globals)
    .map(([key, value]) => `${key}:${value}`)
    .join(';');
  if (globalsValue.length > 0) {
    url += `&globals=${globalsValue}`;
  }
  return url;
}
