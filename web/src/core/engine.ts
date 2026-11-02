// The language engine: the single authority on what form every word takes in
// every position. UI, MCP tools and exports ask it; none of them read lexeme
// form fields or run rules themselves.
//
// Forms have three layers, always kept apart:
//   phonemic  the morphological result; input to all further derivation
//   phonetic  phonemic after the rewrite rules; what gets shown in [brackets]
//             and what phonotactics are checked against
//   roman     romanization of the phonemic form, never of the phonetic one
//
// A derived word is computed recursively from its parent's phonemic form, so
// v -> n (-a) then n -> adj (-o) on kal gives kala, then kalao.

import { applyRule, literalTexts, unknownPhonemes } from './morphology';
import { deromanize, romanize, validateBijection, type BijectionViolation } from './notation';
import {
  computeCell,
  coverageMatrix,
  cartesian,
  featureKey,
  findTiebreakConflicts,
  translateBindings,
  type CoverageMatrix,
  type FeatureSet,
  type RawCell,
  type ResolvedRule,
  type TiebreakConflict,
} from './paradigm';
import {
  applyRewriteRules,
  buildInventory,
  computeAllophones,
  generateWords,
  matchesAt,
  validateWord,
  type Allophone,
  type Inventory,
  type Violation,
} from './phonology';
import { isParticle, type Construction, type ConstructionSlot, type Dimension, type Id, type Lexeme, type Marker, type MorphRule, type PartOfSpeech, type ProjectDoc, type SlotFeatures } from './types';

export interface RuleRef {
  id: Id;
  name: string;
}

export interface WordForm {
  lexemeId: Id;
  /** 'broken': a live derivation that cannot currently be computed. */
  status: 'ok' | 'broken';
  origin: 'root' | 'derived' | 'detached';
  phonemic: string;
  phonetic: string;
  roman: string;
  /** Romanization if available and enabled, otherwise the phonemic form. */
  label: string;
  /** The stored IPA was hand-edited away from what the romanization implies. */
  ipaOverridden: boolean;
  /** Derivation steps from the root down to this word. */
  chain: { parentId: Id; rule: RuleRef }[];
  reason?: string;
}

export type ParadigmCell =
  | {
      kind: 'filled';
      key: string;
      features: FeatureSet;
      phonemic: string;
      phonetic: string;
      roman: string;
      rules: RuleRef[];
      partial: boolean;
    }
  | { kind: 'unmarked'; key: string; features: FeatureSet; phonemic: string; phonetic: string; roman: string; marker: Marker }
  | { kind: 'override'; key: string; features: FeatureSet; phonemic: string; phonetic: string; roman: string; notes?: string | null; computed: RawCell | null }
  | { kind: 'uncovered'; key: string; features: FeatureSet; reason: string }
  | { kind: 'ambiguous'; key: string; features: FeatureSet; rules: RuleRef[] };

export interface Paradigm {
  lexemeId: Id;
  posId: Id | null;
  axes: Dimension[];
  cells: Map<string, ParadigmCell>;
  /** Set when the base form is broken, so nothing can be computed. */
  reason?: string;
}

export interface DerivationOption {
  rule: MorphRule;
  /** Output form of this rule on this word, respecting any exception. */
  phonemic: string;
  phonetic: string;
  roman: string;
  label: string;
  isException: boolean;
  /** The committed dictionary word for this derivation, if any. */
  child: Lexeme | null;
}

export type TokenMatch =
  | { kind: 'word'; lexeme: Lexeme; gloss: string; phonemic: string; phonetic: string }
  | { kind: 'inflected'; lexeme: Lexeme; gloss: string; phonemic: string; phonetic: string; features: FeatureSet; rules: RuleRef[] }
  | { kind: 'derivation'; lexeme: Lexeme; rule: MorphRule; gloss: string; phonemic: string; phonetic: string };

export interface PhraseToken {
  /** The token without surrounding punctuation. */
  text: string;
  raw: string;
  /** All readings, best first. Empty = unknown. */
  matches: TokenMatch[];
  /** The phonetic form used for the IPA tier. */
  phonetic: string;
  violations: Violation[];
}

export interface GlossedToken extends PhraseToken {
  /** What this token glosses as in this phrase. Null = unknown. */
  gloss: string | null;
  /** Glosses of the readings not chosen. A tag replacing the chosen reading's meaning isn't one. */
  otherReadings: string[];
}

/** A construction found in a phrase, covering tokens start to end (exclusive). */
export interface ConstructionMatch {
  construction: Construction;
  start: number;
  end: number;
}

export interface PhraseAnalysis {
  tokens: GlossedToken[];
  /** In phrase order, never overlapping. */
  constructions: ConstructionMatch[];
}

interface SlotPick {
  token: number;
  reading: TokenMatch;
  tag: string | null;
}

export interface AncestryNode {
  lexemeId: Id;
  lexeme: Lexeme;
  edgeLabel: string;
  isRuleDerived: boolean;
  parents: AncestryNode[];
  isCycle: boolean;
  isTruncated: boolean;
}

export interface ChildLink {
  lexeme: Lexeme;
  edgeLabel: string;
  isRuleDerived: boolean;
}

export interface WordListEntry {
  lexeme: Lexeme;
  derivedMatchCount: number;
  automatic: boolean;
}

export interface ConstructionPiece {
  text: string;
  /** Nothing in the lexicon fills this slot. */
  missing: boolean;
  isTargetWord?: boolean;
  tag?: string | null;
}

export interface SlotSummary {
  text: string;
  /** Names of the levels this slot is restricted to. */
  form: string[];
  tag: string | null;
  missing: boolean;
}

function hasFeatures(have: FeatureSet, want: SlotFeatures | undefined): boolean {
  return Object.entries(want ?? {}).every(([dim, level]) => have[dim] === level);
}

const MAX_ANCESTRY_DEPTH = 10;
const MAX_DYNAMIC_DEPTH = 3;

// Automatic derivations are generated, not stored, so they have no row id. Each
// (parent, rule) pair gets a stable negative id for the session instead.
const dynamicIds = new Map<string, Id>();
const dynamicPairs = new Map<Id, { parentId: Id; ruleId: Id }>();

