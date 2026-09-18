// Fresh backend salts only. Never reads production credentials or prints secrets.
import { randomBytes } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const app = resolve(dirname(fileURLToPath(import.meta.url)), '../app');
const envPath = resolve(app, '.env.local');
if (existsSync(envPath)) throw new Error('Experiment secrets already exist; refusing to rotate.');
if (readFileSync(resolve(app, 'supabase/.temp/project-ref'), 'utf8').trim() !== 'ffidvfguojalzpclipzi') {
  throw new Error('Wrong backend target');
}
const secrets = Object.fromEntries(['BURN_FILES_IP_SALT', 'REDEMPTION_CODE_SALT', 'BURN_FILES_CRON_SECRET']
  .map(name => [name, randomBytes(32).toString('hex')]));
writeFileSync(envPath, Object.entries(secrets).map(([name, value]) => `${name}=${value}`).join('\n') + '\n', {flag: 'wx', mode: 0o600});
mkdirSync(resolve(app, 'supabase/.temp'), {recursive: true});
writeFileSync(resolve(app, 'supabase/.temp/setup-cron.sql'),
  `select vault.create_secret('${secrets.BURN_FILES_CRON_SECRET}', 'burn_files_cron_secret');\n`, {flag: 'wx', mode: 0o600});
console.log('Generated ignored, experiment-only backend secrets.');
