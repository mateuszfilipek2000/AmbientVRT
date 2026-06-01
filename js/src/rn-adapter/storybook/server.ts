import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { createServer, type Server } from 'node:http';
import { extname, join, normalize } from 'node:path';
import type { AddressInfo } from 'node:net';

const CONTENT_TYPES: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.map': 'application/json; charset=utf-8',
};

/** A running static file server over a Storybook build. */
export interface StorybookServer {
  /** Base URL, e.g. `http://127.0.0.1:53124`. No trailing slash. */
  baseUrl: string;
  /** Stops the server and releases the port. */
  close: () => Promise<void>;
}

function contentTypeFor(filePath: string): string {
  return CONTENT_TYPES[extname(filePath).toLowerCase()] ?? 'application/octet-stream';
}

/**
 * Resolves a request URL path to an absolute file path inside `staticDir`,
 * defending against `..` traversal. Returns `null` for escaping paths.
 */
function resolveRequestPath(staticDir: string, urlPath: string): string | null {
  // Strip the query string; Storybook drives stories via `iframe.html?id=...`.
  const pathname = decodeURIComponent(urlPath.split('?')[0]);
  const relative = normalize(pathname).replace(/^(\.\.[/\\])+/, '');
  const candidate = join(staticDir, relative === '/' ? 'index.html' : relative);
  if (!candidate.startsWith(staticDir)) {
    return null;
  }
  return candidate;
}

/**
 * Serves the Storybook static build at `staticDir` over loopback on an
 * ephemeral port, so Playwright can open `iframe.html`. Call {@link
 * StorybookServer.close} when done.
 */
export async function serveStorybook(staticDir: string): Promise<StorybookServer> {
  const server: Server = createServer((req, res) => {
    void (async () => {
      const filePath = resolveRequestPath(staticDir, req.url ?? '/');
      if (filePath === null) {
        res.writeHead(403).end('Forbidden');
        return;
      }
      try {
        const stats = await stat(filePath);
        const target = stats.isDirectory() ? join(filePath, 'index.html') : filePath;
        res.writeHead(200, { 'content-type': contentTypeFor(target) });
        createReadStream(target).pipe(res);
      } catch {
        res.writeHead(404).end('Not found');
      }
    })();
  });

  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      server.removeListener('error', reject);
      resolve();
    });
  });

  const address = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}`;

  return {
    baseUrl,
    close: () =>
      new Promise<void>((resolve, reject) => {
        server.close((err) => (err ? reject(err) : resolve()));
      }),
  };
}
