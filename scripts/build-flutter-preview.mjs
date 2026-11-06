// Builds the actual Flutter example; React only hosts it in the preview.
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const base = process.env.BASE_PATH ?? '/';
if (!base.startsWith('/') || !base.endsWith('/')) {
  throw new Error('BASE_PATH must start and end with /');
}
const result = spawnSync('flutter', [
  'build', 'web',
  '--release',
  '--no-web-resources-cdn',
  '--pwa-strategy=none',
  `--base-href=${base}flutter/`,
  `--output=${path.join(root, 'artifacts/blooted-preview/public/flutter')}`,
], {
  cwd: path.join(root, 'packages/blooted/example'),
  stdio: 'inherit',
});
if (result.error) {
  throw new Error(`Flutter SDK is required to build the preview: ${result.error.message}`);
}
if (result.status !== 0) process.exit(result.status ?? 1);
