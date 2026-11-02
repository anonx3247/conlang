import { describe, expect, it } from 'vitest';
import { ankiEntries } from '../src/core/anki';
import * as c from '../src/core/commands';
import { dynamicIdFor, LanguageEngine } from '../src/core/engine';
import { featureKey } from '../src/core/paradigm';
import { emptyProject, FORMAT_VERSION, parseProject, parseProjectReport, serializeProject } from '../src/core/types';
import type { Branch, ProjectDoc } from '../src/core/types';

const suffix = (a: string): Branch[] => [{ conditions: [], operations: [{ type: 'suffix', affix: a }] }];
const PRESENT = 1;
const PAST = 2;
const PARTICIPLE = 3;

function setup() {
  const d = emptyProject('T');
  const verb = c.savePos(d, null, 'Verb', 'v');
  const noun = c.savePos(d, null, 'Noun', 'n');
  const tense = c.addDimension(d, verb, 'Tense', [{ name: 'Present', abbr: 'prs' }, { name: 'Past', abbr: 'pst' }, { name: 'Past Participle', abbr: 'ptcp' }], null);
  const infl = (name: string, affix: string, level: number) => c.saveRule(d, null, { name, kind: 'inflectional', branches: suffix(affix), posIds: [verb], bindings: { [tense]: level }, inputPosId: null, outputPosId: null, outputIntrinsic: {}, autoApply: false });
  infl('Past', 'ed', PAST);
  infl('Participle', 'en', PARTICIPLE);
  c.saveMarker(d, null, [verb], 'Present', { [tense]: PRESENT });
  const have = c.addWord(d, { phonemic: 'hav', posId: verb, meaning: 'to have' });
  const run = c.addWord(d, { phonemic: 'run', posId: verb, meaning: 'to run' });
  const dog = c.addWord(d, { phonemic: 'dog', posId: noun, meaning: 'dog' });
  const and = c.addWord(d, { phonemic: 'and', posId: noun, meaning: 'and' });
  const that = c.addWord(d, { phonemic: 'zat', posId: noun, meaning: 'that' });
  const mo = c.addWord(d, { phonemic: 'mo', posId: null, glossTag: 'NEG' });
  return { d, verb, noun, tense, have, run, dog, and, that, mo };
}

function construction(d: ProjectDoc, name: string, slots: c.SlotInput[]) {
  const id = c.addConstruction(d, name);
  for (const s of slots) c.addSlot(d, id, s);
  return id;
}

const analyze = (d: ProjectDoc, text: string) => {
  const r = new LanguageEngine(d).glossPhrase(text);
  return { glosses: r.tokens.map((t) => t.gloss), found: r.constructions.map((m) => [m.construction.name, m.start, m.end]) };
};

