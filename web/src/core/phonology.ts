// Inventory, tokenization, segment matching, word generation, validation,
// rewrite rules and allophones. All pure functions over structured data.

import type {
  Constraint,
  GeminationPosition,
  NaturalClass,
  Phoneme,
  RewriteRule,
  Segment,
  SyllableTemplate,
} from './types';

const STOPS = ['p', 'b', 't', 'd', 'ʈ', 'ɖ', 'c', 'ɟ', 'k', 'ɡ', 'q', 'ɢ', 'ʔ'];
const NASALS = ['m', 'ɱ', 'n', 'ɳ', 'ɲ', 'ŋ', 'ɴ'];
const FRICATIVES = ['ɸ', 'β', 'f', 'v', 'θ', 'ð', 's', 'z', 'ʃ', 'ʒ', 'ʂ', 'ʐ', 'ç', 'ʝ', 'x', 'ɣ', 'χ', 'ʁ', 'ħ', 'ʕ', 'h', 'ɦ', 'ɬ', 'ɮ'];
const AFFRICATES = ['t͡s', 'd͡z', 't͡ʃ', 'd͡ʒ', 'ʈ͡ʂ', 'ɖ͡ʐ', 't͡ɕ', 'd͡ʑ'];
const APPROXIMANTS = ['j', 'w', 'ɥ', 'ɰ', 'ʋ', 'ɹ', 'ɻ', 'l', 'ɭ', 'ʎ', 'ʟ'];
const RHOTICS = ['r', 'ɾ', 'ɹ', 'ɻ', 'ɽ', 'ʀ', 'ʁ'];
const LIQUIDS = ['l', 'ɭ', 'ʎ', 'ʟ', ...RHOTICS];

export const DEFAULT_CLASSES: Record<string, string[]> = {
  stop: STOPS,
  nasal: NASALS,
  fricative: FRICATIVES,
  liquid: LIQUIDS,
  rhotic: RHOTICS,
  obstruent: [...STOPS, ...FRICATIVES, ...AFFRICATES],
  sonorant: [...NASALS, ...LIQUIDS, ...APPROXIMANTS],
  approximant: APPROXIMANTS,
  affricate: AFFRICATES,
};

/**
 * Built-in classes defined by length rather than by a list of sounds. Any sound
 * the language has counts, however its length is written: tt, tː or a phoneme rː.
 */
export const LENGTH_CLASSES: Record<string, string> = {
  geminate: 'any consonant with the elongation mark, or doubled',
  'long vowel': 'any vowel with the elongation mark, or doubled',
};

/** Case-sensitive single-letter aliases for the default classes. */
export const CLASS_ALIASES: Record<string, string> = { S: 'stop', N: 'nasal', F: 'fricative', L: 'liquid', R: 'rhotic' };

export interface Inventory {
  consonants: string[];
  vowels: string[];
  classes: Record<string, string[]>;
  /** Lowercase names of classes the user defined, which win over a built-in of the same name. */
  custom: Set<string>;
}

export const EMPTY_INVENTORY: Inventory = { consonants: [], vowels: [], classes: {}, custom: new Set() };

export function buildInventory(phonemes: Phoneme[], classes: NaturalClass[]): Inventory {
  const bySymbol = (a: Phoneme, b: Phoneme) => a.symbol.localeCompare(b.symbol);
  const consonants = phonemes.filter((p) => p.type === 'consonant').sort(bySymbol).map((p) => p.symbol);
  const vowels = phonemes.filter((p) => p.type === 'vowel').sort(bySymbol).map((p) => p.symbol);
  const have = new Set(phonemes.map((p) => p.symbol));
  const idToSymbol = new Map(phonemes.map((p) => [p.id, p.symbol]));
  const map: Record<string, string[]> = {};
  for (const [k, v] of Object.entries(DEFAULT_CLASSES)) map[k] = v.filter((s) => have.has(s));
  for (const c of classes) {
    map[c.name.toLowerCase()] = c.phonemeIds.map((id) => idToSymbol.get(id)).filter((s): s is string => !!s);
  }
  return { consonants, vowels, classes: map, custom: new Set(classes.map((c) => c.name.toLowerCase())) };
}

const LENGTH_MARK = 'ː';

export function withoutLength(symbol: string) {
  return symbol.length > 1 && symbol.endsWith(LENGTH_MARK) ? symbol.slice(0, -LENGTH_MARK.length) : symbol;
}

