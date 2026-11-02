import { resolveClass } from '../../core/phonology';
import { useState } from 'react';
import templates from '../../data/dimension_templates.json';
import * as cmd from '../../core/commands';
import { formatAbbr } from '../../core/notation';
import type { Dimension, Id, Level, PartOfSpeech, Segment } from '../../core/types';
import { mutate, run, snack, useEngine } from '../../storage/store';
import { confirmDialog, Dialog, FilledButton, Icon, IconButton, openDialog, promptDialog, Select, TextButton, TextField } from '../common';
import { SegmentEditor } from '../segments';

export function PosDimensionsPage() {
  const engine = useEngine();
  const posList = engine.doc.partsOfSpeech.slice().sort((a, b) => a.name.localeCompare(b.name));
  const [selected, setSelected] = useState<Id | null>(null);
  const editPos = (p?: PartOfSpeech) => openDialog<void>((close) => <PosDialog existing={p} close={() => close()} />);
  const removePos = async (p: PartOfSpeech) => {
    const count = engine.doc.lexemes.filter((l) => l.posId === p.id).length;
    const others = posList.filter((x) => x.id !== p.id);
    if (count > 0 && !others.length) {
      await openDialog<void>((close) => (
        <Dialog title={`Cannot delete ${p.name}`} onClose={() => close()} actions={<TextButton onClick={() => close()}>OK</TextButton>}>
          {count} word(s) use this POS and there are no other parts of speech to migrate them to. Add another POS first.
        </Dialog>
      ));
      return;
    }
    const target = await openDialog<{ to: Id | null }>((close) => <PosDeleteDialog pos={p} count={count} others={others} close={close} />);
    if (!target) return;
    run((d) => cmd.deletePos(d, p.id, target.to));
    if (selected === p.id) setSelected(others[0]?.id ?? null);
  };
  return (
    <div className="row top fill" style={{ gap: 0 }}>
      <div className="col fill" style={{ width: 280, flex: 'none', background: 'var(--surface-low)', gap: 0 }}>
        <div className="row between" style={{ padding: '12px 12px 8px 16px' }}>
          <span className="h-section">Parts of Speech</span>
          <IconButton icon="add" title="Add POS" onClick={() => void editPos()} />
        </div>
        <div className="grow scroll">
          {posList.length === 0 && <div className="center faint">No parts of speech yet.</div>}
          {posList.map((p) => (
            <div key={p.id} className={`list-row ${p.id === selected ? 'sel' : ''}`} onClick={() => setSelected(p.id)} data-testid={`pos-${p.name}`}>
              <span className="grow ellipsis">{p.name} ({formatAbbr(p.abbr)})</span>
              <IconButton icon="edit" size={16} title="Edit POS" onClick={(e) => { e.stopPropagation(); void editPos(p); }} />
              <IconButton icon="delete_outline" size={16} danger title="Delete POS" onClick={(e) => { e.stopPropagation(); void removePos(p); }} />
            </div>
          ))}
        </div>
      </div>
      <div className="vr fill" />
      <div className="grow fill">
        {selected === null || !engine.pos(selected) ? <div className="center faint">Select a Part of Speech to edit its dimensions.</div> : <DimensionEditor posId={selected} />}
      </div>
    </div>
  );
}

function PosDialog({ existing, close }: { existing?: PartOfSpeech; close: () => void }) {
  const [name, setName] = useState(existing?.name ?? '');
  const [abbr, setAbbr] = useState(existing?.abbr ?? '');
  const save = () => {
    if (!name.trim() || !abbr.trim()) return;
    run((d) => cmd.savePos(d, existing?.id ?? null, name, abbr));
    close();
  };
  return (
    <Dialog
      title={existing ? 'Edit Part of Speech' : 'Add Part of Speech'}
      onClose={close}
      actions={
        <>
          <TextButton onClick={close}>Cancel</TextButton>
          <FilledButton onClick={save}>{existing ? 'Save' : 'Add'}</FilledButton>
        </>
      }
    >
      <TextField autoFocus label="Name" placeholder="e.g. Noun, Verb, Adjective" value={name} onChange={setName} />
      <TextField label="Abbreviation" placeholder="e.g. N, V, ADJ" value={abbr} onChange={setAbbr} onKeyDown={(e) => { if (e.key === 'Enter') save(); }} />
    </Dialog>
  );
}

