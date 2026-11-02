import { describe, expect, it } from 'vitest';
import * as c from '../src/core/commands';
import { LanguageEngine } from '../src/core/engine';
import { featureKey } from '../src/core/paradigm';
import type { ProjectDoc, Branch } from '../src/core/types';
import { engine, project, run } from './helpers';

const suffix = (a: string): Branch[] => [{ conditions: [], operations: [{ type: 'suffix', affix: a }] }];

function base(): { doc: ProjectDoc; v: number; n: number; adj: number; a: number; o: number; kal: number } {
  let v = 0, n = 0, adj = 0, a = 0, o = 0, kal = 0;
  const doc = project((d) => {
    for (const s of ['k', 'l', 't', 'm']) c.addPhoneme(d, { symbol: s, type: 'consonant' });
    for (const s of ['a', 'o', 'i']) c.addPhoneme(d, { symbol: s, type: 'vowel' });
    v = c.savePos(d, null, 'Verb', 'v');
    n = c.savePos(d, null, 'Noun', 'n');
    adj = c.savePos(d, null, 'Adjective', 'adj');
    a = c.saveRule(d, null, { name: 'Nominal', kind: 'derivational', branches: suffix('a'), posIds: [], bindings: {}, inputPosId: v, outputPosId: n, outputIntrinsic: {}, autoApply: false });
    o = c.saveRule(d, null, { name: 'Adjectival', kind: 'derivational', branches: suffix('o'), posIds: [], bindings: {}, inputPosId: n, outputPosId: adj, outputIntrinsic: {}, autoApply: false });
    kal = c.addWord(d, { phonemic: 'kal', posId: v, meaning: 'to run' });
  });
  return { doc, v, n, adj, a, o, kal };
}

