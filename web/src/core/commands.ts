// Every change to a project. Shared by the UI and the MCP tools so both follow
// the same rules. Commands mutate a draft (see applyCommand) and throw
// CommandError with a message fit to show the user.

import { dynamicPair, LanguageEngine } from './engine';
import { featureKey, type FeatureSet } from './paradigm';
import { validateBijection } from './notation';
import type {
  Branch,
  Constraint,
  Construction,
  ConstructionSlot,
  Dimension,
  GeminationPosition,
  Id,
  Lexeme,
  Marker,
  MorphRule,
  Phoneme,
  ProjectDoc,
  RewriteRule,
  RuleKind,
  Segment,
  StandardFormBranch,
} from './types';
import ipaSounds from '../data/ipa_sounds.json';

export class CommandError extends Error {}

/** Runs a command on a copy of the document and returns the new version. */
export function applyCommand<T>(doc: ProjectDoc, command: (draft: ProjectDoc) => T, now = new Date().toISOString()): { doc: ProjectDoc; result: T } {
  const draft = structuredClone(doc);
  const result = command(draft);
  draft.updatedAt = now;
  return { doc: draft, result };
}

function newId(d: ProjectDoc): Id {
  return d.nextId++;
}

function find<T extends { id: Id }>(list: T[], id: Id, what: string): T {
  const row = list.find((x) => x.id === id);
  if (!row) throw new CommandError(`${what} not found.`);
  return row;
}

function removeFrom<T>(list: T[], pred: (x: T) => boolean) {
  for (let i = list.length - 1; i >= 0; i--) if (pred(list[i])) list.splice(i, 1);
}

// ---------------------------------------------------------------------------
// Phonology
// ---------------------------------------------------------------------------

export type PhonemeInput = Omit<Phoneme, 'id'>;

function cleanPhoneme(p: PhonemeInput): PhonemeInput {
  const consonant = p.type === 'consonant';
  return {
    symbol: p.symbol,
    type: p.type,
    manner: consonant ? (p.manner ?? null) : null,
    place: consonant ? (p.place ?? null) : null,
    voicing: consonant ? (p.voicing ?? null) : null,
    height: consonant ? null : (p.height ?? null),
    backness: consonant ? null : (p.backness ?? null),
    rounded: consonant ? null : (p.rounded ?? false),
  };
}

export function addPhoneme(d: ProjectDoc, p: PhonemeInput): Id {
  const id = newId(d);
  d.phonemes.push({ id, ...cleanPhoneme(p) });
  return id;
}

export function updatePhoneme(d: ProjectDoc, id: Id, p: PhonemeInput) {
  Object.assign(find(d.phonemes, id, 'Phoneme'), cleanPhoneme(p));
}

export function deletePhoneme(d: ProjectDoc, id: Id) {
  removeFrom(d.phonemes, (p) => p.id === id);
  for (const c of d.naturalClasses) c.phonemeIds = c.phonemeIds.filter((x) => x !== id);
}

export function saveNaturalClass(d: ProjectDoc, id: Id | null, name: string, phonemeIds: Id[]): Id {
  const trimmed = name.trim();
  const problem = naturalClassNameProblem(trimmed);
  if (problem) throw new CommandError(problem);
  if (id !== null) {
    Object.assign(find(d.naturalClasses, id, 'Natural class'), { name: trimmed, phonemeIds });
    return id;
  }
  const nid = newId(d);
  d.naturalClasses.push({ id: nid, name: trimmed, phonemeIds });
  return nid;
}

export function naturalClassNameProblem(name: string): string | null {
  if (!name.trim()) return 'Required';
  if (name === 'C' || name === 'V') return 'C and V are reserved system classes';
  const aliases: Record<string, string> = { S: 'Stop', N: 'Nasal', F: 'Fricative', L: 'Liquid', R: 'Rhotic' };
  if (aliases[name]) return `${name} is a reserved default-class alias (${aliases[name]}). Use a different name.`;
  return null;
}

export function deleteNaturalClass(d: ProjectDoc, id: Id) {
  removeFrom(d.naturalClasses, (c) => c.id === id);
}

export function saveTemplate(d: ProjectDoc, id: Id | null, segments: Segment[], description: string): Id {
  if (!segments.length) throw new CommandError('A template needs at least one position.');
  if (id !== null) {
    Object.assign(find(d.templates, id, 'Template'), { segments, description: description || null });
    return id;
  }
  const nid = newId(d);
  d.templates.push({ id: nid, segments, description: description || null, active: true });
  return nid;
}

export function setTemplateActive(d: ProjectDoc, id: Id, active: boolean) {
  find(d.templates, id, 'Template').active = active;
}

export function deleteTemplate(d: ProjectDoc, id: Id) {
  removeFrom(d.templates, (t) => t.id === id);
}

export function saveSequenceConstraint(d: ProjectDoc, id: Id | null, segments: Segment[], position: 'anywhere' | 'start' | 'end', description: string): Id {
  if (!segments.length) throw new CommandError('A forbidden sequence needs at least one position.');
  if (id !== null) {
    Object.assign(find(d.constraints, id, 'Constraint'), { segments, position, description: description || null });
    return id;
  }
  const nid = newId(d);
  d.constraints.push({ id: nid, kind: 'sequence', segments, position, description: description || null, active: true });
  return nid;
}

export function saveGeminationConstraint(d: ProjectDoc, id: Id | null, positions: GeminationPosition[], description: string): Id {
  const normalized: GeminationPosition[] = !positions.length || positions.includes('everywhere') ? ['everywhere'] : positions;
  if (id !== null) {
    Object.assign(find(d.constraints, id, 'Constraint'), { positions: normalized, description: description || null });
    return id;
  }
  if (d.constraints.some((c) => c.kind === 'gemination')) {
    throw new CommandError('A gemination constraint already exists. Edit the existing one.');
  }
  const nid = newId(d);
  d.constraints.push({ id: nid, kind: 'gemination', positions: normalized, description: description || null, active: true } as Constraint);
  return nid;
}

