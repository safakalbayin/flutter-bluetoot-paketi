// Separate web-only entry: native main.dart continues using the Android plugin.
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const base = process.env.BASE_PATH ?? '/device-identity/';
if (!base.startsWith('/') || !base.endsWith('/')) {
  throw new Error('BASE_PATH must start and end with /');
}
const result = spawnSync('flutter', [
  'build', 'web', '--release',
  '--target=lib/main_preview.dart',
  '--no-web-resources-cdn',
  '--pwa-strategy=none',
  `--base-href=${base}flutter/`,
  `--output=${path.join(root, 'artifacts/device-identity-preview/public/flutter')}`,
], {
  cwd: path.join(root, 'packages/device_identity/example'),
  stdio: 'inherit',
});
if (result.error) throw new Error(`Flutter SDK required: ${result.error.message}`);
if (result.status !== 0) process.exit(result.status ?? 1);