export function dynamicIdFor(parentId: Id, ruleId: Id): Id {
  const key = `${parentId}:${ruleId}`;
  let id = dynamicIds.get(key);
  if (id === undefined) {
    id = -(dynamicIds.size + 1);
    dynamicIds.set(key, id);
    dynamicPairs.set(id, { parentId, ruleId });
  }
  return id;
}

export function dynamicPair(id: Id) {
  return dynamicPairs.get(id);
}

export function isDynamicId(id: Id) {
  return id < 0;
}

export class LanguageEngine {
  readonly doc: ProjectDoc;
  readonly inventory: Inventory;
  readonly bijectionViolations: BijectionViolation[];
  readonly romanizationOn: boolean;

  private readonly lexemeById: Map<Id, Lexeme>;
  private readonly ruleById: Map<Id, MorphRule>;
  private readonly posById: Map<Id, PartOfSpeech>;
  private readonly mappings: { phoneme: string; latin: string }[];
  private readonly formCache = new Map<Id, WordForm>();
  private readonly paradigmCache = new Map<Id, Paradigm>();
  private readonly resolvedRulesCache = new Map<Id, ResolvedRule[]>();
  private surfaceCache: Map<string, TokenMatch[]> | null = null;
  private dynamicCache: Lexeme[] | null = null;
  /** `parent:rule` -> stored row of a rule-linked word. */
  private readonly rowByPair = new Map<string, Lexeme>();

  constructor(doc: ProjectDoc) {
    this.doc = doc;
    this.inventory = buildInventory(doc.phonemes, doc.naturalClasses);
    this.mappings = doc.romanization.filter((m) => m.phoneme && m.latin);
    this.bijectionViolations = validateBijection(doc.romanization);
    this.romanizationOn = doc.settings.romanizationEnabled;
    this.lexemeById = new Map(doc.lexemes.map((l) => [l.id, l]));
    this.ruleById = new Map(doc.rules.map((r) => [r.id, r]));
    this.posById = new Map(doc.partsOfSpeech.map((p) => [p.id, p]));
    for (const l of doc.lexemes) if (l.form.kind === 'derived') this.rowByPair.set(`${l.form.parentId}:${l.form.ruleId}`, l);
    // Saved details on an automatic word: no meaning of its own means the live template.
    for (const l of doc.lexemes) {
      if (this.isDynamic(l) && !l.meaning) this.lexemeById.set(l.id, { ...l, meaning: this.templateMeaning(l) });
    }
  }

  // -------------------------------------------------------------------------
  // Notation
  // -------------------------------------------------------------------------

  romanize(phonemic: string): string {
    return romanize(phonemic, this.mappings);
  }

  deromanize(rom: string): string {
    return deromanize(rom, this.mappings);
  }

  phonetic(phonemic: string): string {
    return applyRewriteRules(phonemic, this.doc.rewriteRules, this.inventory);
  }

  /** What a user types into a literal field, as phonemic text. */
  toPhonemic(input: string): string {
    return this.romanizationOn ? this.deromanize(input) : input;
  }

  /** Phonemic text as shown in a literal field. */
  fromPhonemic(phonemic: string): string {
    return this.romanizationOn ? this.romanize(phonemic) : phonemic;
  }

  /** Label for an arbitrary phonemic form: romanized if enabled. */
  labelFor(phonemic: string): string {
    return this.romanizationOn && this.mappings.length ? this.romanize(phonemic) : phonemic;
  }

  /** Long vowels an elongation can produce that have no romanization, so they'd show with ː. */
  unromanizedLongVowels(): string[] {
    if (!this.romanizationOn) return [];
    return this.inventory.vowels.filter((v) => !v.endsWith('ː') && !this.mappings.some((m) => m.phoneme === `${v}ː`)).map((v) => `${v}ː`);
  }

  allophones(symbol: string): Allophone[] {
    return computeAllophones(symbol, this.doc.rewriteRules, this.inventory);
  }

  // -------------------------------------------------------------------------
  // Lookups
  // -------------------------------------------------------------------------

  lexeme(id: Id): Lexeme | undefined {
    const known = this.lexemeById.get(id);
    if (known || id >= 0) return known;
    const pair = dynamicPair(id);
    if (!pair) return undefined;
    const parent = this.lexeme(pair.parentId);
    const rule = this.ruleById.get(pair.ruleId);
    if (!parent || !rule) return undefined;
    const row = this.rowByPair.get(`${parent.id}:${rule.id}`);
    if (row) {
      const resolved = this.lexemeById.get(row.id)!;
      this.lexemeById.set(id, resolved);
      return resolved;
    }
    const word: Lexeme = {
      id,
      form: { kind: 'derived', parentId: parent.id, ruleId: rule.id },
      meaning: null,
      posId: rule.outputPosId ?? rule.inputPosId,
      isException: false,
      rootOnly: false,
      skippedDimensionIds: [],
      intrinsicLevels: {},
    };
    word.meaning = this.templateMeaning(word);
    this.lexemeById.set(id, word);
    return word;
  }

  /** Generated by an automatic rule, whether or not details are saved on it. */
  isDynamic(l: Lexeme): boolean {
    return l.form.kind === 'derived' && !!this.ruleById.get(l.form.ruleId)?.autoApply;
  }

  /** "parent meaning (rule name)", following the parent and rule as they change. */
  templateMeaning(l: Lexeme): string | null {
    if (l.form.kind !== 'derived') return null;
    const rule = this.ruleById.get(l.form.ruleId);
    const parent = this.lexeme(l.form.parentId);
    const parentMeaning = parent && this.glossOf(parent);
    if (!rule) return null;
    return parentMeaning ? `${parentMeaning} (${rule.name})` : `(${rule.name})`;
  }

  /** Every automatic word in the language. Computed only when something asks. */
  dynamicWords(): Lexeme[] {
    if (this.dynamicCache) return this.dynamicCache;
    const out = new Map<Id, Lexeme>();
    const visit = (l: Lexeme) => {
      for (const o of this.derivationOptions(l.id)) {
        if (o.rule.autoApply && o.child && !out.has(o.child.id)) {
          out.set(o.child.id, o.child);
          visit(o.child);
        }
      }
    };
    for (const row of this.doc.lexemes) {
      const l = this.lexeme(row.id)!;
      if (this.isDynamic(l)) out.set(l.id, l);
    }
    for (const row of this.doc.lexemes) visit(this.lexeme(row.id)!);
    this.dynamicCache = [...out.values()];
    return this.dynamicCache;
  }

