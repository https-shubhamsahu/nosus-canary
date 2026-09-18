// Generate the isolated fresh-project bootstrap without editing historical SQL.
// This generates SQL only; applying it always requires an explicit project ID.
import { readFileSync, readdirSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const folder = resolve(root, 'app/supabase/migrations');
let sql = readdirSync(folder).filter(name => name.endsWith('.sql')).sort()
  .map(name => readFileSync(resolve(folder, name), 'utf8')).join('\n');
sql = sql.replaceAll('rxfnazmusofikwaggntb.supabase.co', 'ffidvfguojalzpclipzi.supabase.co');
// Production had an orphaned function, absent in a fresh DB. A later migration
// drops it. Skip only its search_path adjustment when it does not exist.
sql = sql.replace('ALTER FUNCTION public.revoke_device(uuid) SET search_path = public;',
  "DO $bootstrap$ BEGIN IF to_regprocedure('public.revoke_device(uuid)') IS NOT NULL THEN ALTER FUNCTION public.revoke_device(uuid) SET search_path = public; END IF; END $bootstrap$;");
sql += '\n' + readFileSync(resolve(root, 'supabase/migrations/20260916082811_experiment_drops.sql'), 'utf8');
if (sql.includes('rxfnazmusofikwaggntb.supabase.co')) throw new Error('Production URL in bootstrap');
const output = resolve(root, 'app/supabase/.temp/experiment-bootstrap.sql');
mkdirSync(dirname(output), { recursive: true });
writeFileSync(output, sql);
console.log('Generated fresh-project SQL for ffidvfguojalzpclipzi only:', output);
