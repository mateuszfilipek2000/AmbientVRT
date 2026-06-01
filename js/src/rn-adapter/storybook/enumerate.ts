import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

import type { Story } from '../types';

/** Shape of a Storybook `index.json` entry (v3+). Only the fields we use. */
interface IndexEntry {
  type?: string;
  id: string;
  name: string;
  title: string;
}

interface StorybookIndex {
  v: number;
  entries: Record<string, IndexEntry>;
}

/** Filename of the story index emitted by `storybook build`. */
export const STORY_INDEX_FILENAME = 'index.json';

/**
 * Reads `<staticDir>/index.json` and returns every `type === 'story'` entry as
 * a {@link Story}, sorted by id for deterministic ordering.
 *
 * Non-story entries (docs, etc.) are filtered out. Throws if the index is
 * missing or malformed.
 */
export async function enumerateStories(staticDir: string): Promise<Story[]> {
  const indexPath = join(staticDir, STORY_INDEX_FILENAME);
  let raw: string;
  try {
    raw = await readFile(indexPath, 'utf8');
  } catch (cause) {
    throw new Error(
      `Could not read Storybook index at ${indexPath}. Did you run \`storybook build\`?`,
      { cause },
    );
  }

  let index: StorybookIndex;
  try {
    index = JSON.parse(raw) as StorybookIndex;
  } catch (cause) {
    throw new Error(`Storybook index at ${indexPath} is not valid JSON.`, { cause });
  }

  if (index.entries === undefined || index.entries === null) {
    throw new Error(`Storybook index at ${indexPath} has no \`entries\`.`);
  }

  const stories = Object.values(index.entries)
    .filter((entry) => entry.type === 'story')
    .map((entry): Story => ({ id: entry.id, title: entry.title, name: entry.name }));

  stories.sort((a, b) => a.id.localeCompare(b.id));
  return stories;
}