  /** Stored words plus generated ones. */
  allWords(): Lexeme[] {
    const dynamic = this.dynamicWords();
    const seen = new Set(dynamic.map((l) => l.id));
    return [...this.doc.lexemes.filter((l) => !seen.has(l.id)), ...dynamic];
  }

  rule(id: Id): MorphRule | undefined {
    return this.ruleById.get(id);
  }

  pos(id: Id | null | undefined): PartOfSpeech | undefined {
    return id == null ? undefined : this.posById.get(id);
  }

  dimensionsForPos(posId: Id): Dimension[] {
    return this.doc.dimensions.filter((d) => d.posId === posId).sort((a, b) => a.order - b.order);
  }

  /** Own fixed levels, on top of any the producing rule assigns. */
  intrinsicLevels(l: Lexeme): FeatureSet {
    const inherited = l.form.kind === 'derived' ? this.ruleById.get(l.form.ruleId)?.outputIntrinsic : undefined;
    return { ...inherited, ...l.intrinsicLevels };
  }

  // -------------------------------------------------------------------------
  // Base form of a word
  // -------------------------------------------------------------------------

  /** The form of a word. Everything that shows a word goes through here. */
  form(id: Id): WordForm {
    return this.resolveForm(id, new Set());
  }

  private makeForm(l: Lexeme, origin: WordForm['origin'], phonemic: string, chain: WordForm['chain'], manualRoman?: string | null): WordForm {
    const computedRoman = this.romanize(phonemic);
    const roman = manualRoman || computedRoman;
    return {
      lexemeId: l.id,
      status: 'ok',
      origin,
      phonemic,
      phonetic: this.phonetic(phonemic),
      roman,
      label: this.romanizationOn ? roman : phonemic,
      ipaOverridden: !!manualRoman && this.mappings.length > 0 && this.deromanize(manualRoman) !== phonemic,
      chain,
    };
  }

  private brokenForm(l: Lexeme, origin: WordForm['origin'], reason: string, chain: WordForm['chain'] = []): WordForm {
    return { lexemeId: l.id, status: 'broken', origin, phonemic: '', phonetic: '', roman: '', label: '(no form)', ipaOverridden: false, chain, reason };
  }

  private resolveForm(id: Id, visiting: Set<Id>): WordForm {
    const cached = this.formCache.get(id);
    if (cached) return cached;
    const l = this.lexeme(id);
    if (!l) throw new Error(`Unknown word ${id}`);

    let result: WordForm;
    if (l.form.kind === 'root') {
      result = this.makeForm(l, 'root', l.form.phonemic, [], l.form.roman);
    } else if (l.form.kind === 'detached') {
      result = this.makeForm(l, 'detached', l.form.phonemic, [], l.form.roman);
    } else {
      const { parentId, ruleId } = l.form;
      const rule = this.ruleById.get(ruleId);
      const parent = this.lexeme(parentId);
      if (visiting.has(id)) {
        return this.brokenForm(l, 'derived', 'This word derives from itself.');
      }
      if (!rule) {
        result = this.brokenForm(l, 'derived', 'Its derivation rule no longer exists.');
      } else if (!parent) {
        result = this.brokenForm(l, 'derived', 'Its parent word no longer exists.');
      } else {
        const parentForm = this.resolveForm(parentId, new Set(visiting).add(id));
        const chain = [...parentForm.chain, { parentId, rule: { id: rule.id, name: rule.name } }];
        if (parentForm.status === 'broken') {
          result = this.brokenForm(l, 'derived', parentForm.reason ?? 'Its parent word has no form.', chain);
        } else {
          const exception = this.exceptionFor(parentId, ruleId);
          if (exception !== null) {
            result = this.makeForm(l, 'derived', exception, chain);
          } else {
            const res = applyRule(rule, parentForm.phonemic, this.inventory);
            result = res.ok
              ? this.makeForm(l, 'derived', res.form, chain)
              : this.brokenForm(l, 'derived', `Rule "${rule.name}" does not apply to /${parentForm.phonemic}/: ${res.reason}`, chain);
          }
        }
      }
    }
    this.formCache.set(id, result);
    return result;
  }

  private exceptionFor(lexemeId: Id, ruleId: Id): string | null {
    return this.doc.exceptions.find((e) => e.lexemeId === lexemeId && e.ruleId === ruleId)?.form ?? null;
  }

  // -------------------------------------------------------------------------
  // Violations
  // -------------------------------------------------------------------------

  /** Phonotactic violations of a form; offsets refer to the phonetic text. */
  violationsOf(phonetic: string): Violation[] {
    return validateWord(phonetic, this.doc.constraints, this.inventory);
  }

  /** Everything flagged on a word's base form, unless marked as an exception. */
  wordViolations(id: Id): Violation[] {
    const l = this.lexeme(id);
    if (!l || l.isException) return [];
    const form = this.form(id);
    if (form.status === 'broken') return [];
    return [...this.violationsOf(form.phonetic), ...this.standardFormViolations(id)];
  }

  standardFormViolations(id: Id): Violation[] {
    const l = this.lexeme(id);
    if (!l || l.posId == null || l.isException) return [];
    const form = this.form(id);
    if (form.status === 'broken') return [];
    const levels = this.intrinsicLevels(l);
    const out: Violation[] = [];
    for (const dim of this.dimensionsForPos(l.posId)) {
      if (!dim.intrinsic) continue;
      const levelId = levels[dim.id];
      if (levelId === undefined) continue;
      const sf = this.doc.standardForms.find((s) => s.dimensionId === dim.id && s.levelId === levelId);
      if (!sf || !sf.branches.length) continue;
      if (sf.branches.some((b) => matchesAt(b.kind, b.segments, form.phonemic, this.inventory))) continue;
      const level = dim.levels.find((x) => x.id === levelId);
      out.push({
        position: 0,
        length: form.phonetic.length,
        description: `${level?.name ?? 'unknown'} ${dim.name} should ${this.describeStandardForm(sf.branches)}`,
      });
    }
    return out;
  }

