// One-way importer for projects made with the Flutter desktop app (.conlang
// SQLite files). Those store rules as text; this is the only place that text
// is read. It converts to the structured model and is never used afterwards.

import { deromanize, romanize } from '../notation';
import { featureKey } from '../paradigm';
import { CLASS_ALIASES, DEFAULT_CLASSES, LENGTH_CLASSES } from '../phonology';
import {
  emptyProject,
  migrateParticles,
  type Branch,
  type ClassSegment,
  type Condition,
  type Constraint,
  type ConstructionSlot,
  type GeminationPosition,
  type Lexeme,
  type LexemeForm,
  type Operation,
  type ProjectDoc,
  type RewriteRule,
  type Segment,
  type SoundSegment,
  type TemplatePart,
} from '../types';

export type Row = Record<string, unknown>;

export interface LegacyDatabase {
  /** Returns all rows of a table, or [] if the table doesn't exist. */
  table(name: string): Row[];
}

export interface ImportResult {
  doc: ProjectDoc;
  warnings: string[];
}

type Literal = (text: string) => string;

const isClassLetter = (ch: string) => ch === 'C' || ch === 'V' || ch in CLASS_ALIASES;

/** Pattern text such as [nasal]V(k)a into segments. */
export function patternToSegments(pattern: string, literal: Literal = (t) => t): Segment[] {
  const out: Segment[] = [];
  let i = 0;
  let optional = false;
  let run = '';
  const flush = () => {
    if (!run) return;
    const seg: SoundSegment = { kind: 'sound', text: literal(run) };
    if (optional) seg.optional = true;
    out.push(seg);
    run = '';
  };
  const push = (seg: ClassSegment) => {
    flush();
    if (optional) seg.optional = true;
    out.push(seg);
  };
  while (i < pattern.length) {
    const ch = pattern[i];
    if (ch === '[') {
      const close = pattern.indexOf(']', i + 1);
      if (close < 0) {
        run += pattern.slice(i);
        break;
      }
      push({ kind: 'class', name: pattern.slice(i + 1, close) });
      i = close + 1;
    } else if (ch === '(') {
      flush();
      optional = true;
      i++;
    } else if (ch === ')') {
      flush();
      optional = false;
      i++;
    } else if (ch === '#') {
      flush();
      out.push({ kind: 'boundary' });
      i++;
    } else if (isClassLetter(ch)) {
      push({ kind: 'class', name: ch });
      i++;
    } else if (ch === ' ') {
      flush();
      i++;
    } else {
      run += ch;
      i++;
    }
  }
  flush();
  return out;
}

function templateParts(pattern: string, literal: Literal): TemplatePart[] {
  const parts: TemplatePart[] = [];
  let run = '';
  const flush = () => {
    if (run) parts.push({ kind: 'sound', text: literal(run) });
    run = '';
  };
  for (const ch of pattern) {
    if (ch >= '1' && ch <= '9') {
      flush();
      parts.push({ kind: 'slot', index: Number(ch) });
    } else {
      run += ch;
    }
  }
  flush();
  return parts;
}

function parseOperation(tok: string, classNames: Set<string>): Operation | null {
  let m: RegExpMatchArray | null;
  if ((m = tok.match(/^\/([^/]+)\/([^/]*)\/(.*)$/))) {
    const [, from, to, flags] = m;
    const direction = flags.startsWith('e') ? 'fromEnd' : 'fromStart';
    const countStr = flags.slice(1);
    const count = countStr && countStr !== 'A' ? Number(countStr) : null;
    const bare = from.startsWith('[') && from.endsWith(']') ? from.slice(1, -1) : from;
    const isClass = from !== bare || isClassLetter(from) || classNames.has(from.toLowerCase());
    return {
      type: 'replace',
      from: isClass ? { kind: 'class', name: bare } : { kind: 'sound', text: from },
      to,
      count: Number.isNaN(count as number) ? null : count,
      direction,
    };
  }
  if ((m = tok.match(/^redup:([^:]+):(.+)$/))) {
    return { type: 'reduplicate', scope: m[1] as 'full' | 'CV' | 'C', position: m[2] as 'prefix' | 'suffix' };
  }
  if ((m = tok.match(/^infix:([^:]+):(\d+)$/))) return { type: 'infix', affix: m[1], afterConsonant: Number(m[2]) };
  if ((m = tok.match(/^="(.+)"$/))) return { type: 'suppletive', form: m[1] };
  if ((m = tok.match(/^-"(.+)"$/))) return { type: 'removeSuffix', suffix: m[1] };
  if ((m = tok.match(/^-(.+)$/))) return { type: 'removeSuffix', suffix: m[1] };
  if ((m = tok.match(/^\+(.+)$/))) return { type: 'suffix', affix: m[1] };
  if (/^[1-9]/.test(tok) && !tok.endsWith('+')) return { type: 'template', parts: templateParts(tok, (t) => t) };
  if ((m = tok.match(/^([^+]+)\+$/))) return { type: 'prefix', affix: m[1] };
  return null;
}

