import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { unzipSync } from 'fflate';
import initSqlJs from 'sql.js';
import { describe, expect, it } from 'vitest';
import { ankiEntries, buildApkg } from '../src/core/anki';
import * as c from '../src/core/commands';
import { LanguageEngine } from '../src/core/engine';
import { importLegacyProject, isSqliteFile } from '../src/core/legacy/importSqlite';
import { openLegacyDatabase } from '../src/core/legacy/sqlJsAdapter';
import { emptyProject } from '../src/core/types';

const wasm = createRequire(import.meta.url).resolve('sql.js/dist/sql-wasm.wasm');
const locateFile = () => wasm;

describe('anki export', () => {
  it('builds a package whose cards hold each word’s real derived form', async () => {
    const d = emptyProject('T');
    const v = c.savePos(d, null, 'Verb', 'v');
    const r = c.saveRule(d, null, { name: 'Nominal', kind: 'derivational', branches: [{ conditions: [], operations: [{ type: 'suffix', affix: 'a' }] }], posIds: [], bindings: {}, inputPosId: v, outputPosId: v, outputIntrinsic: {}, autoApply: false });
    const kal = c.addWord(d, { phonemic: 'kal', posId: v, meaning: 'run <fast>' });
    const child = c.promoteDerivation(d, kal, r, 'runner');
    const bytes = await buildApkg('Deck', ankiEntries(new LanguageEngine(d), [kal, child]), locateFile);
    const files = unzipSync(bytes);
    expect(Object.keys(files).sort()).toEqual(['collection.anki21', 'media']);
    expect(isSqliteFile(files['collection.anki21'])).toBe(true);
    const SQL = await initSqlJs({ locateFile });
    const db = new SQL.Database(files['collection.anki21']);
    const rows = db.exec('SELECT flds FROM notes ORDER BY id')[0].values.map((v) => String(v[0]).split('\x1f'));
    expect(rows[0][1]).toBe('run &lt;fast&gt;');
    expect(rows[1][0]).toBe('kala');
    expect(rows[1][3]).toContain('Derived from [kal] via [Nominal]');
    expect(db.exec('SELECT count(*) FROM cards')[0].values[0][0]).toBe(2);
  });
});