  describeStandardForm(branches: { kind: string; segments: import('./types').Segment[] }[]): string {
    const verbs: Record<string, string> = { startsWith: 'start with', endsWith: 'end with', contains: 'contain' };
    return branches.map((b) => `${verbs[b.kind]} "${this.segmentsLabel(b.segments)}"`).join(' or ');
  }

  segmentsLabel(segments: import('./types').Segment[]): string {
    return segments
      .map((s) => {
        if (s.kind === 'boundary') return 'word edge';
        const core = s.kind === 'sound' ? this.fromPhonemic(s.text) : s.name;
        return s.optional ? `(${core})` : core;
      })
      .join(' ');
  }

  // -------------------------------------------------------------------------
  // Derivation
  // -------------------------------------------------------------------------

  /** Every derivational rule that yields a new form for this word. */
  derivationOptions(id: Id): DerivationOption[] {
    const l = this.lexeme(id);
    if (!l || l.posId == null) return [];
    const base = this.form(id);
    if (base.status === 'broken') return [];
    const out: DerivationOption[] = [];
    const rules = this.doc.rules
      .filter((r) => r.kind === 'derivational' && r.active && r.inputPosId === l.posId)
      .sort((a, b) => a.order - b.order);
    for (const rule of rules) {
      // An automatic rule can't feed itself, and chains stay a sensible length.
      if (rule.autoApply && this.isDynamic(l) && (base.chain.length >= MAX_DYNAMIC_DEPTH || base.chain.some((c) => c.rule.id === rule.id))) continue;
      const exception = this.exceptionFor(l.id, rule.id);
      let phonemic: string | null = exception;
      if (phonemic === null) {
        const res = applyRule(rule, base.phonemic, this.inventory);
        if (!res.ok || res.form === base.phonemic) continue;
        phonemic = res.form;
      }
      const stored = this.rowByPair.get(`${l.id}:${rule.id}`);
      const child = stored ? this.lexeme(stored.id)! : rule.autoApply ? this.lexeme(dynamicIdFor(l.id, rule.id))! : null;
      out.push({
        rule,
        phonemic,
        phonetic: this.phonetic(phonemic),
        roman: this.romanize(phonemic),
        label: this.labelFor(phonemic),
        isException: exception !== null,
        child,
      });
    }
    return out;
  }

  /** Rules offered as one-click derivations: applicable and not yet committed. */
  derivationSuggestions(id: Id): DerivationOption[] {
    return this.derivationOptions(id).filter((o) => !o.rule.autoApply && !o.child);
  }

  // -------------------------------------------------------------------------
  // Inflection
  // -------------------------------------------------------------------------

  /** Active inflectional rules for a POS with bindings in that POS's ids. */
  rulesForPos(posId: Id): ResolvedRule[] {
    const cached = this.resolvedRulesCache.get(posId);
    if (cached) return cached;
    const dims = this.dimensionsForPos(posId);
    const out: ResolvedRule[] = [];
    for (const rule of this.doc.rules.slice().sort((a, b) => a.order - b.order)) {
      if (rule.kind !== 'inflectional' || !rule.active || !rule.posIds.includes(posId)) continue;
      const bindings = translateBindings(rule.bindings, this.doc.dimensions, dims);
      if (bindings) out.push({ rule, bindings });
    }
    this.resolvedRulesCache.set(posId, out);
    return out;
  }

  /** Inflects a word, or a bare phonemic form when previewing. */
  paradigm(id: Id): Paradigm {
    const cached = this.paradigmCache.get(id);
    if (cached) return cached;
    const l = this.lexeme(id);
    const empty: Paradigm = { lexemeId: id, posId: l?.posId ?? null, axes: [], cells: new Map() };
    if (!l || l.posId == null) return empty;

    const dims = this.dimensionsForPos(l.posId);
    const axes = dims.filter((d) => !d.intrinsic && !l.skippedDimensionIds.includes(d.id));
    const base = this.form(id);
    if (base.status === 'broken') {
      return { ...empty, axes, reason: base.reason };
    }
    const result: Paradigm = { lexemeId: id, posId: l.posId, axes, cells: new Map() };
    if (!axes.length) {
      this.paradigmCache.set(id, result);
      return result;
    }

    const intrinsicDims = new Set(dims.filter((d) => d.intrinsic).map((d) => d.id));
    const rules = this.rulesForPos(l.posId);
    const markers = this.doc.markers.filter((m) => m.posId === l.posId);
    const wordLevels = this.intrinsicLevels(l);
    const overrides = new Map(this.doc.overrides.filter((o) => o.lexemeId === l.id).map((o) => [o.key, o]));

    for (const features of cartesian(axes)) {
      const key = featureKey(features);
      const raw = computeCell({ base: base.phonemic, target: features, rules, markers, inventory: this.inventory, intrinsicDims, wordLevels });
      const override = overrides.get(key);
      if (override) {
        result.cells.set(key, {
          kind: 'override',
          key,
          features,
          phonemic: override.phonemic,
          phonetic: override.phonemic,
          roman: override.roman || this.romanize(override.phonemic),
          notes: override.notes,
          computed: raw,
        });
        continue;
      }
      result.cells.set(key, this.finishCell(raw, key, features));
    }
    this.paradigmCache.set(id, result);
    return result;
  }

  private finishCell(raw: RawCell, key: string, features: FeatureSet): ParadigmCell {
    switch (raw.kind) {
      case 'filled':
        return {
          kind: 'filled',
          key,
          features,
          phonemic: raw.phonemic,
          phonetic: this.phonetic(raw.phonemic),
          roman: this.romanize(raw.phonemic),
          rules: raw.chain.map((r) => ({ id: r.id, name: r.name })),
          partial: raw.partial,
        };
      case 'unmarked':
        return { kind: 'unmarked', key, features, phonemic: raw.phonemic, phonetic: this.phonetic(raw.phonemic), roman: this.romanize(raw.phonemic), marker: raw.marker };
      case 'uncovered':
        return { kind: 'uncovered', key, features, reason: raw.reason };
      case 'ambiguous':
        return { kind: 'ambiguous', key, features, rules: raw.tied.map((r) => ({ id: r.id, name: r.name })) };
    }
  }