const CONDITION_FORMS: [RegExp, Condition['position'] | 'legacy'][] = [
  [/^\^"([^"]+)"/, 'startsWith'],
  [/^~"([^"]+)"/, 'contains'],
  [/^\{([^}]+)\}/, 'legacy'],
  [/^\[([a-zA-Z0-9:-]+)_\]/, 'endsWith'],
  [/^\[_([a-zA-Z0-9_:-]+)\]/, 'startsWith'],
  [/^"([^"]+)"_/, 'endsWith'],
  [/^_"([^"]+)"/, 'startsWith'],
  [/^"([^"]+)"\$/, 'endsWith'],
  [/^"([^"]+)"/, 'endsWith'],
];

/** Converts one stored rule. Returns null if the text can't be understood. */
export function legacyRuleToBranches(source: string, literal: Literal, classNames: Set<string>): Branch[] | null {
  const branches: Branch[] = [];
  for (const raw of source.trim().split(' | ')) {
    let rest = raw.trim();
    const conditions: Condition[] = [];
    for (;;) {
      if (rest.startsWith('_ ')) {
        rest = rest.slice(2).trimStart();
        continue;
      }
      const hit = CONDITION_FORMS.map(([re, pos]) => [rest.match(re), pos] as const).find(([m]) => m);
      if (!hit) break;
      const [m, pos] = hit;
      let pattern = m![1];
      let position: Condition['position'];
      if (pos === 'legacy') {
        const start = pattern.startsWith('_');
        const end = pattern.endsWith('_');
        pattern = pattern.replace(/^_/, '').replace(/_$/, '');
        position = start && !end ? 'startsWith' : end && !start ? 'endsWith' : 'contains';
      } else {
        position = pos;
      }
      // [C_] style forms name a class without brackets.
      if (/^\[_?[a-zA-Z0-9_:-]+_?\]/.test(m![0])) pattern = `[${pattern}]`;
      conditions.push({ position, segments: patternToSegments(pattern, literal) });
      rest = rest.slice(m![0].length).trimStart();
    }
    const tokens = rest.split(' ').filter(Boolean);
    if (!tokens.length) return null;
    const operations: Operation[] = [];
    for (const tok of tokens) {
      const op = parseOperation(tok, classNames);
      if (!op) return null;
      operations.push(op);
    }
    branches.push({ conditions, operations });
  }
  return branches.length ? branches : null;
}

export function legacyRewrite(source: string): Omit<RewriteRule, 'id'> | null {
  const arrow = source.indexOf(' -> ');
  if (arrow < 0) return null;
  const input = source.slice(0, arrow).trim();
  const after = source.slice(arrow + 4).trim();
  const slash = after.indexOf(' / ');
  const output = (slash < 0 ? after : after.slice(0, slash)).trim();
  if (!input || !output) return null;
  let left = '';
  let right = '';
  if (slash >= 0) {
    const context = after.slice(slash + 3).trim();
    const under = context.indexOf('_');
    if (under < 0) return null;
    left = context.slice(0, under);
    right = context.slice(under + 1);
  }
  return { input: patternToSegments(input), output, left: patternToSegments(left), right: patternToSegments(right) };
}

function json<T>(raw: unknown, fallback: T): T {
  if (typeof raw !== 'string' || !raw) return fallback;
  try {
    return (JSON.parse(raw) as T) ?? fallback;
  } catch {
    return fallback;
  }
}

const num = (v: unknown): number | null => (v === null || v === undefined ? null : Number(v));
const str = (v: unknown): string | null => (v === null || v === undefined ? null : String(v));
const bool = (v: unknown) => v === 1 || v === true || v === '1';

function toIso(v: unknown): string {
  if (typeof v === 'number') return new Date(v > 1e11 ? v : v * 1000).toISOString();
  return new Date(String(v)).toISOString();
}