export function setConstraintActive(d: ProjectDoc, id: Id, active: boolean) {
  find(d.constraints, id, 'Constraint').active = active;
}

export function deleteConstraint(d: ProjectDoc, id: Id) {
  removeFrom(d.constraints, (c) => c.id === id);
}

export function saveRewriteRule(d: ProjectDoc, id: Id | null, r: Omit<RewriteRule, 'id'>): Id {
  if (!r.input.length) throw new CommandError('The pattern is empty.');
  if (!r.output.trim()) throw new CommandError('The replacement is empty.');
  if (id !== null) {
    Object.assign(find(d.rewriteRules, id, 'Rewrite rule'), r);
    return id;
  }
  const nid = newId(d);
  d.rewriteRules.push({ id: nid, ...r });
  return nid;
}

export function deleteRewriteRule(d: ProjectDoc, id: Id) {
  removeFrom(d.rewriteRules, (r) => r.id === id);
}

export function setRomanizationEnabled(d: ProjectDoc, enabled: boolean) {
  d.settings.romanizationEnabled = enabled;
}

/** Features for an IPA symbol from the built-in chart. A long sound has the features of its short one. */
export function featuresForSymbol(symbol: string): PhonemeInput | null {
  const short = symbol.length > 1 && symbol.endsWith('ː') ? featuresForSymbol(symbol.slice(0, -1)) : null;
  if (short) return { ...short, symbol };
  const consonant = [...ipaSounds.pulmonic, ...ipaSounds.nonPulmonic].find((s) => s.symbol === symbol);
  if (consonant) {
    return {
      symbol,
      type: 'consonant',
      manner: consonant.manner ?? null,
      place: consonant.place ?? null,
      voicing: consonant.voiced === true ? 'voiced' : consonant.voiced === false ? 'voiceless' : null,
    };
  }
  const vowel = ipaSounds.vowels.find((s) => s.symbol === symbol);
  if (vowel) return { symbol, type: 'vowel', height: vowel.height ?? null, backness: vowel.backness ?? null, rounded: vowel.rounded ?? false };
  return null;
}

/** Adds or edits a mapping. Blocks anything that breaks round-tripping. Returns a created phoneme's symbol. */
export function saveRomanization(d: ProjectDoc, id: Id | null, phoneme: string, latin: string): string | null {
  const ipa = phoneme.trim();
  const lat = latin.trim();
  if (!ipa || !lat) throw new CommandError('Both a Latin letter and an IPA sound are required.');
  const proposed = d.romanization.map((m) => (m.id === id ? { ...m, phoneme: ipa, latin: lat } : m));
  if (id === null) proposed.push({ id: -1, phoneme: ipa, latin: lat });
  const violations = validateBijection(proposed);
  if (violations.length) throw new CommandError(`Romanization bijection conflict: ${violations[0].detail}`);
  if (id !== null) {
    Object.assign(find(d.romanization, id, 'Mapping'), { phoneme: ipa, latin: lat });
    return null;
  }
  d.romanization.push({ id: newId(d), phoneme: ipa, latin: lat });
  if (d.phonemes.some((p) => p.symbol === ipa)) return null;
  addPhoneme(d, featuresForSymbol(ipa) ?? { symbol: ipa, type: 'consonant' });
  return ipa;
}

export function deleteRomanization(d: ProjectDoc, id: Id) {
  removeFrom(d.romanization, (m) => m.id === id);
}

// ---------------------------------------------------------------------------
// Parts of speech and dimensions
// ---------------------------------------------------------------------------

export function savePos(d: ProjectDoc, id: Id | null, name: string, abbr: string): Id {
  const n = name.trim();
  const a = abbr.trim().toLowerCase();
  if (!n || !a) throw new CommandError('A name and an abbreviation are required.');
  if (id !== null) {
    Object.assign(find(d.partsOfSpeech, id, 'Part of speech'), { name: n, abbr: a });
    return id;
  }
  const nid = newId(d);
  d.partsOfSpeech.push({ id: nid, name: n, abbr: a });
  return nid;
}

export function deletePos(d: ProjectDoc, id: Id, migrateTo: Id | null) {
  const count = d.lexemes.filter((l) => l.posId === id).length;
  if (count > 0 && migrateTo === null && d.partsOfSpeech.length <= 1) {
    throw new CommandError(`${count} word(s) use this POS and there are no other parts of speech to migrate them to. Add another POS first.`);
  }
  const dims = d.dimensions.filter((x) => x.posId === id).map((x) => x.id);
  for (const l of d.lexemes) {
    if (l.posId === id) l.posId = migrateTo;
    for (const dim of dims) delete l.intrinsicLevels[dim];
  }
  for (const dim of dims) removeDimensionReferences(d, dim);
  removeFrom(d.dimensions, (x) => x.posId === id);
  removeFrom(d.markers, (m) => m.posId === id);
  for (const r of d.rules) {
    if (r.kind === 'inflectional') r.posIds = r.posIds.filter((p) => p !== id);
    if (r.inputPosId === id) r.inputPosId = null;
    if (r.outputPosId === id) r.outputPosId = null;
  }
  const orphaned = d.rules.filter((r) => r.kind === 'inflectional' && r.posIds.length === 0).map((r) => r.id);
  for (const ruleId of orphaned) deleteRule(d, ruleId);
  const name = d.partsOfSpeech.find((p) => p.id === id)?.name;
  for (const c of d.constructions) for (const s of c.slots) if (s.type === 'pos' && s.posId === id) s.missing = name;
  delete d.settings.paradigmAxes[id];
  delete d.settings.lastSelectedWord[id];
  removeFrom(d.partsOfSpeech, (p) => p.id === id);
}