describe('particles', () => {
  it('a particle glosses as its tag, and an ordinary word has no tag', () => {
    const { d, have, mo } = setup();
    const e = new LanguageEngine(d);
    expect(e.glossOf(e.lexeme(mo)!)).toBe('NEG');
    expect(e.glossOf(e.lexeme(have)!)).toBe('to have');
    expect(analyze(d, 'mo hav').glosses).toEqual(['NEG', 'to have']);
  });
  it('holds a tag or a meaning, never both, and can be flipped', () => {
    const { d, verb, have, mo } = setup();
    expect(() => c.addWord(d, { phonemic: 'x', posId: verb, meaning: 'm', glossTag: 'T' })).toThrow('not both');
    expect(() => c.updateWord(d, mo, { meaning: 'not' })).toThrow('not both');
    c.updateWord(d, mo, { glossTag: null, meaning: 'not' });
    expect(d.lexemes.find((l) => l.id === mo)).toMatchObject({ glossTag: null, meaning: 'not' });
    c.updateWord(d, have, { glossTag: 'AUX', meaning: null });
    expect(d.lexemes.find((l) => l.id === have)).toMatchObject({ glossTag: 'AUX', meaning: null });
  });
  it('goes in the Particle part of speech, abbreviated p, when none is chosen', () => {
    const { d, verb, mo } = setup();
    const particle = d.partsOfSpeech.find((p) => p.name === 'Particle')!;
    expect(particle.abbr).toBe('p');
    expect(d.lexemes.find((l) => l.id === mo)!.posId).toBe(particle.id);
    const other = c.addWord(d, { phonemic: 'lo', posId: null, glossTag: 'DEF' });
    expect(d.lexemes.find((l) => l.id === other)!.posId).toBe(particle.id);
    expect(d.partsOfSpeech.filter((p) => p.name === 'Particle')).toHaveLength(1);
    const chosen = c.addWord(d, { phonemic: 'ko', posId: verb, glossTag: 'AUX' });
    expect(d.lexemes.find((l) => l.id === chosen)!.posId).toBe(verb);
  });
  it('filters by the particles chip, adding up with part of speech chips, and finds tags in search', () => {
    const { d, noun } = setup();
    const e = new LanguageEngine(d);
    expect(e.wordList('', new Set(), false, true).map((w) => e.glossOf(w.lexeme))).toEqual(['NEG']);
    expect(e.wordList('', new Set([noun]), false, true)).toHaveLength(4);
    expect(e.wordList('neg', new Set()).map((w) => e.form(w.lexeme.id).label)).toEqual(['mo']);
  });
  it('a particle card in Anki shows its tag', () => {
    const { d, mo } = setup();
    expect(ankiEntries(new LanguageEngine(d), [mo])[0].meaning).toBe('NEG');
  });
  it('finds particles that share a tag, ignoring case', () => {
    const { d, mo } = setup();
    const other = c.addWord(d, { phonemic: 'nu', posId: null, glossTag: 'neg' });
    const e = new LanguageEngine(d);
    expect(e.particlesWithTag('NEG', mo).map((l) => l.id)).toEqual([other]);
    expect(e.particlesWithTag('FUT')).toEqual([]);
  });
  it('an automatic word cannot become gloss-only', () => {
    const { d, verb, noun, run } = setup();
    const rule = c.saveRule(d, null, { name: 'Agent', kind: 'derivational', branches: suffix('er'), posIds: [], bindings: {}, inputPosId: verb, outputPosId: noun, outputIntrinsic: {}, autoApply: true });
    expect(() => c.updateWord(d, dynamicIdFor(run, rule), { glossTag: 'AG' })).toThrow('gloss-only');
  });
});

describe('the constructions the user wants to work', () => {
  it('Past: have [PST] + Phrase', () => {
    const { d, have } = setup();
    construction(d, 'Past', [{ type: 'word', lexemeId: have, glossTag: 'PST' }, { type: 'phrase', kind: 'phrase' }]);
    expect(analyze(d, 'hav dog run')).toEqual({ glosses: ['PST', 'dog', 'to run'], found: [['Past', 0, 3]] });
  });
  it('Perfect: have [PERF] + Verb (Past Participle)', () => {
    const { d, have, verb, tense } = setup();
    construction(d, 'Perfect', [{ type: 'word', lexemeId: have, glossTag: 'PERF' }, { type: 'pos', posId: verb, features: { [tense]: PARTICIPLE } }]);
    expect(analyze(d, 'hav runen')).toEqual({ glosses: ['PERF', 'to run.PTCP'], found: [['Perfect', 0, 2]] });
    expect(analyze(d, 'hav runed')).toEqual({ glosses: ['to have', 'to run.PST'], found: [] });
    expect(analyze(d, 'hav dog').found).toEqual([]);
  });
  it('Present-only: have (Present) [PERF] + Phrase, where Present is an unmarked form', () => {
    const { d, have, tense } = setup();
    construction(d, 'Present only', [{ type: 'word', lexemeId: have, glossTag: 'PERF', features: { [tense]: PRESENT } }, { type: 'phrase', kind: 'phrase' }]);
    expect(analyze(d, 'hav dog')).toEqual({ glosses: ['PERF', 'dog'], found: [['Present only', 0, 2]] });
    expect(analyze(d, 'haved dog')).toEqual({ glosses: ['to have.PST', 'dog'], found: [] });
  });
  it('Negation: mo + Verb', () => {
    const { d, mo, verb } = setup();
    construction(d, 'Negation', [{ type: 'word', lexemeId: mo }, { type: 'pos', posId: verb }]);
    expect(analyze(d, 'mo run')).toEqual({ glosses: ['NEG', 'to run'], found: [['Negation', 0, 2]] });
    expect(analyze(d, 'mo runed')).toEqual({ glosses: ['NEG', 'to run.PST'], found: [['Negation', 0, 2]] });
    expect(analyze(d, 'mo dog')).toEqual({ glosses: ['NEG', 'dog'], found: [] });
  });
  it('Coordination: Phrase + and [CONJ] + Phrase', () => {
    const { d, and } = setup();
    construction(d, 'Coordination', [{ type: 'phrase', kind: 'phrase' }, { type: 'word', lexemeId: and, glossTag: 'CONJ' }, { type: 'phrase', kind: 'phrase' }]);
    expect(analyze(d, 'dog run and run dog')).toEqual({ glosses: ['dog', 'to run', 'CONJ', 'to run', 'dog'], found: [['Coordination', 0, 5]] });
    expect(analyze(d, 'and dog').found).toEqual([]);
    expect(analyze(d, 'dog and').found).toEqual([]);
  });
  it('a phrase slot stops at the first fixed word, and the last one takes the rest', () => {
    const { d, and } = setup();
    construction(d, 'Coordination', [{ type: 'phrase', kind: 'phrase' }, { type: 'word', lexemeId: and, glossTag: 'CONJ' }, { type: 'phrase', kind: 'phrase' }]);
    expect(analyze(d, 'dog and run and dog').glosses).toEqual(['dog', 'CONJ', 'to run', 'and', 'dog']);
  });
  it('Subjunctive: that [SBJV] + Clause', () => {
    const { d, that } = setup();
    construction(d, 'Subjunctive', [{ type: 'word', lexemeId: that, glossTag: 'SBJV' }, { type: 'phrase', kind: 'clause', label: 'subjunctive clause' }]);
    expect(analyze(d, 'dog zat dog run')).toEqual({ glosses: ['dog', 'SBJV', 'dog', 'to run'], found: [['Subjunctive', 1, 4]] });
  });
});

