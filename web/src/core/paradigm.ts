// Inflection: resolves one paradigm cell by consuming its features with the
// most specific rules first. Resolution order for a word's cell is
// override -> rules -> marker -> uncovered (overrides are layered in engine.ts).

import { applyRule } from './morphology';
import type { Dimension, Id, Level, Marker, MorphRule } from './types';
import type { Inventory } from './phonology';

export type FeatureSet = Record<string, Id>;

/** Canonical key for a feature set, independent of insertion order. */
export function featureKey(features: FeatureSet): string {
  return Object.keys(features)
    .map(Number)
    .sort((a, b) => a - b)
    .map((d) => `${d}:${features[d]}`)
    .join(',');
}

export function cartesian(dims: Dimension[]): FeatureSet[] {
  let acc: FeatureSet[] = [{}];
  for (const d of dims) {
    const next: FeatureSet[] = [];
    for (const partial of acc) for (const l of d.levels) next.push({ ...partial, [d.id]: l.id });
    acc = next;
  }
  return acc;
}

export function sortedLevels(d: Dimension): Level[] {
  return d.levels.slice().sort((a, b) => a.order - b.order);
}

export interface ResolvedRule {
  rule: MorphRule;
  bindings: FeatureSet;
}

/**
 * Re-expresses a rule's bindings in a POS's own dimensions. A rule attached to
 * several POS binds one POS's dimension ids; on the others it matches the
 * dimension and level by name, then abbreviation. Returns null if unreachable.
 */
export function translateBindings(bindings: FeatureSet, allDims: Dimension[], posDims: Dimension[]): FeatureSet | null {
  const out: FeatureSet = {};
  for (const [dimId, levelId] of Object.entries(bindings)) {
    const auth = allDims.find((d) => d.id === Number(dimId));
    if (!auth) return null;
    if (posDims.some((d) => d.id === auth.id)) {
      out[dimId] = levelId;
      continue;
    }
    const target = posDims.find((d) => d.name === auth.name);
    if (!target) return null;
    const level = auth.levels.find((l) => l.id === levelId);
    if (!level) return null;
    const match =
      target.levels.find((l) => l.name && l.name === level.name) ?? target.levels.find((l) => l.abbr && l.abbr === level.abbr);
    if (!match) return null;
    out[target.id] = match.id;
  }
  return out;
}

export type RawCell =
  | { kind: 'filled'; phonemic: string; chain: MorphRule[]; partial: boolean }
  | { kind: 'unmarked'; phonemic: string; marker: Marker }
  | { kind: 'uncovered'; reason: string }
  | { kind: 'ambiguous'; tied: MorphRule[] };

export interface CellInput {
  base: string;
  target: FeatureSet;
  rules: ResolvedRule[];
  markers: Marker[];
  inventory: Inventory;
  /** Dimension ids that are intrinsic for this POS: filters, not axes. */
  intrinsicDims: Set<number>;
  /** This word's fixed levels on intrinsic dimensions. */
  wordLevels: FeatureSet;
}

function specificity(bindings: FeatureSet) {
  return Object.keys(bindings).length;
}