export function addDimension(d: ProjectDoc, posId: Id, name: string, levels: { name: string; abbr: string }[], templateId: string | null): Id {
  const id = newId(d);
  const own = d.dimensions.filter((x) => x.posId === posId);
  const order = own.length ? Math.max(...own.map((x) => x.order)) + 1 : 0;
  d.dimensions.push({
    id,
    posId,
    name,
    abbr: null,
    order,
    intrinsic: false,
    templateId,
    levels: levels.map((l, i) => ({ id: i + 1, name: l.name, abbr: l.abbr, order: i })),
  });
  return id;
}

export function updateDimension(d: ProjectDoc, id: Id, name: string, abbr: string) {
  const dim = find(d.dimensions, id, 'Dimension');
  if (!name.trim()) throw new CommandError('Name cannot be empty');
  dim.name = name.trim();
  dim.abbr = abbr.trim() ? abbr.trim().toLowerCase() : null;
}

function removeDimensionReferences(d: ProjectDoc, dimId: Id) {
  for (const r of d.rules) {
    delete r.bindings[dimId];
    delete r.outputIntrinsic[dimId];
  }
  for (const m of d.markers) delete m.bindings[dimId];
  for (const l of d.lexemes) delete l.intrinsicLevels[dimId];
  removeFrom(d.overrides, (o) => o.features[dimId] !== undefined);
  removeFrom(d.standardForms, (s) => s.dimensionId === dimId);
  for (const features of slotFeatures(d)) delete features[dimId];
  d.settings.backfillBanners = d.settings.backfillBanners.filter((b) => b.dimId !== dimId);
}

function slotFeatures(d: ProjectDoc) {
  return d.constructions.flatMap((c) => c.slots.flatMap((s) => (s.type !== 'phrase' && s.features ? [s.features] : [])));
}

export function deleteDimension(d: ProjectDoc, id: Id) {
  removeDimensionReferences(d, id);
  removeFrom(d.dimensions, (x) => x.id === id);
}

/** Turning intrinsic on assigns the first level to words that lack one. Returns how many. */
export function setDimensionIntrinsic(d: ProjectDoc, id: Id, intrinsic: boolean): number {
  const dim = find(d.dimensions, id, 'Dimension');
  const was = dim.intrinsic;
  dim.intrinsic = intrinsic;
  if (!intrinsic || was || !dim.levels.length) return 0;
  const first = dim.levels.slice().sort((a, b) => a.order - b.order)[0].id;
  let count = 0;
  for (const l of d.lexemes) {
    if (l.posId !== dim.posId || l.intrinsicLevels[id] !== undefined) continue;
    l.intrinsicLevels[id] = first;
    count++;
  }
  d.settings.backfillBanners = d.settings.backfillBanners.filter((b) => b.dimId !== id);
  if (count) d.settings.backfillBanners.push({ dimId: id, dimName: dim.name, count });
  // Axis-level overrides no longer address a cell once the dimension stops being an axis.
  removeFrom(d.overrides, (o) => o.features[id] !== undefined);
  return count;
}

export function dismissBackfillBanner(d: ProjectDoc, dimId: Id) {
  d.settings.backfillBanners = d.settings.backfillBanners.filter((b) => b.dimId !== dimId);
}

export function purgeIntrinsicEntries(d: ProjectDoc, dimId: Id): number {
  let count = 0;
  for (const l of d.lexemes) {
    if (l.intrinsicLevels[dimId] !== undefined) {
      delete l.intrinsicLevels[dimId];
      count++;
    }
  }
  return count;
}

export function saveLevel(d: ProjectDoc, dimId: Id, levelId: Id | null, name: string, abbr: string): Id {
  const dim = find(d.dimensions, dimId, 'Dimension');
  const n = name.trim();
  const a = abbr.trim().toLowerCase();
  if (!n) throw new CommandError('Name cannot be empty');
  if (!a) throw new CommandError('Abbreviation cannot be empty');
  if (levelId !== null) {
    Object.assign(find(dim.levels, levelId, 'Level'), { name: n, abbr: a });
    return levelId;
  }
  const id = dim.levels.length ? Math.max(...dim.levels.map((l) => l.id)) + 1 : 1;
  const order = dim.levels.length ? Math.max(...dim.levels.map((l) => l.order)) + 1 : 0;
  dim.levels.push({ id, name: n, abbr: a, order });
  return id;
}

export interface LevelReferences {
  lexemeIds: Id[];
  patternCount: number;
  ruleNames: string[];
  markerCount: number;
  overrideCount: number;
  slotCount: number;
  total: number;
}

export function levelReferences(d: ProjectDoc, dimId: Id, levelId: Id): LevelReferences {
  const lexemeIds = d.lexemes.filter((l) => l.intrinsicLevels[dimId] === levelId).map((l) => l.id);
  const patternCount = d.standardForms.filter((s) => s.dimensionId === dimId && s.levelId === levelId).length;
  const ruleNames = d.rules.filter((r) => r.bindings[dimId] === levelId || r.outputIntrinsic[dimId] === levelId).map((r) => r.name);
  const markerCount = d.markers.filter((m) => m.bindings[dimId] === levelId).length;
  const overrideCount = d.overrides.filter((o) => o.features[dimId] === levelId).length;
  const slotCount = slotFeatures(d).filter((f) => f[dimId] === levelId).length;
  return { lexemeIds, patternCount, ruleNames, markerCount, overrideCount, slotCount, total: lexemeIds.length + patternCount + ruleNames.length + markerCount + overrideCount + slotCount };
}