/** A long sound is the same kind as its short one, even if it was filed under the other kind. */
export function isOfKind(symbol: string, kind: 'vowel' | 'consonant', inv: Inventory) {
  const short = withoutLength(symbol);
  if (inv.vowels.includes(short)) return kind === 'vowel';
  if (inv.consonants.includes(short)) return kind === 'consonant';
  return (kind === 'vowel' ? inv.vowels : inv.consonants).includes(symbol);
}

/** How a sound is written when elongated: ː on a vowel, doubled for a consonant unless it has its own long phoneme. */
export function longForm(symbol: string, kind: 'vowel' | 'consonant', inv: Inventory) {
  const long = `${symbol}${LENGTH_MARK}`;
  return kind === 'vowel' || inv.consonants.includes(long) ? long : symbol + symbol;
}

function lengthClassKind(name: string, inv: Inventory): 'vowel' | 'consonant' | null {
  const key = name.toLowerCase();
  if (inv.custom.has(key) || !(key in LENGTH_CLASSES)) return null;
  return key === 'geminate' ? 'consonant' : 'vowel';
}

export function resolveClass(name: string, inv: Inventory): string[] {
  if (name === 'C') return inv.consonants;
  if (name === 'V') return inv.vowels;
  const lengthKind = lengthClassKind(name, inv);
  if (lengthKind) {
    const sounds = lengthKind === 'vowel' ? inv.vowels : inv.consonants;
    return [...new Set(sounds.map((s) => (s !== withoutLength(s) ? s : longForm(s, lengthKind, inv))))];
  }
  const alias = CLASS_ALIASES[name];
  if (alias) return inv.classes[alias] ?? [];
  return inv.classes[name.toLowerCase()] ?? [];
}

export interface Token {
  symbol: string;
  offset: number;
}

/** Longest-match tokenizer. Unknown characters become single tokens. */
export function tokenize(word: string, inv: Inventory, extra: string[] = []): Token[] {
  const all = new Set<string>([...inv.consonants, ...inv.vowels, ...extra]);
  for (const list of Object.values(inv.classes)) for (const s of list) all.add(s);
  const sorted = [...all].filter(Boolean).sort((a, b) => b.length - a.length);
  const tokens: Token[] = [];
  let i = 0;
  while (i < word.length) {
    const m = sorted.find((p) => word.startsWith(p, i));
    const symbol = m ?? String.fromCodePoint(word.codePointAt(i)!);
    tokens.push({ symbol, offset: i });
    i += symbol.length;
  }
  return tokens;
}

/** The length mark belongs to the sound before it, so it isn't a position of its own. */
function joinLengthMarks(tokens: Token[]): Token[] {
  const out: Token[] = [];
  for (const t of tokens) {
    const last = out[out.length - 1];
    if (t.symbol === LENGTH_MARK && last) out[out.length - 1] = { ...last, symbol: last.symbol + LENGTH_MARK };
    else out.push(t);
  }
  return out;
}

/**
 * C, V and the built-in classes hold a long sound when they hold its short one.
 * A user's class means exactly what it lists, so [short] doesn't take eː.
 */
function soundInClass(name: string, symbol: string, inv: Inventory): boolean {
  const lengthKind = lengthClassKind(name, inv);
  if (lengthKind) return symbol !== withoutLength(symbol) && isOfKind(symbol, lengthKind, inv);
  const list = resolveClass(name, inv);
  if (list.includes(symbol)) return true;
  const isCustom = name !== 'C' && name !== 'V' && inv.custom.has((CLASS_ALIASES[name] ?? name).toLowerCase());
  return !isCustom && symbol !== withoutLength(symbol) && list.includes(withoutLength(symbol));
}

/**
 * Matches `segments` starting at token `start`; returns every possible end
 * index, so optional segments backtrack correctly.
 */
function matchEnds(segments: Segment[], tokens: Token[], start: number, inv: Inventory): number[] {
  if (segments.length === 0) return [start];
  const [head, ...rest] = segments;
  const out: number[] = [];
  const advance = (pos: number) => out.push(...matchEnds(rest, tokens, pos, inv));
  if (head.kind === 'boundary') {
    if (start === 0 || start === tokens.length) advance(start);
    return out;
  }
  if (head.kind === 'class') {
    const t = tokens[start];
    if (t && soundInClass(head.name, t.symbol, inv)) advance(start + 1);
    // A doubled sound is written as two tokens but is one geminate or long vowel.
    const lengthKind = lengthClassKind(head.name, inv);
    if (t && lengthKind && tokens[start + 1]?.symbol === t.symbol && isOfKind(t.symbol, lengthKind, inv)) advance(start + 2);
  } else {
    let pos = start;
    let remaining = head.text;
    let ok = true;
    while (remaining) {
      if (pos >= tokens.length || !remaining.startsWith(tokens[pos].symbol)) {
        ok = false;
        break;
      }
      remaining = remaining.slice(tokens[pos].symbol.length);
      pos++;
    }
    if (ok) advance(pos);
  }
  if (head.optional) advance(start);
  return out;
}

