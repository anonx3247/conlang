// The structured rule builder: branches of conditions and operations, a live
// preview, and for inflections the POS and feature bindings.

import { useMemo, useState } from 'react';
import * as cmd from '../../core/commands';
import { formatAbbr } from '../../core/notation';
import type { FeatureSet } from '../../core/paradigm';
import type { Branch, Condition, Dimension, Id, Marker, MorphRule, Operation, RuleKind } from '../../core/types';
import { mutate, useEngine } from '../../storage/store';
import { Check, Chip, Dialog, FilledButton, Icon, IconButton, openDialog, OutlinedButton, Select, SelectField, TextButton, TextField, ViolationText } from '../common';
import { LiteralInput, SegmentEditor, TemplateEditor, typedClass, useClassOptions } from '../segments';

type OpType = Operation['type'];

const OP_LABELS: { value: OpType; label: string }[] = [
  { value: 'prefix', label: 'Prefix (add to start)' },
  { value: 'suffix', label: 'Suffix (add to end)' },
  { value: 'infix', label: 'Infix (insert inside)' },
  { value: 'replace', label: 'Replace' },
  { value: 'template', label: 'Root template' },
  { value: 'reduplicate', label: 'Reduplication (copy)' },
  { value: 'elongate', label: 'Elongation (long vowel or geminate)' },
  { value: 'suppletive', label: 'Whole-word override (irregular)' },
  { value: 'removeSuffix', label: 'Remove ending' },
];

function blankOp(type: OpType): Operation {
  switch (type) {
    case 'prefix': return { type, affix: '' };
    case 'suffix': return { type, affix: '' };
    case 'infix': return { type, affix: '', afterConsonant: 1 };
    case 'replace': return { type, from: { kind: 'sound', text: '' }, to: '', count: null, direction: 'fromStart' };
    case 'template': return { type, parts: [] };
    case 'reduplicate': return { type, scope: 'CV', position: 'prefix' };
    case 'elongate': return { type, target: 'vowel', index: 1, direction: 'fromStart' };
    case 'suppletive': return { type, form: '' };
    case 'removeSuffix': return { type, suffix: '' };
  }
}

function opIsComplete(op: Operation): boolean {
  switch (op.type) {
    case 'prefix':
    case 'suffix':
    case 'infix':
      return !!op.affix.trim();
    case 'replace':
      return (op.from.kind === 'class' || !!op.from.text.trim()) && !!op.to.trim();
    case 'template':
      return op.parts.length > 0;
    case 'reduplicate':
    case 'elongate':
      return true;
    case 'suppletive':
      return !!op.form.trim();
    case 'removeSuffix':
      return !!op.suffix.trim();
  }
}

/** Keeps complete operations and non-empty conditions; used for preview and save. */
function cleanBranches(branches: Branch[]): Branch[] {
  return branches
    .map((b) => ({ conditions: b.conditions.filter((c) => c.segments.length), operations: b.operations.filter(opIsComplete) }))
    .filter((b) => b.operations.length);
}

const WHICH = [{ value: 1 as const, label: 'first' }, { value: 2 as const, label: 'second' }, { value: 3 as const, label: 'third' }];
const SOUND_KIND = [{ value: 'vowel' as const, label: 'vowel' }, { value: 'consonant' as const, label: 'consonant' }];
const DIRECTION = [{ value: 'fromStart' as const, label: 'from beginning' }, { value: 'fromEnd' as const, label: 'from end' }];

const literalHelp = (rom: boolean) => (rom ? 'romanized; use . to force a glyph boundary (at.ha vs atha)' : 'phonemic IPA');

function UnknownPhonemes({ text }: { text: string }) {
  const engine = useEngine();
  if (!text) return null;
  const chars = engine.unknownPhonemesIn(text);
  if (!chars.length) return null;
  return (
    <span className="small err" data-testid="unknown-phoneme" title={chars.map((c) => `'${c}' is not in the phoneme inventory (did you mean to define it first?)`).join(' | ')}>
      <ViolationText text={text} violations={chars.map((c) => ({ position: Math.max(0, text.indexOf(c)), length: c.length, description: '' }))} />
    </span>
  );
}