export function computeCell(i: CellInput): RawCell {
  const isIntrinsic = (dim: string) => i.intrinsicDims.has(Number(dim));

  const passesIntrinsic = (bindings: FeatureSet) =>
    Object.entries(bindings).every(([d, l]) => !isIntrinsic(d) || i.wordLevels[d] === l);

  const axisBindings = (bindings: FeatureSet) =>
    Object.fromEntries(Object.entries(bindings).filter(([d]) => !isIntrinsic(d)));

  const isSubset = (sub: FeatureSet, sup: FeatureSet) => {
    const keys = Object.keys(sub);
    return keys.length > 0 && keys.every((k) => sup[k] === sub[k]);
  };

  const applicableMarkers = i.markers.filter((m) => {
    if (!passesIntrinsic(m.bindings)) return false;
    return isSubset(axisBindings(m.bindings), i.target);
  });

  const markerOr = (reason: string): RawCell => {
    if (!applicableMarkers.length) return { kind: 'uncovered', reason };
    const best = applicableMarkers.slice().sort((a, b) => specificity(b.bindings) - specificity(a.bindings))[0];
    return { kind: 'unmarked', phonemic: i.base, marker: best };
  };

  const eligible = i.rules.filter((r) => r.rule.active && specificity(r.bindings) > 0 && passesIntrinsic(r.bindings));

  let working = i.base;
  const remaining: FeatureSet = { ...i.target };
  const chain: MorphRule[] = [];

  const finish = (): RawCell => {
    // A marker declaring the leftover features unmarked means they are complete.
    const uncovered = Object.keys(remaining).filter(
      (d) => !applicableMarkers.some((m) => axisBindings(m.bindings)[d] === remaining[d]),
    );
    return { kind: 'filled', phonemic: working, chain, partial: uncovered.length > 0 };
  };

  while (Object.keys(remaining).length > 0) {
    const candidates = eligible.filter((r) => isSubset(axisBindings(r.bindings), remaining));
    if (!candidates.length) {
      return chain.length ? finish() : markerOr('No inflectional rule binds the requested feature set.');
    }
    const top = Math.max(...candidates.map((r) => specificity(r.bindings)));
    const topGroup = candidates.filter((r) => specificity(r.bindings) === top);

    const byKey = new Map<string, ResolvedRule[]>();
    for (const r of topGroup) {
      const k = featureKey(r.bindings);
      byKey.set(k, [...(byKey.get(k) ?? []), r]);
    }
    const tied = [...byKey.values()].find((g) => g.length > 1);
    if (tied) return { kind: 'ambiguous', tied: tied.map((r) => r.rule) };

    let winner: ResolvedRule | null = null;
    let winnerForm = '';
    let failure: string | null = null;
    for (const c of topGroup) {
      const res = applyRule(c.rule, working, i.inventory);
      if (res.ok) {
        winner = c;
        winnerForm = res.form;
        break;
      }
      failure ??= `Rule "${c.rule.name}" did not match: ${res.reason}`;
    }
    if (!winner) {
      return chain.length ? finish() : markerOr(failure ?? 'All candidate rules failed.');
    }
    working = winnerForm;
    chain.push(winner.rule);
    for (const d of Object.keys(winner.bindings)) if (!isIntrinsic(d)) delete remaining[d];
  }
  return { kind: 'filled', phonemic: working, chain, partial: false };
}

export interface CoverageCell {
  key: string;
  features: FeatureSet;
  covered: boolean;
}

export interface CoverageMatrix {
  axes: Id[];
  cells: CoverageCell[];
}

/** Which feature combinations have any rule, across dimensions rules reference. */
export function coverageMatrix(rules: ResolvedRule[], dims: Dimension[]): CoverageMatrix {
  const active = rules.filter((r) => r.rule.active);
  const referenced = new Set(active.flatMap((r) => Object.keys(r.bindings).map(Number)));
  const axes = dims.filter((d) => referenced.has(d.id)).sort((a, b) => a.id - b.id);
  if (!axes.length) return { axes: [], cells: [] };
  const cells = cartesian(axes).map((features) => ({
    key: featureKey(features),
    features,
    covered: active.some((r) =>
      axes.every((a) => {
        const b = r.bindings[a.id];
        return b === undefined || b === features[a.id];
      }),
    ),
  }));
  return { axes: axes.map((a) => a.id), cells };
}

export interface TiebreakConflict {
  key: string;
  rules: MorphRule[];
}

/** Groups active rules with identical bindings: they would tie on every cell. */
export function findTiebreakConflicts(rules: ResolvedRule[]): TiebreakConflict[] {
  const m = new Map<string, MorphRule[]>();
  for (const r of rules) {
    if (!r.rule.active || !Object.keys(r.bindings).length) continue;
    const k = featureKey(r.bindings);
    m.set(k, [...(m.get(k) ?? []), r.rule]);
  }
  return [...m.entries()].filter(([, v]) => v.length > 1).map(([key, v]) => ({ key, rules: v }));
}
