// The project document: one JSON file per language. Everything is structured
// data; there is no rule mini-language anywhere in this model.

export type Id = number;

// ---------------------------------------------------------------------------
// Sound sequences (shared by conditions, templates, constraints, rewrites)
// ---------------------------------------------------------------------------

/** A built-in class: C, V, or a natural class referenced by name. */
export interface ClassSegment {
  kind: 'class';
  name: string;
  optional?: boolean;
}

/** Literal phonemic text. */
export interface SoundSegment {
  kind: 'sound';
  text: string;
  optional?: boolean;
}

/** Word edge, usable only in rewrite-rule contexts. */
export interface BoundarySegment {
  kind: 'boundary';
}

export type Segment = ClassSegment | SoundSegment | BoundarySegment;

// ---------------------------------------------------------------------------
// Morphological rules
// ---------------------------------------------------------------------------

export type CondPosition = 'startsWith' | 'endsWith' | 'contains';

export interface Condition {
  position: CondPosition;
  segments: Segment[];
}

export type TemplatePart = { kind: 'slot'; index: number } | { kind: 'sound'; text: string };

export type Operation =
  | { type: 'prefix'; affix: string }
  | { type: 'suffix'; affix: string }
  | { type: 'infix'; affix: string; afterConsonant: number }
  | {
      type: 'replace';
      /** What gets replaced: a single class or a literal sound sequence. */
      from: ClassSegment | SoundSegment;
      to: string;
      /** null = every occurrence. */
      count: number | null;
      direction: 'fromStart' | 'fromEnd';
    }
  | { type: 'template'; parts: TemplatePart[] }
  | { type: 'reduplicate'; scope: 'full' | 'CV' | 'C'; position: 'prefix' | 'suffix' }
  /** Lengthens a vowel or geminates a consonant, picked by position among its kind. */
  | { type: 'elongate'; target: 'vowel' | 'consonant'; index: 1 | 2 | 3; direction: 'fromStart' | 'fromEnd' }
  | { type: 'suppletive'; form: string }
  | { type: 'removeSuffix'; suffix: string };

export interface Branch {
  /** Empty = the default branch. All conditions must hold. */
  conditions: Condition[];
  operations: Operation[];
}

export type RuleKind = 'inflectional' | 'derivational';

export interface MorphRule {
  id: Id;
  name: string;
  kind: RuleKind;
  active: boolean;
  order: number;
  description?: string;
  branches: Branch[];
  /** Inflectional: POS this rule applies to. */
  posIds: Id[];
  /** Inflectional: dimension id -> level id, authored in the smallest posId's id space. */
  bindings: Record<string, Id>;
  /** Derivational. */
  inputPosId: Id | null;
  outputPosId: Id | null;
  outputIntrinsic: Record<string, Id>;
  autoApply: boolean;
}

export interface Marker {
  id: Id;
  posId: Id;
  name: string;
  bindings: Record<string, Id>;
}

/** A word-specific irregular result for one rule. */
export interface RuleException {
  id: Id;
  lexemeId: Id;
  ruleId: Id;
  form: string;
}

// ---------------------------------------------------------------------------
// Phonology
// ---------------------------------------------------------------------------

export interface Phoneme {
  id: Id;
  symbol: string;
  type: 'consonant' | 'vowel';
  manner?: string | null;
  place?: string | null;
  voicing?: string | null;
  height?: string | null;
  backness?: string | null;
  rounded?: boolean | null;
}

export interface NaturalClass {
  id: Id;
  name: string;
  phonemeIds: Id[];
}

export interface SyllableTemplate {
  id: Id;
  segments: Segment[];
  description?: string | null;
  active: boolean;
}

export type GeminationPosition = 'everywhere' | 'coda' | 'onset' | 'initial' | 'final';

export type Constraint =
  | {
      id: Id;
      kind: 'sequence';
      segments: Segment[];
      position: 'anywhere' | 'start' | 'end';
      description?: string | null;
      active: boolean;
    }
  | {
      id: Id;
      kind: 'gemination';
      positions: GeminationPosition[];
      description?: string | null;
      active: boolean;
    };

export interface RewriteRule {
  id: Id;
  input: Segment[];
  output: string;
  left: Segment[];
  right: Segment[];
}

export interface RomanizationMapping {
  id: Id;
  phoneme: string;
  latin: string;
}

// ---------------------------------------------------------------------------
// Grammar
// ---------------------------------------------------------------------------

export interface PartOfSpeech {
  id: Id;
  name: string;
  abbr: string;
}

export interface Level {
  id: Id;
  name: string;
  abbr: string;
  order: number;
}

export interface Dimension {
  id: Id;
  posId: Id;
  name: string;
  abbr?: string | null;
  order: number;
  intrinsic: boolean;
  templateId?: string | null;
  levels: Level[];
}

export type StandardFormKind = 'startsWith' | 'endsWith' | 'contains';

export interface StandardFormBranch {
  kind: StandardFormKind;
  segments: Segment[];
}