export function importLegacyProject(db: LegacyDatabase, name: string): ImportResult {
  const doc = emptyProject(name);
  const warnings: string[] = [];

  const settings = new Map(db.table('project_settings').map((r) => [String(r.key), String(r.value)]));

  doc.phonemes = db.table('phonemes').map((r) => ({
    id: Number(r.id),
    symbol: String(r.symbol),
    type: r.type === 'vowel' ? 'vowel' : 'consonant',
    manner: str(r.manner),
    place: str(r.place),
    voicing: str(r.voicing),
    height: str(r.height),
    backness: str(r.backness),
    rounded: r.rounded === null || r.rounded === undefined ? null : bool(r.rounded),
  }));
  doc.naturalClasses = db.table('natural_classes').map((r) => ({
    id: Number(r.id),
    name: String(r.name),
    phonemeIds: json<unknown[]>(r.phoneme_ids, []).filter((x): x is number => typeof x === 'number'),
  }));
  doc.romanization = db.table('romanization_mappings').map((r) => ({ id: Number(r.id), phoneme: String(r.ipa_symbol), latin: String(r.latin_mapping) }));
  const mappings = doc.romanization.filter((m) => m.phoneme && m.latin);
  doc.settings.romanizationEnabled = settings.get('romanization_enabled') !== 'false';
  const literal: Literal = (t) => (doc.settings.romanizationEnabled ? deromanize(t, mappings) : t);

  doc.templates = db.table('phonotactic_templates').map((r) => ({
    id: Number(r.id),
    segments: patternToSegments(String(r.pattern)),
    description: str(r.description),
    active: bool(r.is_active),
  }));
  doc.constraints = db.table('phonotactic_constraints').map((r): Constraint => {
    const id = Number(r.id);
    const description = str(r.description);
    const active = bool(r.is_active);
    if (r.type === 'gemination') {
      const valid: GeminationPosition[] = ['everywhere', 'coda', 'onset', 'initial', 'final'];
      const positions = String(r.position ?? '').split(',').map((s) => s.trim()).filter((s): s is GeminationPosition => (valid as string[]).includes(s));
      return { id, kind: 'gemination', positions: positions.length ? positions : ['everywhere'], description, active };
    }
    const pattern = String(r.pattern).split('->')[0].trim();
    const pos = r.position === 'start' || r.position === 'end' ? r.position : 'anywhere';
    return { id, kind: 'sequence', segments: patternToSegments(pattern), position: pos, description, active };
  });
  for (const r of db.table('rewrite_rules').slice().sort((a, b) => Number(a.ordering ?? 0) - Number(b.ordering ?? 0))) {
    const parsed = legacyRewrite(String(r.source));
    if (parsed) doc.rewriteRules.push({ id: Number(r.id), ...parsed });
    else warnings.push(`Rewrite rule skipped, could not read: ${r.source}`);
  }

  doc.partsOfSpeech = db.table('parts_of_speech').map((r) => ({ id: Number(r.id), name: String(r.name), abbr: String(r.abbreviation) }));
  const posForText = (raw: unknown): number | null => {
    const needle = String(raw ?? '').trim().toLowerCase();
    if (!needle) return null;
    const hit = doc.partsOfSpeech.find((p) => p.name.toLowerCase() === needle) ?? doc.partsOfSpeech.find((p) => p.abbr.toLowerCase() === needle);
    if (!hit) warnings.push(`Word part of speech "${raw}" matches nothing; left blank.`);
    return hit?.id ?? null;
  };

  doc.dimensions = db.table('dimensions').map((r) => ({
    id: Number(r.id),
    posId: Number(r.pos_id),
    name: String(r.name),
    abbr: str(r.abbreviation),
    order: Number(r.ordering ?? 0),
    intrinsic: bool(r.intrinsic),
    templateId: str(r.template_id),
    levels: json<{ id: number; name: string; abbr: string; ordering: number }[]>(r.levels_json, []).map((l) => ({ id: l.id, name: l.name, abbr: l.abbr, order: l.ordering ?? 0 })),
  }));
  doc.standardForms = db.table('standard_form_patterns').map((r) => ({
    dimensionId: Number(r.dimension_id),
    levelId: Number(r.level_id),
    branches: json<{ kind: 'startsWith' | 'endsWith' | 'contains'; literal: string }[]>(r.branches_json, []).map((b) => ({
      kind: b.kind,
      segments: patternToSegments(b.literal, literal),
    })),
  }));

  const junction = new Map<number, number[]>();
  for (const r of db.table('inflectional_rule_pos')) {
    const id = Number(r.rule_id);
    junction.set(id, [...(junction.get(id) ?? []), Number(r.pos_id)]);
  }
  const classNames = new Set([...Object.keys(DEFAULT_CLASSES), ...Object.keys(LENGTH_CLASSES), ...doc.naturalClasses.map((c) => c.name.toLowerCase())]);
  doc.rules = db.table('morphological_rules').map((r) => {
    const fb = json<Record<string, unknown>>(r.feature_bindings, {});
    const bindings: Record<string, number> = {};
    for (const [k, v] of Object.entries(fb)) if (/^\d+$/.test(k) && typeof v === 'number') bindings[k] = v;
    const outputIntrinsic = (fb.outputIntrinsic ?? {}) as Record<string, number>;
    const kind = r.kind === 'inflectional' ? 'inflectional' : 'derivational';
    const fbPos = Array.isArray(fb.pos) ? (fb.pos as number[]) : [];
    const posIds = kind === 'inflectional' ? (junction.get(Number(r.id)) ?? (fbPos.length ? fbPos : r.input_pos_id != null ? [Number(r.input_pos_id)] : [])) : [];
    const branches = legacyRuleToBranches(String(r.source), literal, classNames);
    if (!branches) warnings.push(`Rule "${r.name}" could not be read and was imported inactive with no steps. Its old text was: ${r.source}`);
    return {
      id: Number(r.id),
      name: String(r.name),
      kind,
      active: branches ? bool(r.is_active) : false,
      order: Number(r.ordering ?? 0),
      branches: branches ?? [],
      posIds,
      bindings,
      inputPosId: kind === 'derivational' ? num(r.input_pos_id) ?? (fbPos[0] ?? null) : null,
      outputPosId: kind === 'derivational' ? num(r.output_pos_id) : null,
      outputIntrinsic,
      autoApply: bool(r.auto_apply),
    };
  });
  doc.markers = db.table('markers').map((r) => {
    const fb = json<Record<string, unknown>>(r.feature_bindings, {});
    const bindings: Record<string, number> = {};
    for (const [k, v] of Object.entries(fb)) if (/^\d+$/.test(k) && typeof v === 'number') bindings[k] = v;
    return { id: Number(r.id), posId: Number(r.pos_id), name: String(r.name ?? 'Unmarked'), bindings };
  });
  doc.exceptions = db.table('morphological_rule_exceptions').map((r) => ({ id: Number(r.id), lexemeId: Number(r.lexeme_id), ruleId: Number(r.rule_id), form: String(r.override_form) }));

  const keepRoman = (phonemic: string, rom: unknown): string | null => {
    const value = str(rom)?.trim();
    if (!value) return null;
    return romanize(phonemic, mappings) === value ? null : value;
  };
  doc.lexemes = db.table('lexemes').map((r): Lexeme => {
    const phonemic = String(r.ipa);
    const parent = num(r.derived_from_lexeme_id);
    const rule = num(r.derived_via_rule_id);
    const legacyRoot = str(r.root_id);
    let form: LexemeForm;
    if (parent !== null && rule !== null) form = { kind: 'derived', parentId: parent, ruleId: rule };
    else if (parent !== null) form = { kind: 'detached', parentId: parent, phonemic, roman: keepRoman(phonemic, r.romanization) };
    else if (legacyRoot) form = { kind: 'detached', parentId: Number(legacyRoot), phonemic, roman: keepRoman(phonemic, r.romanization) };
    else form = { kind: 'root', phonemic, roman: keepRoman(phonemic, r.romanization) };
    return {
      id: Number(r.id),
      form,
      meaning: str(r.meaning),
      posId: posForText(r.part_of_speech),
      isException: bool(r.is_phonological_exception),
      rootOnly: bool(r.root_only_via_derivations),
      isClosedClass: bool(r.is_closed_class),
      glossTag: str(r.gloss_tag),
      skippedDimensionIds: json<number[]>(r.skipped_dimensions_json, []),
      intrinsicLevels: json<Record<string, number>>(r.intrinsic_levels_json, {}),
    } as Lexeme;
  });
  doc.parents = db.table('lexeme_parents').map((r) => ({
    childId: Number(r.child_lexeme_id),
    parentId: Number(r.parent_lexeme_id),
    relationship: str(r.relationship),
    notes: str(r.notes),
  }));
  doc.overrides = db.table('paradigm_cell_overrides').map((r) => {
    const features = json<Record<string, number>>(r.feature_set_json, {});
    return {
      lexemeId: Number(r.lexeme_id),
      key: featureKey(features),
      features,
      phonemic: String(r.override_ipa),
      roman: str(r.override_romanization),
      notes: str(r.notes),
    };
  });

  const slots = db.table('construction_slots');
  doc.constructions = db.table('phrase_constructions').map((r) => ({
    id: Number(r.id),
    name: String(r.name),
    order: Number(r.ordering ?? 0),
    slots: slots
      .filter((s) => Number(s.construction_id) === Number(r.id))
      .sort((a, b) => Number(a.ordering ?? 0) - Number(b.ordering ?? 0))
      .map((s) => {
        const type = s.slot_type === 'pos' ? ('pos' as const) : ('gloss_tag' as const);
        let value = String(s.slot_value);
        if (type === 'pos') {
          const hit = doc.partsOfSpeech.find((p) => p.abbr.toUpperCase() === value.toUpperCase() || p.name.toUpperCase() === value.toUpperCase());
          if (hit) value = String(hit.id);
        }
        // In the old shape here; migrateParticles below converts it.
        return { id: Number(s.id), type, value, label: str(s.label) } as unknown as ConstructionSlot;
      }),
  }));
  doc.phrases = db.table('scratchpad_phrases').map((r) => ({
    id: Number(r.id),
    text: String(r.original_text ?? ''),
    translation: str(r.free_translation),
    createdAt: toIso(r.created_at),
    updatedAt: toIso(r.updated_at),
  }));

  const typology = doc.settings.typology;
  typology.alignment = settings.get('typology.alignment') ?? null;
  typology.wordOrder = settings.get('typology.word_order') ?? null;
  typology.modality = settings.get('typology.modality') ?? null;
  typology.headDirection = settings.get('typology.head_direction') ?? null;
  typology.adposition = settings.get('typology.adposition_type') ?? null;
  typology.adjectivePlacement = settings.get('typology.adj_placement') ?? null;
  typology.genitivePlacement = settings.get('typology.gen_placement') ?? null;
  for (const [key, value] of settings) {
    let m: RegExpMatchArray | null;
    if ((m = key.match(/^typology\.paradigm_axes\.(\d+)$/))) {
      const axes = json<{ rows?: number; cols?: number }>(value, {});
      doc.settings.paradigmAxes[m[1]] = { rows: axes.rows ?? null, cols: axes.cols ?? null };
    } else if ((m = key.match(/^paradigm\.last_selected_word\.(\d+)$/))) {
      const id = Number(value);
      if (!Number.isNaN(id)) doc.settings.lastSelectedWord[m[1]] = id;
    } else if ((m = key.match(/^intrinsic_backfill_pending_(\d+)$/))) {
      if (settings.get(`intrinsic_backfill_banner_dismissed_${m[1]}`) === 'true') continue;
      const banner = json<{ dimId?: number; dimName?: string; count?: number }>(value, {});
      if (banner.dimId != null && banner.dimName && banner.count != null) {
        doc.settings.backfillBanners.push({ dimId: banner.dimId, dimName: banner.dimName, count: banner.count });
      }
    }
  }

  const ids = [
    ...doc.phonemes,
    ...doc.naturalClasses,
    ...doc.templates,
    ...doc.constraints,
    ...doc.rewriteRules,
    ...doc.romanization,
    ...doc.partsOfSpeech,
    ...doc.dimensions,
    ...doc.rules,
    ...doc.markers,
    ...doc.exceptions,
    ...doc.lexemes,
    ...doc.constructions,
    ...doc.constructions.flatMap((c) => c.slots),
    ...doc.phrases,
  ].map((x) => x.id);
  doc.nextId = (ids.length ? Math.max(...ids) : 0) + 1;
  warnings.push(...migrateParticles(doc));

  // Automatic words carrying only the old templated gloss go back to following the template.
  for (const l of doc.lexemes) {
    if (l.form.kind !== 'derived') continue;
    const { parentId, ruleId } = l.form;
    const rule = doc.rules.find((r) => r.id === ruleId);
    const parent = doc.lexemes.find((p) => p.id === parentId);
    if (rule?.autoApply && parent?.meaning && l.meaning === `${parent.meaning} (${rule.name})`) l.meaning = null;
  }
  return { doc, warnings };
}

/** SQLite files begin with this magic text. */
export function isSqliteFile(bytes: Uint8Array): boolean {
  const magic = 'SQLite format 3';
  return magic.split('').every((c, i) => bytes[i] === c.charCodeAt(0));
}
