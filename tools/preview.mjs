// Local preview of the landing page with a mock app list (real index is only built in CI).
// Usage: npm run preview  → http://localhost:5190
import { createServer } from 'node:http';
import { readFileSync, writeFileSync, mkdirSync, copyFileSync } from 'node:fs';
import { join, extname } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/(\w:)/, '$1');
const site = join(root, 'site');
mkdirSync(join(site, 'repo'), { recursive: true });

writeFileSync(join(site, 'index.html'), readFileSync(join(root, 'branding/index.html'), 'utf8')
  .replaceAll('__REPO_URL__', 'https://example.github.io/appbutik/repo')
  .replaceAll('__REPO_NAME__', 'Appbutik')
  .replaceAll('__FINGERPRINT__', '0'.repeat(64)));
copyFileSync(join(root, 'branding/icon.png'), join(site, 'icon.png'));
writeFileSync(join(site, 'repo/index-v1.json'), JSON.stringify({
  apps: [
    { packageName: 'se.example.glosor', localized: { 'en-US': { name: 'Glosor', summary: 'Öva glosor offline' } } },
    { packageName: 'se.example.timer', name: 'Lektionstimer', summary: 'Timer för klassrummet' },
  ],
  packages: { 'se.example.glosor': [{ versionName: '1.2.0' }], 'se.example.timer': [{ versionName: '0.9' }] },
}));

const types = { '.html': 'text/html; charset=utf-8', '.json': 'application/json', '.png': 'image/png' };
createServer((req, res) => {
  const path = join(site, decodeURIComponent(new URL(req.url, 'http://x').pathname).replace(/\/$/, '/index.html'));
  try {
    res.writeHead(200, { 'content-type': types[extname(path)] ?? 'application/octet-stream' });
    res.end(readFileSync(path));
  } catch {
    res.writeHead(404).end();
  }
}).listen(5190, () => console.log('http://localhost:5190'));