function OperationFields({ op, onChange }: { op: Operation; onChange: (o: Operation) => void }) {
  const engine = useEngine();
  const classes = useClassOptions();
  const help = <span className="help">{literalHelp(engine.romanizationOn)}</span>;
  switch (op.type) {
    case 'prefix':
    case 'suffix':
      return (
        <div className="col" style={{ gap: 3 }}>
          <LiteralInput aria-label="Affix" placeholder="affix, e.g. in" value={op.affix} onChange={(affix) => onChange({ ...op, affix })} />
          {help}
          <UnknownPhonemes text={op.affix} />
        </div>
      );
    case 'infix':
      return (
        <div className="col" style={{ gap: 3 }}>
          <div className="row">
            <div className="grow"><LiteralInput aria-label="Affix" placeholder="affix" value={op.affix} onChange={(affix) => onChange({ ...op, affix })} /></div>
            <label className="row small muted" style={{ gap: 4, whiteSpace: 'nowrap' }}>
              after consonant
              <input type="number" min={1} style={{ width: 54 }} value={op.afterConsonant} aria-label="After consonant number" onChange={(e) => onChange({ ...op, afterConsonant: Number(e.target.value) || 1 })} />
            </label>
          </div>
          {help}
          <UnknownPhonemes text={op.affix} />
        </div>
      );
    case 'replace': {
      const fromValue = op.from.kind === 'class' ? op.from.name : '';
      return (
        <div className="col" style={{ gap: 4 }}>
          <div className="row">
            <Select inline ariaLabel="Replace what" value={fromValue} options={[{ value: '', label: 'sound' }, ...classes]} onChange={(v) => onChange({ ...op, from: v ? { kind: 'class', name: String(v) } : { kind: 'sound', text: '' } })} />
            {op.from.kind === 'sound' && <div className="grow"><LiteralInput aria-label="From" placeholder="from" value={op.from.text} onChange={(text) => onChange({ ...op, from: typedClass(text, engine) ?? { kind: 'sound', text } })} /></div>}
            <Icon name="arrow_forward" size={14} />
            <div className="grow"><LiteralInput aria-label="To" placeholder="to" value={op.to} onChange={(to) => onChange({ ...op, to })} /></div>
          </div>
          <div className="row wrap small">
            <Select inline ariaLabel="Occurrences" value={op.count ?? 0} options={[{ value: 0, label: 'all' }, { value: 1, label: '1' }, { value: 2, label: '2' }, { value: 3, label: '3' }]} onChange={(v) => onChange({ ...op, count: v ? Number(v) : null })} />
            <span className="muted">occurrences</span>
            <Select inline ariaLabel="Direction" value={op.direction} options={[{ value: 'fromStart' as const, label: 'from beginning' }, { value: 'fromEnd' as const, label: 'from end' }]} onChange={(v) => onChange({ ...op, direction: v ?? 'fromStart' })} />
          </div>
          {help}
          {op.from.kind === 'sound' && <UnknownPhonemes text={op.from.text} />}
          <UnknownPhonemes text={op.to} />
        </div>
      );
    }
    case 'template':
      return <TemplateEditor value={op.parts} onChange={(parts) => onChange({ ...op, parts })} />;
    case 'reduplicate':
      return (
        <div className="row small">
          <span className="muted">Scope:</span>
          <Select inline ariaLabel="Scope" value={op.scope} options={[{ value: 'full' as const, label: 'full' }, { value: 'CV' as const, label: 'CV' }, { value: 'C' as const, label: 'C' }]} onChange={(v) => onChange({ ...op, scope: v ?? 'CV' })} />
          <span className="muted">Position:</span>
          <Select inline ariaLabel="Position" value={op.position} options={[{ value: 'prefix' as const, label: 'prefix' }, { value: 'suffix' as const, label: 'suffix' }]} onChange={(v) => onChange({ ...op, position: v ?? 'prefix' })} />
        </div>
      );
    case 'elongate': {
      const unromanized = op.target === 'vowel' ? engine.unromanizedLongVowels() : [];
      return (
        <div className="col" style={{ gap: 3 }}>
          <div className="row wrap small">
            <span className="muted">The</span>
            <Select inline ariaLabel="Which one" value={op.index} options={WHICH} onChange={(v) => onChange({ ...op, index: v ?? 1 })} />
            <Select inline ariaLabel="Sound to elongate" value={op.target} options={SOUND_KIND} onChange={(v) => onChange({ ...op, target: v ?? 'vowel' })} />
            <Select inline ariaLabel="Direction" value={op.direction} options={DIRECTION} onChange={(v) => onChange({ ...op, direction: v ?? 'fromStart' })} />
          </div>
          {unromanized.length > 0 && <span className="help" data-testid="long-vowel-note">{unromanized.join(', ')} {unromanized.length === 1 ? 'has' : 'have'} no romanization, so {unromanized.length === 1 ? 'it shows' : 'they show'} with ː. Add letters under Phonology → Inventory.</span>}
        </div>
      );
    }
    case 'suppletive':
      return (
        <div className="col" style={{ gap: 3 }}>
          <LiteralInput aria-label="Replacement word" placeholder="Replaces entire word (e.g. went for go)" value={op.form} onChange={(form) => onChange({ ...op, form })} />
          <UnknownPhonemes text={op.form} />
        </div>
      );
    case 'removeSuffix':
      return (
        <div className="col" style={{ gap: 3 }}>
          <LiteralInput aria-label="Ending to remove" placeholder="ending to remove" value={op.suffix} onChange={(suffix) => onChange({ ...op, suffix })} />
          <UnknownPhonemes text={op.suffix} />
        </div>
      );
  }
}

