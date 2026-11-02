import { useMemo, useState } from 'react';
import * as cmd from '../../core/commands';
import { describeRewrite, describeSegments, type Violation } from '../../core/phonology';
import type { Constraint, GeminationPosition, RewriteRule, Segment, SyllableTemplate } from '../../core/types';
import { mutate, run, useDoc, useEngine } from '../../storage/store';
import { Chip, confirmDialog, Dialog, FilledButton, Icon, IconButton, openDialog, Select, Switch, TextButton, TextField, TonalButton, ViolationText } from '../common';
import { IpaField } from '../ipa';
import { SegmentEditor } from '../segments';

function SectionHeader({ title, help, onAdd, testId }: { title: string; help: string; onAdd: () => void; testId?: string }) {
  return (
    <div className="row top" style={{ padding: '16px 16px 8px' }}>
      <div className="grow">
        <div className="h-section">{title}</div>
        <div className="small faint">{help}</div>
      </div>
      <TonalButton icon="add" onClick={onAdd} data-testid={testId}>Add</TonalButton>
    </div>
  );
}

const Row = ({ children }: { children: React.ReactNode }) => <div className="row" style={{ padding: '6px 16px', borderTop: '1px solid rgba(68,71,79,.3)' }}>{children}</div>;

export function SoundRulesPage() {
  const [width] = useState(460);
  return (
    <div className="row top fill" style={{ gap: 0 }}>
      <div className="scroll fill" style={{ width, flex: 'none', background: 'var(--surface-low)' }}>
        <Templates />
        <Constraints />
        <RewriteRules />
      </div>
      <div className="vr fill" />
      <div className="grow fill"><WordGeneratorPanel /></div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Templates
// ---------------------------------------------------------------------------

function Templates() {
  const doc = useDoc();
  const edit = (t?: SyllableTemplate) => openDialog<void>((close) => <TemplateDialog existing={t} close={() => close()} />);
  const remove = async (t: SyllableTemplate) => {
    if (await confirmDialog({ title: 'Delete template?', body: `Remove "${describeSegments(t.segments)}"?` })) run((d) => cmd.deleteTemplate(d, t.id));
  };
  return (
    <section>
      <SectionHeader title="Syllable Templates" help="Define the sound structure of syllables from consonants, vowels, classes and optional positions." onAdd={() => void edit()} testId="add-template" />
      {doc.templates.length === 0 && <div className="small italic faint" style={{ padding: '0 16px 8px' }}>No templates yet. Add one to start generating words.</div>}
      {doc.templates.map((t) => (
        <Row key={t.id}>
          <Icon name="check_circle_outline" size={16} className="muted" />
          <div className="grow">
            <div className="bold">{describeSegments(t.segments)}</div>
            {t.description && <div className="small faint">{t.description}</div>}
          </div>
          <Switch label="Template active" checked={t.active} onChange={(v) => run((d) => cmd.setTemplateActive(d, t.id, v))} />
          <IconButton icon="edit" size={16} title="Edit template" onClick={() => void edit(t)} />
          <IconButton icon="delete_outline" size={16} danger title="Delete template" onClick={() => void remove(t)} />
        </Row>
      ))}
    </section>
  );
}

function TemplateDialog({ existing, close }: { existing?: SyllableTemplate; close: () => void }) {
  const [segments, setSegments] = useState<Segment[]>(existing?.segments ?? []);
  const [description, setDescription] = useState(existing?.description ?? '');
  return (
    <Dialog
      title={existing ? 'Edit template' : 'Add template'}
      onClose={close}
      actions={
        <>
          <TextButton onClick={close}>Cancel</TextButton>
          <FilledButton disabled={!segments.length} onClick={() => { run((d) => cmd.saveTemplate(d, existing?.id ?? null, segments, description)); close(); }}>Save</FilledButton>
        </>
      }
    >
      <div className="field">
        <span>Template positions</span>
        <SegmentEditor value={segments} onChange={setSegments} label="Template" placeholder="sound" testId="template-editor" />
      </div>
      <TextField label="Description (optional)" placeholder="e.g. Open syllable" value={description} onChange={setDescription} />
      <div className="note">Add positions in order. Use the circle on a position to make it optional, as in (C)V(C).</div>
    </Dialog>
  );
}

// ---------------------------------------------------------------------------
// Constraints
// ---------------------------------------------------------------------------

const GEM_LABEL: Record<GeminationPosition, string> = { everywhere: 'Everywhere', coda: 'Coda', onset: 'Onset', initial: 'Word-initial', final: 'Word-final' };

function Constraints() {
  const doc = useDoc();
  const editSeq = (c?: Extract<Constraint, { kind: 'sequence' }>) => openDialog<void>((close) => <SequenceDialog existing={c} close={() => close()} />);
  const editGem = (c?: Extract<Constraint, { kind: 'gemination' }>) => openDialog<void>((close) => <GeminationDialog existing={c} close={() => close()} />);
  const add = () =>
    openDialog<void>((close) => (
      <Dialog title="Add constraint" onClose={() => close()}>
        <button type="button" className="list-row" onClick={() => { close(); void editSeq(); }}>
          <Icon name="block" size={20} />
          <span><div>Forbidden sequence</div><div className="small faint">e.g. no two stops in a row</div></span>
        </button>
        <button type="button" className="list-row" onClick={() => { close(); void editGem(); }}>
          <Icon name="block" size={20} />
          <span><div>No gemination</div><div className="small faint">Prevent identical adjacent consonants</div></span>
        </button>
      </Dialog>
    ));
  const remove = async (c: Constraint) => {
    const label = c.kind === 'gemination' ? 'No gemination' : `"${describeSegments(c.segments)}"`;
    if (await confirmDialog({ title: 'Delete constraint?', body: `Remove ${label}?` })) run((d) => cmd.deleteConstraint(d, c.id));
  };
  return (
    <section>
      <SectionHeader title="Forbidden Sequences" help="Patterns the word generator must avoid, such as two stops in a row." onAdd={() => void add()} testId="add-constraint" />
      {doc.constraints.length === 0 && <div className="small italic faint" style={{ padding: '0 16px 8px' }}>No forbidden sequences yet. Add one to filter word generation.</div>}
      {doc.constraints.map((c) => (
        <Row key={c.id}>
          <Icon name="block" size={16} className="muted" />
          <div className="grow">
            {c.kind === 'gemination' ? (
              <>
                <div className="bold">No gemination</div>
                {c.description && <div className="small faint">{c.description}</div>}
                <div className="row wrap" style={{ gap: 4 }}>{c.positions.map((p) => <span key={p} className="badge">{GEM_LABEL[p]}</span>)}</div>
              </>
            ) : (
              <>
                <div className="bold">{describeSegments(c.segments)}</div>
                {c.description && <div className="small faint">{c.description}</div>}
                {c.position !== 'anywhere' && <div className="tiny faint">{c.position === 'start' ? 'at word beginning' : 'at word end'}</div>}
              </>
            )}
          </div>
          <Switch label="Constraint active" checked={c.active} onChange={(v) => run((d) => cmd.setConstraintActive(d, c.id, v))} />
          <IconButton icon="edit" size={16} title="Edit constraint" onClick={() => void (c.kind === 'gemination' ? editGem(c) : editSeq(c))} />
          <IconButton icon="delete_outline" size={16} danger title="Delete constraint" onClick={() => void remove(c)} />
        </Row>
      ))}
    </section>
  );
}

function SequenceDialog({ existing, close }: { existing?: Extract<Constraint, { kind: 'sequence' }>; close: () => void }) {
  const [segments, setSegments] = useState<Segment[]>(existing?.segments ?? []);
  const [position, setPosition] = useState<'anywhere' | 'start' | 'end'>(existing?.position ?? 'anywhere');
  const [description, setDescription] = useState(existing?.description ?? '');
  return (
    <Dialog
      title={existing ? 'Edit forbidden sequence' : 'Add forbidden sequence'}
      onClose={close}
      actions={
        <>
          <TextButton onClick={close}>Cancel</TextButton>
          <FilledButton disabled={!segments.length} onClick={() => { run((d) => cmd.saveSequenceConstraint(d, existing?.id ?? null, segments, position, description)); close(); }}>Save</FilledButton>
        </>
      }
    >
      <div className="field">
        <span>Forbidden pattern</span>
        <SegmentEditor value={segments} onChange={setSegments} allowOptional={false} label="Forbidden pattern" />
      </div>
      <div className="row">
        <span className="small muted">Position:</span>
        <Select inline ariaLabel="Position" value={position} onChange={(v) => setPosition(v ?? 'anywhere')} options={[{ value: 'anywhere' as const, label: 'anywhere in word' }, { value: 'start' as const, label: 'word beginning' }, { value: 'end' as const, label: 'word end' }]} />
      </div>
      <TextField label="Description (optional)" placeholder="e.g. No two stops in a row" value={description} onChange={setDescription} />
      <div className="note">{'Examples:\n  stop + stop     no two stops in a row\n  C + C           no consonant clusters\n  nasal + stop    no nasal+stop sequences'}</div>
    </Dialog>
  );
}

function GeminationDialog({ existing, close }: { existing?: Extract<Constraint, { kind: 'gemination' }>; close: () => void }) {
  const [positions, setPositions] = useState<GeminationPosition[]>(existing?.positions ?? ['everywhere']);
  const [description, setDescription] = useState(existing?.description ?? 'No geminate consonants');
  const [error, setError] = useState<string | null>(null);
  const specific: GeminationPosition[] = ['coda', 'onset', 'initial', 'final'];
  const toggle = (p: GeminationPosition) => {
    if (p === 'everywhere') {
      setPositions(positions.includes('everywhere') ? specific : ['everywhere']);
      return;
    }
    const next = positions.includes(p) ? positions.filter((x) => x !== p) : [...positions.filter((x) => x !== 'everywhere'), p];
    setPositions(next.length ? next : ['everywhere']);
  };
  const save = () => {
    try {
      mutate((d) => cmd.saveGeminationConstraint(d, existing?.id ?? null, positions, description));
      close();
    } catch (e) {
      if (e instanceof cmd.CommandError) setError(e.message);
      else throw e;
    }
  };
  return (
    <Dialog
      title={existing ? 'Edit gemination restriction' : 'Add gemination restriction'}
      onClose={close}
      actions={
        <>
          <TextButton onClick={close}>Cancel</TextButton>
          <FilledButton onClick={save}>Save</FilledButton>
        </>
      }
    >
      <div className="small muted">Restrict gemination at:</div>
      <div className="row wrap" style={{ gap: 6 }}>
        {(['everywhere', ...specific] as GeminationPosition[]).map((p) => <Chip key={p} selected={positions.includes(p)} onClick={() => toggle(p)}>{GEM_LABEL[p]}</Chip>)}
      </div>
      {error && <div className="field-error">{error}</div>}
      <TextField label="Description (optional)" placeholder="No geminate consonants" value={description} onChange={setDescription} />
    </Dialog>
  );
}

// ---------------------------------------------------------------------------
// Rewrite rules
// ---------------------------------------------------------------------------

function RewriteRules() {
  const doc = useDoc();
  const edit = (r?: RewriteRule) => openDialog<void>((close) => <RewriteDialog existing={r} close={() => close()} />);
  const remove = async (r: RewriteRule) => {
    if (await confirmDialog({ title: 'Delete rewrite rule?', body: `Remove "${describeRewrite(r)}"?` })) run((d) => cmd.deleteRewriteRule(d, r.id));
  };
  return (
    <section>
      <SectionHeader title="Rewrite Rules" help="Sound changes: what becomes what, and in which context." onAdd={() => void edit()} testId="add-rewrite" />
      {doc.rewriteRules.length === 0 && <div className="small italic faint" style={{ padding: '0 16px 16px' }}>No rewrite rules yet. Add one to define sound changes.</div>}
      {doc.rewriteRules.map((r) => (
        <Row key={r.id}>
          <Icon name="swap_horiz" size={16} className="muted" />
          <div className="grow bold">{describeRewrite(r)}</div>
          <IconButton icon="edit" size={16} title="Edit rule" onClick={() => void edit(r)} />
          <IconButton icon="delete_outline" size={16} danger title="Delete rule" onClick={() => void remove(r)} />
        </Row>
      ))}
    </section>
  );
}

function RewriteDialog({ existing, close }: { existing?: RewriteRule; close: () => void }) {
  const [input, setInput] = useState<Segment[]>(existing?.input ?? []);
  const [output, setOutput] = useState(existing?.output ?? '');
  const [left, setLeft] = useState<Segment[]>(existing?.left ?? []);
  const [right, setRight] = useState<Segment[]>(existing?.right ?? []);
  const valid = input.length > 0 && output.trim().length > 0;
  return (
    <Dialog
      title={existing ? 'Edit rewrite rule' : 'Add rewrite rule'}
      onClose={close}
      className=""
      actions={
        <>
          <TextButton onClick={close}>Cancel</TextButton>
          <FilledButton disabled={!valid} onClick={() => { run((d) => cmd.saveRewriteRule(d, existing?.id ?? null, { input, output: output.trim(), left, right })); close(); }}>Save</FilledButton>
        </>
      }
    >
      <div className="field">
        <span>Pattern (phonemic)</span>
        <SegmentEditor value={input} onChange={setInput} allowOptional={false} label="Pattern" placeholder="k" />
      </div>
      <IpaField label="Replacement (phonetic)" placeholder="x" value={output} onChange={setOutput} />
      <div className="help">Pattern matches phonemic input; replacement is surface phonetic (allophones, diacritics allowed).</div>
      <div className="small muted bold">Context (optional)</div>
      <div className="field">
        <span>Before</span>
        <SegmentEditor value={left} onChange={setLeft} allowOptional={false} allowBoundary label="Before" placeholder="V" />
      </div>
      <div className="field">
        <span>After</span>
        <SegmentEditor value={right} onChange={setRight} allowOptional={false} allowBoundary label="After" placeholder="V" />
      </div>
      {valid && <div className="row small muted"><Icon name="check_circle_outline" size={14} /> {describeRewrite({ id: 0, input, output, left, right })}</div>}
    </Dialog>
  );
}

// ---------------------------------------------------------------------------
// Word generator
// ---------------------------------------------------------------------------

export function SyllableRange({ min, max, onChange }: { min: number; max: number; onChange: (min: number, max: number) => void }) {
  return (
    <div className="row small">
      <span className="muted">Syllables:</span>
      <label className="row" style={{ gap: 4 }}>from
        <input type="number" min={1} max={max} value={min} aria-label="Minimum syllables" style={{ width: 52 }} onChange={(e) => onChange(Math.max(1, Math.min(max, Number(e.target.value) || 1)), max)} />
      </label>
      <label className="row" style={{ gap: 4 }}>to
        <input type="number" min={min} max={5} value={max} aria-label="Maximum syllables" style={{ width: 52 }} onChange={(e) => onChange(min, Math.max(min, Math.min(5, Number(e.target.value) || min)))} />
      </label>
    </div>
  );
}

function WordGeneratorPanel() {
  const engine = useEngine();
  const [min, setMin] = useState(1);
  const [max, setMax] = useState(3);
  const [seed, setSeed] = useState(0);
  const words = useMemo(() => {
    void seed;
    return engine.generate(20, min, max).map((w) => {
      const phonetic = engine.phonetic(w);
      return { raw: w, phonetic, label: engine.labelFor(w), violations: engine.violationsOf(phonetic) as Violation[] };
    });
  }, [engine, min, max, seed]);
  return (
    <div className="col fill" style={{ gap: 0 }}>
      <div className="row" style={{ padding: '16px 16px 8px' }}>
        <div className="grow">
          <div className="h-section">Word Preview</div>
          <div className="small faint">Generated from active templates and inventory.</div>
        </div>
        <IconButton icon="refresh" title="Regenerate words" onClick={() => setSeed((s) => s + 1)} />
      </div>
      <div style={{ padding: '0 16px 8px' }}><SyllableRange min={min} max={max} onChange={(a, b) => { setMin(a); setMax(b); }} /></div>
      <div className="grow scroll" style={{ padding: '0 16px 16px' }} data-testid="generated-words">
        {words.length === 0 && <div className="center faint">Define templates and add phonemes to preview words.</div>}
        {words.map((w, i) => (
          <div key={i} className="row" style={{ padding: '3px 0' }}>
            {w.label !== w.phonetic ? (
              <>
                <span>{w.label}</span>
                <span className="ipa small">[<ViolationText text={w.phonetic} violations={w.violations} />]</span>
              </>
            ) : (
              <ViolationText text={w.phonetic} violations={w.violations} />
            )}
            {w.violations.length > 0 && <Icon name="warning_amber" size={14} className="err" />}
          </div>
        ))}
      </div>
    </div>
  );
}