describe('construction matching', () => {
  it('a word glosses as its tag only inside a match', () => {
    const { d, have } = setup();
    construction(d, 'Past', [{ type: 'word', lexemeId: have, glossTag: 'PST' }, { type: 'phrase', kind: 'phrase' }]);
    expect(analyze(d, 'hav').glosses).toEqual(['to have']);
    expect(analyze(d, 'hav dog').glosses).toEqual(['PST', 'dog']);
    expect(analyze(d, 'dog hav').glosses).toEqual(['dog', 'to have']);
    // Inside a phrase slot another word stays itself, and so does a second have.
    expect(analyze(d, 'hav hav').glosses).toEqual(['PST', 'to have']);
  });
  it('a tag replacing the chosen reading is not an alternative, but a real homophone is', () => {
    const { d, have, noun } = setup();
    construction(d, 'Past', [{ type: 'word', lexemeId: have, glossTag: 'PST' }, { type: 'phrase', kind: 'phrase' }]);
    const others = (text: string) => new LanguageEngine(d).glossPhrase(text).tokens[0].otherReadings;
    expect(others('hav dog')).toEqual([]);
    c.addWord(d, { phonemic: 'hav', posId: noun, meaning: 'harbor' });
    expect(others('hav dog')).toEqual(['harbor']);
    expect(others('hav')).toEqual(['harbor']);
  });
  it('the same word separates into constructions by form, each with its own tag', () => {
    const { d, have, tense } = setup();
    construction(d, 'Present', [{ type: 'word', lexemeId: have, glossTag: 'PERF', features: { [tense]: PRESENT } }, { type: 'phrase', kind: 'phrase' }]);
    construction(d, 'Past', [{ type: 'word', lexemeId: have, glossTag: 'PLUP', features: { [tense]: PAST } }, { type: 'phrase', kind: 'phrase' }]);
    expect(analyze(d, 'hav dog').glosses).toEqual(['PERF', 'dog']);
    expect(analyze(d, 'haved dog').glosses).toEqual(['PLUP', 'dog']);
  });
  it('form restrictions read the paradigm, so an override counts and the form it replaced does not', () => {
    const { d, have, tense } = setup();
    c.saveCellOverride(d, have, { [tense]: PAST }, 'hud', null);
    construction(d, 'Past', [{ type: 'word', lexemeId: have, glossTag: 'PST', features: { [tense]: PAST } }, { type: 'phrase', kind: 'phrase' }]);
    expect(new LanguageEngine(d).paradigm(have).cells.get(featureKey({ [tense]: PAST }))?.kind).toBe('override');
    expect(analyze(d, 'hud dog').found).toEqual([['Past', 0, 2]]);
    expect(analyze(d, 'haved dog').found).toEqual([]);
  });
  it('an override identical to the bare word still has that form', () => {
    const { d, have, tense } = setup();
    c.saveCellOverride(d, have, { [tense]: PAST }, 'hav', null);
    construction(d, 'Past', [{ type: 'word', lexemeId: have, glossTag: 'PST', features: { [tense]: PAST } }, { type: 'phrase', kind: 'phrase' }]);
    expect(analyze(d, 'hav dog').found).toEqual([['Past', 0, 2]]);
  });
  it('picking only some dimensions leaves the others open', () => {
    const { d, verb, tense, have } = setup();
    const person = c.addDimension(d, verb, 'Person', [{ name: 'First', abbr: '1' }, { name: 'Second', abbr: '2' }], null);
    c.saveRule(d, null, { name: 'Second', kind: 'inflectional', branches: suffix('st'), posIds: [verb], bindings: { [person]: 2 }, inputPosId: null, outputPosId: null, outputIntrinsic: {}, autoApply: false });
    construction(d, 'Past', [{ type: 'word', lexemeId: have, glossTag: 'PST', features: { [tense]: PAST } }, { type: 'phrase', kind: 'phrase' }]);
    expect(analyze(d, 'haved dog').found).toEqual([['Past', 0, 2]]);
    expect(analyze(d, 'havedst dog').found).toEqual([['Past', 0, 2]]);
  });
  it('a form nothing fills does not match, even when the bare word looks right', () => {
    const { d, have, tense, verb } = setup();
    d.markers = d.markers.filter((m) => m.posId !== verb);
    construction(d, 'Present', [{ type: 'word', lexemeId: have, features: { [tense]: PRESENT } }, { type: 'phrase', kind: 'phrase' }]);
    const e = new LanguageEngine(d);
    expect(analyze(d, 'hav dog').found).toEqual([]);
    expect(e.fillConstruction(d.constructions[0])[0]).toMatchObject({ text: '(no Present form of hav)', missing: true });
  });
  it('an intrinsic level can restrict a part of speech slot', () => {
    const { d, noun, have } = setup();
    const gender = c.addDimension(d, noun, 'Gender', [{ name: 'Fem', abbr: 'f' }, { name: 'Masc', abbr: 'm' }], null);
    c.setDimensionIntrinsic(d, gender, true);
    c.addWord(d, { phonemic: 'la', posId: noun, meaning: 'she-cat', intrinsicLevels: { [gender]: 1 } });
    c.addWord(d, { phonemic: 'lo', posId: noun, meaning: 'he-cat', intrinsicLevels: { [gender]: 2 } });
    construction(d, 'Fem', [{ type: 'word', lexemeId: have }, { type: 'pos', posId: noun, features: { [gender]: 1 } }]);
    expect(analyze(d, 'hav la').found).toHaveLength(1);
    expect(analyze(d, 'hav lo').found).toEqual([]);
  });
  it('overlaps: longest match wins', () => {
    const { d, have, verb, mo } = setup();
    construction(d, 'Short', [{ type: 'word', lexemeId: mo }, { type: 'pos', posId: verb }]);
    construction(d, 'Long', [{ type: 'word', lexemeId: mo }, { type: 'pos', posId: verb }, { type: 'word', lexemeId: have, glossTag: 'X' }]);
    expect(analyze(d, 'mo run hav')).toEqual({ glosses: ['NEG', 'to run', 'X'], found: [['Long', 0, 3]] });
  });
  it('overlaps: equal length goes to the earliest in the construction list', () => {
    const { d, have, verb } = setup();
    construction(d, 'First', [{ type: 'word', lexemeId: have, glossTag: 'A' }, { type: 'pos', posId: verb }]);
    construction(d, 'Second', [{ type: 'word', lexemeId: have, glossTag: 'B' }, { type: 'phrase', kind: 'phrase' }]);
    expect(analyze(d, 'hav run')).toEqual({ glosses: ['A', 'to run'], found: [['First', 0, 2]] });
  });
  it('separate matches in one phrase both count', () => {
    const { d, mo, verb } = setup();
    construction(d, 'Negation', [{ type: 'word', lexemeId: mo }, { type: 'pos', posId: verb }]);
    expect(analyze(d, 'mo run dog mo hav').found).toEqual([['Negation', 0, 2], ['Negation', 3, 5]]);
  });
  it('a slot tag replaces a particle tag', () => {
    const { d, mo, verb } = setup();
    construction(d, 'Prohibitive', [{ type: 'word', lexemeId: mo, glossTag: 'PROH' }, { type: 'pos', posId: verb }]);
    expect(analyze(d, 'mo run').glosses).toEqual(['PROH', 'to run']);
    expect(analyze(d, 'mo').glosses).toEqual(['NEG']);
  });
  it('without a Word slot it warns and never matches', () => {
    const { d, verb } = setup();
    const id = construction(d, 'Loose', [{ type: 'pos', posId: verb }, { type: 'phrase', kind: 'phrase' }]);
    const e = new LanguageEngine(d);
    expect(analyze(d, 'run dog').found).toEqual([]);
    expect(e.constructionWarnings(d.constructions.find((x) => x.id === id)!)[0]).toContain('at least one Word slot');
  });
  it('reads as a formula', () => {
    const { d, have, tense, verb } = setup();
    construction(d, 'P', [{ type: 'word', lexemeId: have, glossTag: 'PERF', features: { [tense]: PRESENT } }, { type: 'pos', posId: verb }, { type: 'phrase', kind: 'clause', label: 'sub' }]);
    expect(new LanguageEngine(d).constructionFormula(d.constructions[0])).toBe('hav (Present) [PERF] + Verb + Clause: sub');
  });
});