  /** Cell violations are checked on the cell's own surface form. */
  cellViolations(id: Id, cell: ParadigmCell): Violation[] {
    const l = this.lexeme(id);
    if (!l || l.isException) return [];
    if (cell.kind === 'filled' || cell.kind === 'unmarked' || cell.kind === 'override') return this.violationsOf(cell.phonetic);
    return [];
  }

  coverage(posId: Id): CoverageMatrix {
    return coverageMatrix(this.rulesForPos(posId), this.dimensionsForPos(posId));
  }

  tiebreakConflicts(posId: Id): TiebreakConflict[] {
    return findTiebreakConflicts(this.rulesForPos(posId));
  }

  /** Default rows/columns: stored axes when still valid, else the first two. */
  axesFor(posId: Id): { rows: Dimension | null; cols: Dimension | null; extras: Dimension[]; all: Dimension[] } {
    const all = this.dimensionsForPos(posId).filter((d) => !d.intrinsic);
    const stored = this.doc.settings.paradigmAxes[posId];
    let rows = all.find((d) => d.id === stored?.rows) ?? null;
    let cols = all.find((d) => d.id === stored?.cols && d.id !== rows?.id) ?? null;
    rows ??= all.find((d) => d.id !== cols?.id) ?? null;
    cols ??= all.find((d) => d.id !== rows?.id) ?? null;
    return { rows, cols, extras: all.filter((d) => d.id !== rows?.id && d.id !== cols?.id), all };
  }

  wordsForPos(posId: Id): Lexeme[] {
    return this.doc.lexemes.filter((l) => l.posId === posId && !this.isDynamic(l)).map((l) => this.lexeme(l.id)!).sort((a, b) => a.id - b.id);
  }

  /** Words of a POS that have a complete intrinsic level assignment, grouped. */
  wordsByIntrinsicCombination(posId: Id): Map<string, Lexeme[]> {
    const dims = this.dimensionsForPos(posId).filter((d) => d.intrinsic);
    const out = new Map<string, Lexeme[]>();
    if (!dims.length) return out;
    for (const l of this.wordsForPos(posId)) {
      const levels = this.intrinsicLevels(l);
      const combo: FeatureSet = {};
      for (const d of dims) if (levels[d.id] !== undefined) combo[d.id] = levels[d.id];
      if (Object.keys(combo).length !== dims.length) continue;
      const k = featureKey(combo);
      out.set(k, [...(out.get(k) ?? []), l]);
    }
    return out;
  }

  missingIntrinsicCount(posId: Id, dimId: Id): number {
    return this.wordsForPos(posId).filter((l) => !l.rootOnly && this.intrinsicLevels(l)[dimId] === undefined).length;
  }

  staleIntrinsicCount(dimId: Id): number {
    return this.doc.lexemes.filter((l) => l.intrinsicLevels[dimId] !== undefined).length;
  }

  // -------------------------------------------------------------------------
  // Lexicon queries
  // -------------------------------------------------------------------------

  /**
   * Dictionary list, filtered and sorted by each word's real form. Automatic
   * words stay out unless asked for, or unless a search finds them. The part of
   * speech filter and the particles filter add up, like the chips that set them.
   */
  wordList(query: string, posFilter: Set<Id>, includeAutomatic = false, particlesFilter = false): WordListEntry[] {
    const q = query.toLowerCase();
    const out: WordListEntry[] = [];
    const pool = q || includeAutomatic ? this.allWords() : this.doc.lexemes.filter((l) => !this.isDynamic(l));
    for (const raw of pool) {
      const l = this.lexeme(raw.id)!;
      if ((posFilter.size || particlesFilter) && !(l.posId != null && posFilter.has(l.posId)) && !(particlesFilter && isParticle(l))) continue;
      const automatic = this.isDynamic(l);
      if (!q) {
        out.push({ lexeme: l, derivedMatchCount: 0, automatic });
        continue;
      }
      const f = this.form(l.id);
      const own =
        f.phonemic.toLowerCase().includes(q) ||
        f.phonetic.toLowerCase().includes(q) ||
        f.roman.toLowerCase().includes(q) ||
        this.glossOf(l).toLowerCase().includes(q);
      const derived = automatic ? [] : this.derivationOptions(l.id).filter(
        (o) => o.phonemic.toLowerCase().includes(q) || o.phonetic.toLowerCase().includes(q) || o.roman.toLowerCase().includes(q) || (o.child?.meaning ?? '').toLowerCase().includes(q),
      );
      if (own || (!automatic && derived.length)) out.push({ lexeme: l, derivedMatchCount: derived.length, automatic });
    }
    return out.sort((a, b) => this.form(a.lexeme.id).phonemic.localeCompare(this.form(b.lexeme.id).phonemic));
  }

  particles(): Lexeme[] {
    return this.doc.lexemes.filter(isParticle);
  }

  /** Particles holding a tag, for the warning that two of them share it. */
  particlesWithTag(tag: string, exceptId?: Id): Lexeme[] {
    const wanted = tag.trim().toUpperCase();
    return wanted ? this.particles().filter((l) => l.id !== exceptId && l.glossTag?.toUpperCase() === wanted) : [];
  }

  /** What a word glosses as on its own: a particle's tag, otherwise its meaning. */
  glossOf(l: Lexeme): string {
    return l.glossTag || l.meaning || '';
  }

  /** Looks up a meaning for Swadesh/Thesaurus coverage. */
  meaningIndex(): Map<string, Lexeme> {
    const m = new Map<string, Lexeme>();
    for (const l of this.doc.lexemes) {
      const key = l.meaning?.toLowerCase();
      if (key && !m.has(key)) m.set(key, l);
    }
    return m;
  }

  /** Parent word and every further ancestor, through rules and manual links. */
  ancestry(id: Id): AncestryNode | null {
    return this.ancestryNode(id, new Set(), 0, '', false);
  }