describe('derivation chains', () => {
  it('derives from the derived form, not the root (kal -> kala -> kalao)', () => {
    const { doc, kal, a, o } = base();
    let nounId = 0;
    let adjId = 0;
    const next = run(doc, (d) => {
      nounId = c.promoteDerivation(d, kal, a, 'runner');
      adjId = c.promoteDerivation(d, nounId, o, 'runner-like');
    });
    const e = engine(next);
    expect(e.form(nounId).phonemic).toBe('kala');
    expect(e.form(adjId).phonemic).toBe('kalao');
    expect(e.form(adjId).chain.map((s) => s.rule.name)).toEqual(['Nominal', 'Adjectival']);
    expect(e.derivationOptions(nounId).map((x) => x.phonemic)).toEqual(['kalao']);
  });

  it('a derived word stores no phonemes, so a parent edit flows through', () => {
    const { doc, kal, a } = base();
    let id = 0;
    let next = run(doc, (d) => { id = c.promoteDerivation(d, kal, a, 'runner'); });
    expect(next.lexemes.find((l) => l.id === id)!.form).toEqual({ kind: 'derived', parentId: kal, ruleId: a });
    next = run(next, (d) => c.updateWord(d, kal, { phonemic: 'tam' }));
    expect(engine(next).form(id).phonemic).toBe('tama');
  });

  it('a rule edit flows to every derived word', () => {
    const { doc, kal, a, v, n } = base();
    let id = 0;
    let next = run(doc, (d) => { id = c.promoteDerivation(d, kal, a, 'runner'); });
    next = run(next, (d) => c.saveRule(d, a, { name: 'Nominal', kind: 'derivational', branches: suffix('i'), posIds: [], bindings: {}, inputPosId: v, outputPosId: n, outputIntrinsic: {}, autoApply: false }));
    expect(engine(next).form(id).phonemic).toBe('kali');
  });

  it('every consumer sees the derived form rather than the parent', () => {
    const { doc, kal, a, n } = base();
    let id = 0;
    let next = run(doc, (d) => {
      id = c.promoteDerivation(d, kal, a, 'runner');
      const dim = c.addDimension(d, n, 'Number', [{ name: 'Singular', abbr: 'sg' }, { name: 'Plural', abbr: 'pl' }], null);
      const pl = d.dimensions.find((x) => x.id === dim)!.levels[1].id;
      c.saveRule(d, null, { name: 'Plural', kind: 'inflectional', branches: suffix('m'), posIds: [n], bindings: { [dim]: pl }, inputPosId: null, outputPosId: null, outputIntrinsic: {}, autoApply: false });
      c.saveSequenceConstraint(d, null, [{ kind: 'sound', text: 'la' }], 'anywhere', 'no la');
    });
    const e = new LanguageEngine(next);
    expect(e.wordList('kala', new Set()).map((x) => x.lexeme.id)).toContain(id);
    const cells = [...e.paradigm(id).cells.values()];
    expect(cells.some((x) => x.kind === 'filled' && x.phonemic === 'kalam')).toBe(true);
    expect(e.wordViolations(id).length).toBe(1);
    expect(e.wordViolations(kal).length).toBe(0);
    const reading = e.analyzePhrase('kala')[0].matches[0];
    expect(reading.kind).toBe('word');
    if (reading.kind === 'word') expect(reading.lexeme.id).toBe(id);
    expect(e.analyzePhrase('kalam')[0].matches[0].gloss).toContain('runner');
    next = run(next, (d) => c.saveSequenceConstraint(d, null, [{ kind: 'sound', text: 'k' }], 'start', ''));
  });

  it('reports a broken derivation instead of showing the parent form', () => {
    const { doc, kal } = base();
    let rid = 0;
    let id = 0;
    const next = run(doc, (d) => {
      const verb = d.partsOfSpeech[0].id;
      rid = c.saveRule(d, null, { name: 'Only-t', kind: 'derivational', branches: [{ conditions: [{ position: 'startsWith', segments: [{ kind: 'sound', text: 't' }] }], operations: [{ type: 'suffix', affix: 'o' }] }], posIds: [], bindings: {}, inputPosId: verb, outputPosId: verb, outputIntrinsic: {}, autoApply: false });
      id = d.nextId++;
      d.lexemes.push({ id, form: { kind: 'derived', parentId: kal, ruleId: rid }, posId: verb, isException: false, rootOnly: false, skippedDimensionIds: [], intrinsicLevels: {} });
    });
    const f = engine(next).form(id);
    expect(f.status).toBe('broken');
    expect(f.phonemic).toBe('');
    expect(f.reason).toContain('Only-t');
  });

  it('survives derivation cycles', () => {
    const { doc, a } = base();
    const next = run(doc, (d) => {
      d.lexemes.push({ id: 900, form: { kind: 'derived', parentId: 901, ruleId: a }, posId: null, isException: false, rootOnly: false, skippedDimensionIds: [], intrinsicLevels: {} });
      d.lexemes.push({ id: 901, form: { kind: 'derived', parentId: 900, ruleId: a }, posId: null, isException: false, rootOnly: false, skippedDimensionIds: [], intrinsicLevels: {} });
    });
    expect(engine(next).form(900).status).toBe('broken');
  });

  it('exceptions apply both to the option and to the committed word', () => {
    const { doc, kal, a } = base();
    let id = 0;
    const next = run(doc, (d) => {
      c.addException(d, kal, a, 'kolo');
      id = c.promoteDerivation(d, kal, a, 'runner');
    });
    const e = engine(next);
    expect(e.derivationOptions(kal)[0]).toMatchObject({ phonemic: 'kolo', isException: true });
    expect(e.form(id).phonemic).toBe('kolo');
  });

  it('hand-editing a derived word detaches it but keeps the parent link', () => {
    const { doc, kal, a } = base();
    let id = 0;
    const next = run(doc, (d) => {
      id = c.promoteDerivation(d, kal, a, 'runner');
      c.updateWord(d, id, { phonemic: 'kolt' });
    });
    const l = next.lexemes.find((x) => x.id === id)!;
    expect(l.form).toMatchObject({ kind: 'detached', parentId: kal, phonemic: 'kolt' });
    expect(engine(next).form(id).phonemic).toBe('kolt');
    const after = run(next, (d) => c.updateWord(d, kal, { phonemic: 'tam' }));
    expect(engine(after).form(id).phonemic).toBe('kolt');
  });

  it('editing only the meaning of a derived word does not detach it', () => {
    const { doc, kal, a } = base();
    let id = 0;
    const next = run(doc, (d) => {
      id = c.promoteDerivation(d, kal, a, 'runner');
      const current = new LanguageEngine(d).form(id);
      c.updateWord(d, id, { phonemic: current.phonemic, meaning: 'sprinter' });
    });
    expect(next.lexemes.find((x) => x.id === id)!.form.kind).toBe('derived');
  });

  it('deleting a parent or rule freezes derived words at their current form', () => {
    const { doc, kal, a, o } = base();
    let noun = 0;
    let adj = 0;
    const withWords = run(doc, (d) => {
      noun = c.promoteDerivation(d, kal, a, 'runner');
      adj = c.promoteDerivation(d, noun, o, 'runner-like');
    });
    const noParent = run(withWords, (d) => c.deleteWord(d, kal));
    expect(engine(noParent).form(noun)).toMatchObject({ status: 'ok', phonemic: 'kala', origin: 'root' });
    expect(engine(noParent).form(adj).phonemic).toBe('kalao');
    const noRule = run(withWords, (d) => c.deleteRule(d, a));
    expect(engine(noRule).form(noun)).toMatchObject({ status: 'ok', phonemic: 'kala', origin: 'root' });
    expect(engine(noRule).form(adj).phonemic).toBe('kalao');
  });

  describe('automatic derivations', () => {
    const setup = () => {
      const { doc, v, n, kal } = base();
      let rid = 0;
      const next = run(doc, (d) => {
        rid = c.saveRule(d, null, { name: 'Actor', kind: 'derivational', branches: suffix('m'), posIds: [], bindings: {}, inputPosId: v, outputPosId: n, outputIntrinsic: {}, autoApply: true });
      });
      return { next, v, n, kal, rid };
    };
    const generated = (doc: ProjectDoc, parent: number, rid: number) => engine(doc).derivationOptions(parent).find((o) => o.rule.id === rid)!.child!;

    it('stores no word, yet the word exists wherever it is needed', () => {
      const { next, kal, rid, n } = setup();
      expect(next.lexemes).toHaveLength(1);
      const e = engine(next);
      const word = generated(next, kal, rid);
      expect(word).toMatchObject({ meaning: 'to run (Actor)', posId: n });
      expect(e.form(word.id)).toMatchObject({ phonemic: 'kalm', origin: 'derived' });
      expect(e.wordList('', new Set()).map((x) => x.lexeme.id)).toEqual([kal]);
      expect(e.wordList('', new Set(), true).map((x) => x.lexeme.id)).toContain(word.id);
      expect(e.wordList('kalm', new Set()).find((x) => x.lexeme.id === word.id)?.automatic).toBe(true);
      expect(e.analyzePhrase('kalm')[0].matches[0].gloss).toBe('to run (Actor)');
      expect(e.childrenOf(kal).map((x) => x.lexeme.id)).toContain(word.id);
      expect(e.ancestry(word.id)!.parents[0].lexemeId).toBe(kal);
    });

    it('changing the rule changes every word, and a new word gets it immediately', () => {
      const { next, kal, rid, v, n } = setup();
      const changed = run(next, (d) => {
        c.saveRule(d, rid, { name: 'Actor', kind: 'derivational', branches: suffix('t'), posIds: [], bindings: {}, inputPosId: v, outputPosId: n, outputIntrinsic: {}, autoApply: true });
        c.addWord(d, { phonemic: 'tim', posId: v, meaning: 'to go' });
      });
      expect(changed.lexemes).toHaveLength(2);
      expect(engine(changed).form(generated(changed, kal, rid).id).phonemic).toBe('kalt');
      const tim = changed.lexemes[1].id;
      expect(engine(changed).form(generated(changed, tim, rid).id).phonemic).toBe('timt');
    });

    it('a meaning or irregular form is saved on top and the word keeps following its rule', () => {
      const { next, kal, rid, v, n } = setup();
      const id = generated(next, kal, rid).id;
      const withMeaning = run(next, (d) => c.updateWord(d, id, { meaning: 'sprinter' }));
      expect(engine(withMeaning).lexeme(id)!.meaning).toBe('sprinter');
      expect(engine(withMeaning).wordList('', new Set())).toHaveLength(1);
      const row = withMeaning.lexemes.find((l) => l.form.kind === 'derived')!;
      expect(JSON.stringify(row.form)).not.toContain('kalm');
      const rewritten = run(withMeaning, (d) => c.saveRule(d, rid, { name: 'Actor', kind: 'derivational', branches: suffix('t'), posIds: [], bindings: {}, inputPosId: v, outputPosId: n, outputIntrinsic: {}, autoApply: true }));
      expect(engine(rewritten).form(id)).toMatchObject({ phonemic: 'kalt' });
      expect(engine(rewritten).lexeme(id)!.meaning).toBe('sprinter');

      const irregular = run(rewritten, (d) => c.updateWord(d, id, { phonemic: 'kolo' }));
      expect(engine(irregular).form(id)).toMatchObject({ phonemic: 'kolo', origin: 'derived' });
      expect(irregular.exceptions).toHaveLength(1);
      const undone = run(irregular, (d) => c.updateWord(d, id, { phonemic: 'kalt' }));
      expect(undone.exceptions).toHaveLength(0);

      const reset = run(undone, (d) => c.resetAutomaticWord(d, id));
      expect(reset.lexemes).toHaveLength(1);
      expect(engine(reset).lexeme(id)!.meaning).toBe('to run (Actor)');
    });

    it('the template meaning stays live until a meaning is really set', () => {
      const { next, kal, rid } = setup();
      const id = generated(next, kal, rid).id;
      const same = run(next, (d) => c.updateWord(d, id, { meaning: 'to run (Actor)' }));
      expect(same.lexemes).toHaveLength(1);
      const renamed = run(same, (d) => c.updateWord(d, kal, { meaning: 'to dash' }));
      expect(engine(renamed).lexeme(id)!.meaning).toBe('to dash (Actor)');
    });

    it('chains through automatic rules without looping', () => {
      const { doc, v, n, adj, kal } = base();
      const auto = (name: string, a: string, i: number, o: number) => (d: ProjectDoc) => c.saveRule(d, null, { name, kind: 'derivational', branches: suffix(a), posIds: [], bindings: {}, inputPosId: i, outputPosId: o, outputIntrinsic: {}, autoApply: true });
      const next = run(doc, (d) => {
        for (const r of d.rules.slice()) c.deleteRule(d, r.id);
        auto('Nom', 'a', v, n)(d);
        auto('Adj', 'o', n, adj)(d);
        auto('Dim', 'i', n, n)(d);
      });
      const e = engine(next);
      const forms = e.dynamicWords().map((w) => e.form(w.id).phonemic).sort();
      expect(forms).toEqual(['kala', 'kalai', 'kalaio', 'kalao']);
      expect(kal).toBeGreaterThan(0);
    });

    it('a case-by-case rule is unaffected', () => {
      const { doc, kal, a } = base();
      expect(engine(doc).derivationOptions(kal).find((o) => o.rule.id === a)!.child).toBeNull();
      expect(engine(doc).derivationSuggestions(kal)).toHaveLength(1);
    });

    it('deleting the rule keeps saved details as a standalone word and drops the rest', () => {
      const { next, kal, rid } = setup();
      const id = generated(next, kal, rid).id;
      const saved = run(next, (d) => c.updateWord(d, id, { meaning: 'sprinter' }));
      const gone = run(saved, (d) => c.deleteRule(d, rid));
      expect(gone.lexemes.map((l) => l.meaning).sort()).toEqual(['sprinter', 'to run']);
      expect(engine(gone).dynamicWords()).toEqual([]);
    });
  });

  it('a derived word inherits intrinsic levels from its rule', () => {
    const { doc, kal, v, n } = base();
    let dim = 0;
    let id = 0;
    const next = run(doc, (d) => {
      dim = c.addDimension(d, n, 'Gender', [{ name: 'Masc', abbr: 'm' }, { name: 'Fem', abbr: 'f' }], null);
      c.setDimensionIntrinsic(d, dim, true);
      const fem = d.dimensions.find((x) => x.id === dim)!.levels[1].id;
      const rid = c.saveRule(d, null, { name: 'Fem-agent', kind: 'derivational', branches: suffix('i'), posIds: [], bindings: {}, inputPosId: v, outputPosId: n, outputIntrinsic: { [dim]: fem }, autoApply: false });
      id = c.promoteDerivation(d, kal, rid, 'runner');
    });
    const e = engine(next);
    const l = e.lexeme(id)!;
    expect(e.intrinsicLevels(l)[dim]).toBe(2);
  });
});

