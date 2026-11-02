// Applies a structured rule to a phonemic form. Pure: no project state.

import type { Branch, MorphRule, Operation, TemplatePart } from './types';
import { isOfKind, longForm, matchesAt, resolveClass, tokenize, type Inventory, type Token } from './phonology';

export type RuleResult = { ok: true; form: string } | { ok: false; reason: string };

function isConsonant(sym: string, inv: Inventory) {
  return inv.consonants.includes(sym);
}

function applyInfix(form: string, affix: string, n: number, inv: Inventory): string {
  const tokens = tokenize(form, inv);
  let seen = 0;
  for (let i = 0; i < tokens.length; i++) {
    if (isConsonant(tokens[i].symbol, inv) && ++seen === n) {
      const at = tokens[i].offset + tokens[i].symbol.length;
      return form.slice(0, at) + affix + form.slice(at);
    }
  }
  return form + affix;
}

function applyReplace(form: string, op: Extract<Operation, { type: 'replace' }>, inv: Inventory): string {
  const members = op.from.kind === 'class' ? resolveClass(op.from.name, inv) : null;
  const extras = op.from.kind === 'sound' ? (op.from.text.length > 1 ? [op.from.text] : []) : (members ?? []).filter((m) => m.length > 1);
  const tokens = tokenize(form, inv, extras);
  const matched = tokens.flatMap((t, i) => {
    const hit = members ? members.includes(t.symbol) : t.symbol === (op.from as { text: string }).text;
    return hit ? [i] : [];
  });
  let chosen: number[];
  if (op.count === null) chosen = matched;
  else if (op.direction === 'fromEnd') chosen = matched.slice(-op.count);
  else chosen = matched.slice(0, op.count);
  const set = new Set(chosen);
  return tokens.map((t, i) => (set.has(i) ? op.to : t.symbol)).join('');
}

function applyTemplate(form: string, parts: TemplatePart[], inv: Inventory): RuleResult {
  const consonants = tokenize(form, inv).map((t) => t.symbol).filter((s) => isConsonant(s, inv));
  let out = '';
  for (const p of parts) {
    if (p.kind === 'sound') {
      out += p.text;
      continue;
    }
    const c = consonants[p.index - 1];
    if (c === undefined) return { ok: false, reason: `The root has no consonant ${p.index} for this template.` };
    out += c;
  }
  return { ok: true, form: out };
}

function applyRedup(form: string, scope: 'full' | 'CV' | 'C', position: 'prefix' | 'suffix', inv: Inventory): string {
  const tokens = tokenize(form, inv);
  let part = form;
  if (scope === 'C') {
    part = tokens.find((t) => isConsonant(t.symbol, inv))?.symbol ?? '';
  } else if (scope === 'CV') {
    const c = tokens.findIndex((t) => isConsonant(t.symbol, inv));
    const v = c < 0 ? -1 : tokens.findIndex((t, i) => i > c && inv.vowels.includes(t.symbol));
    part = c < 0 ? form : tokens[c].symbol + (v >= 0 ? tokens[v].symbol : '');
  }
  return position === 'prefix' ? part + form : form + part;
}

const ORDINALS = { 1: 'first', 2: 'second', 3: 'third' };

type Kind = 'vowel' | 'consonant';
type Direction = 'fromStart' | 'fromEnd';

/**
 * Finds the nth sound of a kind. tt or aa is one long sound, so it counts once.
 * Returns its first token, or a reason when the word has too few.
 */
function pickSound(form: string, tokens: Token[], kind: Kind, index: 1 | 2 | 3, direction: Direction, inv: Inventory): { at: number } | { reason: string } {
  const spots = tokens.flatMap((t, i) => (isOfKind(t.symbol, kind, inv) && tokens[i - 1]?.symbol !== t.symbol ? [i] : []));
  const fromEnd = direction === 'fromEnd';
  const at = spots[fromEnd ? spots.length - index : index - 1];
  return at === undefined ? { reason: `/${form}/ has no ${ORDINALS[index]} ${kind}${fromEnd ? ' from the end' : ''}.` } : { at };
}

/**
 * A long vowel is written with ː. A geminate is a doubled consonant, which is
 * what the gemination constraint looks for, unless the language has its own
 * long phoneme such as rː. A sound that is already long stays as it is.
 */