export function deleteLevel(d: ProjectDoc, dimId: Id, levelId: Id) {
  if (levelReferences(d, dimId, levelId).total) throw new CommandError('This level is still in use; reassign it first.');
  const dim = find(d.dimensions, dimId, 'Dimension');
  dim.levels = dim.levels.filter((l) => l.id !== levelId);
}

export function reassignLevelAndDelete(d: ProjectDoc, dimId: Id, oldId: Id, newId_: Id) {
  const swap = (rec: Record<string, Id>) => {
    if (rec[dimId] === oldId) rec[dimId] = newId_;
  };
  for (const l of d.lexemes) swap(l.intrinsicLevels);
  for (const r of d.rules) {
    swap(r.bindings);
    swap(r.outputIntrinsic);
  }
  for (const m of d.markers) swap(m.bindings);
  for (const f of slotFeatures(d)) swap(f);
  for (const o of d.overrides) {
    if (o.features[dimId] === oldId) {
      o.features[dimId] = newId_;
      o.key = featureKey(o.features);
    }
  }
  const taken = d.standardForms.some((s) => s.dimensionId === dimId && s.levelId === newId_);
  if (taken) removeFrom(d.standardForms, (s) => s.dimensionId === dimId && s.levelId === oldId);
  else for (const s of d.standardForms) if (s.dimensionId === dimId && s.levelId === oldId) s.levelId = newId_;
  const dim = find(d.dimensions, dimId, 'Dimension');
  dim.levels = dim.levels.filter((l) => l.id !== oldId);
}

export function saveStandardForm(d: ProjectDoc, dimId: Id, levelId: Id, branches: StandardFormBranch[]) {
  removeFrom(d.standardForms, (s) => s.dimensionId === dimId && s.levelId === levelId);
  const useful = branches.filter((b) => b.segments.length);
  if (useful.length) d.standardForms.push({ dimensionId: dimId, levelId, branches: useful });
}

export function setParadigmAxes(d: ProjectDoc, posId: Id, rows: Id | null, cols: Id | null) {
  d.settings.paradigmAxes[posId] = { rows, cols };
}

export function setLastSelectedWord(d: ProjectDoc, posId: Id, lexemeId: Id) {
  d.settings.lastSelectedWord[posId] = lexemeId;
}

export function setTypology(d: ProjectDoc, key: keyof ProjectDoc['settings']['typology'], value: string) {
  d.settings.typology[key] = value;
}

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

export interface RuleInput {
  name: string;
  kind: RuleKind;
  description?: string;
  branches: Branch[];
  posIds: Id[];
  bindings: FeatureSet;
  inputPosId: Id | null;
  outputPosId: Id | null;
  outputIntrinsic: FeatureSet;
  autoApply: boolean;
}

/** Why a rule can't be saved, or null. Mirrors the editor's validation. */
export function ruleProblem(d: ProjectDoc, r: RuleInput): string | null {
  if (!r.name.trim()) return 'Rule name is required.';
  if (r.kind === 'inflectional') {
    if (!r.posIds.length) return 'At least one POS must be selected for inflectional rules.';
    if (!Object.keys(r.bindings).length) return 'Inflectional rules must bind at least one feature. Select at least one level chip above.';
    const bound = Object.keys(r.bindings).map(Number);
    const hasAxis = r.posIds.some((posId) => {
      const dims = d.dimensions.filter((x) => x.posId === posId);
      return bound.some((id) => {
        const own = dims.find((x) => x.id === id);
        if (own) return !own.intrinsic;
        const auth = d.dimensions.find((x) => x.id === id);
        return !!auth && dims.some((x) => x.name === auth.name && !x.intrinsic);
      });
    });
    if (!hasAxis) return 'Rule has no non-intrinsic axes — it would produce no paradigm variation. Intrinsic-only behavior belongs in the word itself.';
  }
  if (!r.branches.length || r.branches.every((b) => !b.operations.length)) return 'At least one branch with one operation is required.';
  return null;
}

/** Defaults come after conditional branches, since the first match wins. */
function orderBranches(branches: Branch[]): Branch[] {
  return branches
    .filter((b) => b.operations.length)
    .map((b, i) => ({ b, i }))
    .sort((x, y) => Number(!x.b.conditions.length) - Number(!y.b.conditions.length) || x.i - y.i)
    .map((x) => x.b);
}

export function saveRule(d: ProjectDoc, id: Id | null, input: RuleInput): Id {
  const problem = ruleProblem(d, input);
  if (problem) throw new CommandError(problem);
  const inflectional = input.kind === 'inflectional';
  const fields = {
    name: input.name.trim(),
    kind: input.kind,
    description: input.description || undefined,
    branches: orderBranches(input.branches),
    posIds: inflectional ? input.posIds.slice().sort((a, b) => a - b) : [],
    bindings: inflectional ? input.bindings : {},
    inputPosId: inflectional ? null : input.inputPosId,
    outputPosId: inflectional ? null : input.outputPosId ?? input.inputPosId,
    outputIntrinsic: inflectional ? {} : input.outputIntrinsic,
    autoApply: inflectional ? false : input.autoApply,
  };
  let ruleId: Id;
  if (id !== null) {
    const rule = find(d.rules, id, 'Rule');
    Object.assign(rule, fields);
    ruleId = id;
    syncDerivedPos(d, rule);
  } else {
    ruleId = newId(d);
    const order = d.rules.length ? Math.max(...d.rules.map((r) => r.order)) + 1 : 0;
    d.rules.push({ id: ruleId, active: true, order, ...fields });
  }
  return ruleId;
}