function PosDeleteDialog({ pos, count, others, close }: { pos: PartOfSpeech; count: number; others: PartOfSpeech[]; close: (v?: { to: Id | null }) => void }) {
  const [to, setTo] = useState<Id | null>(others[0]?.id ?? null);
  const migrate = count > 0 && others.length > 0;
  return (
    <Dialog
      title={`Delete ${pos.name}?`}
      onClose={() => close()}
      actions={
        <>
          <TextButton onClick={() => close()}>Cancel</TextButton>
          <TextButton danger disabled={migrate && to === null} onClick={() => close({ to: migrate ? to : null })}>Delete</TextButton>
        </>
      }
    >
      {migrate ? (
        <>
          <div>{count} word(s) use this POS. Reassign them to:</div>
          <Select ariaLabel="Reassign to" value={to} options={others.map((p) => ({ value: p.id, label: `${p.name} (${formatAbbr(p.abbr)})` }))} onChange={setTo} />
          <div>All its dimensions, inflectional rules, and markers will also be deleted. This cannot be undone.</div>
        </>
      ) : (
        <div>This will also delete all its dimensions, inflectional rules, and markers for this POS. This cannot be undone.</div>
      )}
    </Dialog>
  );
}

function DimensionEditor({ posId }: { posId: Id }) {
  const engine = useEngine();
  const dims = engine.dimensionsForPos(posId);
  const add = async () => {
    const t = await openDialog<{ id: string; name: string; levels: { name: string; abbr: string }[] }>((close) => <TemplatePicker close={close} />);
    if (t) run((d) => cmd.addDimension(d, posId, t.name, t.levels, t.id));
  };
  return (
    <div className="col fill" style={{ gap: 0 }}>
      <div className="row between" style={{ padding: '12px 16px 8px' }}>
        <span className="h-section">Dimensions</span>
        <TextButton icon="add" onClick={() => void add()}>Add Dimension</TextButton>
      </div>
      {dims.length === 0 ? (
        <div className="center">
          <Icon name="layers" size={48} style={{ color: 'var(--on-surface-4)' }} />
          <div>No dimensions yet</div>
          <div className="faint">Click "Add Dimension" to begin.</div>
        </div>
      ) : (
        <div className="grow scroll col" style={{ padding: '0 16px 16px' }}>
          {dims.map((d) => <DimensionCard key={d.id} dim={d} posId={posId} />)}
        </div>
      )}
    </div>
  );
}

