// Converts a Flutter-era .conlang (SQLite) project to a .conlang.json file.
// Usage: npm run import-legacy -- <input.conlang> [output.conlang.json]

import { readFileSync, writeFileSync } from 'node:fs';
import { basename } from 'node:path';
import { createRequire } from 'node:module';
import { importLegacyProject } from '../src/core/legacy/importSqlite';
import { openLegacyDatabase } from '../src/core/legacy/sqlJsAdapter';
import { serializeProject } from '../src/core/types';

const [input, output] = process.argv.slice(2);
if (!input) {
  console.error('Usage: import-legacy <input.conlang> [output.conlang.json]');
  process.exit(1);
}
const require = createRequire(import.meta.url);
const wasm = require.resolve('sql.js/dist/sql-wasm.wasm');
const db = await openLegacyDatabase(new Uint8Array(readFileSync(input)), { locateFile: () => wasm });
const name = basename(input).replace(/\.conlang$/i, '');
const { doc, warnings } = importLegacyProject(db, name);
db.close();
const target = output ?? input.replace(/\.conlang$/i, '') + '.conlang.json';
writeFileSync(target, serializeProject(doc));
console.log(`${name}: ${doc.lexemes.length} words, ${doc.rules.length} rules, ${doc.phonemes.length} phonemes -> ${target}`);
for (const w of warnings) console.warn(`  warning: ${w}`);
