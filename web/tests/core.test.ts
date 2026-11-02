import { describe, expect, it } from 'vitest';
import * as c from '../src/core/commands';
import { LanguageEngine } from '../src/core/engine';
import { applyRule } from '../src/core/morphology';
import { deromanize, formatAbbr, formatAbbrUpper, romanize, validateBijection } from '../src/core/notation';
import { computeCell, coverageMatrix, featureKey, findTiebreakConflicts, translateBindings } from '../src/core/paradigm';
import { applyRewriteRules, buildInventory, computeAllophones, generateWords, matchesAt, resolveClass, validateWord } from '../src/core/phonology';
import { legacyRewrite, legacyRuleToBranches, patternToSegments } from '../src/core/legacy/importSqlite';
import { parseProject, serializeProject, emptyProject } from '../src/core/types';
import type { Branch, Dimension, MorphRule, Phoneme } from '../src/core/types';

const P = (symbol: string, type: 'consonant' | 'vowel', id = symbol.charCodeAt(0)): Phoneme => ({ id, symbol, type });
const INV = buildInventory([...'ptkmnslr'].map((s) => P(s, 'consonant')).concat(P('tʃ', 'consonant', 999)).concat([...'aeiou'].map((s) => P(s, 'vowel'))), []);
const rule = (...b: Branch[]) => ({ branches: b });
const ops = (...operations: Branch['operations']): Branch => ({ conditions: [], operations });

describe('morphological operations', () => {
  const form = (b: Branch, w: string) => {
    const r = applyRule(rule(b), w, INV);
    return r.ok ? r.form : null;
  };
  it('prefix, suffix', () => {
    expect(form(ops({ type: 'prefix', affix: 'un' }), 'kata')).toBe('unkata');
    expect(form(ops({ type: 'suffix', affix: 'ka' }), 'kata')).toBe('kataka');
  });
  it('infix after the nth consonant, appending when too few', () => {
    expect(form(ops({ type: 'infix', affix: 'um', afterConsonant: 1 }), 'talis')).toBe('tumalis');
    expect(form(ops({ type: 'infix', affix: 'um', afterConsonant: 9 }), 'ta')).toBe('taum');
  });
  it('replace all, counted, by direction, by class, multi-sound', () => {
    const rep = (from: Extract<Branch['operations'][0], { type: 'replace' }>['from'], to: string, count: number | null, direction: 'fromStart' | 'fromEnd' = 'fromStart') => ops({ type: 'replace', from, to, count, direction });
    expect(form(rep({ kind: 'sound', text: 'a' }, 'o', null), 'kata')).toBe('koto');
    expect(form(rep({ kind: 'sound', text: 'a' }, 'o', 1), 'kata')).toBe('kota');
    expect(form(rep({ kind: 'sound', text: 'a' }, 'o', 1, 'fromEnd'), 'kata')).toBe('kato');
    expect(form(rep({ kind: 'class', name: 'V' }, 'i', 1, 'fromEnd'), 'kato')).toBe('kati');
    expect(form(rep({ kind: 'sound', text: 'ai' }, 'e', null), 'kait')).toBe('ket');
  });
  describe('elongation', () => {
    const el = (target: 'vowel' | 'consonant', index: 1 | 2 | 3, direction: 'fromStart' | 'fromEnd' = 'fromStart') => ops({ type: 'elongate', target, index, direction });
    it('lengthens the chosen vowel, counting only vowels, from either end', () => {
      expect(form(el('vowel', 1), 'kataso')).toBe('kaːtaso');
      expect(form(el('vowel', 2), 'kataso')).toBe('kataːso');
      expect(form(el('vowel', 3), 'kataso')).toBe('katasoː');
      expect(form(el('vowel', 1, 'fromEnd'), 'kataso')).toBe('katasoː');
      expect(form(el('vowel', 3, 'fromEnd'), 'kataso')).toBe('kaːtaso');
    });
    it('geminates the chosen consonant, counting only consonants, from either end', () => {
      expect(form(el('consonant', 1), 'atas')).toBe('attas');
      expect(form(el('consonant', 2), 'atas')).toBe('atass');
      expect(form(el('consonant', 1, 'fromEnd'), 'atas')).toBe('atass');
      expect(form(el('consonant', 2, 'fromEnd'), 'atas')).toBe('attas');
    });
    it('treats a multi-character phoneme as one sound', () => {
      expect(form(el('consonant', 1), 'atʃa')).toBe('atʃtʃa');
    });
    it('uses the language’s own long phoneme for a consonant when it has one', () => {
      const inv = buildInventory([P('r', 'consonant'), P('rː', 'consonant', 998), P('t', 'consonant'), P('a', 'vowel')], []);
      const go = (w: string, index: 1 | 2) => { const r = applyRule(rule(el('consonant', index)), w, inv); return r.ok && r.form; };
      expect(go('ara', 1)).toBe('arːa');
      expect(go('ata', 1)).toBe('atta');
      // A long phoneme counts as one consonant and is already long.
      expect(go('arːa', 1)).toBe('arːa');
    });
    it('uses a long vowel phoneme as one vowel, whether or not it is in the inventory', () => {
      const inv = buildInventory([P('t', 'consonant'), P('a', 'vowel'), P('aː', 'vowel', 998), P('i', 'vowel')], []);
      const go = (w: string, index: 1 | 2) => { const r = applyRule(rule(el('vowel', index)), w, inv); return r.ok && r.form; };
      expect(go('taːti', 2)).toBe('taːtiː');
      expect(go('taːti', 1)).toBe('taːti');
      // INV has no aː phoneme: the mark still makes the a long.
      expect(form(el('vowel', 1), 'kaːta')).toBe('kaːta');
      expect(form(el('vowel', 2), 'kaːta')).toBe('kaːtaː');
    });
    it('counts a long vowel as a vowel even if a project filed it as a consonant', () => {
      const inv = buildInventory([P('t', 'consonant'), P('aː', 'consonant', 998), P('a', 'vowel')], []);
      const r = applyRule(rule(el('vowel', 1, 'fromEnd')), 'kataː', inv);
      expect(r.ok && r.form).toBe('kataː');
      const g = applyRule(rule(el('consonant', 1, 'fromEnd')), 'taː', inv);
      expect(g.ok && g.form).toBe('ttaː');
    });
    it('counts a sound that is already long once, and leaves it unchanged', () => {
      expect(form(el('consonant', 2), 'katta')).toBe('katta');
      expect(form(el('consonant', 3), 'kattas')).toBe('kattass');
      expect(form(el('vowel', 1), 'kaata')).toBe('kaata');
      expect(form(el('vowel', 2), 'kaata')).toBe('kaataː');
    });
    it('gives a reason instead of a wrong form when there are too few sounds', () => {
      expect(applyRule(rule(el('vowel', 3)), 'kata', INV)).toEqual({ ok: false, reason: '/kata/ has no third vowel.' });
      expect(applyRule(rule(el('consonant', 3, 'fromEnd')), 'kata', INV)).toEqual({ ok: false, reason: '/kata/ has no third consonant from the end.' });
    });
    it('a geminate it makes is what the gemination constraint flags', () => {
      const r = applyRule(rule(el('consonant', 1)), 'atas', INV);
      const constraint = { id: 1, kind: 'gemination' as const, positions: ['everywhere' as const], active: true };
      expect(r.ok && validateWord(r.form, [constraint], INV)).toHaveLength(1);
    });
  });
  it('an operation from an older file gives no form, and says why', () => {
    const stale = ops({ type: 'copy' } as unknown as Branch['operations'][number]);
    const r = applyRule(rule(stale), 'kata', INV);
    expect(r.ok).toBe(false);
    expect(!r.ok && r.reason).toContain('operation that no longer exists (copy)');
  });
  it('root-and-pattern templates; a missing slot is a no-match, not a stray digit', () => {
    const t = ops({ type: 'template', parts: [{ kind: 'slot', index: 1 }, { kind: 'sound', text: 'a' }, { kind: 'slot', index: 2 }, { kind: 'slot', index: 3 }, { kind: 'sound', text: 'aa' }] });
    expect(form(t, 'ktm')).toBe('katmaa');
    expect(form(t, 'kt')).toBeNull();
  });
  it('reduplication, suppletion, ending removal', () => {
    expect(form(ops({ type: 'reduplicate', scope: 'CV', position: 'prefix' }), 'talas')).toBe('tatalas');
    expect(form(ops({ type: 'reduplicate', scope: 'full', position: 'suffix' }), 'ta')).toBe('tata');
    expect(form(ops({ type: 'reduplicate', scope: 'C', position: 'prefix' }), 'ta')).toBe('tta');
    expect(form(ops({ type: 'suppletive', form: 'went' }), 'go')).toBe('went');
    expect(form(ops({ type: 'removeSuffix', suffix: 'o' }, { type: 'suffix', affix: 'in' }), 'kato')).toBe('katin');
  });
  it('first matching branch wins; conditions AND together; no branch is a no-match', () => {
    const ends = (text: string): Branch['conditions'][0] => ({ position: 'endsWith', segments: [{ kind: 'sound', text }] });
    const r = rule(
      { conditions: [ends('a'), { position: 'startsWith', segments: [{ kind: 'sound', text: 'k' }] }], operations: [{ type: 'suffix', affix: 'x' }] },
      { conditions: [ends('a')], operations: [{ type: 'suffix', affix: 'y' }] },
    );
    expect(applyRule(r, 'kata', INV)).toEqual({ ok: true, form: 'katax' });
    expect(applyRule(r, 'tata', INV)).toEqual({ ok: true, form: 'tatay' });
    expect(applyRule(r, 'tat', INV).ok).toBe(false);
    expect(applyRule(r, '', INV).ok).toBe(false);
  });
});