/** Live derived words carry the rule's output POS. */
function syncDerivedPos(d: ProjectDoc, rule: MorphRule) {
  if (rule.kind !== 'derivational' || rule.outputPosId == null) return;
  for (const l of d.lexemes) if (l.form.kind === 'derived' && l.form.ruleId === rule.id) l.posId = rule.outputPosId;
}

export function setRuleActive(d: ProjectDoc, id: Id, active: boolean) {
  find(d.rules, id, 'Rule').active = active;
}

/** Live derivations of a deleted rule keep their current form, as standalone words. */
export function deleteRule(d: ProjectDoc, id: Id) {
  freezeDerivations(d, (l) => l.form.kind === 'derived' && l.form.ruleId === id);
  removeFrom(d.rules, (r) => r.id === id);
  removeFrom(d.exceptions, (e) => e.ruleId === id);
}

export function moveRule(d: ProjectDoc, id: Id, delta: -1 | 1) {
  const rule = find(d.rules, id, 'Rule');
  const same = d.rules.filter((r) => r.kind === rule.kind).sort((a, b) => a.order - b.order || a.id - b.id);
  // Imported projects can hold duplicate orders, so settle a sequence first.
  same.forEach((r, i) => {
    r.order = i;
  });
  const i = same.findIndex((r) => r.id === id);
  const other = same[i + delta];
  if (!other) return;
  [rule.order, other.order] = [other.order, rule.order];
}

export function saveMarker(d: ProjectDoc, id: Id | null, posIds: Id[], name: string, bindings: FeatureSet): Id {
  if (!Object.keys(bindings).length) throw new CommandError('Select at least one dimension + level to mark as unmarked.');
  if (!posIds.length) throw new CommandError('Select at least one POS to attach this marker to.');
  const fields: Omit<Marker, 'id'> = { posId: posIds[0], name: name.trim() || 'Unmarked', bindings };
  if (id !== null) {
    Object.assign(find(d.markers, id, 'Marker'), fields);
    return id;
  }
  const nid = newId(d);
  d.markers.push({ id: nid, ...fields });
  return nid;
}

export function deleteMarker(d: ProjectDoc, id: Id) {
  removeFrom(d.markers, (m) => m.id === id);
}

// ---------------------------------------------------------------------------
// Lexicon
// ---------------------------------------------------------------------------

export interface WordInput {
  phonemic: string;
  /** Kept only when it differs from what the mappings would give. */
  roman?: string | null;
  meaning?: string | null;
  posId: Id | null;
  rootOnly?: boolean;
  intrinsicLevels?: FeatureSet;
  /** Makes this a particle, which has the tag instead of a meaning. */
  glossTag?: string | null;
  parentIds?: Id[];
}

function requiredIntrinsicProblem(d: ProjectDoc, posId: Id | null, levels: FeatureSet): string | null {
  if (posId === null) return null;
  const pos = d.partsOfSpeech.find((p) => p.id === posId);
  for (const dim of d.dimensions.filter((x) => x.posId === posId && x.intrinsic)) {
    if (levels[dim.id] === undefined) return `Required — every ${pos?.name} must have a fixed ${dim.name}.`;
  }
  return null;
}

function normalizedRoman(d: ProjectDoc, phonemic: string, roman: string | null | undefined): string | null {
  const r = roman?.trim();
  if (!r) return null;
  return new LanguageEngine(d).romanize(phonemic) === r ? null : r;
}

function defaultLexemeFields(): Pick<Lexeme, 'isException' | 'rootOnly' | 'skippedDimensionIds' | 'intrinsicLevels'> {
  return { isException: false, rootOnly: false, skippedDimensionIds: [], intrinsicLevels: {} };
}

const BOTH_MEANING_AND_TAG = 'A word has either a meaning or a gloss tag, not both.';

/** Where a particle goes when nothing better was chosen. */
function particlePos(d: ProjectDoc): Id {
  return d.partsOfSpeech.find((p) => p.name.toLowerCase() === 'particle')?.id ?? savePos(d, null, 'Particle', 'p');
}

export function addWord(d: ProjectDoc, w: WordInput): Id {
  const phonemic = w.phonemic.trim();
  if (!phonemic) throw new CommandError('IPA is required');
  const glossTag = w.glossTag?.trim() || null;
  const meaning = w.meaning?.trim() || null;
  if (glossTag && meaning) throw new CommandError(BOTH_MEANING_AND_TAG);
  if (!w.rootOnly && !glossTag && w.posId === null) throw new CommandError('Part of speech is required');
  const levels = w.intrinsicLevels ?? {};
  if (!glossTag) {
    const problem = requiredIntrinsicProblem(d, w.posId, levels);
    if (problem) throw new CommandError(problem);
  }
  const posId = glossTag && w.posId === null ? particlePos(d) : w.posId;
  const id = newId(d);
  d.lexemes.push({
    ...defaultLexemeFields(),
    id,
    form: { kind: 'root', phonemic, roman: normalizedRoman(d, phonemic, w.roman) },
    meaning,
    posId,
    rootOnly: !!w.rootOnly,
    glossTag,
    intrinsicLevels: levels,
  });
  for (const parentId of w.parentIds ?? []) addParent(d, id, parentId);
  return id;
}

/**
 * Edits a word. If this is a live derivation and the form changed, the word
 * detaches from its rule (keeping its parent) so the hand-written form sticks.
 */
