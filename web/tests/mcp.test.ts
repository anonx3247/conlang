import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import * as c from '../src/core/commands';
import { emptyProject, parseProject, serializeProject } from '../src/core/types';

const dir = mkdtempSync(join(tmpdir(), 'conlang-mcp-'));
const file = join(dir, 'Test.conlang.json');
let client: Client;

async function call(name: string, args: Record<string, unknown> = {}) {
  const r = (await client.callTool({ name, arguments: args })) as { isError?: boolean; content: { text: string }[] };
  if (r.isError) throw new Error(r.content[0].text);
  return JSON.parse(r.content[0].text);
}

beforeAll(async () => {
  const d = emptyProject('Test');
  for (const s of ['k', 'l', 't']) c.addPhoneme(d, { symbol: s, type: 'consonant' });
  for (const s of ['a', 'o']) c.addPhoneme(d, { symbol: s, type: 'vowel' });
  c.saveTemplate(d, null, [{ kind: 'class', name: 'C' }, { kind: 'class', name: 'V' }], '');
  const v = c.savePos(d, null, 'Verb', 'v');
  const n = c.savePos(d, null, 'Noun', 'n');
  const num = c.addDimension(d, n, 'Number', [{ name: 'Singular', abbr: 'sg' }, { name: 'Plural', abbr: 'pl' }], null);
  c.saveRule(d, null, { name: 'Plural', kind: 'inflectional', branches: [{ conditions: [], operations: [{ type: 'suffix', affix: 't' }] }], posIds: [n], bindings: { [num]: 2 }, inputPosId: null, outputPosId: null, outputIntrinsic: {}, autoApply: false });
  c.saveRule(d, null, { name: 'Nominal', kind: 'derivational', branches: [{ conditions: [], operations: [{ type: 'suffix', affix: 'a' }] }], posIds: [], bindings: {}, inputPosId: v, outputPosId: n, outputIntrinsic: {}, autoApply: false });
  c.addWord(d, { phonemic: 'kal', posId: v, meaning: 'to run' });
  writeFileSync(file, serializeProject(d));
  client = new Client({ name: 'test', version: '1.0.0' });
  await client.connect(new StdioClientTransport({ command: 'npx', args: ['tsx', 'mcp/server.ts', '--project', file] }));
}, 30000);

afterAll(async () => {
  await client?.close();
});