describe('pattern matching', () => {
  it('matches classes, literals across tokens, positions', () => {
    expect(matchesAt('endsWith', [{ kind: 'class', name: 'nasal' }, { kind: 'class', name: 'V' }], 'kana', INV)).toBe(true);
    expect(matchesAt('startsWith', [{ kind: 'class', name: 'C' }, { kind: 'class', name: 'V' }], 'ata', INV)).toBe(false);
    expect(matchesAt('contains', [{ kind: 'sound', text: 'na' }], 'kanat', INV)).toBe(true);
  });
  it('backtracks over optional segments, which the old engine could not', () => {
    const seg = patternToSegments('V(k)k');
    expect(matchesAt('endsWith', seg, 'tak', INV)).toBe(true);
    expect(matchesAt('endsWith', seg, 'takk', INV)).toBe(true);
  });
  it('resolves aliases, and intersects defaults with the inventory', () => {
    expect(resolveClass('S', INV).sort()).toEqual(['k', 'p', 't']);
    expect(resolveClass('stop', INV).sort()).toEqual(['k', 'p', 't']);
    expect(resolveClass('V', INV)).toHaveLength(5);
    expect(resolveClass('nothing', INV)).toEqual([]);
  });
  it('lets user classes take precedence over defaults', () => {
    const inv = buildInventory([P('p', 'consonant', 1), P('t', 'consonant', 2)], [{ id: 1, name: 'Stop', phonemeIds: [1] }]);
    expect(resolveClass('stop', inv)).toEqual(['p']);
  });
});