  private ancestryNode(id: Id, visited: Set<Id>, depth: number, edgeLabel: string, isRuleDerived: boolean): AncestryNode | null {
    const lexeme = this.lexeme(id);
    if (!lexeme) return null;
    const base = { lexemeId: id, lexeme, edgeLabel, isRuleDerived, parents: [] as AncestryNode[] };
    if (visited.has(id)) return { ...base, isCycle: true, isTruncated: false };
    if (depth >= MAX_ANCESTRY_DEPTH) return { ...base, isCycle: false, isTruncated: true };
    const next = new Set(visited).add(id);
    const parents: AncestryNode[] = [];
    const f = lexeme.form;
    if (f.kind === 'derived') {
      const name = this.ruleById.get(f.ruleId)?.name;
      const node = this.ancestryNode(f.parentId, next, depth + 1, name ? `via ${name}` : 'via rule', true);
      if (node) parents.push(node);
    } else if (f.kind === 'detached' && f.parentId != null) {
      const node = this.ancestryNode(f.parentId, next, depth + 1, 'edited from', true);
      if (node) parents.push(node);
    }
    for (const row of this.doc.parents.filter((p) => p.childId === id)) {
      const node = this.ancestryNode(row.parentId, next, depth + 1, row.relationship || 'parent', false);
      if (node) parents.push(node);
    }
    return { ...base, parents, isCycle: false, isTruncated: false };
  }

  childrenOf(id: Id): ChildLink[] {
    const out: ChildLink[] = [];
    const self = this.lexeme(id);
    if (!self) return out;
    id = self.id;
    for (const o of this.derivationOptions(id)) {
      if (o.rule.autoApply && o.child) out.push({ lexeme: o.child, edgeLabel: `via ${o.rule.name}`, isRuleDerived: true });
    }
    for (const raw of this.doc.lexemes) {
      const l = this.lexeme(raw.id)!;
      const f = l.form;
      if (f.kind === 'derived' && f.parentId === id) {
        if (this.isDynamic(l)) continue;
        const name = this.ruleById.get(f.ruleId)?.name;
        out.push({ lexeme: l, edgeLabel: name ? `via ${name}` : 'rule-derived', isRuleDerived: true });
      } else if (f.kind === 'detached' && f.parentId === id) {
        out.push({ lexeme: l, edgeLabel: 'edited from', isRuleDerived: true });
      }
    }
    for (const row of this.doc.parents.filter((p) => p.parentId === id)) {
      const child = this.lexeme(row.childId);
      if (child) out.push({ lexeme: child, edgeLabel: row.relationship || 'parent', isRuleDerived: false });
    }
    return out;
  }

  // -------------------------------------------------------------------------
  // Constructions
  // -------------------------------------------------------------------------

  /** Fills a construction's slots, optionally with a specific word. */
  fillConstruction(c: Construction, word?: Lexeme): ConstructionPiece[] {
    let usedWord = false;
    return c.slots.map((slot) => {
      if (slot.type === 'phrase') return { text: `[${slot.label || slot.kind}]`, missing: false };
      const tag = slot.glossTag || null;
      const forms = this.featureNames(slot.features).join(' ');
      if (slot.type === 'word') {
        const l = this.lexeme(slot.lexemeId);
        if (!l) return { text: `(missing word: ${slot.missing ?? 'unknown'})`, missing: true, tag };
        const text = this.formsFor(l, slot.features)[0];
        if (!text) return { text: `(no ${forms} form of ${this.form(l.id).label})`, missing: true, tag };
        return { text, missing: false, isTargetWord: word?.id === l.id, tag };
      }
      const pos = this.pos(slot.posId);
      if (!pos) return { text: `(missing part of speech: ${slot.missing ?? 'unknown'})`, missing: true, tag };
      if (word && word.posId === slot.posId && !usedWord) {
        const text = this.formsFor(word, slot.features)[0];
        if (text) {
          usedWord = true;
          return { text, missing: false, isTargetWord: true, tag };
        }
      }
      const stored = this.wordsForPos(slot.posId);
      for (const l of [...stored.filter((x) => !isParticle(x)), ...stored.filter(isParticle)]) {
        const text = this.formsFor(l, slot.features)[0];
        if (text) return { text, missing: false, tag };
      }
      return { text: `(no ${forms ? `${forms} ` : ''}${pos.abbr} word in lexicon)`, missing: true, tag };
    });
  }

  constructionsForWord(l: Lexeme): Construction[] {
    return this.doc.constructions
      .filter((c) => c.slots.some((s) => (s.type === 'word' && s.lexemeId === l.id) || (s.type === 'pos' && l.posId != null && s.posId === l.posId)))
      .sort((a, b) => a.order - b.order);
  }

  /** The dimensions a slot's form picker offers. Empty means hide the picker. */
  slotDimensions(slot: { type: 'word'; lexemeId: Id } | { type: 'pos'; posId: Id } | { type: 'phrase' }): Dimension[] {
    if (slot.type === 'phrase') return [];
    if (slot.type === 'pos') return this.dimensionsForPos(slot.posId);
    const l = this.lexeme(slot.lexemeId);
    if (!l || l.posId == null) return [];
    return this.dimensionsForPos(l.posId).filter((d) => !l.skippedDimensionIds.includes(d.id));
  }

  /** How a slot reads in lists and summaries. */
  slotSummary(slot: ConstructionSlot): SlotSummary {
    if (slot.type === 'phrase') {
      const kind = slot.kind === 'clause' ? 'Clause' : 'Phrase';
      return { text: slot.label ? `${kind}: ${slot.label}` : kind, form: [], tag: null, missing: false };
    }
    const base = { form: this.featureNames(slot.features), tag: slot.glossTag || null };
    if (slot.type === 'word') {
      const l = this.lexeme(slot.lexemeId);
      return l ? { ...base, text: this.form(l.id).label, missing: false } : { ...base, text: slot.missing ?? 'unknown word', missing: true };
    }
    const pos = this.pos(slot.posId);
    return pos ? { ...base, text: pos.name, missing: false } : { ...base, text: slot.missing ?? 'unknown part of speech', missing: true };
  }