describe('MCP server', () => {
  it('lists its tools', async () => {
    const { tools } = await client.listTools();
    const names = tools.map((t) => t.name);
    for (const n of ['search_lexicon', 'get_paradigm_table', 'get_phoneme_inventory', 'get_grammar', 'list_morphology_rules', 'analyze_phrase', 'add_word', 'derive_word']) expect(names).toContain(n);
  });
  it('reads the language', async () => {
    expect(await call('get_project_overview')).toMatchObject({ name: 'Test', counts: { words: 1, phonemes: 5 } });
    expect((await call('search_lexicon', { query: 'run' })).words[0]).toMatchObject({ form: 'kal', partOfSpeech: 'Verb' });
    expect((await call('get_word', { word: 'kal' })).derivations[0]).toMatchObject({ rule: 'Nominal', form: 'kala' });
    expect((await call('generate_words', { count: 3 })).length).toBeGreaterThan(0);
  });
  it('derives through the shared engine and saves to the file', async () => {
    const noun = await call('derive_word', { word: 'kal', rule: 'Nominal', meaning: 'runner' });
    expect(noun).toMatchObject({ form: 'kala', origin: 'derived', partOfSpeech: 'Noun', derivedVia: ['Nominal'] });
    const table = await call('get_paradigm_table', { word: 'kala' });
    expect(table.cells.find((x: { kind: string }) => x.kind === 'filled').romanization).toBe('kalat');
    const stored = parseProject(readFileSync(file, 'utf8')).lexemes.find((l) => l.id === noun.id)!;
    expect(stored.form.kind).toBe('derived');
    expect(JSON.stringify(stored.form)).not.toContain('kala');
  });
  it('sees edits made to the file by the web app', async () => {
    const d = parseProject(readFileSync(file, 'utf8'));
    c.addWord(d, { phonemic: 'tol', posId: d.partsOfSpeech[1].id, meaning: 'river' });
    writeFileSync(file, serializeProject(d));
    expect((await call('search_lexicon', { query: 'river' })).total).toBe(1);
  });
  it('analyzes phrases and writes phrases', async () => {
    const tokens = await call('analyze_phrase', { text: 'kala kalat zzz' });
    expect(tokens.map((t: { gloss: string }) => t.gloss)).toEqual(['runner', 'runner.PL', '?']);
    await call('add_phrase', { text: 'kala', translation: 'a runner' });
    expect(parseProject(readFileSync(file, 'utf8')).phrases[0]).toMatchObject({ text: 'kala', translation: 'a runner' });
  });
  it('adds particles and constructions, and analyzes phrases with them', async () => {
    const mo = await call('add_word', { romanization: 'mo', glossTag: 'NEG' });
    expect(mo).toMatchObject({ glossTag: 'NEG', particle: true, meaning: null, partOfSpeech: 'Particle' });
    expect((await call('add_word', { romanization: 'to', glossTag: 'neg' })).warning).toContain('mo');
    await expect(call('add_word', { romanization: 'la', glossTag: 'X', meaning: 'y' })).rejects.toThrow('not both');
    const made = await call('add_construction', { name: 'Negation', slots: [{ type: 'word', word: 'mo' }, { type: 'pos', partOfSpeech: 'Verb' }] });
    expect(made).toMatchObject({ slots: 'mo + Verb', warnings: [] });
    await call('add_construction', { name: 'Past', slots: [{ type: 'word', word: 'kal', glossTag: 'PST' }, { type: 'clause', label: 'rest' }] });
    const tokens = await call('analyze_phrase', { text: 'mo kal' });
    expect(tokens.map((t: { gloss: string; construction: string }) => [t.gloss, t.construction])).toEqual([['NEG', 'Negation'], ['to run', 'Negation']]);
    expect((await call('analyze_phrase', { text: 'kal tol' })).map((t: { gloss: string }) => t.gloss)).toEqual(['PST', 'river']);
    const grammar = await call('get_grammar');
    expect(grammar.particles.map((p: { form: string }) => p.form)).toEqual(['mo', 'to']);
    expect(grammar.constructions[1]).toMatchObject({ name: 'Past', slots: 'kal [PST] + Clause: rest' });
    const loose = await call('add_construction', { name: 'Loose', slots: [{ type: 'pos', partOfSpeech: 'Verb' }] });
    expect(loose.warnings[0]).toContain('at least one Word slot');
    expect((await call('get_word', { word: 'mo' })).slotsIn).toEqual(['Negation']);
    expect((await call('delete_word', { word: 'mo' })).constructionsWithMissingSlot).toEqual(['Negation']);
    expect((await call('get_grammar')).constructions[0].warnings[0]).toContain('The word mo is missing');
    const flipped = await call('update_word', { word: 'to', glossTag: '', meaning: 'also' });
    expect(flipped).toMatchObject({ particle: false, meaning: 'also' });
    expect(await call('update_word', { word: 'also', glossTag: 'ADD' })).toMatchObject({ particle: true, meaning: null });
  });
  it('tells the caller once what upgrading an older file changed', async () => {
    const current = readFileSync(file, 'utf8');
    const old = JSON.parse(current);
    old.version = 1;
    old.lexemes.push({ id: 900, form: { kind: 'root', phonemic: 'al' }, meaning: 'to', posId: null, isException: false, rootOnly: false, isClosedClass: true, glossTag: 'PREP', skippedDimensionIds: [], intrinsicLevels: {} });
    old.constructions = [];
    writeFileSync(file, JSON.stringify(old));
    const first = (await client.callTool({ name: 'get_project_overview', arguments: {} })) as { content: { text: string }[] };
    expect(first.content[1].text).toContain('PREP was dropped');
    const second = (await client.callTool({ name: 'get_project_overview', arguments: {} })) as { content: { text: string }[] };
    expect(second.content).toHaveLength(1);
    writeFileSync(file, current);
  });
  it('adds a rule with an elongation', async () => {
    await call('add_derivational_rule', { name: 'Intensive', inputPartOfSpeech: 'Verb', outputPartOfSpeech: 'Verb', branches: [{ operations: [{ type: 'elongate', target: 'consonant', index: 1, direction: 'fromEnd' }] }] });
    const derivations = (await call('get_word', { word: 'kal' })).derivations as { rule: string; form: string }[];
    expect(derivations.find((x) => x.rule === 'Intensive')?.form).toBe('kall');
    await expect(call('add_derivational_rule', { name: 'Bad', inputPartOfSpeech: 'Verb', outputPartOfSpeech: 'Verb', branches: [{ operations: [{ type: 'elongate', target: 'vowel', index: 4 }] }] })).rejects.toThrow();
  });
  it('adds structured rules and reports validation problems as tool errors', async () => {
    await call('add_derivational_rule', { name: 'Dim', inputPartOfSpeech: 'Noun', outputPartOfSpeech: 'Noun', branches: [{ operations: [{ type: 'suffix', affix: 'o' }] }] });
    expect((await call('get_word', { word: 'kala' })).derivations[0].form).toBe('kalao');
    await expect(call('add_word', { romanization: 'zz', partOfSpeech: 'Nope' })).rejects.toThrow('Unknown part of speech');
    await expect(call('get_word', { word: 'missing' })).rejects.toThrow('No word matches');
  });
});