describe('romanization', () => {
  const m = [{ phoneme: 'a', latin: 'a' }, { phoneme: 't', latin: 't' }, { phoneme: 'h', latin: 'h' }, { phoneme: 'θ', latin: 'th' }];
  it('inserts a dot only when concatenation would misread', () => {
    expect(romanize('atha', m)).toBe('at.ha');
    expect(romanize('aθa', m)).toBe('atha');
    expect(deromanize('atha', m)).toBe('aθa');
    expect(deromanize('at.ha', m)).toBe('atha');
  });
  it('passes unknown characters through', () => expect(romanize('axa', m)).toBe('axa'));
  it('allows disambiguable sets, rejects duplicates', () => {
    const rows = m.map((x, id) => ({ id, ...x }));
    expect(validateBijection(rows)).toEqual([]);
    expect(validateBijection([...rows, { id: 9, phoneme: 'a', latin: 'q' }])[0].kind).toBe('duplicatePhoneme');
    expect(validateBijection([...rows, { id: 9, phoneme: 'q', latin: 'a' }])[0].kind).toBe('duplicateLatin');
  });
  it('formats abbreviations', () => {
    expect(formatAbbr('SG.')).toBe('sg.');
    expect(formatAbbrUpper('sg.')).toBe('SG');
    expect(formatAbbr(null)).toBe('');
  });
});

describe('phonotactics', () => {
  const seq = (text: string, position: 'anywhere' | 'start' | 'end' = 'anywhere') => ({ id: 1, kind: 'sequence' as const, segments: patternToSegments(text), position, active: true });
  it('flags forbidden sequences with offsets and positions', () => {
    expect(validateWord('aptka', [seq('SS')], INV)).toMatchObject([{ position: 1, length: 2 }, { position: 2, length: 2 }]);
    expect(validateWord('tpa', [seq('SS', 'end')], INV)).toEqual([]);
    expect(validateWord('tpa', [seq('SS', 'start')], INV)).toHaveLength(1);
    expect(validateWord('tt', [{ ...seq('SS'), active: false }], INV)).toEqual([]);
  });
  it('flags gemination by position', () => {
    const gem = (...positions: ('everywhere' | 'coda' | 'onset' | 'initial' | 'final')[]) => [{ id: 1, kind: 'gemination' as const, positions, active: true }];
    expect(validateWord('atta', gem('everywhere'), INV)).toHaveLength(1);
    expect(validateWord('atta', gem('initial'), INV)).toHaveLength(0);
    expect(validateWord('tta', gem('initial'), INV)).toHaveLength(1);
    expect(validateWord('att', gem('final'), INV)).toHaveLength(1);
    expect(validateWord('atta', gem('onset'), INV)).toHaveLength(1);
    expect(validateWord('attk', gem('coda'), INV)).toHaveLength(1);
    expect(validateWord('aia', gem('everywhere'), INV)).toHaveLength(0);
  });
  it('applies rewrite rules in order with contexts and word edges', () => {
    const r = (input: string, output: string, left: string, right: string) => ({ id: 1, ...legacyRewrite(`${input} -> ${output} / ${left}_${right}`)! });
    expect(applyRewriteRules('kaka', [r('k', 'x', 'V', 'V')], INV)).toBe('kaxa');
    expect(applyRewriteRules('kat', [r('t', 'ʔ', '', '#')], INV)).toBe('kaʔ');
    expect(applyRewriteRules('tat', [r('t', 'd', '#', '')], INV)).toBe('dat');
    expect(applyRewriteRules('kai', [{ id: 1, input: patternToSegments('ai'), output: 'e', left: [], right: [] }], INV)).toBe('ke');
  });
  it('lists allophones without clusters or identities', () => {
    const rules = ['s -> ʃ / _i', 's -> s / _a', 'st -> ʃt'].map((s, i) => ({ id: i, ...legacyRewrite(s)! }));
    expect(computeAllophones('s', rules, INV).map((a) => a.output)).toEqual(['ʃ']);
  });
  it('generates only constraint-respecting words', () => {
    const templates = [{ id: 1, segments: patternToSegments('CV(C)'), active: true }];
    let seed = 7;
    const rng = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
    const words = generateWords({ templates, constraints: [seq('SS')], inventory: INV, count: 30, rng });
    expect(words.length).toBeGreaterThan(0);
    for (const w of words) expect(validateWord(w, [seq('SS')], INV)).toEqual([]);
    expect(generateWords({ templates: [], constraints: [], inventory: INV, count: 3 })).toEqual([]);
  });
});