  /** One line such as: have (Present) [PERF] + Phrase */
  constructionFormula(c: Construction): string {
    return c.slots
      .map((slot) => {
        const s = this.slotSummary(slot);
        return [s.missing ? `${s.text} (missing)` : s.text, s.form.length ? `(${s.form.join(', ')})` : '', s.tag ? `[${s.tag}]` : ''].filter(Boolean).join(' ');
      })
      .join(' + ');
  }

  constructionWarnings(c: Construction): string[] {
    const out: string[] = [];
    if (c.slots.length && !c.slots.some((s) => s.type === 'word')) {
      out.push('This construction needs at least one Word slot. A fixed word is what makes it recognizable, so without one it never matches.');
    }
    for (const slot of c.slots) {
      const s = this.slotSummary(slot);
      if (s.missing) out.push(`The ${slot.type === 'word' ? 'word' : 'part of speech'} ${s.text} is missing, so this construction ${slot.type === 'word' ? 'never matches' : 'cannot fill that slot'}. Pick a replacement for that slot.`);
    }
    return out;
  }

  /** Names of the levels in a set of features. */
  private featureNames(features: SlotFeatures | undefined): string[] {
    return Object.entries(features ?? {}).flatMap(([dimId, levelId]) => {
      const name = this.doc.dimensions.find((d) => d.id === Number(dimId))?.levels.find((l) => l.id === levelId)?.name;
      return name ? [name] : [];
    });
  }

  /** A word's forms that fit a slot's form choice, as displayed. */
  private formsFor(l: Lexeme, want: SlotFeatures | undefined): string[] {
    const fixed = this.intrinsicLevels(l);
    const f = this.form(l.id);
    const out: string[] = [];
    if (f.status === 'ok' && hasFeatures(fixed, want)) out.push(f.label);
    for (const cell of this.paradigm(l.id).cells.values()) {
      if (cell.kind !== 'filled' && cell.kind !== 'unmarked' && cell.kind !== 'override') continue;
      if (hasFeatures({ ...fixed, ...cell.features }, want)) out.push(this.romanizationOn ? cell.roman : cell.phonemic);
    }
    return out;
  }

  // -------------------------------------------------------------------------
  // Phrase analysis
  // -------------------------------------------------------------------------

  /** All surface forms the language can produce, each with its readings. */
  surfaceIndex(): Map<string, TokenMatch[]> {
    if (this.surfaceCache) return this.surfaceCache;
    const index = new Map<string, TokenMatch[]>();
    const add = (keys: string[], match: TokenMatch) => {
      for (const k of new Set(keys.filter(Boolean))) {
        const list = index.get(k) ?? [];
        list.push(match);
        index.set(k, list);
      }
    };

    const words = this.allWords().map((w) => this.lexeme(w.id)!);
    // Committed words first so they outrank computed readings of the same text.
    for (const l of words) {
      const f = this.form(l.id);
      if (f.status === 'broken') continue;
      add([f.phonemic, f.phonetic, f.roman], { kind: 'word', lexeme: l, gloss: this.glossOf(l) || f.phonemic, phonemic: f.phonemic, phonetic: f.phonetic });
    }
    for (const l of words) {
      const f = this.form(l.id);
      if (f.status === 'broken') continue;
      const base = this.glossOf(l) || f.phonemic;
      for (const cell of this.paradigm(l.id).cells.values()) {
        if (cell.kind !== 'filled' && cell.kind !== 'override') continue;
        const abbrs = this.levelAbbrs(cell.features);
        add([cell.phonemic, cell.phonetic, cell.roman], {
          kind: 'inflected',
          lexeme: l,
          gloss: abbrs.length ? `${base}.${abbrs.join('.')}` : base,
          phonemic: cell.phonemic,
          phonetic: cell.phonetic,
          features: cell.features,
          rules: cell.kind === 'filled' ? cell.rules : [],
        });
      }
    }
    for (const l of words) {
      const f = this.form(l.id);
      if (f.status === 'broken') continue;
      const base = this.glossOf(l) || f.phonemic;
      for (const o of this.derivationOptions(l.id)) {
        if (o.child) continue;
        add([o.phonemic, o.phonetic, o.roman], { kind: 'derivation', lexeme: l, rule: o.rule, gloss: `${base}.${o.rule.name}`, phonemic: o.phonemic, phonetic: o.phonetic });
      }
    }
    this.surfaceCache = index;
    return index;
  }

  levelAbbrs(features: FeatureSet): string[] {
    const out: string[] = [];
    for (const [dimId, levelId] of Object.entries(features)) {
      const level = this.doc.dimensions.find((d) => d.id === Number(dimId))?.levels.find((l) => l.id === levelId);
      if (level) out.push(level.abbr.toUpperCase());
    }
    return out;
  }

  /** Splits on whitespace, ignoring punctuation around each token. */
  analyzePhrase(text: string): PhraseToken[] {
    const words = text.trim().split(/\s+/).filter(Boolean);
    const index = this.surfaceIndex();
    return words.map((raw) => {
      const stripped = raw.replace(/^[\p{P}]+|[\p{P}]+$/gu, '') || raw;
      const matches = index.get(raw) ?? index.get(stripped) ?? index.get(stripped.toLowerCase()) ?? [];
      const best = matches[0];
      const exception = best?.lexeme.isException ?? false;
      const phonetic = best ? best.phonetic : this.phonetic(this.toPhonemic(stripped));
      return { raw, text: stripped, matches, phonetic, violations: best && !exception ? this.violationsOf(best.phonetic) : [] };
    });
  }

  /** A phrase with its glosses: constructions found in it decide what tagged words mean here. */
  glossPhrase(text: string): PhraseAnalysis {
    const tokens = this.analyzePhrase(text);
    const found = this.findConstructions(tokens);
    const picks = new Map(found.flatMap((m) => m.picks).map((p) => [p.token, p]));
    return {
      tokens: tokens.map((t, i) => {
        const pick = picks.get(i);
        const reading = pick?.reading ?? t.matches[0];
        const others = [...new Set(t.matches.filter((m) => m !== reading).map((m) => m.gloss))].filter((g) => g !== reading?.gloss);
        if (!pick) return { ...t, gloss: reading?.gloss ?? null, otherReadings: others };
        return { ...t, gloss: pick.tag ?? reading.gloss, otherReadings: others, phonetic: reading.phonetic, violations: reading.lexeme.isException ? [] : this.violationsOf(reading.phonetic) };
      }),
      constructions: found.map(({ construction, start, end }) => ({ construction, start, end })),
    };
  }