function ConditionsEditor({ conditions, onChange }: { conditions: Condition[]; onChange: (c: Condition[]) => void }) {
  const list = conditions.length ? conditions : [{ position: 'contains' as const, segments: [] }];
  const update = (i: number, c: Condition) => onChange(list.map((x, j) => (j === i ? c : x)));
  return (
    <div className="col" style={{ gap: 4 }}>
      <div className="small muted">Conditions:</div>
      {list.map((c, i) => (
        <div key={i} className="row">
          <Select inline ariaLabel="Condition position" value={c.position} options={[{ value: 'startsWith' as const, label: 'starts with' }, { value: 'endsWith' as const, label: 'ends with' }, { value: 'contains' as const, label: 'contains' }]} onChange={(v) => update(i, { ...c, position: v ?? 'contains' })} />
          <div className="grow"><SegmentEditor value={c.segments} onChange={(segments) => update(i, { ...c, segments })} label="Condition" placeholder="any word" /></div>
          {list.length > 1 && <IconButton icon="close" size={14} title="Remove condition" onClick={() => onChange(list.filter((_, j) => j !== i))} />}
        </div>
      ))}
      <div><TextButton icon="add" onClick={() => onChange([...list, { position: 'contains', segments: [] }])}>Add condition (AND)</TextButton></div>
    </div>
  );
}