describe('paradigm cells', () => {
  const mk = (id: number, bindings: Record<string, number>, affix: string, active = true): { rule: MorphRule; bindings: Record<string, number> } => ({
    bindings,
    rule: { id, name: `r${id}`, kind: 'inflectional', active, order: id, branches: [ops({ type: 'suffix', affix })], posIds: [1], bindings, inputPosId: null, outputPosId: null, outputIntrinsic: {}, autoApply: false },
  });
  const base = { base: 'kat', markers: [], inventory: INV, intrinsicDims: new Set<number>(), wordLevels: {} };
  it('consumes features most-specific first', () => {
    const cell = computeCell({ ...base, target: { 1: 1, 2: 2 }, rules: [mk(1, { 1: 1 }, 'a'), mk(2, { 2: 2 }, 'b'), mk(3, { 1: 1, 2: 2 }, 'z')] });
    expect(cell).toMatchObject({ kind: 'filled', phonemic: 'katz', partial: false });
  });
  it('stacks rules across dimensions in order', () => {
    expect(computeCell({ ...base, target: { 1: 1, 2: 2 }, rules: [mk(1, { 1: 1 }, 'a'), mk(2, { 2: 2 }, 'b')] })).toMatchObject({ phonemic: 'katab' });
  });
  it('reports ties, and uncovered cells', () => {
    expect(computeCell({ ...base, target: { 1: 1 }, rules: [mk(1, { 1: 1 }, 'a'), mk(2, { 1: 1 }, 'b')] }).kind).toBe('ambiguous');
    expect(computeCell({ ...base, target: { 1: 2 }, rules: [mk(1, { 1: 1 }, 'a')] }).kind).toBe('uncovered');
  });
  it('rules beat markers; markers beat uncovered', () => {
    const marker = { id: 1, posId: 1, name: 'Sg', bindings: { 1: 1 } };
    expect(computeCell({ ...base, target: { 1: 1 }, rules: [], markers: [marker] }).kind).toBe('unmarked');
    expect(computeCell({ ...base, target: { 1: 1 }, rules: [mk(1, { 1: 1 }, 'a')], markers: [marker] }).kind).toBe('filled');
  });
  it('a marker completes features a rule leaves over', () => {
    const marker = { id: 1, posId: 1, name: 'Sg', bindings: { 1: 1 } };
    expect(computeCell({ ...base, target: { 1: 1, 2: 2 }, rules: [mk(1, { 2: 2 }, 'b')], markers: [marker] })).toMatchObject({ phonemic: 'katb', partial: false });
  });
  it('intrinsic bindings filter by the word rather than act as axes', () => {
    const rules = [mk(1, { 9: 1, 1: 1 }, 'm'), mk(2, { 9: 2, 1: 1 }, 'f')];
    const i = { ...base, target: { 1: 1 }, rules, intrinsicDims: new Set([9]) };
    expect(computeCell({ ...i, wordLevels: { 9: 2 } })).toMatchObject({ phonemic: 'katf' });
    expect(computeCell({ ...i, wordLevels: {} }).kind).toBe('uncovered');
  });
  it('translates multi-POS bindings by name, dropping unreachable rules', () => {
    const dim = (id: number, posId: number, name: string, levels: [number, string, string][]): Dimension => ({ id, posId, name, order: 0, intrinsic: false, levels: levels.map(([i, n, a]) => ({ id: i, name: n, abbr: a, order: i })) });
    const noun = dim(1, 1, 'Number', [[1, 'Sg', 'sg'], [2, 'Pl', 'pl']]);
    const adj = dim(2, 2, 'Number', [[7, 'Sg', 'sg'], [8, 'Pl', 'pl']]);
    expect(translateBindings({ 1: 2 }, [noun, adj], [adj])).toEqual({ 2: 8 });
    expect(translateBindings({ 1: 2 }, [noun, adj], [noun])).toEqual({ 1: 2 });
    expect(translateBindings({ 1: 2 }, [noun], [dim(3, 3, 'Case', [[1, 'Nom', 'nom']])])).toBeNull();
  });
  it('builds coverage and finds conflicts', () => {
    const dims: Dimension[] = [{ id: 1, posId: 1, name: 'N', order: 0, intrinsic: false, levels: [{ id: 1, name: 'a', abbr: 'a', order: 0 }, { id: 2, name: 'b', abbr: 'b', order: 1 }] }];
    const rules = [mk(1, { 1: 1 }, 'x')];
    expect(coverageMatrix(rules, dims).cells.map((c) => c.covered)).toEqual([true, false]);
    expect(findTiebreakConflicts([mk(1, { 1: 1 }, 'x'), mk(2, { 1: 1 }, 'y'), mk(3, { 1: 2 }, 'z')])[0].rules).toHaveLength(2);
    expect(featureKey({ 11: 1, 10: 2 })).toBe('10:2,11:1');
  });
});