describe('words used in slots', () => {
  it('deleting a word lists the constructions using it, then marks the slot missing', () => {
    const { d, mo, verb } = setup();
    const id = construction(d, 'Negation', [{ type: 'word', lexemeId: mo }, { type: 'pos', posId: verb }]);
    expect(c.constructionsUsingWord(d, mo).map((x) => x.name)).toEqual(['Negation']);
    c.deleteWord(d, mo);
    const con = d.constructions.find((x) => x.id === id)!;
    expect(con.slots[0]).toMatchObject({ type: 'word', missing: 'mo' });
    const e = new LanguageEngine(d);
    expect(e.slotSummary(con.slots[0])).toMatchObject({ text: 'mo', missing: true });
    expect(e.constructionWarnings(con)[0]).toContain('The word mo is missing');
    expect(analyze(d, 'run').found).toEqual([]);
  });
  it('a missing slot can be pointed at another word', () => {
    const { d, mo, have, verb } = setup();
    const id = construction(d, 'Negation', [{ type: 'word', lexemeId: mo }, { type: 'pos', posId: verb }]);
    c.deleteWord(d, mo);
    c.updateSlot(d, id, d.constructions[0].slots[0].id, { type: 'word', lexemeId: have, glossTag: 'NEG' });
    expect(d.constructions[0].slots[0]).not.toHaveProperty('missing');
    expect(analyze(d, 'hav run').glosses).toEqual(['NEG', 'to run']);
  });
  it('a slot can point at an automatic word, which saves its row until the slot goes', () => {
    const { d, verb, noun, run } = setup();
    const rule = c.saveRule(d, null, { name: 'Agent', kind: 'derivational', branches: suffix('er'), posIds: [], bindings: {}, inputPosId: verb, outputPosId: noun, outputIntrinsic: {}, autoApply: true });
    const before = d.lexemes.length;
    const id = construction(d, 'Agentive', [{ type: 'word', lexemeId: dynamicIdFor(run, rule), glossTag: 'AGT' }, { type: 'pos', posId: verb }]);
    const slot = d.constructions[0].slots[0];
    expect(d.lexemes).toHaveLength(before + 1);
    expect(slot.type === 'word' && slot.lexemeId).toBeGreaterThan(0);
    expect(analyze(d, 'runer run')).toEqual({ glosses: ['AGT', 'to run'], found: [['Agentive', 0, 2]] });
    // Survives a save and reload, where session ids are gone.
    const reloaded = parseProject(serializeProject(d));
    expect(analyze(reloaded, 'runer run').glosses).toEqual(['AGT', 'to run']);
    // Editing a detail away must not prune a row a slot depends on.
    c.updateWord(d, dynamicIdFor(run, rule), { meaning: '' });
    expect(d.lexemes).toHaveLength(before + 1);
    c.deleteSlot(d, id, slot.id);
    expect(d.lexemes).toHaveLength(before);
  });
  it('deleting a construction releases an automatic word too', () => {
    const { d, verb, noun, run } = setup();
    const rule = c.saveRule(d, null, { name: 'Agent', kind: 'derivational', branches: suffix('er'), posIds: [], bindings: {}, inputPosId: verb, outputPosId: noun, outputIntrinsic: {}, autoApply: true });
    const before = d.lexemes.length;
    const id = construction(d, 'A', [{ type: 'word', lexemeId: dynamicIdFor(run, rule) }]);
    c.deleteConstruction(d, id);
    expect(d.lexemes).toHaveLength(before);
  });
  it('keeps a stored derived word when its slot goes', () => {
    const { d, verb, noun, run } = setup();
    const rule = c.saveRule(d, null, { name: 'Agent', kind: 'derivational', branches: suffix('er'), posIds: [], bindings: {}, inputPosId: verb, outputPosId: noun, outputIntrinsic: {}, autoApply: false });
    const child = c.promoteDerivation(d, run, rule, '');
    const id = construction(d, 'A', [{ type: 'word', lexemeId: child }]);
    c.deleteSlot(d, id, d.constructions[0].slots[0].id);
    expect(d.lexemes.some((l) => l.id === child)).toBe(true);
  });
  it('levels and dimensions used by a slot count as references, and follow changes', () => {
    const { d, verb, tense, have } = setup();
    construction(d, 'Past', [{ type: 'word', lexemeId: have, features: { [tense]: PAST } }]);
    expect(c.levelReferences(d, tense, PAST).slotCount).toBe(1);
    c.reassignLevelAndDelete(d, tense, PAST, PARTICIPLE);
    const slot = d.constructions[0].slots[0];
    expect(slot.type === 'word' && slot.features).toEqual({ [tense]: PARTICIPLE });
    c.deleteDimension(d, tense);
    expect(slot.type === 'word' && slot.features).toEqual({});
    expect(verb).toBeGreaterThan(0);
  });
  it('changing a word to another part of speech clears the form its slots picked', () => {
    const { d, noun, tense, have } = setup();
    construction(d, 'Past', [{ type: 'word', lexemeId: have, features: { [tense]: PAST } }]);
    c.updateWord(d, have, { posId: noun });
    expect(d.constructions[0].slots[0]).not.toHaveProperty('features');
  });
  it('deleting a part of speech marks its slots missing', () => {
    const { d, have, verb, noun } = setup();
    construction(d, 'N', [{ type: 'word', lexemeId: have }, { type: 'pos', posId: noun }]);
    c.deletePos(d, noun, verb);
    const e = new LanguageEngine(d);
    expect(e.slotSummary(d.constructions[0].slots[1])).toMatchObject({ text: 'Noun', missing: true });
  });
});

