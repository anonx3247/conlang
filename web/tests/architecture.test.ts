// Guards the design rule behind this rewrite: screens never compute or read a
// word's form themselves. They ask the engine.

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

function files(dir: string): string[] {
  return readdirSync(dir).flatMap((f) => {
    const p = join(dir, f);
    return statSync(p).isDirectory() ? files(p) : p.endsWith('.tsx') || p.endsWith('.ts') ? [p] : [];
  });
}

describe('architecture', () => {
  const ui = files('src/ui').map((p) => ({ p, s: readFileSync(p, 'utf8') }));
  it('UI never reads stored word forms', () => {
    const bad = ui.filter(({ s }) => /\.form\.(kind|phonemic|roman|parentId|ruleId)\b/.test(s)).map(({ p }) => p);
    expect(bad).toEqual([]);
  });
  it('UI never runs the morphology or rewrite engines directly', () => {
    const bad = ui.filter(({ s }) => /core\/(morphology|phonology)'/.test(s) && /\b(applyRule|applyRewriteRules|matchesAt)\b/.test(s)).map(({ p }) => p);
    expect(bad).toEqual([]);
  });
  it('the rule mini-language exists only in the legacy importer', () => {
    const all = [...files('src'), ...files('mcp')].filter((p) => !p.includes('legacy') && !p.includes('storage/store') && !p.includes('scripts'));
    const bad = all.filter((p) => /legacyRuleToBranches|patternToSegments/.test(readFileSync(p, 'utf8')));
    expect(bad).toEqual([]);
  });
});