describe('commands', () => {
  const doc = () => emptyProject('T');
  it('saving rejects what the editor rejects', () => {
    const d = doc();
    const base = { name: 'x', kind: 'inflectional' as const, branches: [ops({ type: 'suffix', affix: 'a' })], posIds: [], bindings: {}, inputPosId: null, outputPosId: null, outputIntrinsic: {}, autoApply: false };
    expect(() => c.saveRule(d, null, { ...base, name: ' ' })).toThrow('Rule name is required');
    expect(() => c.saveRule(d, null, base)).toThrow('At least one POS');
    const pos = c.savePos(d, null, 'Noun', 'N');
    expect(() => c.saveRule(d, null, { ...base, posIds: [pos] })).toThrow('must bind at least one feature');
    const dim = c.addDimension(d, pos, 'G', [{ name: 'M', abbr: 'm' }], null);
    c.setDimensionIntrinsic(d, dim, true);
    expect(() => c.saveRule(d, null, { ...base, posIds: [pos], bindings: { [dim]: 1 } })).toThrow('no non-intrinsic axes');
    expect(d.partsOfSpeech[0].abbr).toBe('n');
  });
  it('puts default branches last so conditional ones can fire', () => {
    const d = doc();
    const pos = c.savePos(d, null, 'V', 'v');
    const id = c.saveRule(d, null, { name: 'r', kind: 'derivational', branches: [ops({ type: 'suffix', affix: 'a' }), { conditions: [{ position: 'endsWith', segments: [{ kind: 'sound', text: 'a' }] }], operations: [{ type: 'suffix', affix: 'b' }] }], posIds: [], bindings: {}, inputPosId: pos, outputPosId: pos, outputIntrinsic: {}, autoApply: false });
    expect(d.rules.find((r) => r.id === id)!.branches[0].conditions).toHaveLength(1);
  });
  it('intrinsic toggle backfills and banners; reassign rewrites every reference', () => {
    const d = doc();
    const pos = c.savePos(d, null, 'Noun', 'n');
    const dim = c.addDimension(d, pos, 'Gender', [{ name: 'M', abbr: 'm' }, { name: 'F', abbr: 'f' }], null);
    const w = c.addWord(d, { phonemic: 'a', posId: pos });
    expect(c.setDimensionIntrinsic(d, dim, true)).toBe(1);
    expect(d.lexemes.find((l) => l.id === w)!.intrinsicLevels[dim]).toBe(1);
    expect(d.settings.backfillBanners).toHaveLength(1);
    c.saveStandardForm(d, dim, 1, [{ kind: 'endsWith', segments: [{ kind: 'sound', text: 'a' }] }]);
    expect(c.levelReferences(d, dim, 1).total).toBe(2);
    expect(() => c.deleteLevel(d, dim, 1)).toThrow('still in use');
    c.reassignLevelAndDelete(d, dim, 1, 2);
    expect(d.lexemes[0].intrinsicLevels[dim]).toBe(2);
    expect(d.standardForms[0].levelId).toBe(2);
    expect(d.dimensions[0].levels.map((l) => l.id)).toEqual([2]);
  });
  it('requires intrinsic levels and POS on new words', () => {
    const d = doc();
    const pos = c.savePos(d, null, 'Noun', 'n');
    const dim = c.addDimension(d, pos, 'Gender', [{ name: 'M', abbr: 'm' }], null);
    c.setDimensionIntrinsic(d, dim, true);
    expect(() => c.addWord(d, { phonemic: 'a', posId: null })).toThrow('Part of speech');
    expect(() => c.addWord(d, { phonemic: 'a', posId: pos })).toThrow('fixed Gender');
    expect(c.addWord(d, { phonemic: 'a', posId: pos, intrinsicLevels: { [dim]: 1 } })).toBeGreaterThan(0);
    expect(c.addWord(d, { phonemic: 'b', posId: null, rootOnly: true })).toBeGreaterThan(0);
  });
  it('deleting a POS migrates words and removes what it owned', () => {
    const d = doc();
    const a = c.savePos(d, null, 'A', 'a');
    const b = c.savePos(d, null, 'B', 'b');
    const dim = c.addDimension(d, a, 'X', [{ name: 'x', abbr: 'x' }], null);
    c.saveRule(d, null, { name: 'r', kind: 'inflectional', branches: [ops({ type: 'suffix', affix: 'a' })], posIds: [a], bindings: { [dim]: 1 }, inputPosId: null, outputPosId: null, outputIntrinsic: {}, autoApply: false });
    const w = c.addWord(d, { phonemic: 'a', posId: a });
    c.deletePos(d, a, b);
    expect(d.lexemes.find((l) => l.id === w)!.posId).toBe(b);
    expect(d.rules).toHaveLength(0);
    expect(d.dimensions).toHaveLength(0);
  });
  it('blocks romanization that cannot round-trip, and auto-adds the phoneme', () => {
    const d = doc();
    expect(c.saveRomanization(d, null, 'ʃ', 'sh')).toBe('ʃ');
    expect(d.phonemes[0]).toMatchObject({ symbol: 'ʃ', type: 'consonant', manner: 'fricative' });
    expect(() => c.saveRomanization(d, null, 'x', 'sh')).toThrow('bijection');
  });
  it('allows one gemination constraint and rejects self-parenting', () => {
    const d = doc();
    c.saveGeminationConstraint(d, null, ['coda'], '');
    expect(() => c.saveGeminationConstraint(d, null, ['onset'], '')).toThrow('already exists');
    const w = c.addWord(d, { phonemic: 'a', posId: null, rootOnly: true });
    expect(() => c.addParent(d, w, w)).toThrow('own parent');
  });
  it('round-trips through the file format and refuses other files', () => {
    const d = doc();
    c.addWord(d, { phonemic: 'a', posId: null, rootOnly: true });
    expect(parseProject(serializeProject(d))).toEqual(d);
    expect(() => parseProject('{}')).toThrow('not a Conlang Workbench project');
    expect(() => parseProject('nope')).toThrow('not valid JSON');
    expect(() => parseProject(JSON.stringify({ ...d, version: 99 }))).toThrow('newer version');
  });
});

describe('engine queries', () => {
  const setup = () => {
    const d = emptyProject('T');
    for (const s of ['k', 't', 'l']) c.addPhoneme(d, { symbol: s, type: 'consonant' });
    c.addPhoneme(d, { symbol: 'a', type: 'vowel' });
    const n = c.savePos(d, null, 'Noun', 'n');
    const num = c.addDimension(d, n, 'Number', [{ name: 'Sg', abbr: 'sg' }, { name: 'Pl', abbr: 'pl' }], null);
    c.saveRule(d, null, { name: 'Plural', kind: 'inflectional', branches: [ops({ type: 'suffix', affix: 'ta' })], posIds: [n], bindings: { [num]: 2 }, inputPosId: null, outputPosId: null, outputIntrinsic: {}, autoApply: false });
    const kal = c.addWord(d, { phonemic: 'kal', posId: n, meaning: 'stone' });
    return { d, n, num, kal };
  };
  it('an override wins, and is what phrase analysis reads', () => {
    const { d, num, kal } = setup();
    c.saveCellOverride(d, kal, { [num]: 2 }, 'kel', null);
    const e = new LanguageEngine(d);
    expect(e.paradigm(kal).cells.get(featureKey({ [num]: 2 }))).toMatchObject({ kind: 'override', phonemic: 'kel' });
    expect(e.analyzePhrase('kel')[0].matches[0].gloss).toBe('stone.PL');
    expect(e.analyzePhrase('kalta')[0].matches).toEqual([]);
  });
  it('tolerates punctuation, and leaves unknown tokens honest', () => {
    const { d } = setup();
    const e = new LanguageEngine(d);
    const [a, b] = e.analyzePhrase('kal, zzz.');
    expect(a.matches[0].gloss).toBe('stone');
    expect(b.matches).toEqual([]);
  });
  it('phrase violations are checked on the surface form, not the root', () => {
    const { d, kal } = setup();
    c.saveSequenceConstraint(d, null, [{ kind: 'sound', text: 'l' }, { kind: 'sound', text: 't' }], 'anywhere', 'no lt');
    const e = new LanguageEngine(d);
    expect(e.wordViolations(kal)).toEqual([]);
    expect(e.analyzePhrase('kalta')[0].violations).toHaveLength(1);
  });
  it('a word marked as an exception is not flagged anywhere', () => {
    const { d, kal } = setup();
    c.saveSequenceConstraint(d, null, [{ kind: 'sound', text: 'k' }], 'anywhere', 'no k');
    c.setWordException(d, kal, true);
    const e = new LanguageEngine(d);
    expect(e.wordViolations(kal)).toEqual([]);
    expect(e.analyzePhrase('kal')[0].violations).toEqual([]);
  });
  it('standard forms warn softly', () => {
    const { d, n } = setup();
    const g = c.addDimension(d, n, 'Gender', [{ name: 'Fem', abbr: 'f' }], null);
    c.setDimensionIntrinsic(d, g, true);
    c.saveStandardForm(d, g, 1, [{ kind: 'endsWith', segments: [{ kind: 'sound', text: 'a' }] }]);
    const e = new LanguageEngine(d);
    expect(e.wordViolations(d.lexemes[0].id)[0].description).toContain('Fem Gender should end with');
  });
  it('builds ancestry and detects cycles without looping', () => {
    const { d, kal, n } = setup();
    const child = c.addWord(d, { phonemic: 'tal', posId: n });
    c.addParent(d, child, kal, 'from');
    c.addParent(d, kal, child);
    const node = new LanguageEngine(d).ancestry(child)!;
    expect(node.parents[0].edgeLabel).toBe('from');
    expect(node.parents[0].parents[0].isCycle).toBe(true);
  });
  it('fills constructions from the lexicon, or says what is missing', () => {
    const { d, n, kal } = setup();
    const ta = c.addWord(d, { phonemic: 'ta', posId: null, glossTag: 'NEG' });
    const gone = c.addWord(d, { phonemic: 'la', posId: null, glossTag: 'FUT' });
    const id = c.addConstruction(d, 'Neg');
    c.addSlot(d, id, { type: 'word', lexemeId: ta });
    c.addSlot(d, id, { type: 'pos', posId: n });
    c.addSlot(d, id, { type: 'word', lexemeId: gone });
    c.addSlot(d, id, { type: 'phrase', kind: 'clause', label: 'subjunctive clause' });
    c.deleteWord(d, gone);
    const e = new LanguageEngine(d);
    const con = d.constructions[0];
    expect(e.fillConstruction(con, e.lexeme(kal)).map((p) => p.text)).toEqual(['ta', 'kal', '(missing word: la)', '[subjunctive clause]']);
    expect(e.constructionsForWord(e.lexeme(kal)!)).toHaveLength(1);
    expect(e.constructionsForWord(e.lexeme(ta)!)).toHaveLength(1);
  });
});