export function updateWord(d: ProjectDoc, id: Id, w: Partial<WordInput>) {
  const engine = new LanguageEngine(d);
  const before = engine.lexeme(id);
  if (before && engine.isDynamic(before)) {
    updateAutomaticWord(d, id, w);
    return;
  }
  const l = find(d.lexemes, id, 'Word');
  const glossTag = w.glossTag !== undefined ? w.glossTag?.trim() || null : l.glossTag || null;
  const meaning = w.meaning !== undefined ? w.meaning?.trim() || null : l.meaning || null;
  if (glossTag && meaning) throw new CommandError(BOTH_MEANING_AND_TAG);
  const posId = w.posId !== undefined ? w.posId : l.posId;
  if (w.posId === null && !l.rootOnly && !glossTag) throw new CommandError('Part of speech is required');
  const nextPos = glossTag && posId === null ? particlePos(d) : posId;
  if (nextPos !== l.posId) {
    // The levels a slot picked belong to the old part of speech.
    for (const c of d.constructions) for (const s of c.slots) if (s.type === 'word' && s.lexemeId === id) delete s.features;
  }
  l.posId = nextPos;
  if (w.intrinsicLevels !== undefined) {
    const problem = glossTag ? null : requiredIntrinsicProblem(d, l.posId, w.intrinsicLevels);
    if (problem) throw new CommandError(problem);
    l.intrinsicLevels = w.intrinsicLevels;
  }
  l.meaning = meaning;
  l.glossTag = glossTag;
  if (w.rootOnly !== undefined) l.rootOnly = w.rootOnly;
  if (w.phonemic !== undefined) {
    const phonemic = w.phonemic.trim();
    if (!phonemic) throw new CommandError('IPA is required');
    if (l.form.kind === 'derived') {
      const current = new LanguageEngine(d).form(id);
      if (current.status === 'broken' || current.phonemic !== phonemic || (w.roman?.trim() && w.roman.trim() !== current.roman)) {
        detachWord(d, id, phonemic, w.roman ?? null);
      }
    } else {
      const roman = w.roman !== undefined ? normalizedRoman(d, phonemic, w.roman) : l.form.roman;
      l.form = { ...l.form, phonemic, roman };
    }
  }
}

/**
 * Stores details on top of an automatic word. It stays generated: a changed
 * form becomes an exception on the rule, a meaning only overlays the template.
 */
function updateAutomaticWord(d: ProjectDoc, id: Id, w: Partial<WordInput>) {
  if (w.glossTag?.trim()) throw new CommandError('An automatic word follows its rule, so it cannot be gloss-only.');
  const rowId = ensureWordRow(d, id);
  const engine = new LanguageEngine(d);
  const row = find(d.lexemes, rowId, 'Word');
  if (row.form.kind !== 'derived') return;
  const { parentId, ruleId } = row.form;
  if (w.meaning !== undefined) {
    const text = w.meaning?.trim() || null;
    row.meaning = text === engine.templateMeaning(row) ? null : text;
  }
  if (w.intrinsicLevels !== undefined) row.intrinsicLevels = w.intrinsicLevels;
  if (w.phonemic !== undefined) {
    const phonemic = w.phonemic.trim();
    if (!phonemic) throw new CommandError('IPA is required');
    const rule = find(d.rules, ruleId, 'Rule');
    const parent = engine.form(parentId);
    const generated = parent.status === 'ok' ? engine.tryRule(rule, parent.phonemic) : null;
    removeFrom(d.exceptions, (e) => e.lexemeId === parentId && e.ruleId === ruleId);
    if (!generated?.ok || generated.form !== phonemic) d.exceptions.push({ id: newId(d), lexemeId: parentId, ruleId, form: phonemic });
  }
  pruneAutomaticRow(d, rowId);
}

/** Gets the stored row for a word, saving an automatic word's row when it first needs one. */
export function ensureWordRow(d: ProjectDoc, id: Id): Id {
  if (id >= 0) return id;
  const pair = dynamicPair(id);
  if (!pair) throw new CommandError('Word not found.');
  const parentId = ensureWordRow(d, pair.parentId);
  const existing = d.lexemes.find((l) => l.form.kind === 'derived' && l.form.parentId === parentId && l.form.ruleId === pair.ruleId);
  if (existing) return existing.id;
  const rule = find(d.rules, pair.ruleId, 'Rule');
  const rowId = newId(d);
  d.lexemes.push({ ...defaultLexemeFields(), id: rowId, form: { kind: 'derived', parentId, ruleId: rule.id }, meaning: null, posId: rule.outputPosId ?? rule.inputPosId });
  return rowId;
}

/** Drops a saved automatic row that no longer adds anything. */
function pruneAutomaticRow(d: ProjectDoc, id: Id) {
  const row = d.lexemes.find((l) => l.id === id);
  if (!row || row.form.kind !== 'derived') return;
  const hasDetail =
    !!row.meaning || row.isException || row.skippedDimensionIds.length > 0 || Object.keys(row.intrinsicLevels).length > 0 ||
    d.overrides.some((o) => o.lexemeId === id) || d.parents.some((p) => p.childId === id || p.parentId === id) ||
    d.exceptions.some((e) => e.lexemeId === id) ||
    constructionsUsingWord(d, id).length > 0 ||
    d.lexemes.some((l) => (l.form.kind === 'derived' || l.form.kind === 'detached') && l.form.parentId === id);
  if (!hasDetail) removeFrom(d.lexemes, (l) => l.id === id);
}

/** Clears everything saved on an automatic word, returning it to pure rule output. */
export function resetAutomaticWord(d: ProjectDoc, id: Id) {
  const rowId = ensureWordRow(d, id);
  const row = find(d.lexemes, rowId, 'Word');
  if (row.form.kind !== 'derived') return;
  const { parentId, ruleId } = row.form;
  removeFrom(d.exceptions, (e) => e.lexemeId === parentId && e.ruleId === ruleId);
  removeFrom(d.overrides, (o) => o.lexemeId === rowId);
  removeFrom(d.parents, (p) => p.childId === rowId);
  Object.assign(row, { meaning: null, isException: false, skippedDimensionIds: [], intrinsicLevels: {} });
  pruneAutomaticRow(d, rowId);
}