describe('forms and notation layers', () => {
  it('keeps phonemic, phonetic and roman apart', () => {
    let id = 0;
    const doc = project((d) => {
      c.addPhoneme(d, { symbol: 's', type: 'consonant' });
      c.addPhoneme(d, { symbol: 'a', type: 'vowel' });
      c.addPhoneme(d, { symbol: 'n', type: 'consonant' });
      d.romanization.push({ id: 100, phoneme: 's', latin: 'c' });
      d.romanization.push({ id: 101, phoneme: 'a', latin: 'a' });
      d.romanization.push({ id: 102, phoneme: 'n', latin: 'n' });
      c.saveRewriteRule(d, null, { input: [{ kind: 'sound', text: 's' }], output: 'z', left: [{ kind: 'class', name: 'V' }], right: [{ kind: 'class', name: 'V' }] });
      id = c.addWord(d, { phonemic: 'sasana', posId: null, rootOnly: true });
    });
    const f = engine(doc).form(id);
    expect(f.phonemic).toBe('sasana');
    expect(f.phonetic).toBe('sazana');
    expect(f.roman).toBe('cacana');
  });

  it('rewrites partial inflection results too', () => {
    let id = 0, num = 0, cas = 0;
    const doc = project((d) => {
      for (const s of ['s', 'n']) c.addPhoneme(d, { symbol: s, type: 'consonant' });
      c.addPhoneme(d, { symbol: 'a', type: 'vowel' });
      const p = c.savePos(d, null, 'Noun', 'n');
      num = c.addDimension(d, p, 'Number', [{ name: 'Sg', abbr: 'sg' }, { name: 'Pl', abbr: 'pl' }], null);
      cas = c.addDimension(d, p, 'Case', [{ name: 'Nom', abbr: 'nom' }, { name: 'Acc', abbr: 'acc' }], null);
      c.saveRule(d, null, { name: 'Plural', kind: 'inflectional', branches: suffix('sa'), posIds: [p], bindings: { [num]: 2 }, inputPosId: null, outputPosId: null, outputIntrinsic: {}, autoApply: false });
      c.saveRewriteRule(d, null, { input: [{ kind: 'sound', text: 's' }], output: 'z', left: [{ kind: 'class', name: 'V' }], right: [{ kind: 'class', name: 'V' }] });
      id = c.addWord(d, { phonemic: 'na', posId: p });
    });
    const cell = engine(doc).paradigm(id).cells.get(featureKey({ [num]: 2, [cas]: 1 }))!;
    expect(cell).toMatchObject({ kind: 'filled', phonemic: 'nasa', phonetic: 'naza', partial: true });
  });
});