function applyElongate(form: string, op: Extract<Operation, { type: 'elongate' }>, inv: Inventory): RuleResult {
  const tokens = tokenize(form, inv);
  const picked = pickSound(form, tokens, op.target, op.index, op.direction, inv);
  if ('reason' in picked) return { ok: false, reason: picked.reason };
  const { symbol } = tokens[picked.at];
  const next = tokens[picked.at + 1]?.symbol;
  if (symbol.endsWith('ː') || next === 'ː' || next === symbol) return { ok: true, form };
  const result = longForm(symbol, op.target, inv);
  return { ok: true, form: tokens.map((t, i) => (i === picked.at ? result : t.symbol)).join('') };
}

function applyOperation(form: string, op: Operation, inv: Inventory): RuleResult {
  switch (op.type) {
    case 'prefix':
      return { ok: true, form: op.affix + form };
    case 'suffix':
      return { ok: true, form: form + op.affix };
    case 'infix':
      return { ok: true, form: applyInfix(form, op.affix, op.afterConsonant, inv) };
    case 'replace':
      return { ok: true, form: applyReplace(form, op, inv) };
    case 'template':
      return applyTemplate(form, op.parts, inv);
    case 'reduplicate':
      return { ok: true, form: applyRedup(form, op.scope, op.position, inv) };
    case 'elongate':
      return applyElongate(form, op, inv);
    case 'suppletive':
      return { ok: true, form: op.form };
    case 'removeSuffix':
      return { ok: true, form: form.endsWith(op.suffix) ? form.slice(0, form.length - op.suffix.length) : form };
    default:
      // A file saved by a version that had an operation this one no longer has.
      return { ok: false, reason: `This rule uses an operation that no longer exists (${(op as { type: string }).type}). Edit the rule to replace it.` };
  }
}

export function branchMatches(branch: Branch, form: string, inv: Inventory): boolean {
  if (branch.conditions.length === 0) return true;
  if (!form) return false;
  return branch.conditions.every((c) => matchesAt(c.position, c.segments, form, inv));
}

/** The first branch whose conditions all hold wins. */
export function applyRule(rule: Pick<MorphRule, 'branches'>, form: string, inv: Inventory): RuleResult {
  if (!form) return { ok: false, reason: 'Root is empty' };
  for (const branch of rule.branches) {
    if (!branchMatches(branch, form, inv)) continue;
    let working = form;
    for (const op of branch.operations) {
      const r = applyOperation(working, op, inv);
      if (!r.ok) return r;
      working = r.form;
    }
    return { ok: true, form: working };
  }
  return { ok: false, reason: `No branch matched root "${form}"` };
}

export interface UnknownPhoneme {
  char: string;
}

/** Scans literal text in a rule for characters outside the inventory. */
export function unknownPhonemes(texts: string[], inv: Inventory): UnknownPhoneme[] {
  const known = [...inv.consonants, ...inv.vowels].sort((a, b) => b.length - a.length);
  const out: UnknownPhoneme[] = [];
  for (const t of texts) {
    let i = 0;
    while (i < t.length) {
      const m = known.find((p) => t.startsWith(p, i));
      if (m) {
        i += m.length;
      } else {
        const ch = String.fromCodePoint(t.codePointAt(i)!);
        out.push({ char: ch });
        i += ch.length;
      }
    }
  }
  return out;
}

export function literalTexts(rule: Pick<MorphRule, 'branches'>): string[] {
  const out: string[] = [];
  for (const b of rule.branches) {
    for (const c of b.conditions) for (const s of c.segments) if (s.kind === 'sound') out.push(s.text);
    for (const op of b.operations) {
      switch (op.type) {
        case 'prefix':
        case 'suffix':
        case 'infix':
          out.push(op.affix);
          break;
        case 'replace':
          if (op.from.kind === 'sound') out.push(op.from.text);
          out.push(op.to);
          break;
        case 'template':
          for (const p of op.parts) if (p.kind === 'sound') out.push(p.text);
          break;
        case 'suppletive':
          out.push(op.form);
          break;
        case 'removeSuffix':
          out.push(op.suffix);
          break;
        case 'reduplicate':
        case 'elongate':
          break;
      }
    }
  }
  return out;
}