export interface StandardForm {
  dimensionId: Id;
  levelId: Id;
  branches: StandardFormBranch[];
}

/** Levels a slot accepts, by dimension id. Dimensions left out accept any level. */
export type SlotFeatures = Record<string, Id>;

export type ConstructionSlot =
  /** One specific word or particle. `missing` names it once it no longer exists. */
  | { id: Id; type: 'word'; lexemeId: Id; glossTag?: string | null; features?: SlotFeatures; missing?: string | null }
  /** Any word of a part of speech. `missing` names the part of speech once it no longer exists. */
  | { id: Id; type: 'pos'; posId: Id; glossTag?: string | null; features?: SlotFeatures; missing?: string | null }
  /** Any run of words. The two kinds match the same way; the difference is documentation. */
  | { id: Id; type: 'phrase'; kind: 'phrase' | 'clause'; label?: string | null };

export interface Construction {
  id: Id;
  name: string;
  order: number;
  slots: ConstructionSlot[];
}

// ---------------------------------------------------------------------------
// Lexicon
// ---------------------------------------------------------------------------

/**
 * How a word gets its form. A derived word stores no phonemes at all, so no
 * screen can accidentally show a stale or parent form.
 */
export type LexemeForm =
  | { kind: 'root'; phonemic: string; roman?: string | null }
  /** Live derivation: always recomputed from the parent through the rule. */
  | { kind: 'derived'; parentId: Id; ruleId: Id }
  /** Hand-edited derivation: keeps its parent link, has its own form. */
  | { kind: 'detached'; parentId: Id | null; phonemic: string; roman?: string | null };

export interface Lexeme {
  id: Id;
  form: LexemeForm;
  meaning?: string | null;
  posId: Id | null;
  isException: boolean;
  rootOnly: boolean;
  /** Set only on a particle, which has this tag instead of a meaning. */
  glossTag?: string | null;
  skippedDimensionIds: Id[];
  intrinsicLevels: Record<string, Id>;
}

export function isParticle(l: Pick<Lexeme, 'glossTag'>): boolean {
  return !!l.glossTag;
}

export interface ParentLink {
  childId: Id;
  parentId: Id;
  relationship?: string | null;
  notes?: string | null;
}

export interface CellOverride {
  lexemeId: Id;
  /** Canonical feature key, see featureKey(). */
  key: string;
  features: Record<string, Id>;
  phonemic: string;
  roman?: string | null;
  notes?: string | null;
}

// ---------------------------------------------------------------------------
// Scratchpad and settings
// ---------------------------------------------------------------------------