function DimensionCard({ dim, posId }: { dim: Dimension; posId: Id }) {
  const engine = useEngine();
  const stale = dim.intrinsic ? 0 : engine.staleIntrinsicCount(dim.id);
  const missing = dim.intrinsic ? engine.missingIntrinsicCount(posId, dim.id) : 0;
  const rename = () => openDialog<void>((close) => <DimensionDialog dim={dim} close={() => close()} />);
  const remove = async () => {
    if (await confirmDialog({ title: 'Delete dimension?', body: `Delete dimension '${dim.name}'? All levels and associated rules will be affected.` })) run((d) => cmd.deleteDimension(d, dim.id));
  };
  const purge = async () => {
    if (await confirmDialog({ title: 'Purge stale intrinsic levels', body: `This will remove the intrinsic level entry for '${dim.name}' from ${stale} lexemes. This cannot be undone.`, confirm: 'Purge' })) run((d) => cmd.purgeIntrinsicEntries(d, dim.id));
  };
  const removeLevel = async (l: Level) => {
    if (!(await confirmDialog({ title: 'Delete level?', body: `Delete level '${l.name} (${l.abbr})' from ${dim.name}? This cannot be undone.` }))) return;
    const report = cmd.levelReferences(engine.doc, dim.id, l.id);
    if (!report.total) {
      run((d) => cmd.deleteLevel(d, dim.id, l.id));
      return;
    }
    const others = dim.levels.filter((x) => x.id !== l.id);
    if (!others.length) {
      snack('Cannot delete the last level — add another first.');
      return;
    }
    const target = await openDialog<Id>((close) => <ReassignDialog level={l} report={report} candidates={others} close={close} />);
    if (target !== undefined) run((d) => cmd.reassignLevelAndDelete(d, dim.id, l.id, target));
  };
  return (
    <div className="card" data-testid={`dimension-${dim.name}`}>
      <div className="row">
        <span className="grow bold">{dim.name}</span>
        {dim.intrinsic && missing > 0 && <span title={`${missing} word${missing === 1 ? '' : 's'} missing ${dim.name} assignment`}><Icon name="warning_amber" size={16} className="amber" /></span>}
        <IconButton icon="edit" size={16} title="Edit dimension" onClick={() => void rename()} />
        <IconButton icon="delete_outline" size={16} danger title="Delete dimension" onClick={() => void remove()} />
      </div>
      <label className="check small muted" style={{ margin: '4px 0 8px' }}>
        <input type="checkbox" checked={dim.intrinsic} aria-label="Intrinsic" onChange={(e) => run((d) => cmd.setDimensionIntrinsic(d, dim.id, e.target.checked))} />
        Intrinsic — words of this POS have a fixed level (not inflected)
      </label>
      {!dim.intrinsic && stale > 0 && <TextButton icon="cleaning_services" onClick={() => void purge()}>Purge stale intrinsic levels for {stale} words</TextButton>}
      <div className="row wrap" style={{ gap: 6 }}>
        {dim.levels.slice().sort((a, b) => a.order - b.order).map((l) => (
          <span key={l.id} className="chip">
            <button type="button" title="Edit level" aria-label={`Edit ${l.name}`} onClick={() => void openDialog<void>((close) => <LevelDialog dim={dim} level={l} close={() => close()} />)}><Icon name="edit" size={13} /></button>
            {l.name} ({formatAbbr(l.abbr)})
            {dim.intrinsic && <button type="button" title="Edit standard form pattern" aria-label={`Standard form for ${l.name}`} onClick={() => void openDialog<void>((close) => <StandardFormDialog dim={dim} level={l} close={() => close()} />)}><Icon name="text_snippet" size={13} /></button>}
            <button type="button" title="Delete level" aria-label={`Delete ${l.name}`} onClick={() => void removeLevel(l)}><Icon name="close" size={13} /></button>
          </span>
        ))}
        <button type="button" className="chip" title="Add level" aria-label="Add level" onClick={() => void openDialog<void>((close) => <LevelDialog dim={dim} close={() => close()} />)}><Icon name="add" size={14} /></button>
      </div>
    </div>
  );
}

function DimensionDialog({ dim, close }: { dim: Dimension; close: () => void }) {
  const [name, setName] = useState(dim.name);
  const [abbr, setAbbr] = useState(dim.abbr ?? '');
  const [error, setError] = useState<string | null>(null);
  const save = () => {
    if (!name.trim()) {
      setError('Name cannot be empty');
      return;
    }
    run((d) => cmd.updateDimension(d, dim.id, name, abbr));
    close();
  };
  return (
    <Dialog title="Edit dimension" onClose={close} actions={<><TextButton onClick={close}>Cancel</TextButton><FilledButton onClick={save}>Save</FilledButton></>}>
      <TextField autoFocus label="Dimension name" value={name} error={error} onChange={setName} onKeyDown={(e) => { if (e.key === 'Enter') save(); }} />
      <TextField label="Abbreviation (optional)" placeholder="e.g. GEN, NUM, CAS" value={abbr} onChange={setAbbr} onKeyDown={(e) => { if (e.key === 'Enter') save(); }} />
    </Dialog>
  );
}