function BranchesEditor({ branches, onChange }: { branches: Branch[]; onChange: (b: Branch[]) => void }) {
  const update = (i: number, b: Branch) => onChange(branches.map((x, j) => (j === i ? b : x)));
  return (
    <div className="col">
      {branches.map((b, bi) => (
        <div key={bi} className="card" data-testid={`branch-${bi}`}>
          <div className="row between">
            <span className="primary bold small">Branch {bi + 1}</span>
            {branches.length > 1 && <IconButton icon="close" size={16} danger title="Remove branch" onClick={() => onChange(branches.filter((_, j) => j !== bi))} />}
          </div>
          <ConditionsEditor conditions={b.conditions} onChange={(conditions) => update(bi, { ...b, conditions })} />
          <div style={{ height: 10 }} />
          {b.operations.map((op, oi) => (
            <div key={oi} className="row top" style={{ marginBottom: 6 }}>
              <div style={{ width: 230, flex: 'none' }}>
                <Select ariaLabel="Operation type" value={op.type} options={OP_LABELS} onChange={(t) => t && update(bi, { ...b, operations: b.operations.map((x, j) => (j === oi ? blankOp(t) : x)) })} />
              </div>
              <div className="grow"><OperationFields op={op} onChange={(o) => update(bi, { ...b, operations: b.operations.map((x, j) => (j === oi ? o : x)) })} /></div>
              {b.operations.length > 1 && <IconButton icon="close" size={14} title="Remove operation" onClick={() => update(bi, { ...b, operations: b.operations.filter((_, j) => j !== oi) })} />}
            </div>
          ))}
          <TextButton icon="add" onClick={() => update(bi, { ...b, operations: [...b.operations, blankOp('suffix')] })}>Add operation</TextButton>
        </div>
      ))}
      <div><OutlinedButton icon="add" onClick={() => onChange([...branches, { conditions: [], operations: [blankOp('suffix')] }])}>Add branch</OutlinedButton></div>
    </div>
  );
}