export function matchesAt(position: 'startsWith' | 'endsWith' | 'contains', segments: Segment[], word: string, inv: Inventory): boolean {
  if (!word) return false;
  if (segments.length === 0) return true;
  const tokens = joinLengthMarks(tokenize(word, inv));
  if (position === 'startsWith') return matchEnds(segments, tokens, 0, inv).length > 0;
  for (let s = 0; s <= tokens.length; s++) {
    const ends = matchEnds(segments, tokens, s, inv);
    if (position === 'contains' ? ends.length > 0 : ends.includes(tokens.length)) return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

export interface Violation {
  position: number;
  length: number;
  description: string;
}

const GEMINATION_LABEL: Record<GeminationPosition, string> = {
  everywhere: 'everywhere',
  coda: 'coda',
  onset: 'onset',
  initial: 'initial',
  final: 'final',
};

export function describeSegments(segments: Segment[]): string {
  return segments
    .map((s) => {
      const core = s.kind === 'boundary' ? '#' : s.kind === 'sound' ? s.text : /^[A-Z]$/.test(s.name) ? s.name : `[${s.name}]`;
      return s.kind !== 'boundary' && s.optional ? `(${core})` : core;
    })
    .join('');
}

export function validateWord(word: string, constraints: Constraint[], inv: Inventory): Violation[] {
  if (!word) return [];
  const active = constraints.filter((c) => c.active);
  const tokens = tokenize(word, inv);
  const end = (t: Token) => t.offset + t.symbol.length;
  const out: Violation[] = [];

  for (const c of active) {
    if (c.kind === 'sequence') {
      if (!c.segments.length) continue;
      const label = c.description || `forbidden: ${describeSegments(c.segments)}`;
      const sounds = joinLengthMarks(tokens);
      for (let i = 0; i < sounds.length; i++) {
        if (c.position === 'start' && i !== 0) break;
        for (const e of matchEnds(c.segments, sounds, i, inv)) {
          if (e === i) continue;
          if (c.position === 'end' && e !== sounds.length) continue;
          out.push({ position: sounds[i].offset, length: end(sounds[e - 1]) - sounds[i].offset, description: label });
          break;
        }
      }
    } else {
      const consonants = new Set(inv.consonants);
      const vowels = new Set(inv.vowels);
      for (let i = 0; i + 1 < tokens.length; i++) {
        if (tokens[i].symbol !== tokens[i + 1].symbol || !consonants.has(tokens[i].symbol)) continue;
        const next = tokens[i + 2]?.symbol;
        const atStart = i === 0;
        const atEnd = i + 2 === tokens.length;
        const prevVowel = i > 0 && vowels.has(tokens[i - 1].symbol);
        const fires = c.positions.some((p) => {
          switch (p) {
            case 'everywhere':
              return true;
            case 'initial':
              return atStart;
            case 'final':
              return atEnd;
            case 'onset':
              return atStart || prevVowel;
            case 'coda':
              return atEnd || (next !== undefined && !vowels.has(next));
          }
        });
        if (fires) {
          const where = c.positions.includes('everywhere') ? 'everywhere' : c.positions.map((p) => GEMINATION_LABEL[p]).join('/');
          out.push({ position: tokens[i].offset, length: tokens[i].symbol.length * 2, description: `gemination violation (${where})` });
        }
      }
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Rewrite rules (phonemic -> phonetic)
// ---------------------------------------------------------------------------

function literalExtras(rule: RewriteRule, inv: Inventory): string[] {
  const out: string[] = [];
  for (const s of [...rule.input, ...rule.left, ...rule.right]) {
    if (s.kind === 'sound' && s.text.length > 1) out.push(s.text);
    // Lets a doubled sound be one slot when the rule names a length class.
    if (s.kind === 'class' && lengthClassKind(s.name, inv)) out.push(...resolveClass(s.name, inv));
  }
  return out;
}

function slotMatches(seg: Segment, symbol: string, inv: Inventory): boolean {
  if (seg.kind === 'sound') return seg.text === symbol;
  if (seg.kind === 'class') return resolveClass(seg.name, inv).includes(symbol) || soundInClass(seg.name, symbol, inv);
  return false;
}

function contextMatches(tokens: Token[], anchor: number, ctx: Segment[], inv: Inventory, left: boolean): boolean {
  if (!ctx.length) return true;
  // The matched sound's own mark comes next, so it was really a long sound, not what the rule named.
  if (!left && tokens[anchor]?.symbol === LENGTH_MARK) return false;
  const sounds = joinLengthMarks(tokens);
  const before = joinLengthMarks(tokens.slice(0, anchor)).length;
  const start = left ? before - ctx.length : before;
  for (let j = 0; j < ctx.length; j++) {
    const idx = start + j;
    const seg = ctx[j];
    if (seg.kind === 'boundary') {
      if (idx !== -1 && idx !== sounds.length) return false;
      continue;
    }
    if (idx < 0 || idx >= sounds.length || !slotMatches(seg, sounds[idx].symbol, inv)) return false;
  }
  return true;
}

export function applyRewriteRule(word: string, rule: RewriteRule, inv: Inventory): string {
  const tokens = tokenize(word, inv, literalExtras(rule, inv));
  if (!tokens.length || !rule.input.length) return word;
  const n = rule.input.length;
  let out = '';
  let i = 0;
  while (i < tokens.length) {
    const inputOk =
      i + n <= tokens.length && rule.input.every((s, j) => slotMatches(s, tokens[i + j].symbol, inv));
    if (inputOk && contextMatches(tokens, i, rule.left, inv, true) && contextMatches(tokens, i + n, rule.right, inv, false)) {
      out += rule.output;
      i += n;
    } else {
      out += tokens[i].symbol;
      i++;
    }
  }
  return out;
}

export function applyRewriteRules(word: string, rules: RewriteRule[], inv: Inventory): string {
  return rules.reduce((w, r) => applyRewriteRule(w, r, inv), word);
}

export interface Allophone {
  output: string;
  rule: RewriteRule;
  isFeatureBundle: boolean;
}

/** Lists what a phoneme surfaces as. Cluster rules are skipped, identity too. */
export function computeAllophones(symbol: string, rules: RewriteRule[], inv: Inventory): Allophone[] {
  const seen = new Set<string>();
  const out: Allophone[] = [];
  for (const r of rules) {
    if (r.input.length !== 1) continue;
    const s = r.input[0];
    const hit = s.kind === 'sound' ? s.text === symbol : s.kind === 'class' && resolveClass(s.name, inv).includes(symbol);
    if (!hit || r.output === symbol || seen.has(r.output)) continue;
    seen.add(r.output);
    out.push({ output: r.output, rule: r, isFeatureBundle: r.output.length >= 2 && r.output.startsWith('[') && r.output.endsWith(']') });
  }
  return out;
}

export function describeRewrite(r: RewriteRule): string {
  const ctx = r.left.length || r.right.length ? ` / ${describeSegments(r.left)}_${describeSegments(r.right)}` : '';
  return `${describeSegments(r.input)} → ${r.output}${ctx}`;
}

// ---------------------------------------------------------------------------
// Word generator
// ---------------------------------------------------------------------------

export type Rng = () => number;

function syllable(t: SyllableTemplate, inv: Inventory, rng: Rng): string {
  let out = '';
  for (const s of t.segments) {
    if (s.kind === 'boundary') continue;
    if (s.optional && rng() >= 0.5) continue;
    if (s.kind === 'sound') {
      out += s.text;
      continue;
    }
    const options = resolveClass(s.name, inv);
    if (options.length) out += options[Math.floor(rng() * options.length)];
  }
  return out;
}

export interface GenerateOptions {
  templates: SyllableTemplate[];
  constraints: Constraint[];
  inventory: Inventory;
  count: number;
  minSyllables?: number;
  maxSyllables?: number;
  rng?: Rng;
}

/** Generates phonemic words that obey every active constraint. */
export function generateWords(o: GenerateOptions): string[] {
  const { inventory: inv, count } = o;
  const min = o.minSyllables ?? 1;
  const max = o.maxSyllables ?? 3;
  const rng = o.rng ?? Math.random;
  const templates = o.templates.filter((t) => t.active && t.segments.length);
  if (!templates.length || (!inv.consonants.length && !inv.vowels.length)) return [];
  const hasConstraints = o.constraints.some((c) => c.active);
  const results: string[] = [];
  const maxAttempts = hasConstraints ? count * 10 : count;
  for (let i = 0; i < maxAttempts && results.length < count; i++) {
    const n = min + Math.floor(rng() * (max - min + 1));
    let word = '';
    for (let s = 0; s < n; s++) word += syllable(templates[Math.floor(rng() * templates.length)], inv, rng);
    if (!word) continue;
    if (hasConstraints && validateWord(word, o.constraints, inv).length) continue;
    results.push(word);
  }
  return results;
}