function LevelDialog({ dim, level, close }: { dim: Dimension; level?: Level; close: () => void }) {
  const [name, setName] = useState(level?.name ?? '');
  const [abbr, setAbbr] = useState(level?.abbr ?? '');
  const [errors, setErrors] = useState<{ name?: string; abbr?: string }>({});
  const save = () => {
    const e = { name: name.trim() ? undefined : 'Name cannot be empty', abbr: abbr.trim() ? undefined : 'Abbreviation cannot be empty' };
    setErrors(e);
    if (e.name || e.abbr) return;
    mutate((d) => cmd.saveLevel(d, dim.id, level?.id ?? null, name, abbr));
    close();
  };
  return (
    <Dialog title={level ? 'Edit level' : 'Add level'} onClose={close} actions={<><TextButton onClick={close}>Cancel</TextButton><FilledButton onClick={save}>Save</FilledButton></>}>
      <TextField autoFocus label="Level name" value={name} error={errors.name} onChange={setName} />
      <TextField label="Abbreviation" value={abbr} error={errors.abbr} onChange={setAbbr} onKeyDown={(e) => { if (e.key === 'Enter') save(); }} />
    </Dialog>
  );
}

function ReassignDialog({ level, report, candidates, close }: { level: Level; report: cmd.LevelReferences; candidates: Level[]; close: (v?: Id) => void }) {
  const [target, setTarget] = useState<Id | null>(null);
  return (
    <Dialog
      title={`Reassign and delete '${level.name}'`}
      onClose={() => close()}
      actions={
        <>
          <TextButton onClick={() => close()}>Cancel</TextButton>
          <FilledButton disabled={target === null} onClick={() => close(target!)}>Reassign and delete</FilledButton>
        </>
      }
    >
      <div>{report.total} references will be updated:</div>
      {report.lexemeIds.length > 0 && <div>• {report.lexemeIds.length} words</div>}
      {report.patternCount > 0 && <div>• {report.patternCount} standard-form patterns</div>}
      {report.ruleNames.length > 0 && <div>• {report.ruleNames.length} rule{report.ruleNames.length === 1 ? '' : 's'}</div>}
      {report.markerCount > 0 && <div>• {report.markerCount} markers</div>}
      {report.overrideCount > 0 && <div>• {report.overrideCount} cell overrides</div>}
      {report.slotCount > 0 && <div>• {report.slotCount} construction slots</div>}
      <div>Reassign to:</div>
      <Select ariaLabel="Reassign to" value={target} placeholder="Select a level" options={candidates.map((l) => ({ value: l.id, label: `${l.name} (${formatAbbr(l.abbr)})` }))} onChange={setTarget} />
    </Dialog>
  );
}