function PreviewPanel({ branches, ruleId, posForWords }: { branches: Branch[]; ruleId: Id | null; posForWords?: Id | null }) {
  const engine = useEngine();
  const [stack, setStack] = useState(false);
  const [seed, setSeed] = useState(0);
  const samples = useMemo(() => {
    void seed;
    const own = posForWords != null ? engine.wordsForPos(posForWords).map((l) => engine.form(l.id)).filter((f) => f.status === 'ok').map((f) => f.phonemic).slice(0, 4) : [];
    return [...own, ...engine.sampleWords(8 - own.length)];
  }, [engine, seed, posForWords]);
  const hasInventory = engine.inventory.consonants.length > 0 || engine.inventory.vowels.length > 0;
  const hasTemplates = engine.doc.templates.some((t) => t.active);

  let message: string | null = null;
  if (!hasInventory) message = 'Define phonemes and phonotactic templates first to see a preview.';
  else if (!hasTemplates && samples.length === 0) message = 'Add phonotactic templates on the Sound Rules page to generate sample words.';
  else if (!branches.length) message = 'Build a rule above to see a preview.';

  return (
    <div className="col" data-testid="rule-preview">
      <div className="row">
        <span className="bold small grow">Preview</span>
        <IconButton icon="layers" selected={stack} title={stack ? 'Showing stacked rules' : 'Show single rule'} onClick={() => setStack((s) => !s)} />
        <IconButton icon="refresh" title="Regenerate preview" onClick={() => setSeed((s) => s + 1)} />
      </div>
      {message ? (
        <div className="small faint">{message}</div>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <tbody>
            {samples.map((w, i) => {
              const single = engine.tryRule({ branches }, w);
              const stacked = stack ? engine.stackRules({ branches }, ruleId, w) : null;
              const result = stack ? stacked!.form : single.ok ? single.form : null;
              const phonetic = result !== null ? engine.phonetic(result) : '';
              const violations = result !== null ? engine.violationsOf(phonetic) : [];
              return (
                <tr key={i}>
                  <td style={{ padding: '3px 4px' }}>{engine.labelFor(w)}</td>
                  <td style={{ width: 22 }} title={stacked ? `${stacked.applied} rules applied` : undefined}><Icon name="arrow_forward" size={14} /></td>
                  <td style={{ padding: '3px 4px' }}>
                    {result !== null ? (
                      <>
                        <div>{engine.labelFor(result)}</div>
                        <div className="ipa small">[<ViolationText text={phonetic} violations={violations} />]</div>
                      </>
                    ) : (
                      <span className="small faint">{single.ok ? 'no match' : single.reason}</span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
    </div>
  );
}

/** Warns when sample output of a derivation misses its output POS's standard form. */
function StandardFormWarning({ branches, outputPosId, levels }: { branches: Branch[]; outputPosId: Id; levels: FeatureSet }) {
  const engine = useEngine();
  const warnings = useMemo(() => {
    const word = engine.sampleWords(20).map((w) => engine.tryRule({ branches }, w)).find((r) => r.ok);
    if (!word || !word.ok) return [];
    const out: string[] = [];
    for (const dim of engine.dimensionsForPos(outputPosId).filter((d) => d.intrinsic)) {
      const toCheck = levels[dim.id] !== undefined ? dim.levels.filter((l) => l.id === levels[dim.id]) : dim.levels;
      for (const level of toCheck) {
        const sf = engine.doc.standardForms.find((s) => s.dimensionId === dim.id && s.levelId === level.id);
        if (!sf?.branches.length) continue;
        if (sf.branches.some((b) => engine.tryConditions(b.kind, b.segments, word.form))) continue;
        out.push(`${level.name} ${dim.name}: should ${engine.describeStandardForm(sf.branches)}`);
      }
    }
    return out;
  }, [engine, branches, outputPosId, levels]);
  if (!warnings.length) return null;
  return <div className="note amber row top"><Icon name="warning_amber" size={14} /><span>{warnings.join('; ')}</span></div>;
}

function sharedDimensions(engine: ReturnType<typeof useEngine>, posIds: Id[]): Dimension[] {
  const per = posIds.map((id) => engine.dimensionsForPos(id));
  if (!per.length || per.some((l) => !l.length)) return [];
  if (per.length === 1) return per[0];
  const names = per.slice(1).reduce((acc, l) => acc.filter((n) => l.some((d) => d.name === n)), per[0].map((d) => d.name));
  return per[0].filter((d) => names.includes(d.name));
}

export interface RuleEditorProps {
  kind: RuleKind;
  existing?: MorphRule;
  marker?: Marker;
  prefillBindings?: FeatureSet;
  prefillPosIds?: Id[];
}

export function openRuleEditor(p: RuleEditorProps) {
  return openDialog<void>((close) => <RuleEditor {...p} close={() => close()} />);
}

function RuleEditor({ kind, existing, marker, prefillBindings, prefillPosIds, close }: RuleEditorProps & { close: () => void }) {
  const engine = useEngine();
  const posList = engine.doc.partsOfSpeech.slice().sort((a, b) => a.name.localeCompare(b.name));
  const [name, setName] = useState(existing?.name ?? marker?.name ?? '');
  const [branches, setBranches] = useState<Branch[]>(existing?.branches.length ? structuredClone(existing.branches) : [{ conditions: [], operations: [blankOp('suffix')] }]);
  const [unmarked, setUnmarked] = useState(!!marker);
  const [posIds, setPosIds] = useState<Id[]>(existing?.posIds ?? (marker ? [marker.posId] : (prefillPosIds ?? [])));
  const [bindings, setBindings] = useState<FeatureSet>(existing?.bindings ?? marker?.bindings ?? prefillBindings ?? {});
  const [inputPos, setInputPos] = useState<Id | null>(existing?.inputPosId ?? null);
  const [outputPos, setOutputPos] = useState<Id | null>(existing?.outputPosId ?? null);
  const [outputIntrinsic, setOutputIntrinsic] = useState<FeatureSet>(existing?.outputIntrinsic ?? {});
  const [autoApply, setAutoApply] = useState(existing?.autoApply ?? false);
  const [description, setDescription] = useState(existing?.description ?? '');
  const [error, setError] = useState<string | null>(null);

  const cleaned = useMemo(() => cleanBranches(branches), [branches]);
  const inflectional = kind === 'inflectional';
  const conflict = useMemoConflict(engine, inflectional && !unmarked, posIds, bindings, existing?.id ?? null);

  if (engine.bijectionViolations.length) {
    return (
      <Dialog title="Rule editor locked" onClose={close} actions={<TextButton onClick={close}>Close</TextButton>}>
        <div className="row"><Icon name="lock" className="err" /> Rule editor is locked until romanization conflicts are resolved — see Phonology → Romanization.</div>
        {engine.bijectionViolations.map((v, i) => <div key={i} className="small">• {v.detail}</div>)}
      </Dialog>
    );
  }

  const dims = inflectional ? sharedDimensions(engine, posIds) : [];

  const save = () => {
    setError(null);
    try {
      if (unmarked) {
        mutate((d) => cmd.saveMarker(d, marker?.id ?? null, posIds, name, bindings));
      } else {
        mutate((d) =>
          cmd.saveRule(d, existing?.id ?? null, {
            name,
            kind,
            description,
            branches: cleaned,
            posIds,
            bindings,
            inputPosId: inputPos,
            outputPosId: outputPos ?? inputPos,
            outputIntrinsic,
            autoApply,
          }),
        );
      }
      close();
    } catch (e) {
      if (e instanceof cmd.CommandError) setError(e.message);
      else throw e;
    }
  };

  const title = marker ? 'Edit Marker' : unmarked ? 'New Marker' : existing ? 'Edit Rule' : 'New Rule';
  const posOption = (p: { id: Id; name: string; abbr: string }) => ({ value: p.id, label: `${p.name} (${formatAbbr(p.abbr)})` });
  const outputDims = outputPos != null ? engine.dimensionsForPos(outputPos).filter((d) => d.intrinsic) : [];

  return (
    <Dialog wide onClose={close} title={undefined}>
      <div className="row between" style={{ padding: '16px 20px 8px' }}>
        <span className="dialog-title">{title}</span>
        <IconButton icon="close" title="Close" onClick={close} />
      </div>
      <div className="grow" style={{ display: 'flex', minHeight: 0 }}>
        <div className="scroll col" style={{ flex: 3, padding: '4px 20px 16px', gap: 12 }}>
          <TextField label="Rule name" placeholder="e.g. Plural, Agentive" value={name} onChange={setName} autoFocus />
          {inflectional && <Check checked={unmarked} onChange={setUnmarked}>Leave as unmarked (no rule, just a ∅ cell)</Check>}
          {inflectional ? (
            <>
              <div className="h-section" style={{ fontWeight: 500 }}>Applies to</div>
              <div className="row wrap" style={{ gap: 6 }}>
                {posList.map((p) => (
                  <Chip key={p.id} selected={posIds.includes(p.id)} onClick={() => setPosIds(posIds.includes(p.id) ? posIds.filter((x) => x !== p.id) : [...posIds, p.id])}>
                    {p.name} ({formatAbbr(p.abbr)})
                  </Chip>
                ))}
              </div>
              {!posIds.length && <div className="small err">Select at least one POS above.</div>}
              {posIds.length > 0 && dims.length === 0 && (
                <div className="small muted">
                  {posIds.length > 1 ? 'These POS share no common dimensions — rule cannot bind any features.' : 'This POS has no dimensions yet. Add dimensions in Grammar → Parts of Speech to enable inflectional binding.'}
                </div>
              )}
              {dims.map((dim) => (
                <div key={dim.id} className="row top">
                  <span style={{ width: 100, flex: 'none', paddingTop: 4 }}>{dim.name}</span>
                  <div className="row wrap" style={{ gap: 6 }}>
                    {dim.levels.map((l) => {
                      const selected = bindings[dim.id] === l.id;
                      return (
                        <Chip
                          key={l.id}
                          selected={selected}
                          title={l.name}
                          onClick={() => {
                            const next = { ...bindings };
                            if (selected) delete next[dim.id];
                            else next[dim.id] = l.id;
                            setBindings(next);
                          }}
                        >
                          {formatAbbr(l.abbr)}
                        </Chip>
                      );
                    })}
                  </div>
                </div>
              ))}
              {!Object.keys(bindings).length && <div className="small err">Inflectional rules must bind at least one feature. Select at least one level chip above.</div>}
              {conflict && (
                <div className="banner error" data-testid="tiebreak-banner">
                  <Icon name="warning" size={16} />
                  <span className="small">Conflict: This rule has the same specificity as '{conflict}' and both match overlapping cells. Add a distinguishing dimension binding to resolve.</span>
                </div>
              )}
            </>
          ) : (
            <>
              <SelectField label="Input POS" value={inputPos} placeholder="" options={posList.map(posOption)} onChange={(v) => { setInputPos(v); if (outputPos === null) setOutputPos(v); }} />
              <div className="row small muted"><Icon name="arrow_downward" size={16} /></div>
              <SelectField label="Output POS" value={outputPos} placeholder="" options={posList.map(posOption)} onChange={(v) => { setOutputPos(v); setOutputIntrinsic({}); }} />
              {outputDims.length > 0 && (
                <>
                  <div className="small muted">Output intrinsic levels</div>
                  {outputDims.map((dim) => (
                    <SelectField
                      key={dim.id}
                      label={dim.name}
                      value={outputIntrinsic[dim.id] ?? null}
                      placeholder="Select level"
                      options={dim.levels.map((l) => ({ value: l.id, label: `${l.name} (${formatAbbr(l.abbr)})` }))}
                      onChange={(v) => {
                        const next = { ...outputIntrinsic };
                        if (v === null) delete next[dim.id];
                        else next[dim.id] = v;
                        setOutputIntrinsic(next);
                      }}
                    />
                  ))}
                </>
              )}
              <div className="col" style={{ gap: 4 }} role="radiogroup" aria-label="How this derivation applies">
                <div className="small muted">Applies</div>
                <div className="row wrap" style={{ gap: 6 }}>
                  <Chip selected={!autoApply} onClick={() => setAutoApply(false)}>Case by case</Chip>
                  <Chip selected={autoApply} onClick={() => setAutoApply(true)}>Automatic</Chip>
                </div>
                <div className="help">
                  {autoApply
                    ? 'For productive patterns like make → maker. Every matching word gets this form, generated from the rule and never stored, so changing the rule updates them all. They appear on each word\'s page and in search, not in the main list.'
                    : 'For patterns that only fit some words, like a suffix for residents of a place. A word is added to the dictionary only when you choose it.'}
                </div>
              </div>
              {autoApply && <div className="small faint italic">Default meaning: "parent meaning ({name || 'rule name'})"</div>}
            </>
          )}
          {!unmarked && (
            <>
              <TextField label="Description (optional)" placeholder="Shown when you click a cell this rule fills" value={description} onChange={setDescription} />
              <BranchesEditor branches={branches} onChange={setBranches} />
            </>
          )}
        </div>
        {!unmarked && (
          <>
            <div className="vr" />
            <div className="scroll col" style={{ flex: 2, padding: '4px 20px 16px' }}>
              <PreviewPanel branches={cleaned} ruleId={existing?.id ?? null} posForWords={inflectional ? (posIds[0] ?? null) : inputPos} />
              {!inflectional && outputPos != null && cleaned.length > 0 && <StandardFormWarning branches={cleaned} outputPosId={outputPos} levels={outputIntrinsic} />}
            </div>
          </>
        )}
      </div>
      <div className="row" style={{ padding: '12px 20px', borderTop: '1px solid var(--outline-variant)' }}>
        {error ? <span className="grow small err" data-testid="rule-error">{error}</span> : <span className="grow" />}
        <TextButton onClick={close}>Cancel</TextButton>
        <FilledButton onClick={save}>Save</FilledButton>
      </div>
    </Dialog>
  );
}

function useMemoConflict(engine: ReturnType<typeof useEngine>, active: boolean, posIds: Id[], bindings: FeatureSet, selfId: Id | null): string | null {
  return useMemo(() => {
    if (!active || !Object.keys(bindings).length) return null;
    const key = JSON.stringify(Object.keys(bindings).map(Number).sort((a, b) => a - b).map((k) => [k, bindings[k]]));
    const names = new Set<string>();
    for (const r of engine.doc.rules) {
      if (r.kind !== 'inflectional' || !r.active || r.id === selfId || !r.posIds.some((p) => posIds.includes(p))) continue;
      const k = JSON.stringify(Object.keys(r.bindings).map(Number).sort((a, b) => a - b).map((n) => [n, r.bindings[n]]));
      if (k === key) names.add(r.name);
    }
    return names.size ? [...names].join(', ') : null;
  }, [engine, active, posIds, bindings, selfId]);
}