describe('format 1 migration', () => {
  const v1 = (edit: (doc: Record<string, unknown>) => void) => {
    const raw = {
      format: 'conlang-workbench', version: 1, name: 'Old', createdAt: '2026-01-01T00:00:00.000Z', updatedAt: '2026-01-01T00:00:00.000Z', nextId: 100,
      partsOfSpeech: [{ id: 1, name: 'Verb', abbr: 'v' }],
      lexemes: [] as unknown[], constructions: [] as unknown[],
    };
    edit(raw);
    return JSON.stringify(raw);
  };
  const word = (id: number, phonemic: string, meaning: string | null, glossTag: string | null, extra = {}) => ({ id, form: { kind: 'root', phonemic }, meaning, posId: null, isException: false, rootOnly: false, isClosedClass: true, glossTag, skippedDimensionIds: [], intrinsicLevels: {}, ...extra });
  const con = (slots: unknown[], id = 50, name = 'C') => ({ id, name, order: 0, slots });

  it('a tag with no meaning becomes a particle in an auto-created Particle part of speech', () => {
    const { doc, warnings, migrated } = parseProjectReport(v1((r) => { r.lexemes = [word(1, 'mo', null, 'NEG'), word(2, 'lo', '  ', 'DEF')]; }));
    expect(migrated).toBe(true);
    expect(doc.version).toBe(FORMAT_VERSION);
    expect(warnings).toEqual([]);
    const pos = doc.partsOfSpeech.find((p) => p.name === 'Particle')!;
    expect(pos).toMatchObject({ abbr: 'p', id: 100 });
    expect(doc.nextId).toBe(101);
    expect(doc.lexemes[0]).toMatchObject({ glossTag: 'NEG', meaning: null, posId: pos.id });
    expect(doc.lexemes[1]).toMatchObject({ glossTag: 'DEF', meaning: null, posId: pos.id });
    expect(doc.lexemes[0]).not.toHaveProperty('isClosedClass');
  });
  it('a particle keeps a part of speech it already has, and reuses an existing Particle', () => {
    const { doc } = parseProjectReport(v1((r) => {
      r.partsOfSpeech = [{ id: 1, name: 'Article', abbr: 'art' }, { id: 2, name: 'particle', abbr: 'part' }];
      r.lexemes = [word(1, 'lo', null, 'DEF', { posId: 1 }), word(2, 'mo', null, 'NEG')];
    }));
    expect(doc.lexemes.map((l) => l.posId)).toEqual([1, 2]);
    expect(doc.partsOfSpeech).toHaveLength(2);
  });
  it('a tag with a meaning moves to the Word slots using it', () => {
    const { doc, warnings } = parseProjectReport(v1((r) => {
      r.lexemes = [word(1, 'dur', 'to go', 'FUT', { posId: 1 })];
      r.constructions = [con([{ id: 60, type: 'gloss_tag', value: 'fut' }, { id: 61, type: 'pos', value: '1' }])];
    }));
    expect(warnings).toEqual([]);
    expect(doc.lexemes[0]).toMatchObject({ meaning: 'to go', glossTag: null });
    expect(doc.constructions[0].slots).toEqual([{ id: 60, type: 'word', lexemeId: 1, glossTag: 'FUT' }, { id: 61, type: 'pos', posId: 1 }]);
    expect(analyze(doc, 'dur').glosses).toEqual(['to go']);
  });
  it('an unused tag on a meaning word is dropped and reported', () => {
    const { doc, warnings } = parseProjectReport(v1((r) => { r.lexemes = [word(11, 'al', 'to', 'PREP')]; }));
    expect(doc.lexemes[0]).toMatchObject({ meaning: 'to', glossTag: null });
    expect(warnings).toHaveLength(1);
    expect(warnings[0]).toContain('al');
    expect(warnings[0]).toContain('PREP was dropped');
  });
  it('a tag slot with no word stays, flagged missing and reported', () => {
    const { doc, warnings } = parseProjectReport(v1((r) => { r.constructions = [con([{ id: 60, type: 'gloss_tag', value: 'FUT' }], 50, 'Future')]; }));
    expect(doc.constructions[0].slots[0]).toMatchObject({ type: 'word', missing: 'FUT', glossTag: 'FUT' });
    expect(warnings[0]).toContain('Future');
    const e = new LanguageEngine(doc);
    expect(e.slotSummary(doc.constructions[0].slots[0])).toMatchObject({ text: 'FUT', missing: true });
    expect(e.fillConstruction(doc.constructions[0])[0]).toMatchObject({ text: '(missing word: FUT)', missing: true });
    expect(e.constructionWarnings(doc.constructions[0]).join()).toContain('The word FUT is missing');
  });
  it('a tag slot prefers the particle when a meaning word shares the tag, and reports the choice', () => {
    const { doc, warnings } = parseProjectReport(v1((r) => {
      r.lexemes = [word(1, 'dur', 'to go', 'FUT'), word(2, 'ze', null, 'FUT')];
      r.constructions = [con([{ id: 60, type: 'gloss_tag', value: 'FUT' }])];
    }));
    expect(doc.constructions[0].slots[0]).toEqual({ id: 60, type: 'word', lexemeId: 2 });
    expect(warnings.join()).toContain('several words');
    expect(warnings.join()).toContain('FUT was dropped');
  });
  it('a pos slot naming nothing stays flagged, and a slot label is reported', () => {
    const { doc, warnings } = parseProjectReport(v1((r) => { r.constructions = [con([{ id: 60, type: 'pos', value: '99', label: 'head' }])]; }));
    expect(doc.constructions[0].slots[0]).toMatchObject({ type: 'pos', missing: '99' });
    expect(warnings.join()).toContain('"head" was dropped');
  });
  it('a current file is left alone', () => {
    const d = emptyProject('T');
    c.addWord(d, { phonemic: 'mo', posId: null, glossTag: 'NEG' });
    const report = parseProjectReport(serializeProject(d));
    expect(report).toEqual({ doc: d, warnings: [], migrated: false });
  });
});