export function setSkippedDimension(d: ProjectDoc, id: Id, dimId: Id, skipped: boolean) {
  const w = find(d.lexemes, ensureWordRow(d, id), 'Word');
  w.skippedDimensionIds = skipped ? [...w.skippedDimensionIds, dimId] : w.skippedDimensionIds.filter((x) => x !== dimId);
}

/** Hand-edits a derived form: it stops tracking the rule but stays linked to its parent. */
export function detachWord(d: ProjectDoc, id: Id, phonemic: string, roman: string | null) {
  const l = find(d.lexemes, id, 'Word');
  if (l.form.kind !== 'derived') throw new CommandError('This word is not linked to a rule.');
  // Children keep deriving from this word's new form, nothing else to change.
  l.intrinsicLevels = { ...d.rules.find((r) => r.id === (l.form as { ruleId: Id }).ruleId)?.outputIntrinsic, ...l.intrinsicLevels };
  l.form = { kind: 'detached', parentId: l.form.parentId, phonemic, roman: normalizedRoman(d, phonemic, roman) };
}

/** Commits a computed derivation to the dictionary as a live derived word. */
export function promoteDerivation(d: ProjectDoc, parentId: Id, ruleId: Id, gloss: string): Id {
  parentId = ensureWordRow(d, parentId);
  const parent = find(d.lexemes, parentId, 'Parent word');
  const rule = find(d.rules, ruleId, 'Rule');
  const existing = d.lexemes.find((l) => l.form.kind === 'derived' && l.form.parentId === parentId && l.form.ruleId === ruleId);
  if (existing) return existing.id;
  const id = newId(d);
  d.lexemes.push({
    ...defaultLexemeFields(),
    id,
    form: { kind: 'derived', parentId: parent.id, ruleId: rule.id },
    meaning: gloss.trim() || null,
    posId: rule.outputPosId ?? rule.inputPosId,
  });
  return id;
}

/** Turns words into standalone roots holding their current form. */
function freezeDerivations(d: ProjectDoc, pred: (l: Lexeme) => boolean) {
  const engine = new LanguageEngine(d);
  const targets = d.lexemes.filter(pred);
  const frozen = targets.map((l) => ({ l, form: engine.form(l.id) }));
  for (const { l, form } of frozen) {
    if (l.form.kind !== 'derived') continue;
    const fallback = form.status === 'ok' ? form.phonemic : '?';
    l.intrinsicLevels = { ...d.rules.find((r) => r.id === (l.form as { ruleId: Id }).ruleId)?.outputIntrinsic, ...l.intrinsicLevels };
    l.form = { kind: 'root', phonemic: fallback };
  }
}

/** Removes a committed derivation. Words derived from it keep their current forms. */
export function demoteDerivation(d: ProjectDoc, id: Id) {
  const l = find(d.lexemes, id, 'Word');
  if (l.form.kind !== 'derived') return;
  deleteWord(d, id);
}

/** Constructions with a slot naming this word, for the warning before deleting it. */
export function constructionsUsingWord(d: ProjectDoc, id: Id): Construction[] {
  return d.constructions.filter((c) => c.slots.some((s) => s.type === 'word' && s.lexemeId === id));
}

/** Slots using the word stay, marked missing, so the construction shows what it lost. */
export function deleteWord(d: ProjectDoc, id: Id) {
  const using = constructionsUsingWord(d, id);
  if (using.length) {
    const label = new LanguageEngine(d).form(id).label;
    for (const c of using) for (const s of c.slots) if (s.type === 'word' && s.lexemeId === id) s.missing = label;
  }
  freezeDerivations(d, (c) => c.form.kind === 'derived' && c.form.parentId === id);
  for (const c of d.lexemes) if (c.form.kind === 'detached' && c.form.parentId === id) c.form.parentId = null;
  removeFrom(d.lexemes, (l) => l.id === id);
  removeFrom(d.parents, (p) => p.childId === id || p.parentId === id);
  removeFrom(d.overrides, (o) => o.lexemeId === id);
  removeFrom(d.exceptions, (e) => e.lexemeId === id);
  for (const key of Object.keys(d.settings.lastSelectedWord)) {
    if (d.settings.lastSelectedWord[key] === id) delete d.settings.lastSelectedWord[key];
  }
}

export function setWordException(d: ProjectDoc, id: Id, isException: boolean) {
  find(d.lexemes, ensureWordRow(d, id), 'Word').isException = isException;
}

export function addParent(d: ProjectDoc, childId: Id, parentId: Id, relationship?: string | null) {
  if (childId === parentId) throw new CommandError('A word cannot be its own parent.');
  childId = ensureWordRow(d, childId);
  parentId = ensureWordRow(d, parentId);
  if (d.parents.some((p) => p.childId === childId && p.parentId === parentId)) return;
  d.parents.push({ childId, parentId, relationship: relationship || null });
}

export function removeParent(d: ProjectDoc, childId: Id, parentId: Id) {
  removeFrom(d.parents, (p) => p.childId === childId && p.parentId === parentId);
}

export function setParents(d: ProjectDoc, childId: Id, parentIds: Id[]) {
  childId = ensureWordRow(d, childId);
  removeFrom(d.parents, (p) => p.childId === childId && !parentIds.includes(p.parentId));
  for (const id of parentIds) addParent(d, childId, id);
}