export interface Phrase {
  id: Id;
  text: string;
  translation?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface ParadigmAxes {
  rows: Id | null;
  cols: Id | null;
}

export interface BackfillBanner {
  dimId: Id;
  dimName: string;
  count: number;
}

export interface ProjectSettings {
  romanizationEnabled: boolean;
  typology: {
    alignment?: string | null;
    wordOrder?: string | null;
    modality?: string | null;
    headDirection?: string | null;
    adposition?: string | null;
    adjectivePlacement?: string | null;
    genitivePlacement?: string | null;
  };
  paradigmAxes: Record<string, ParadigmAxes>;
  lastSelectedWord: Record<string, Id>;
  backfillBanners: BackfillBanner[];
}

export const FORMAT = 'conlang-workbench';
export const FORMAT_VERSION = 2;

export interface ProjectDoc {
  format: typeof FORMAT;
  version: number;
  name: string;
  createdAt: string;
  updatedAt: string;
  nextId: number;
  phonemes: Phoneme[];
  naturalClasses: NaturalClass[];
  templates: SyllableTemplate[];
  constraints: Constraint[];
  rewriteRules: RewriteRule[];
  romanization: RomanizationMapping[];
  partsOfSpeech: PartOfSpeech[];
  dimensions: Dimension[];
  standardForms: StandardForm[];
  rules: MorphRule[];
  markers: Marker[];
  exceptions: RuleException[];
  lexemes: Lexeme[];
  parents: ParentLink[];
  overrides: CellOverride[];
  constructions: Construction[];
  phrases: Phrase[];
  settings: ProjectSettings;
}

export function emptyProject(name: string, now = new Date().toISOString()): ProjectDoc {
  return {
    format: FORMAT,
    version: FORMAT_VERSION,
    name,
    createdAt: now,
    updatedAt: now,
    nextId: 1,
    phonemes: [],
    naturalClasses: [],
    templates: [],
    constraints: [],
    rewriteRules: [],
    romanization: [],
    partsOfSpeech: [],
    dimensions: [],
    standardForms: [],
    rules: [],
    markers: [],
    exceptions: [],
    lexemes: [],
    parents: [],
    overrides: [],
    constructions: [],
    phrases: [],
    settings: {
      romanizationEnabled: true,
      typology: {},
      paradigmAxes: {},
      lastSelectedWord: {},
      backfillBanners: [],
    },
  };
}

export interface ParsedProject {
  doc: ProjectDoc;
  /** What an upgrade changed that the user should hear about. */
  warnings: string[];
  /** The file was in an older format, so it should be saved again. */
  migrated: boolean;
}

/** Parses a project file, upgrading older formats. Throws with a readable message when it isn't one. */
export function parseProjectReport(text: string): ParsedProject {
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch {
    throw new Error('This file is not valid JSON.');
  }
  const parsed = raw as Partial<ProjectDoc>;
  if (!parsed || typeof parsed !== 'object' || parsed.format !== FORMAT) {
    throw new Error('This file is not a Conlang Workbench project.');
  }
  if (typeof parsed.version !== 'number' || parsed.version > FORMAT_VERSION) {
    throw new Error('This project was saved by a newer version of Conlang Workbench.');
  }
  const base = emptyProject(parsed.name ?? 'Untitled', parsed.createdAt);
  const doc = { ...base, ...parsed, settings: { ...base.settings, ...parsed.settings } } as ProjectDoc;
  const migrated = parsed.version < FORMAT_VERSION;
  const warnings = migrated ? migrateParticles(doc) : [];
  doc.version = FORMAT_VERSION;
  return { doc, warnings, migrated };
}

export function parseProject(text: string): ProjectDoc {
  return parseProjectReport(text).doc;
}

type V1Lexeme = Lexeme & { isClosedClass?: boolean };
type V1Slot = { id: Id; type: 'gloss_tag' | 'pos'; value: string; label?: string | null };

/**
 * Format 1 to 2. Words used to hold a closed-class flag and a tag side by side,
 * and slots named a tag. Now a tag on a word means it is a particle, and slots
 * point at the word itself. Returns what the user should be told.
 */
export function migrateParticles(doc: ProjectDoc): string[] {
  const warnings: string[] = [];
  const words = doc.lexemes as V1Lexeme[];
  const tagOf = (l: V1Lexeme) => l.glossTag?.trim() || null;
  const isOldParticle = (l: V1Lexeme) => !!tagOf(l) && !l.meaning?.trim();
  const nameOf = (l: V1Lexeme) => {
    const form = l.form.kind === 'derived' ? '' : l.form.roman || l.form.phonemic;
    return [form, l.meaning?.trim() && `"${l.meaning.trim()}"`].filter(Boolean).join(' ') || `word #${l.id}`;
  };
  // Particles first, since only they could fill a tag slot before.
  const withTag = (tag: string) =>
    words
      .filter((l) => tagOf(l)?.toUpperCase() === tag.toUpperCase())
      .sort((a, b) => Number(isOldParticle(b)) - Number(isOldParticle(a)) || Number(!!b.isClosedClass) - Number(!!a.isClosedClass) || a.id - b.id);

  const usedBySlot = new Set<Id>();
  for (const c of doc.constructions) {
    c.slots = (c.slots as unknown as V1Slot[]).map((old): ConstructionSlot => {
      if (old.label?.trim()) warnings.push(`Construction "${c.name}": the slot label "${old.label.trim()}" was dropped.`);
      if (old.type === 'pos') {
        const posId = Number(old.value);
        if (doc.partsOfSpeech.some((p) => p.id === posId)) return { id: old.id, type: 'pos', posId };
        warnings.push(`Construction "${c.name}": ${old.value} is not a part of speech, so that slot is marked missing.`);
        return { id: old.id, type: 'pos', posId: 0, missing: old.value };
      }
      const [word, ...others] = withTag(old.value);
      if (!word) {
        warnings.push(`Construction "${c.name}": no word has the tag ${old.value}, so that slot is marked missing.`);
        return { id: old.id, type: 'word', lexemeId: 0, glossTag: old.value, missing: old.value };
      }
      if (others.length) warnings.push(`Construction "${c.name}": several words have the tag ${old.value}. The slot now points at ${nameOf(word)}.`);
      usedBySlot.add(word.id);
      return { id: old.id, type: 'word', lexemeId: word.id, ...(isOldParticle(word) ? {} : { glossTag: tagOf(word) }) };
    });
  }

  let particlePos: Id | null = null;
  for (const l of words) {
    const tag = tagOf(l);
    if (tag && !isOldParticle(l) && !usedBySlot.has(l.id)) warnings.push(`${nameOf(l)}: the gloss tag ${tag} was dropped, because the word has a meaning and no construction uses the tag.`);
    if (isOldParticle(l)) {
      l.glossTag = tag;
      l.meaning = null;
      if (l.posId == null) {
        particlePos ??= doc.partsOfSpeech.find((p) => p.name.toLowerCase() === 'particle')?.id ?? null;
        if (particlePos === null) {
          particlePos = doc.nextId++;
          doc.partsOfSpeech.push({ id: particlePos, name: 'Particle', abbr: 'p' });
        }
        l.posId = particlePos;
      }
    } else {
      l.glossTag = null;
    }
    delete l.isClosedClass;
  }
  return warnings;
}

export function serializeProject(doc: ProjectDoc): string {
  return JSON.stringify(doc, null, 2) + '\n';
}
