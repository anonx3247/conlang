// MCP server for Conlang Workbench. Runs on the user's own machine over stdio
// and works directly on one project file, re-reading it on every call so edits
// made in the web app are always seen. The web app notices
// them within a couple of seconds. Nothing here touches the network.
//
//   node conlang-mcp.mjs --project /path/to/MyLanguage.conlang.json

import { existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import * as cmd from '../src/core/commands';
import { LanguageEngine, type ParadigmCell } from '../src/core/engine';
import { describeRewrite, describeSegments } from '../src/core/phonology';
import { isParticle, parseProjectReport, serializeProject, type Lexeme, type ProjectDoc } from '../src/core/types';
import glossary from '../src/data/glossary.json';
import swadesh from '../src/data/swadesh_list.json';

const argIndex = process.argv.indexOf('--project');
const projectPath = argIndex >= 0 ? process.argv[argIndex + 1] : process.env.CONLANG_PROJECT;
if (!projectPath) {
  console.error('Usage: conlang-mcp --project /path/to/MyLanguage.conlang.json');
  process.exit(1);
}
if (!existsSync(projectPath)) {
  console.error(`Project file not found: ${projectPath}`);
  process.exit(1);
}

// What upgrading the file changed, told once with the next tool result. Reading
// doesn't rewrite the file, so the same notes come back until something is saved.
const upgradeNotes = new Set<string>();
const toldNotes = new Set<string>();

function load(): ProjectDoc {
  const { doc, warnings } = parseProjectReport(readFileSync(projectPath!, 'utf8'));
  for (const w of warnings) if (!toldNotes.has(w)) upgradeNotes.add(w);
  return doc;
}

function engine() {
  return new LanguageEngine(load());
}

function change<T>(command: (d: ProjectDoc) => T): T {
  const { doc, result } = cmd.applyCommand(load(), command);
  // Overwritten in place so the browser's link to this file stays valid. The
  // backup covers a crash mid-write; the app retries if it reads a partial file.
  const text = serializeProject(doc);
  const backup = `${projectPath}.tmp-${process.pid}`;
  writeFileSync(backup, text);
  writeFileSync(projectPath!, text);
  rmSync(backup);
  return result;
}

function ok(value: unknown) {
  const content = [{ type: 'text' as const, text: JSON.stringify(value, null, 2) }];
  if (upgradeNotes.size) {
    content.push({ type: 'text' as const, text: `This project was upgraded to the current format. Tell the user:\n${[...upgradeNotes].join('\n')}` });
    upgradeNotes.forEach((n) => toldNotes.add(n));
    upgradeNotes.clear();
  }
  return { content };
}

/** Wraps a tool so a CommandError comes back as a readable tool error. */
function tool<A>(fn: (args: A) => unknown) {
  return async (args: A) => {
    try {
      return ok(fn(args));
    } catch (e) {
      if (e instanceof cmd.CommandError) return { isError: true, content: [{ type: 'text' as const, text: e.message }] };
      throw e;
    }
  };
}

function describeWord(e: LanguageEngine, l: Lexeme) {
  const f = e.form(l.id);
  return {
    id: l.id,
    form: f.label,
    phonemic: f.phonemic,
    phonetic: f.phonetic,
    romanization: f.roman,
    status: f.status,
    origin: f.origin,
    meaning: l.meaning ?? null,
    partOfSpeech: e.pos(l.posId)?.name ?? null,
    derivedVia: f.chain.map((c) => c.rule.name),
    glossTag: l.glossTag ?? null,
    particle: isParticle(l),
    ...(f.reason ? { problem: f.reason } : {}),
  };
}

function describeCell(e: LanguageEngine, c: ParadigmCell) {
  const features = Object.fromEntries(
    Object.entries(c.features).map(([dimId, levelId]) => {
      const d = e.doc.dimensions.find((x) => x.id === Number(dimId));
      return [d?.name ?? dimId, d?.levels.find((l) => l.id === levelId)?.name ?? levelId];
    }),
  );
  switch (c.kind) {
    case 'filled':
      return { features, kind: c.kind, romanization: c.roman, phonetic: c.phonetic, rules: c.rules.map((r) => r.name), ...(c.partial ? { partial: true } : {}) };
    case 'unmarked':
    case 'override':
      return { features, kind: c.kind, romanization: c.roman, phonetic: c.phonetic };
    case 'uncovered':
      return { features, kind: c.kind, reason: c.reason };
    case 'ambiguous':
      return { features, kind: c.kind, tiedRules: c.rules.map((r) => r.name) };
  }
}

function requirePos(e: LanguageEngine, name: string | undefined): number | null {
  if (!name) return null;
  const n = name.trim().toLowerCase();
  const p = e.doc.partsOfSpeech.find((x) => x.name.toLowerCase() === n) ?? e.doc.partsOfSpeech.find((x) => x.abbr.toLowerCase() === n);
  if (!p) throw new cmd.CommandError(`Unknown part of speech "${name}". Known: ${e.doc.partsOfSpeech.map((x) => x.name).join(', ')}`);
  return p.id;
}

const server = new McpServer({ name: 'conlang-workbench', version: '1.0.0' });

// ---------------------------------------------------------------------------
// Read tools
// ---------------------------------------------------------------------------

server.tool('get_project_overview', 'Summary of the language: name, counts, typology and how complete it is.', {}, tool(() => {
  const e = engine();
  const d = e.doc;
  const index = e.meaningIndex();
  return {
    name: d.name,
    updatedAt: d.updatedAt,
    counts: { phonemes: d.phonemes.length, words: d.lexemes.length, partsOfSpeech: d.partsOfSpeech.length, rules: d.rules.length, constructions: d.constructions.length, phrases: d.phrases.length },
    typology: d.settings.typology,
    swadeshCoverage: `${swadesh.filter((s) => index.has(s.concept.toLowerCase())).length}/${swadesh.length}`,
  };
}));

server.tool('get_phoneme_inventory', 'All phonemes with features, natural classes and romanization.', {}, tool(() => {
  const e = engine();
  const d = e.doc;
  return {
    phonemes: d.phonemes.map(({ id, ...p }) => ({ ...p, romanization: e.romanize(p.symbol), allophones: e.allophones(p.symbol).map((a) => a.output) })),
    naturalClasses: d.naturalClasses.map((c) => ({ name: c.name, members: c.phonemeIds.map((id) => d.phonemes.find((p) => p.id === id)?.symbol).filter(Boolean) })),
    romanizationEnabled: d.settings.romanizationEnabled,
    romanization: d.romanization.map((m) => ({ phoneme: m.phoneme, latin: m.latin })),
  };
}));

server.tool('get_phonotactics', 'Syllable templates, forbidden sequences, gemination limits and rewrite rules.', {}, tool(() => {
  const d = load();
  return {
    templates: d.templates.map((t) => ({ pattern: describeSegments(t.segments), active: t.active, description: t.description })),
    constraints: d.constraints.map((c) => (c.kind === 'gemination' ? { kind: c.kind, positions: c.positions, active: c.active } : { kind: c.kind, pattern: describeSegments(c.segments), position: c.position, active: c.active, description: c.description })),
    rewriteRules: d.rewriteRules.map((r) => describeRewrite(r)),
  };
}));

server.tool('search_lexicon', 'Finds words by form or meaning, optionally within one part of speech. Results show each word as it actually surfaces.', {
  query: z.string().default('').describe('Text in any of romanization, IPA or meaning; empty lists everything'),
  partOfSpeech: z.string().optional(),
  limit: z.number().int().positive().max(500).default(50),
}, tool(({ query, partOfSpeech, limit }: { query: string; partOfSpeech?: string; limit: number }) => {
  const e = engine();
  const pos = requirePos(e, partOfSpeech);
  const hits = e.wordList(query, new Set(pos === null ? [] : [pos]));
  return { total: hits.length, words: hits.slice(0, limit).map((h) => describeWord(e, h.lexeme)) };
}));

const wordRef = { word: z.string().describe('A word id, or its form or meaning') };

function findWord(e: LanguageEngine, ref: string): Lexeme {
  const id = Number(ref);
  if (Number.isInteger(id) && e.lexeme(id)) return e.lexeme(id)!;
  const low = ref.toLowerCase();
  const hit = e.allWords().filter((l) => {
    const f = e.form(l.id);
    return f.roman.toLowerCase() === low || f.phonemic === ref || f.phonetic === ref;
  });
  const hits = hit.length ? hit : e.allWords().filter((l) => e.lexeme(l.id)?.meaning?.toLowerCase() === low);
  if (!hits.length) throw new cmd.CommandError(`No word matches "${ref}".`);
  if (hits.length > 1) throw new cmd.CommandError(`"${ref}" is ambiguous; use one of these ids: ${hits.map((l) => l.id).join(', ')}`);
  return hits[0];
}

server.tool('get_word', 'Full details of a word: forms, etymology, available derivations, violations.', wordRef, tool(({ word }: { word: string }) => {
  const e = engine();
  const l = findWord(e, word);
  return {
    ...describeWord(e, l),
    violations: e.wordViolations(l.id).map((v) => v.description),
    isPhonotacticException: l.isException,
    parents: e.doc.parents.filter((p) => p.childId === l.id).map((p) => ({ word: e.form(p.parentId).label, relationship: p.relationship })),
    children: e.childrenOf(l.id).map((c) => ({ id: c.lexeme.id, word: e.form(c.lexeme.id).label, relation: c.edgeLabel })),
    derivations: e.derivationOptions(l.id).map((o) => ({ rule: o.rule.name, form: o.label, phonetic: o.phonetic, inDictionary: !!o.child })),
    constructions: e.constructionsForWord(l).map((c) => ({ name: c.name, slots: e.constructionFormula(c), phrase: e.fillConstruction(c, l).map((p) => p.text).join(' ') })),
    slotsIn: cmd.constructionsUsingWord(e.doc, l.id).map((c) => c.name),
  };
}));

server.tool('get_paradigm_table', "A word's complete inflection table, including manual overrides.", wordRef, tool(({ word }: { word: string }) => {
  const e = engine();
  const l = findWord(e, word);
  const p = e.paradigm(l.id);
  if (p.reason) throw new cmd.CommandError(p.reason);
  return { word: e.form(l.id).label, dimensions: p.axes.map((d) => ({ name: d.name, levels: d.levels.map((x) => x.name) })), cells: [...p.cells.values()].map((c) => describeCell(e, c)) };
}));

server.tool('get_grammar', 'Parts of speech and their dimensions, plus particles and constructions.', {}, tool(() => {
  const e = engine();
  const d = e.doc;
  return {
    partsOfSpeech: d.partsOfSpeech.map((p) => ({
      name: p.name,
      abbreviation: p.abbr,
      dimensions: e.dimensionsForPos(p.id).map((x) => ({ name: x.name, intrinsic: x.intrinsic, levels: x.levels.map((l) => ({ name: l.name, abbreviation: l.abbr })) })),
    })),
    particles: e.particles().map((l) => describeWord(e, l)),
    constructions: d.constructions.map((c) => ({ name: c.name, slots: e.constructionFormula(c), example: e.fillConstruction(c).map((x) => x.text).join(' '), warnings: e.constructionWarnings(c) })),
    typology: d.settings.typology,
  };
}));

server.tool('list_morphology_rules', 'Every rule with its structured branches. Literal text in rules is phonemic.', {
  kind: z.enum(['inflectional', 'derivational']).optional(),
}, tool(({ kind }: { kind?: 'inflectional' | 'derivational' }) => {
  const e = engine();
  return e.doc.rules.filter((r) => !kind || r.kind === kind).sort((a, b) => a.order - b.order).map((r) => ({
    id: r.id,
    name: r.name,
    kind: r.kind,
    active: r.active,
    autoApply: r.autoApply,
    input: e.pos(r.inputPosId)?.name,
    output: e.pos(r.outputPosId)?.name,
    appliesTo: r.posIds.map((p) => e.pos(p)?.name),
    binds: e.levelAbbrs(r.bindings),
    branches: r.branches,
  }));
}));

server.tool('analyze_phrase', 'Parses a phrase into words with interlinear glosses, the construction each word belongs to, IPA and problems.', { text: z.string() }, tool(({ text }: { text: string }) => {
  const e = engine();
  const { tokens, constructions } = e.glossPhrase(text);
  return tokens.map((t, i) => ({
    token: t.raw,
    gloss: t.gloss ?? '?',
    known: t.matches.length > 0,
    otherReadings: t.otherReadings,
    construction: constructions.find((m) => i >= m.start && i < m.end)?.construction.name ?? null,
    ipa: t.phonetic,
    violations: t.violations.map((v) => v.description),
  }));
}));

server.tool('check_word', 'Tests a candidate word (romanized, or IPA if romanization is off) against the sound rules.', { word: z.string() }, tool(({ word }: { word: string }) => {
  const e = engine();
  const phonemic = e.toPhonemic(word);
  const phonetic = e.phonetic(phonemic);
  return { phonemic, phonetic, romanization: e.romanize(phonemic), unknownSounds: e.unknownPhonemesIn(phonemic), violations: e.violationsOf(phonetic).map((v) => v.description) };
}));

server.tool('generate_words', 'Generates new words that obey the syllable templates and constraints.', {
  count: z.number().int().positive().max(200).default(20),
  minSyllables: z.number().int().positive().default(1),
  maxSyllables: z.number().int().positive().default(3),
}, tool(({ count, minSyllables, maxSyllables }: { count: number; minSyllables: number; maxSyllables: number }) => {
  const e = engine();
  return e.generate(count, minSyllables, Math.max(minSyllables, maxSyllables)).map((w) => ({ form: e.labelFor(w), phonemic: w, phonetic: e.phonetic(w) }));
}));

server.tool('swadesh_coverage', 'Which Swadesh concepts have a word, and which are still missing.', {}, tool(() => {
  const e = engine();
  const index = e.meaningIndex();
  const missing = swadesh.filter((s) => !index.has(s.concept.toLowerCase()));
  return { covered: swadesh.length - missing.length, total: swadesh.length, missing: missing.map((s) => ({ concept: s.concept, category: s.category })) };
}));

server.tool('lookup_glossary', 'Looks up a linguistics term in the built-in glossary.', { query: z.string() }, tool(({ query }: { query: string }) => {
  const q = query.toLowerCase();
  return (glossary as { term: string; definition: string }[]).filter((g) => g.term.toLowerCase().includes(q) || g.definition.toLowerCase().includes(q)).slice(0, 10);
}));

// ---------------------------------------------------------------------------
// Write tools (same commands and validation as the app's own forms)
// ---------------------------------------------------------------------------

function describeChangedWord(id: number) {
  const e = engine();
  const l = e.lexeme(id)!;
  const shared = l.glossTag ? e.particlesWithTag(l.glossTag, id).map((x) => e.form(x.id).label) : [];
  return { ...describeWord(e, l), ...(shared.length ? { warning: `Other particles have the tag ${l.glossTag}: ${shared.join(', ')}` } : {}) };
}

server.tool('add_word', 'Adds a root word. Give romanization, or phonemic IPA, or both. Give a meaning for an ordinary word, or a gloss tag instead for a particle.', {
  romanization: z.string().optional(),
  ipa: z.string().optional(),
  meaning: z.string().optional(),
  glossTag: z.string().optional().describe('Makes this a particle, which glosses as the tag, such as NEG. Cannot be combined with meaning.'),
  partOfSpeech: z.string().optional().describe('A particle with none goes in the Particle part of speech'),
  intrinsicLevels: z.record(z.string()).optional().describe('Dimension name -> level name, for intrinsic dimensions such as gender'),
}, tool((a: { romanization?: string; ipa?: string; meaning?: string; glossTag?: string; partOfSpeech?: string; intrinsicLevels?: Record<string, string> }) => {
  const id = change((d) => {
    const e = new LanguageEngine(d);
    const posId = requirePos(e, a.partOfSpeech);
    const phonemic = a.ipa ?? (a.romanization ? e.deromanize(a.romanization) : '');
    const levels: Record<string, number> = {};
    for (const [dimName, levelName] of Object.entries(a.intrinsicLevels ?? {})) {
      const dim = e.dimensionsForPos(posId ?? -1).find((x) => x.name.toLowerCase() === dimName.toLowerCase());
      const level = dim?.levels.find((l) => l.name.toLowerCase() === levelName.toLowerCase());
      if (!dim || !level) throw new cmd.CommandError(`No level "${levelName}" on dimension "${dimName}".`);
      levels[dim.id] = level.id;
    }
    return cmd.addWord(d, { phonemic, roman: a.romanization ?? null, meaning: a.meaning, glossTag: a.glossTag, posId, intrinsicLevels: levels });
  });
  return describeChangedWord(id);
}));

server.tool('update_word', 'Edits a word. Changing the form of a rule-derived word unlinks it from its rule. Setting a gloss tag makes it a particle and clears its meaning; an empty gloss tag makes it an ordinary word again.', {
  ...wordRef,
  meaning: z.string().optional(),
  glossTag: z.string().optional(),
  ipa: z.string().optional(),
  partOfSpeech: z.string().optional(),
}, tool((a: { word: string; meaning?: string; glossTag?: string; ipa?: string; partOfSpeech?: string }) => {
  let id = 0;
  change((d) => {
    const e = new LanguageEngine(d);
    const l = findWord(e, a.word);
    id = l.id;
    const patch: Partial<cmd.WordInput> = {};
    if (a.meaning !== undefined) patch.meaning = a.meaning;
    if (a.glossTag !== undefined) {
      patch.glossTag = a.glossTag;
      if (a.glossTag.trim() && a.meaning === undefined) patch.meaning = null;
    }
    if (a.ipa !== undefined) patch.phonemic = a.ipa;
    if (a.partOfSpeech !== undefined) patch.posId = requirePos(e, a.partOfSpeech);
    cmd.updateWord(d, l.id, patch);
  });
  return describeChangedWord(id);
}));

server.tool('delete_word', 'Deletes a word. Words derived from it keep their current forms as standalone words, and construction slots using it are marked missing. Check get_word first: its slotsIn field lists those constructions.', wordRef, tool(({ word }: { word: string }) => {
  const affected = change((d) => {
    const { id } = findWord(new LanguageEngine(d), word);
    const names = cmd.constructionsUsingWord(d, id).map((c) => c.name);
    cmd.deleteWord(d, id);
    return names;
  });
  return { deleted: word, constructionsWithMissingSlot: affected };
}));

server.tool('derive_word', 'Adds the result of a derivational rule to the dictionary as a live word: it follows later edits to its parent and rule.', {
  ...wordRef,
  rule: z.string().describe('Rule name'),
  meaning: z.string().default(''),
}, tool(({ word, rule, meaning }: { word: string; rule: string; meaning: string }) => {
  const id = change((d) => {
    const e = new LanguageEngine(d);
    const parent = findWord(e, word);
    const r = d.rules.find((x) => x.name.toLowerCase() === rule.toLowerCase() && x.kind === 'derivational');
    if (!r) throw new cmd.CommandError(`No derivational rule named "${rule}".`);
    if (!e.derivationOptions(parent.id).some((o) => o.rule.id === r.id)) throw new cmd.CommandError(`Rule "${r.name}" does not apply to this word.`);
    return cmd.promoteDerivation(d, parent.id, r.id, meaning);
  });
  const e = engine();
  return describeWord(e, e.lexeme(id)!);
}));

const segmentSchema = z.union([
  z.object({ kind: z.literal('class'), name: z.string(), optional: z.boolean().optional() }),
  z.object({ kind: z.literal('sound'), text: z.string(), optional: z.boolean().optional() }),
]);
const operationSchema = z.union([
  z.object({ type: z.literal('prefix'), affix: z.string() }),
  z.object({ type: z.literal('suffix'), affix: z.string() }),
  z.object({ type: z.literal('infix'), affix: z.string(), afterConsonant: z.number().int().positive() }),
  z.object({
    type: z.literal('replace'),
    from: z.union([z.object({ kind: z.literal('class'), name: z.string() }), z.object({ kind: z.literal('sound'), text: z.string() })]),
    to: z.string(),
    count: z.number().int().positive().nullable().default(null),
    direction: z.enum(['fromStart', 'fromEnd']).default('fromStart'),
  }),
  z.object({ type: z.literal('template'), parts: z.array(z.union([z.object({ kind: z.literal('slot'), index: z.number().int().min(1).max(9) }), z.object({ kind: z.literal('sound'), text: z.string() })])) }),
  z.object({ type: z.literal('reduplicate'), scope: z.enum(['full', 'CV', 'C']), position: z.enum(['prefix', 'suffix']) }),
  z.object({ type: z.literal('elongate'), target: z.enum(['vowel', 'consonant']).describe('vowel: lengthen with ː. consonant: geminate'), index: z.union([z.literal(1), z.literal(2), z.literal(3)]).describe('Which one: first, second or third, counting only that kind of sound'), direction: z.enum(['fromStart', 'fromEnd']).default('fromStart') }),
  z.object({ type: z.literal('suppletive'), form: z.string() }),
  z.object({ type: z.literal('removeSuffix'), suffix: z.string() }),
]);
const branchSchema = z.object({
  conditions: z.array(z.object({ position: z.enum(['startsWith', 'endsWith', 'contains']), segments: z.array(segmentSchema) })).default([]),
  operations: z.array(operationSchema).min(1),
});

server.tool('add_derivational_rule', 'Creates a derivational rule from structured branches. First branch whose conditions all hold wins; literal text is phonemic.', {
  name: z.string(),
  inputPartOfSpeech: z.string(),
  outputPartOfSpeech: z.string(),
  branches: z.array(branchSchema).min(1),
  autoApply: z.boolean().default(false),
}, tool((a: { name: string; inputPartOfSpeech: string; outputPartOfSpeech: string; branches: z.infer<typeof branchSchema>[]; autoApply: boolean }) => {
  const id = change((d) => {
    const e = new LanguageEngine(d);
    return cmd.saveRule(d, null, { name: a.name, kind: 'derivational', branches: a.branches, posIds: [], bindings: {}, inputPosId: requirePos(e, a.inputPartOfSpeech), outputPosId: requirePos(e, a.outputPartOfSpeech), outputIntrinsic: {}, autoApply: a.autoApply });
  });
  return { id, name: a.name };
}));

server.tool('add_inflectional_rule', 'Creates an inflectional rule bound to dimension levels, such as Number=Plural.', {
  name: z.string(),
  partsOfSpeech: z.array(z.string()).min(1),
  features: z.record(z.string()).describe('Dimension name -> level name'),
  branches: z.array(branchSchema).min(1),
}, tool((a: { name: string; partsOfSpeech: string[]; features: Record<string, string>; branches: z.infer<typeof branchSchema>[] }) => {
  const id = change((d) => {
    const e = new LanguageEngine(d);
    const posIds = a.partsOfSpeech.map((p) => requirePos(e, p)!);
    const bindings: Record<string, number> = {};
    for (const [dimName, levelName] of Object.entries(a.features)) {
      const dim = e.dimensionsForPos(posIds[0]).find((x) => x.name.toLowerCase() === dimName.toLowerCase());
      const level = dim?.levels.find((l) => l.name.toLowerCase() === levelName.toLowerCase() || l.abbr.toLowerCase() === levelName.toLowerCase());
      if (!dim || !level) throw new cmd.CommandError(`No level "${levelName}" on dimension "${dimName}" of ${a.partsOfSpeech[0]}.`);
      bindings[dim.id] = level.id;
    }
    return cmd.saveRule(d, null, { name: a.name, kind: 'inflectional', branches: a.branches, posIds, bindings, inputPosId: null, outputPosId: null, outputIntrinsic: {}, autoApply: false });
  });
  return { id, name: a.name };
}));

server.tool('add_phoneme', 'Adds a phoneme; features are filled in when the symbol is on the IPA chart. Optionally sets its romanization.', {
  symbol: z.string(),
  type: z.enum(['consonant', 'vowel']).optional(),
  romanization: z.string().optional(),
}, tool((a: { symbol: string; type?: 'consonant' | 'vowel'; romanization?: string }) => {
  change((d) => {
    if (d.phonemes.some((p) => p.symbol === a.symbol)) throw new cmd.CommandError(`/${a.symbol}/ is already in the inventory.`);
    const known = cmd.featuresForSymbol(a.symbol);
    const input = known ?? { symbol: a.symbol, type: a.type ?? 'consonant' };
    if (a.romanization) cmd.saveRomanization(d, null, a.symbol, a.romanization);
    if (!d.phonemes.some((p) => p.symbol === a.symbol)) cmd.addPhoneme(d, input);
  });
  return { added: a.symbol };
}));

const slotFormSchema = z.record(z.string()).optional().describe('Dimension name -> level name. Only what matters: dimensions left out accept any level.');

server.tool('add_construction', 'Creates a construction. It needs at least one word slot, because a fixed word is what makes it recognizable. A phrase or clause slot takes every word up to the next fixed word or the end of the phrase.', {
  name: z.string(),
  slots: z.array(z.union([
    z.object({ type: z.literal('word'), word: z.string(), glossTag: z.string().optional(), form: slotFormSchema }),
    z.object({ type: z.literal('pos'), partOfSpeech: z.string(), glossTag: z.string().optional(), form: slotFormSchema }),
    z.object({ type: z.enum(['phrase', 'clause']), label: z.string().optional() }),
  ])).min(1),
}, tool((a: { name: string; slots: ({ type: 'word'; word: string; glossTag?: string; form?: Record<string, string> } | { type: 'pos'; partOfSpeech: string; glossTag?: string; form?: Record<string, string> } | { type: 'phrase' | 'clause'; label?: string })[] }) => {
  const id = change((d) => {
    const e = new LanguageEngine(d);
    const features = (dims: ReturnType<LanguageEngine['slotDimensions']>, form: Record<string, string> = {}) => {
      const out: Record<string, number> = {};
      for (const [dimName, levelName] of Object.entries(form)) {
        const dim = dims.find((x) => x.name.toLowerCase() === dimName.toLowerCase());
        const level = dim?.levels.find((l) => l.name.toLowerCase() === levelName.toLowerCase() || l.abbr.toLowerCase() === levelName.toLowerCase());
        if (!dim || !level) throw new cmd.CommandError(`No level "${levelName}" on dimension "${dimName}".`);
        out[dim.id] = level.id;
      }
      return out;
    };
    const cid = cmd.addConstruction(d, a.name.trim());
    for (const s of a.slots) {
      if (s.type === 'word') {
        const lexemeId = findWord(e, s.word).id;
        cmd.addSlot(d, cid, { type: 'word', lexemeId, glossTag: s.glossTag, features: features(e.slotDimensions({ type: 'word', lexemeId }), s.form) });
      } else if (s.type === 'pos') {
        const posId = requirePos(e, s.partOfSpeech)!;
        cmd.addSlot(d, cid, { type: 'pos', posId, glossTag: s.glossTag, features: features(e.slotDimensions({ type: 'pos', posId }), s.form) });
      } else {
        cmd.addSlot(d, cid, { type: 'phrase', kind: s.type, label: s.label });
      }
    }
    return cid;
  });
  const e = engine();
  const c = e.doc.constructions.find((x) => x.id === id)!;
  return { id, name: c.name, slots: e.constructionFormula(c), warnings: e.constructionWarnings(c) };
}));

server.tool('add_phrase', 'Saves a phrase to the scratchpad, with an optional free translation.', {
  text: z.string(),
  translation: z.string().optional(),
}, tool((a: { text: string; translation?: string }) => {
  const id = change((d) => {
    const pid = cmd.createPhrase(d);
    cmd.updatePhrase(d, pid, { text: a.text, translation: a.translation ?? null });
    return pid;
  });
  return { id };
}));

await server.connect(new StdioServerTransport());