describe('length classes', () => {
  // aː is a phoneme and eː isn't, the two ways real projects hold long vowels. rː is a phoneme too.
  const inv = buildInventory([...'ptkmnsr'].map((x) => P(x, 'consonant')).concat(P('rː', 'consonant', 998), P('aː', 'vowel', 997)).concat([...'aeiou'].map((x) => P(x, 'vowel'))), []);
  const cl = (name: string) => ({ kind: 'class' as const, name });
  const forbids = (word: string, ...segments: ReturnType<typeof cl>[]) => validateWord(word, [{ id: 1, kind: 'sequence', segments, position: 'anywhere', active: true }], inv);
  const LONG = cl('long vowel');
  const GEM = cl('geminate');
  it('recognizes a geminate however it is written', () => {
    for (const w of ['atta', 'atːa', 'arːa', 'arra']) expect(matchesAt('contains', [GEM], w, inv)).toBe(true);
    for (const w of ['ata', 'atka', 'aːta', 'aa']) expect(matchesAt('contains', [GEM], w, inv)).toBe(false);
  });
  it('recognizes a long vowel however it is written', () => {
    for (const w of ['taːt', 'teːt', 'teet']) expect(matchesAt('contains', [LONG], w, inv)).toBe(true);
    for (const w of ['tat', 'taet', 'tatː', 'tatt']) expect(matchesAt('contains', [LONG], w, inv)).toBe(false);
  });
  it('no vowel touching a long vowel, in both directions and both ways of holding length', () => {
    for (const w of ['tiaːt', 'tieːt', 'taːeːt', 'teːaːt']) expect(forbids(w, cl('V'), LONG)).toHaveLength(1);
    for (const w of ['taːit', 'teːit', 'taːeːt']) expect(forbids(w, LONG, cl('V'))).toHaveLength(1);
    for (const w of ['taːteːt', 'taːt', 'tit', 'tait']) {
      expect(forbids(w, cl('V'), LONG)).toEqual([]);
      expect(forbids(w, LONG, cl('V'))).toEqual([]);
    }
  });
  it('no two geminates touching', () => {
    for (const w of ['attkka', 'atːkka', 'arːkka', 'attrːa']) expect(forbids(w, GEM, GEM)).toHaveLength(1);
    for (const w of ['attakka', 'atta', 'attka']) expect(forbids(w, GEM, GEM)).toEqual([]);
  });
  it('no consonant touching a geminate, without flagging the geminate alone', () => {
    for (const w of ['antta', 'antːa', 'anrːa']) expect(forbids(w, cl('C'), GEM)).toHaveLength(1);
    for (const w of ['attna', 'atːna', 'arːna']) expect(forbids(w, GEM, cl('C'))).toHaveLength(1);
    for (const w of ['atta', 'atːa', 'arːa', 'attanna']) {
      expect(forbids(w, cl('C'), GEM)).toEqual([]);
      expect(forbids(w, GEM, cl('C'))).toEqual([]);
    }
  });
  it('highlights the whole long sound', () => {
    expect(forbids('tieːt', cl('V'), LONG)[0]).toMatchObject({ position: 1, length: 3 });
    expect(forbids('attkka', GEM, GEM)[0]).toMatchObject({ position: 1, length: 4 });
  });
  it('C and V hold a long sound, whichever way it is written', () => {
    expect(matchesAt('endsWith', [cl('V')], 'keː', inv)).toBe(true);
    expect(matchesAt('endsWith', [cl('V'), cl('C')], 'keːt', inv)).toBe(true);
    expect(matchesAt('startsWith', [cl('C'), cl('V')], 'tːa', inv)).toBe(true);
    expect(matchesAt('contains', [cl('stop')], 'atːa', inv)).toBe(true);
  });
  it('a user class means exactly what it lists', () => {
    const own = buildInventory([P('t', 'consonant'), P('e', 'vowel', 1), P('i', 'vowel', 2), P('iː', 'vowel', 3)], [{ id: 9, name: 'short', phonemeIds: [1] }, { id: 10, name: 'long', phonemeIds: [3] }]);
    expect(matchesAt('contains', [cl('short')], 'te', own)).toBe(true);
    expect(matchesAt('contains', [cl('short')], 'teː', own)).toBe(false);
    expect(matchesAt('contains', [cl('long')], 'tiː', own)).toBe(true);
  });
  it('a user class named the same replaces the built-in', () => {
    const own = buildInventory([P('t', 'consonant', 1), P('k', 'consonant', 2), P('a', 'vowel', 3)], [{ id: 9, name: 'Geminate', phonemeIds: [2] }]);
    expect(resolveClass('geminate', own)).toEqual(['k']);
    expect(matchesAt('contains', [GEM], 'atta', own)).toBe(false);
    expect(matchesAt('contains', [GEM], 'aka', own)).toBe(true);
  });
  it('the generator uses them in templates, writing each sound one way', () => {
    const small = buildInventory([P('t', 'consonant', 1), P('r', 'consonant', 2), P('rː', 'consonant', 3), P('a', 'vowel', 4)], []);
    expect(resolveClass('geminate', small).sort()).toEqual(['rː', 'tt']);
    expect(resolveClass('long vowel', small)).toEqual(['aː']);
    const words = generateWords({ templates: [{ id: 1, segments: [{ kind: 'sound', text: 'a' }, GEM, LONG], active: true }], constraints: [], inventory: small, count: 20, minSyllables: 1, maxSyllables: 1 });
    expect(new Set(words)).toEqual(new Set(['attaː', 'arːaː']));
  });
  it('generated words respect a constraint on them', () => {
    const small = buildInventory([P('t', 'consonant', 1), P('a', 'vowel', 2)], []);
    const words = generateWords({ templates: [{ id: 1, segments: [{ kind: 'sound', text: 'a' }, GEM, { kind: 'sound', text: 't' }], active: true }, { id: 2, segments: [{ kind: 'sound', text: 'ta' }], active: true }], constraints: [{ id: 1, kind: 'sequence', segments: [GEM, cl('C')], position: 'anywhere', active: true }], inventory: small, count: 20, minSyllables: 1, maxSyllables: 1 });
    expect(words.length).toBeGreaterThan(0);
    expect(new Set(words)).toEqual(new Set(['ta']));
  });
  it('rewrite rules and the replace operation can use them', () => {
    const rw = (r: { input: ReturnType<typeof cl>[] | { kind: 'sound'; text: string }[]; output: string; left?: ReturnType<typeof cl>[]; right?: ReturnType<typeof cl>[] }) => ({ id: 1, left: [], right: [], ...r });
    expect(applyRewriteRules('atta', [rw({ input: [GEM], output: 'ʔ' })], inv)).toBe('aʔa');
    expect(applyRewriteRules('teːt', [rw({ input: [LONG], output: 'ie' })], inv)).toBe('tiet');
    expect(applyRewriteRules('attan', [rw({ input: [{ kind: 'sound', text: 'a' }], output: 'o', left: [GEM] })], inv)).toBe('atton');
    const rep = applyRule(rule(ops({ type: 'replace', from: GEM, to: 'd', count: null, direction: 'fromStart' })), 'attakka', inv);
    expect(rep.ok && rep.form).toBe('adada');
  });
  it('a rewrite context sees past a length mark held only as a mark', () => {
    const r = { id: 1, input: [{ kind: 'sound' as const, text: 't' }], output: 'd', left: [cl('V')], right: [cl('V')] };
    expect(applyRewriteRules('keːta', [r], inv)).toBe('keːda');
    expect(applyRewriteRules('kaːta', [r], inv)).toBe('kaːda');
    expect(applyRewriteRules('keːtːa', [r], inv)).toBe('keːtːa');
    expect(applyRewriteRules('kata', [r], inv)).toBe('kada');
  });
  it('the gemination constraint still reads the vowel after a geminate', () => {
    const g = (w: string) => validateWord(w, [{ id: 1, kind: 'gemination', positions: ['coda'], active: true }], inv);
    expect(g('atteː')).toEqual([]);
    expect(g('att')).toHaveLength(1);
  });
  it('a form elongation makes is what the classes recognize', () => {
    const el = (target: 'vowel' | 'consonant') => rule(ops({ type: 'elongate', target, index: 1, direction: 'fromStart' }));
    for (const w of ['tem', 'tam']) {
      const r = applyRule(el('vowel'), w, inv);
      expect(r.ok && matchesAt('contains', [LONG], r.form, inv)).toBe(true);
    }
    for (const w of ['ata', 'ara']) {
      const r = applyRule(el('consonant'), w, inv);
      expect(r.ok && matchesAt('contains', [GEM], r.form, inv)).toBe(true);
    }
  });
});

