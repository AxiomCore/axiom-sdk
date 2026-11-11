// Deterministic build: strips the erasable TypeScript of src/index.ts into
// dist/index.js and copies the hand-written declarations to dist/index.d.ts.
// `node scripts/build.mjs --check` fails when dist/ is not what the build emits.
import { stripTypeScriptTypes } from 'node:module';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

export function render() {
  const source = readFileSync(join(root, 'src/index.ts'), 'utf8');
  const stripped = stripTypeScriptTypes(source, { mode: 'strip' });
  const body = stripped
    .split('\n')
    .map((line) => line.replace(/\s+$/, ''))
    // A stripped class field declaration such as `readonly code: string;` leaves wide gaps.
    .map((line) => line.replace(/^(\s*)\s*?([A-Za-z_$][\w$]*)\s+;$/, (_m, indent, name) => indent.slice(0, 2) + name + ';'))
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .replace(/\s*$/, '\n');
  const js = '// Generated from src/index.ts by scripts/build.mjs. Do not edit.\n' + body;
  const dts = readFileSync(join(root, 'types/index.d.ts'), 'utf8');
  return { 'dist/index.js': js, 'dist/index.d.ts': dts };
}

export function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

if (import.meta.main) {
  const outputs = render();
  const check = process.argv.includes('--check');
  let stale = false;
  for (const [rel, content] of Object.entries(outputs)) {
    const path = join(root, rel);
    if (check) {
      let existing = null;
      try {
        existing = readFileSync(path, 'utf8');
      } catch {
        existing = null;
      }
      if (existing !== content) {
        console.error(`stale: ${rel}`);
        stale = true;
      }
    } else {
      mkdirSync(dirname(path), { recursive: true });
      writeFileSync(path, content);
    }
  }
  console.log(`dist/index.js sha256 ${sha256(outputs['dist/index.js'])}`);
  if (stale) process.exit(1);
}
