import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { render, sha256 } from '../scripts/build.mjs';

const dist = (rel) => readFileSync(new URL('../' + rel, import.meta.url), 'utf8');

test('dist/ is exactly what the deterministic build emits from src/ and types/', () => {
  const first = render();
  const second = render();
  assert.deepEqual(first, second);
  for (const [rel, content] of Object.entries(first)) assert.equal(dist(rel), content, `${rel} is stale: run npm run build`);
  assert.match(sha256(first['dist/index.js']), /^[0-9a-f]{64}$/);
});

test('dist/index.js has no imports, no window access and no global writes', () => {
  const js = dist('dist/index.js');
  assert.ok(!/^\s*import\s/m.test(js));
  assert.ok(!/\bwindow\b/.test(js));
  assert.ok(!/globalThis\.[A-Za-z_$][\w$]*\s*=[^=]/.test(js));
  assert.ok(!/\b(localStorage|sessionStorage)\.setItem\([^)]*(access|refresh)/i.test(js));
});