describe('elongation through the engine', () => {
  const setup = () => {
    const d = emptyProject('T');
    for (const s of ['k', 't', 'l']) c.addPhoneme(d, { symbol: s, type: 'consonant' });
    for (const s of ['a', 'i']) c.addPhoneme(d, { symbol: s, type: 'vowel' });
    for (const [p, l] of [['k', 'k'], ['t', 't'], ['l', 'l'], ['a', 'a'], ['i', 'i'], ['aː', 'ā']]) c.saveRomanization(d, null, p, l);
    const n = c.savePos(d, null, 'Noun', 'n');
    const num = c.addDimension(d, n, 'Number', [{ name: 'Sg', abbr: 'sg' }, { name: 'Pl', abbr: 'pl' }], null);
    c.saveRule(d, null, { name: 'Plural', kind: 'inflectional', branches: [ops({ type: 'elongate', target: 'vowel', index: 1, direction: 'fromEnd' })], posIds: [n], bindings: { [num]: 2 }, inputPosId: null, outputPosId: null, outputIntrinsic: {}, autoApply: false });
    return { d, n, num };
  };
  it('fills paradigm cells, romanizes the long vowel, and round-trips in phrase analysis', () => {
    const { d, n, num } = setup();
    const kata = c.addWord(d, { phonemic: 'kata', posId: n, meaning: 'stone' });
    const e = new LanguageEngine(d);
    expect(e.paradigm(kata).cells.get(featureKey({ [num]: 2 }))).toMatchObject({ kind: 'filled', phonemic: 'kataː', roman: 'katā' });
    expect(e.analyzePhrase('katā')[0].matches[0].gloss).toBe('stone.PL');
    expect(e.analyzePhrase('kataː')[0].matches[0].gloss).toBe('stone.PL');
  });
  it('says in the paradigm when a word has too few sounds', () => {
    const { d, n, num } = setup();
    d.rules[0].branches = [ops({ type: 'elongate', target: 'vowel', index: 3, direction: 'fromStart' })];
    const kata = c.addWord(d, { phonemic: 'kata', posId: n, meaning: 'stone' });
    expect(new LanguageEngine(d).paradigm(kata).cells.get(featureKey({ [num]: 2 }))).toMatchObject({ kind: 'uncovered', reason: expect.stringContaining('/kata/ has no third vowel') });
  });
  it('a word typed with the long letter is already long, because rules see the phonemic form', () => {
    const { d, n, num } = setup();
    const word = c.addWord(d, { phonemic: new LanguageEngine(d).deromanize('katā'), posId: n, meaning: 'stone' });
    const e = new LanguageEngine(d);
    expect(e.form(word)).toMatchObject({ phonemic: 'kataː', roman: 'katā' });
    expect(e.paradigm(word).cells.get(featureKey({ [num]: 2 }))).toMatchObject({ phonemic: 'kataː', roman: 'katā' });
  });
  it('adding a long vowel romanization files the new phoneme as a vowel with its short vowel’s features', () => {
    const d = emptyProject('T');
    c.saveRomanization(d, null, 'aː', 'ā');
    c.saveRomanization(d, null, 'tː', 'tt');
    expect(d.phonemes[0]).toMatchObject({ symbol: 'aː', type: 'vowel', height: 'open' });
    expect(d.phonemes[1]).toMatchObject({ symbol: 'tː', type: 'consonant', manner: 'plosive' });
    expect(c.featuresForSymbol('ː')).toBeNull();
  });
  it('names long vowels with no romanization', () => {
    const { d } = setup();
    const e = new LanguageEngine(d);
    expect(e.unromanizedLongVowels()).toEqual(['iː']);
    c.setRomanizationEnabled(d, false);
    expect(new LanguageEngine(d).unromanizedLongVowels()).toEqual([]);
  });
});