describe('legacy project import', () => {
  it('converts a SQLite project end to end', async () => {
    const SQL = await initSqlJs({ locateFile });
    const db = new SQL.Database();
    db.run(`
      CREATE TABLE phonemes (id INT, symbol TEXT, type TEXT, manner TEXT, place TEXT, voicing TEXT, height TEXT, backness TEXT, rounded INT);
      INSERT INTO phonemes VALUES (1,'k','consonant','plosive','velar','voiceless',NULL,NULL,NULL),(2,'a','vowel',NULL,NULL,NULL,'open','front',0),(3,'θ','consonant',NULL,NULL,NULL,NULL,NULL,NULL);
      CREATE TABLE romanization_mappings (id INT, ipa_symbol TEXT, latin_mapping TEXT);
      INSERT INTO romanization_mappings VALUES (1,'k','k'),(2,'a','a'),(3,'θ','th');
      CREATE TABLE parts_of_speech (id INT, name TEXT, abbreviation TEXT);
      INSERT INTO parts_of_speech VALUES (1,'Noun','N'),(2,'Verb','V');
      CREATE TABLE dimensions (id INT, pos_id INT, name TEXT, ordering INT, levels_json TEXT, template_id TEXT, intrinsic INT, abbreviation TEXT);
      INSERT INTO dimensions VALUES (5,1,'Number',0,'[{"id":1,"name":"Sg","abbr":"sg","ordering":0},{"id":2,"name":"Pl","abbr":"pl","ordering":1}]',NULL,0,NULL);
      CREATE TABLE morphological_rules (id INT, name TEXT, source TEXT, ordering INT, is_active INT, pos_id INT, pos_ids TEXT, kind TEXT, feature_bindings TEXT, input_pos_id INT, output_pos_id INT, auto_apply INT);
      INSERT INTO morphological_rules VALUES (1,'Agent','+θa',0,1,NULL,'','derivational','{"pos":[2]}',2,1,0),(2,'Plural','+ka',1,1,NULL,'','inflectional','{"pos":[1],"5":2}',1,NULL,0),(3,'Broken','???',2,1,NULL,'','derivational','{}',2,2,0);
      CREATE TABLE inflectional_rule_pos (rule_id INT, pos_id INT);
      INSERT INTO inflectional_rule_pos VALUES (2,1);
      CREATE TABLE lexemes (id INT, ipa TEXT, root_id TEXT, rule_ids TEXT, computed_form TEXT, romanization TEXT, meaning TEXT, part_of_speech TEXT, is_phonological_exception INT, skipped_dimensions_json TEXT, derived_from_lexeme_id INT, derived_via_rule_id INT, root_only_via_derivations INT, intrinsic_levels_json TEXT, is_closed_class INT, gloss_tag TEXT);
      INSERT INTO lexemes VALUES (1,'ka',NULL,NULL,NULL,'ka','do','verb',0,NULL,NULL,NULL,0,NULL,0,NULL),(2,'ka',NULL,NULL,NULL,NULL,'doer','Noun',0,NULL,1,1,0,NULL,0,NULL);
      CREATE TABLE project_settings (id INT, key TEXT, value TEXT);
      INSERT INTO project_settings VALUES (1,'typology.alignment','erg_abs'),(2,'typology.paradigm_axes.1','{"rows":5,"tabs":[]}');
    `);
    const legacy = await openLegacyDatabase(db.export(), { locateFile });
    const { doc, warnings } = importLegacyProject(legacy, 'Old');
    legacy.close();
    const e = new LanguageEngine(doc);
    // The placeholder IPA stored on the derived row is not carried over.
    expect(doc.lexemes[1].form).toEqual({ kind: 'derived', parentId: 1, ruleId: 1 });
    expect(e.form(2)).toMatchObject({ phonemic: 'kaθa', roman: 'katha', origin: 'derived' });
    expect(doc.lexemes[0].posId).toBe(2);
    expect(doc.settings.typology.alignment).toBe('erg_abs');
    expect(doc.settings.paradigmAxes[1].rows).toBe(5);
    expect([...e.paradigm(2).cells.values()].some((x) => x.kind === 'filled' && x.phonemic === 'kaθaka')).toBe(true);
    expect(doc.rules.find((r) => r.name === 'Broken')).toMatchObject({ active: false, branches: [] });
    expect(warnings[0]).toContain('Broken');
    expect(doc.nextId).toBeGreaterThan(5);
  });
  it('applies the particle migration to imported projects', async () => {
    const SQL = await initSqlJs({ locateFile });
    const db = new SQL.Database();
    db.run(`
      CREATE TABLE parts_of_speech (id INT, name TEXT, abbreviation TEXT);
      INSERT INTO parts_of_speech VALUES (1,'Verb','v');
      CREATE TABLE lexemes (id INT, ipa TEXT, root_id TEXT, rule_ids TEXT, computed_form TEXT, romanization TEXT, meaning TEXT, part_of_speech TEXT, is_phonological_exception INT, skipped_dimensions_json TEXT, derived_from_lexeme_id INT, derived_via_rule_id INT, root_only_via_derivations INT, intrinsic_levels_json TEXT, is_closed_class INT, gloss_tag TEXT);
      INSERT INTO lexemes VALUES (11,'al',NULL,NULL,NULL,NULL,'to',NULL,0,NULL,NULL,NULL,0,NULL,1,'PREP'),(12,'dur',NULL,NULL,NULL,NULL,'to go','Verb',0,NULL,NULL,NULL,0,NULL,1,'PERF'),(13,'mo',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,0,NULL,1,'NEG');
      CREATE TABLE phrase_constructions (id INT, name TEXT, ordering INT);
      INSERT INTO phrase_constructions VALUES (20,'Perfect',0),(21,'Future',1),(22,'Negation',2);
      CREATE TABLE construction_slots (id INT, construction_id INT, slot_type TEXT, slot_value TEXT, ordering INT, label TEXT);
      INSERT INTO construction_slots VALUES (30,20,'gloss_tag','PERF',0,NULL),(31,20,'pos','v',1,NULL),(32,21,'gloss_tag','FUT',0,NULL),(33,22,'gloss_tag','NEG',0,NULL),(34,22,'pos','nope',1,NULL);
    `);
    const legacy = await openLegacyDatabase(db.export(), { locateFile });
    const { doc, warnings } = importLegacyProject(legacy, 'Old');
    legacy.close();
    const word = (id: number) => doc.lexemes.find((l) => l.id === id)!;
    expect(word(11)).toMatchObject({ meaning: 'to', glossTag: null, posId: null });
    expect(word(12)).toMatchObject({ meaning: 'to go', glossTag: null, posId: 1 });
    expect(word(13)).toMatchObject({ meaning: null, glossTag: 'NEG' });
    expect(doc.partsOfSpeech.find((p) => p.id === word(13).posId)).toMatchObject({ name: 'Particle', abbr: 'p' });
    expect(doc.constructions[0].slots).toEqual([{ id: 30, type: 'word', lexemeId: 12, glossTag: 'PERF' }, { id: 31, type: 'pos', posId: 1 }]);
    expect(doc.constructions[1].slots[0]).toMatchObject({ type: 'word', missing: 'FUT' });
    expect(doc.constructions[2].slots[1]).toMatchObject({ type: 'pos', missing: 'nope' });
    expect(warnings.join('\n')).toContain('PREP was dropped');
    expect(warnings.join('\n')).toContain('no word has the tag FUT');
    expect(warnings.join('\n')).toContain('nope is not a part of speech');
    expect(doc.nextId).toBeGreaterThan(Math.max(...doc.partsOfSpeech.map((p) => p.id)));
  });
  it('recognizes SQLite files', () => {
    expect(isSqliteFile(new TextEncoder().encode('SQLite format 3\0'))).toBe(true);
    expect(isSqliteFile(new TextEncoder().encode('{"format"'))).toBe(false);
    expect(readFileSync(wasm).length).toBeGreaterThan(0);
  });
});