export function addException(d: ProjectDoc, lexemeId: Id, ruleId: Id, form: string): Id {
  if (!form.trim()) throw new CommandError('An override form is required.');
  lexemeId = ensureWordRow(d, lexemeId);
  removeFrom(d.exceptions, (e) => e.lexemeId === lexemeId && e.ruleId === ruleId);
  const id = newId(d);
  d.exceptions.push({ id, lexemeId, ruleId, form: form.trim() });
  return id;
}

export function deleteException(d: ProjectDoc, id: Id) {
  removeFrom(d.exceptions, (e) => e.id === id);
}

export function saveCellOverride(d: ProjectDoc, lexemeId: Id, features: FeatureSet, phonemic: string, roman: string | null, notes?: string | null) {
  if (!phonemic.trim()) throw new CommandError('A form is required.');
  lexemeId = ensureWordRow(d, lexemeId);
  const key = featureKey(features);
  removeFrom(d.overrides, (o) => o.lexemeId === lexemeId && o.key === key);
  d.overrides.push({ lexemeId, key, features, phonemic: phonemic.trim(), roman: roman?.trim() || null, notes: notes ?? null });
}

export function clearCellOverride(d: ProjectDoc, lexemeId: Id, features: FeatureSet) {
  lexemeId = ensureWordRow(d, lexemeId);
  const key = featureKey(features);
  removeFrom(d.overrides, (o) => o.lexemeId === lexemeId && o.key === key);
}

// ---------------------------------------------------------------------------
// Constructions
// ---------------------------------------------------------------------------

export function addConstruction(d: ProjectDoc, name = 'New Construction'): Id {
  const id = newId(d);
  d.constructions.push({ id, name, order: d.constructions.length, slots: [] });
  return id;
}

export function renameConstruction(d: ProjectDoc, id: Id, name: string) {
  if (name.trim()) find(d.constructions, id, 'Construction').name = name.trim();
}

export function deleteConstruction(d: ProjectDoc, id: Id) {
  const words = find(d.constructions, id, 'Construction').slots.flatMap((s) => (s.type === 'word' ? [s.lexemeId] : []));
  removeFrom(d.constructions, (c) => c.id === id);
  words.forEach((w) => releaseAutomaticRow(d, w));
}

type DistributiveOmit<T, K extends string> = T extends unknown ? Omit<T, K> : never;
export type SlotInput = DistributiveOmit<ConstructionSlot, 'id' | 'missing'>;

/** Saves any automatic word the slot names, since a slot persists a reference to it. */
function cleanSlot(d: ProjectDoc, s: SlotInput): SlotInput {
  if (s.type === 'phrase') return { type: 'phrase', kind: s.kind, label: s.label?.trim() || null };
  const tag = s.glossTag?.trim() || null;
  const features = Object.keys(s.features ?? {}).length ? { features: s.features } : {};
  if (s.type === 'pos') {
    find(d.partsOfSpeech, s.posId, 'Part of speech');
    return { type: 'pos', posId: s.posId, glossTag: tag, ...features };
  }
  const lexemeId = ensureWordRow(d, s.lexemeId);
  find(d.lexemes, lexemeId, 'Word');
  return { type: 'word', lexemeId, glossTag: tag, ...features };
}

export function addSlot(d: ProjectDoc, constructionId: Id, slot: SlotInput): Id {
  const c = find(d.constructions, constructionId, 'Construction');
  const clean = cleanSlot(d, slot);
  const id = newId(d);
  c.slots.push({ id, ...clean });
  return id;
}

export function updateSlot(d: ProjectDoc, constructionId: Id, slotId: Id, slot: SlotInput) {
  const c = find(d.constructions, constructionId, 'Construction');
  const old = find(c.slots, slotId, 'Slot');
  const clean = cleanSlot(d, slot);
  c.slots[c.slots.indexOf(old)] = { id: slotId, ...clean };
  if (old.type === 'word') releaseAutomaticRow(d, old.lexemeId);
}

export function deleteSlot(d: ProjectDoc, constructionId: Id, slotId: Id) {
  const c = find(d.constructions, constructionId, 'Construction');
  const old = find(c.slots, slotId, 'Slot');
  c.slots = c.slots.filter((s) => s.id !== slotId);
  if (old.type === 'word') releaseAutomaticRow(d, old.lexemeId);
}

/** An automatic word saved only because a slot named it goes back to being generated. */
function releaseAutomaticRow(d: ProjectDoc, id: Id) {
  const row = d.lexemes.find((l) => l.id === id);
  if (row?.form.kind === 'derived' && d.rules.find((r) => r.id === (row.form as { ruleId: Id }).ruleId)?.autoApply) pruneAutomaticRow(d, id);
}

export function moveSlot(d: ProjectDoc, constructionId: Id, from: number, to: number) {
  const { slots } = find(d.constructions, constructionId, 'Construction');
  const [item] = slots.splice(from, 1);
  slots.splice(to, 0, item);
}

// ---------------------------------------------------------------------------
// Scratchpad
// ---------------------------------------------------------------------------

export function createPhrase(d: ProjectDoc, now = new Date().toISOString()): Id {
  const id = newId(d);
  d.phrases.push({ id, text: '', translation: null, createdAt: now, updatedAt: now });
  return id;
}

export function updatePhrase(d: ProjectDoc, id: Id, patch: { text?: string; translation?: string | null }, now = new Date().toISOString()) {
  const p = find(d.phrases, id, 'Phrase');
  Object.assign(p, patch, { updatedAt: now });
}

export function deletePhrase(d: ProjectDoc, id: Id) {
  removeFrom(d.phrases, (p) => p.id === id);
}

export function dimensionById(d: ProjectDoc, id: Id): Dimension | undefined {
  return d.dimensions.find((x) => x.id === id);
}