  /** Longest match wins, then whichever comes first in the construction list. */
  private findConstructions(tokens: PhraseToken[]): (ConstructionMatch & { picks: SlotPick[] })[] {
    const list = this.doc.constructions.slice().sort((a, b) => a.order - b.order || a.id - b.id);
    const candidates = list.flatMap((construction, rank) => {
      if (!construction.slots.some((s) => s.type === 'word')) return [];
      return tokens.flatMap((_, start) => {
        const hit = this.matchSlots(construction.slots, tokens, 0, start);
        return hit ? [{ construction, rank, start, end: hit.end, picks: hit.picks }] : [];
      });
    });
    candidates.sort((a, b) => b.end - b.start - (a.end - a.start) || a.rank - b.rank || a.start - b.start);
    const taken = new Set<number>();
    const out: (ConstructionMatch & { picks: SlotPick[] })[] = [];
    for (const c of candidates) {
      const span = Array.from({ length: c.end - c.start }, (_, i) => c.start + i);
      if (span.some((i) => taken.has(i))) continue;
      span.forEach((i) => taken.add(i));
      out.push(c);
    }
    return out.sort((a, b) => a.start - b.start);
  }

  /**
   * Fits slots to tokens. A phrase slot takes at least one word: up to the next
   * fixed word when one follows, otherwise as many as the remaining slots leave.
   */
  private matchSlots(slots: ConstructionSlot[], tokens: PhraseToken[], slotIndex: number, at: number): { end: number; picks: SlotPick[] } | null {
    if (slotIndex === slots.length) return { end: at, picks: [] };
    const slot = slots[slotIndex];
    if (slot.type === 'phrase') {
      const ends = Array.from({ length: Math.max(0, tokens.length - at) }, (_, i) => at + i + 1);
      if (!slots.slice(slotIndex + 1).some((s) => s.type === 'word')) ends.reverse();
      for (const end of ends) {
        const rest = this.matchSlots(slots, tokens, slotIndex + 1, end);
        if (rest) return rest;
      }
      return null;
    }
    if (at >= tokens.length) return null;
    const reading = tokens[at].matches.find((m) => this.readingFitsSlot(m, slot));
    if (!reading) return null;
    const rest = this.matchSlots(slots, tokens, slotIndex + 1, at + 1);
    return rest && { end: rest.end, picks: [{ token: at, reading, tag: slot.glossTag || null }, ...rest.picks] };
  }

  private readingFitsSlot(m: TokenMatch, slot: Exclude<ConstructionSlot, { type: 'phrase' }>): boolean {
    if (m.kind === 'derivation') return false;
    if (slot.type === 'word' ? m.lexeme.id !== slot.lexemeId : m.lexeme.posId !== slot.posId) return false;
    const fixed = this.intrinsicLevels(m.lexeme);
    if (m.kind === 'inflected') return hasFeatures({ ...fixed, ...m.features }, slot.features);
    if (hasFeatures(fixed, slot.features)) return true;
    // Unmarked cells look like the bare word, so they aren't separate readings.
    return [...this.paradigm(m.lexeme.id).cells.values()].some((c) => c.kind === 'unmarked' && c.phonemic === m.phonemic && hasFeatures({ ...fixed, ...c.features }, slot.features));
  }

  // -------------------------------------------------------------------------
  // Generation
  // -------------------------------------------------------------------------

  generate(count: number, minSyllables = 1, maxSyllables = 3, rng?: () => number): string[] {
    return generateWords({
      templates: this.doc.templates,
      constraints: this.doc.constraints,
      inventory: this.inventory,
      count,
      minSyllables,
      maxSyllables,
      rng,
    });
  }

  /** Whether a phonemic form matches a pattern at a position. */
  tryConditions(position: 'startsWith' | 'endsWith' | 'contains', segments: import('./types').Segment[], phonemic: string): boolean {
    return matchesAt(position, segments, phonemic, this.inventory);
  }

  /** Runs an unsaved rule on a phonemic form, for live previews. */
  tryRule(rule: Pick<MorphRule, 'branches'>, phonemic: string) {
    return applyRule(rule, phonemic, this.inventory);
  }

  /** Runs an unsaved set of branches through every active derivational rule in order. */
  stackRules(rule: MorphRule | Pick<MorphRule, 'branches'>, ruleId: Id | null, phonemic: string): { form: string | null; applied: number } {
    const others = this.doc.rules.filter((r) => r.active && r.id !== ruleId).sort((a, b) => a.order - b.order);
    const ordered = ruleId === null ? [...others, rule] : this.doc.rules.filter((r) => r.active).sort((a, b) => a.order - b.order).map((r) => (r.id === ruleId ? rule : r));
    let current = phonemic;
    let applied = 0;
    for (const r of ordered) {
      const res = applyRule(r, current, this.inventory);
      if (res.ok) {
        current = res.form;
        applied++;
      }
    }
    return { form: applied ? current : null, applied };
  }

  /** Characters in a rule's literal text that aren't phonemes of this language. */
  unknownPhonemesInRule(rule: Pick<MorphRule, 'branches'>): string[] {
    return unknownPhonemes(literalTexts(rule), this.inventory).map((u) => u.char);
  }

  /** Characters in phonemic text outside the inventory. */
  unknownPhonemesIn(phonemic: string): string[] {
    return unknownPhonemes([phonemic], this.inventory).map((u) => u.char);
  }

  /** Sample words for rule previews. */
  sampleWords(count: number, rng?: () => number): string[] {
    return this.generate(count, 1, 3, rng);
  }
}

const cache = new WeakMap<ProjectDoc, LanguageEngine>();

/** One engine per immutable document version. */
export function engineFor(doc: ProjectDoc): LanguageEngine {
  let e = cache.get(doc);
  if (!e) {
    e = new LanguageEngine(doc);
    cache.set(doc, e);
  }
  return e;
}