function TemplatePicker({ close }: { close: (v?: { id: string; name: string; levels: { name: string; abbr: string }[] }) => void }) {
  const [search, setSearch] = useState('');
  const q = search.toLowerCase().trim();
  const groups = new Map<string, typeof templates>();
  for (const t of templates) {
    if (q && !t.name.toLowerCase().includes(q) && !t.group.toLowerCase().includes(q) && !t.description.toLowerCase().includes(q)) continue;
    groups.set(t.group, [...(groups.get(t.group) ?? []), t]);
  }
  const custom = async () => {
    const name = await promptDialog({ title: 'New Custom Dimension', label: 'Dimension name', hint: 'e.g. Evidentiality, Politeness, Animacy', confirm: 'Add' });
    if (name) close({ id: 'custom.blank', name, levels: [] });
  };
  return (
    <Dialog title="Add Dimension" onClose={() => close()} actions={<TextButton onClick={() => close()}>Cancel</TextButton>}>
      <input type="search" placeholder="Search templates…" aria-label="Search templates" value={search} onChange={(e) => setSearch(e.target.value)} autoFocus />
      <button type="button" className="card row" style={{ textAlign: 'left' }} title="Start from scratch — no preset levels." onClick={() => void custom()}>
        <Icon name="add_circle_outline" size={18} className="primary" /> Custom (start blank)
      </button>
      {groups.size === 0 && <div className="faint">No templates match your search.</div>}
      {[...groups.entries()].map(([group, list]) => (
        <div key={group} className="col" style={{ gap: 6 }}>
          <div className="tiny muted bold" style={{ letterSpacing: 1 }}>{group.toUpperCase()}</div>
          {list.map((t) => (
            <button key={t.id} type="button" className="card" style={{ textAlign: 'left' }} title={t.description} onClick={() => close({ id: t.id, name: t.name, levels: t.levels })}>
              <div>{t.name}</div>
              <div className="small faint">{t.levels.map((l) => l.abbr).join(' · ')}</div>
            </button>
          ))}
        </div>
      ))}
    </Dialog>
  );
}

function StandardFormDialog({ dim, level, close }: { dim: Dimension; level: Level; close: () => void }) {
  const engine = useEngine();
  const existing = engine.doc.standardForms.find((s) => s.dimensionId === dim.id && s.levelId === level.id);
  type Kind = 'startsWith' | 'endsWith' | 'contains';
  const [branches, setBranches] = useState<{ kind: Kind; segments: Segment[] }[]>(existing?.branches ?? []);
  const update = (i: number, patch: Partial<{ kind: Kind; segments: Segment[] }>) => setBranches(branches.map((b, j) => (j === i ? { ...b, ...patch } : b)));
  const preview = (segs: Segment[]) => {
    const inv = engine.inventory;
    let acc = [''];
    for (const s of segs) {
      const options = s.kind === 'sound' ? [engine.fromPhonemic(s.text)] : s.kind === 'class' ? resolveClass(s.name, inv).map((x) => engine.fromPhonemic(x)) : [''];
      const withOptional = s.kind !== 'boundary' && s.optional ? ['', ...options] : options;
      acc = acc.flatMap((a) => withOptional.map((o) => a + o)).slice(0, 12);
    }
    const shown = acc.filter(Boolean);
    if (!shown.length) return '(no expansions)';
    return shown.length > 8 ? `${shown.slice(0, 8).join(', ')}, ...` : shown.join(', ');
  };
  return (
    <Dialog
      title={`${dim.name} → ${level.name}`}
      onClose={close}
      actions={
        <>
          <TextButton onClick={close}>Cancel</TextButton>
          <FilledButton onClick={() => { run((d) => cmd.saveStandardForm(d, dim.id, level.id, branches)); close(); }}>Save</FilledButton>
        </>
      }
    >
      <div className="small muted">Standard-form branches (any one may match):</div>
      {branches.map((b, i) => (
        <div key={i} className="col" style={{ gap: 2 }}>
          <div className="row">
            <Select inline ariaLabel="Match" value={b.kind} options={[{ value: 'startsWith' as const, label: 'starts with' }, { value: 'endsWith' as const, label: 'ends with' }, { value: 'contains' as const, label: 'contains' }]} onChange={(v) => update(i, { kind: v ?? 'endsWith' })} />
            <div className="grow"><SegmentEditor value={b.segments} onChange={(segments) => update(i, { segments })} label="Pattern" placeholder="e.g. ar" /></div>
            <IconButton icon="delete_outline" size={18} title="Remove branch" onClick={() => setBranches(branches.filter((_, j) => j !== i))} />
          </div>
          {b.segments.length > 0 && <div className="tiny faint">Matches: {preview(b.segments)}</div>}
        </div>
      ))}
      <div><TextButton icon="add" onClick={() => setBranches([...branches, { kind: 'endsWith', segments: [] }])}>Add branch</TextButton></div>
    </Dialog>
  );
}