describe('legacy import', () => {
  const lit = (t: string) => t;
  const conv = (s: string) => legacyRuleToBranches(s, lit, new Set(['stop']));
  it('reads every stored rule shape', () => {
    expect(conv('+a')).toEqual([{ conditions: [], operations: [{ type: 'suffix', affix: 'a' }] }]);
    expect(conv('"C"$ +a | "V"$ /V/a/e1')).toEqual([
      { conditions: [{ position: 'endsWith', segments: [{ kind: 'class', name: 'C' }] }], operations: [{ type: 'suffix', affix: 'a' }] },
      { conditions: [{ position: 'endsWith', segments: [{ kind: 'class', name: 'V' }] }], operations: [{ type: 'replace', from: { kind: 'class', name: 'V' }, to: 'a', count: 1, direction: 'fromEnd' }] },
    ]);
    expect(conv('^"a""b"$ un+')![0].conditions).toHaveLength(2);
    expect(conv('[stop_] -"o" +in')![0]).toMatchObject({ conditions: [{ position: 'endsWith', segments: [{ kind: 'class', name: 'stop' }] }], operations: [{ type: 'removeSuffix', suffix: 'o' }, { type: 'suffix', affix: 'in' }] });
    expect(conv('{_k} infix:um:1')![0].conditions[0].position).toBe('startsWith');
    expect(conv('redup:CV:prefix')![0].operations[0]).toEqual({ type: 'reduplicate', scope: 'CV', position: 'prefix' });
    expect(conv('="went"')![0].operations[0]).toEqual({ type: 'suppletive', form: 'went' });
    expect(conv('1a23aa')![0].operations[0]).toMatchObject({ type: 'template', parts: [{ kind: 'slot', index: 1 }, { kind: 'sound', text: 'a' }, { kind: 'slot', index: 2 }, { kind: 'slot', index: 3 }, { kind: 'sound', text: 'aa' }] });
    expect(conv('/a/o/')![0].operations[0]).toMatchObject({ from: { kind: 'sound', text: 'a' }, count: null });
    expect(conv('???')).toBeNull();
  });
  it('reads patterns and rewrite rules', () => {
    expect(patternToSegments('(C)(C)V(C)')).toEqual([{ kind: 'class', name: 'C', optional: true }, { kind: 'class', name: 'C', optional: true }, { kind: 'class', name: 'V' }, { kind: 'class', name: 'C', optional: true }]);
    expect(patternToSegments('[stop]a')).toEqual([{ kind: 'class', name: 'stop' }, { kind: 'sound', text: 'a' }]);
    expect(legacyRewrite('t -> ʔ / _#')).toMatchObject({ output: 'ʔ', left: [], right: [{ kind: 'boundary' }] });
    expect(legacyRewrite('nope')).toBeNull();
  });
});
