import { useState } from 'react';
import * as cmd from '../../core/commands';
import type { Construction, ConstructionSlot, Id, SlotFeatures } from '../../core/types';
import { mutate, run, uiGet, uiSet, useEngine } from '../../storage/store';
import { confirmDialog, EmptyState, FilledButton, Icon, IconButton, OutlinedButton, Select, SelectField, TextButton, TextField } from '../common';
import { GlossTagInput, WordPicker, wordOption } from '../words';

export function ConstructionsPage() {
  const engine = useEngine();
  const list = engine.doc.constructions.slice().sort((a, b) => a.order - b.order);
  const [selected, setSelected] = useState<Id | null>(uiGet('constructions.selected', null));
  const select = (id: Id | null) => {
    uiSet('constructions.selected', id);
    setSelected(id);
  };
  const add = () => select(mutate((d) => cmd.addConstruction(d)));
  const remove = async (c: Construction) => {
    if (!(await confirmDialog({ title: 'Delete construction?', body: `'${c.name}' and all its slots will be permanently deleted.` }))) return;
    run((d) => cmd.deleteConstruction(d, c.id));
    if (selected === c.id) select(list.find((x) => x.id !== c.id)?.id ?? null);
  };

  if (!list.length) {
    return (
      <EmptyState title="No constructions yet" body="Define phrase patterns (e.g. a negation word + Verb, or an auxiliary + Phrase) to describe how your language expresses grammatical meaning analytically.">
        <FilledButton icon="add" onClick={add}>Add Construction</FilledButton>
      </EmptyState>
    );
  }
  const current = list.find((c) => c.id === selected) ?? list[0];
  return (
    <div className="row top fill" style={{ gap: 0 }}>
      <div className="col fill" style={{ width: 280, flex: 'none', background: 'var(--surface-low)', gap: 0 }}>
        <div className="h-section" style={{ padding: '12px 16px 6px' }}>Constructions</div>
        <div style={{ padding: '0 16px 8px' }}><FilledButton icon="add" onClick={add}>Add Construction</FilledButton></div>
        <div className="grow scroll">
          {list.map((c) => (
            <div key={c.id} className={`list-row ${c.id === current.id ? 'sel' : ''}`} onClick={() => select(c.id)}>
              <span className="grow" style={{ minWidth: 0 }}>
                <div className="ellipsis">{c.name}</div>
                {c.slots.length > 0 && <div className="small faint ellipsis">{engine.constructionFormula(c)}</div>}
              </span>
              <IconButton icon="delete_outline" title="Delete construction" onClick={(e) => { e.stopPropagation(); void remove(c); }} />
            </div>
          ))}
        </div>
      </div>
      <div className="vr fill" />
      <div className="grow fill scroll col pad" key={current.id}>
        <NameField construction={current} />
        <Warnings construction={current} />
        <SlotEditor construction={current} />
        <Preview construction={current} />
      </div>
    </div>
  );
}

function NameField({ construction }: { construction: Construction }) {
  const [name, setName] = useState(construction.name);
  return (
    <TextField
      label="Construction name"
      placeholder="e.g. Negation, Future tense, Genitive"
      maxLength={100}
      value={name}
      onChange={setName}
      onBlur={() => { if (name.trim() && name.trim() !== construction.name) run((d) => cmd.renameConstruction(d, construction.id, name)); }}
    />
  );
}

function Warnings({ construction }: { construction: Construction }) {
  const engine = useEngine();
  const warnings = engine.constructionWarnings(construction);
  if (!warnings.length) return null;
  return (
    <div className="col" style={{ gap: 4 }} data-testid="construction-warnings">
      {warnings.map((w) => <div key={w} className="row small amber"><Icon name="warning_amber" size={14} /><span>{w}</span></div>)}
    </div>
  );
}

function SlotEditor({ construction }: { construction: Construction }) {
  const engine = useEngine();
  const [editing, setEditing] = useState<Id | 'new' | null>(null);
  return (
    <div className="col">
      <div className="bold">Slots</div>
      {construction.slots.length === 0 && editing === null && <div className="small faint">Add slots to define this construction's pattern. At least one must be a Word slot.</div>}
      {construction.slots.map((s, i) =>
        editing === s.id ? (
          <SlotForm key={s.id} existing={s} onCancel={() => setEditing(null)} onSave={(input) => { run((d) => cmd.updateSlot(d, construction.id, s.id, input)); setEditing(null); }} />
        ) : (
          <div key={s.id} className="row" data-testid={`slot-${i}`}>
            <SlotChip slot={s} />
            <IconButton icon="edit" size={14} title="Edit slot" onClick={() => setEditing(s.id)} />
            <IconButton icon="arrow_upward" size={14} title="Move earlier" disabled={i === 0} onClick={() => run((d) => cmd.moveSlot(d, construction.id, i, i - 1))} />
            <IconButton icon="arrow_downward" size={14} title="Move later" disabled={i === construction.slots.length - 1} onClick={() => run((d) => cmd.moveSlot(d, construction.id, i, i + 1))} />
            <IconButton icon="close" size={14} title="Remove slot" onClick={() => run((d) => cmd.deleteSlot(d, construction.id, s.id))} />
            {engine.slotSummary(s).missing && <span className="small err">Missing. Edit this slot to pick a replacement.</span>}
          </div>
        ),
      )}
      {editing === 'new' ? (
        <SlotForm onCancel={() => setEditing(null)} onSave={(input) => { run((d) => cmd.addSlot(d, construction.id, input)); setEditing(null); }} />
      ) : (
        <div><OutlinedButton icon="add" onClick={() => setEditing('new')}>Add Slot</OutlinedButton></div>
      )}
    </div>
  );
}

function SlotChip({ slot }: { slot: ConstructionSlot }) {
  const engine = useEngine();
  const s = engine.slotSummary(slot);
  return (
    <span className={`chip ${s.missing ? 'err' : ''}`}>
      {s.text}
      {s.form.length > 0 && <span className="faint">({s.form.join(', ')})</span>}
      {s.tag && <span className="badge">{s.tag}</span>}
    </span>
  );
}

const SLOT_TYPES = [['word', 'Word'], ['pos', 'Part of Speech'], ['phrase', 'Phrase'], ['clause', 'Clause']] as const;
type SlotChoice = (typeof SLOT_TYPES)[number][0];

function SlotForm({ existing, onSave, onCancel }: { existing?: ConstructionSlot; onSave: (slot: cmd.SlotInput) => void; onCancel: () => void }) {
  const engine = useEngine();
  const initial: SlotChoice = !existing ? 'word' : existing.type === 'phrase' ? existing.kind : existing.type;
  const [type, setType] = useState<SlotChoice>(initial);
  const [lexemeId, setLexemeId] = useState<Id | null>(existing?.type === 'word' && engine.lexeme(existing.lexemeId) ? existing.lexemeId : null);
  const [posId, setPosId] = useState<Id | null>(existing?.type === 'pos' && engine.pos(existing.posId) ? existing.posId : null);
  const [tag, setTag] = useState(existing && existing.type !== 'phrase' ? existing.glossTag ?? '' : '');
  const [features, setFeatures] = useState<SlotFeatures>(existing && existing.type !== 'phrase' ? existing.features ?? {} : {});
  const [label, setLabel] = useState(existing?.type === 'phrase' ? existing.label ?? '' : '');

  const word = lexemeId !== null ? engine.lexeme(lexemeId) : undefined;
  const dimensions = type === 'word' && lexemeId !== null ? engine.slotDimensions({ type: 'word', lexemeId }) : type === 'pos' && posId !== null ? engine.slotDimensions({ type: 'pos', posId }) : [];
  const ready = type === 'word' ? lexemeId !== null : type === 'pos' ? posId !== null : true;
  const save = () => {
    const chosen = Object.fromEntries(Object.entries(features).filter(([dim]) => dimensions.some((d) => d.id === Number(dim))));
    if (type === 'word') onSave({ type: 'word', lexemeId: lexemeId!, glossTag: tag, features: chosen });
    else if (type === 'pos') onSave({ type: 'pos', posId: posId!, glossTag: tag, features: chosen });
    else onSave({ type: 'phrase', kind: type, label });
  };
  return (
    <div className="card col" data-testid="slot-form">
      <div className="row wrap" role="radiogroup" aria-label="Slot type">
        {SLOT_TYPES.map(([value, name]) => (
          <button key={value} type="button" role="radio" aria-checked={type === value} className={`chip ${type === value ? 'sel' : ''}`} onClick={() => { setType(value); setFeatures({}); }}>{type === value && <Icon name="check" size={14} />}{name}</button>
        ))}
      </div>
      {type === 'word' && (word ? (
        <div className="row">
          <span className="chip" data-testid="slot-word">{wordOption(engine, word)}</span>
          <TextButton onClick={() => { setLexemeId(null); setFeatures({}); }}>Change</TextButton>
        </div>
      ) : (
        <WordPicker autoFocus label="Find a word" onPick={(id) => { setLexemeId(id); setFeatures({}); }} />
      ))}
      {type === 'pos' && (
        <SelectField label="Part of Speech" value={posId} placeholder="Select Part of Speech" options={engine.doc.partsOfSpeech.map((p) => ({ value: p.id, label: `${p.name} (${p.abbr})` }))} onChange={(v) => { setPosId(v); setFeatures({}); }} />
      )}
      {(type === 'word' || type === 'pos') && (
        <>
          {dimensions.length > 0 && (
            <div className="col" style={{ gap: 4 }} data-testid="form-picker">
              <div className="small">Form <span className="faint">(optional: pick only what matters)</span></div>
              <div className="row wrap">
                {dimensions.map((d) => (
                  <label key={d.id} className="row small" style={{ gap: 4 }}>
                    <span>{d.name}</span>
                    <Select inline ariaLabel={d.name} value={features[d.id] ?? null} placeholder="Any" options={d.levels.map((l) => ({ value: l.id, label: l.name }))} onChange={(v) => { const next = { ...features }; if (v === null) delete next[d.id]; else next[d.id] = v; setFeatures(next); }} />
                  </label>
                ))}
              </div>
            </div>
          )}
          <GlossTagInput label="Gloss tag (optional)" value={tag} onChange={setTag} />
        </>
      )}
      {(type === 'phrase' || type === 'clause') && (
        <TextField label="Label (optional)" placeholder={type === 'clause' ? 'e.g. subjunctive clause' : 'e.g. object'} value={label} onChange={setLabel} help="Takes every word up to the next fixed word, or the end of the phrase." />
      )}
      <div className="row">
        <FilledButton disabled={!ready} onClick={save}>{existing ? 'Save' : 'Add'}</FilledButton>
        <TextButton onClick={onCancel}>Cancel</TextButton>
      </div>
    </div>
  );
}

export function Preview({ construction }: { construction: Construction }) {
  const engine = useEngine();
  const pieces = engine.fillConstruction(construction);
  return (
    <div className="col" style={{ gap: 4 }}>
      <div className="bold">Preview</div>
      <div className="card" data-testid="construction-preview">
        {pieces.length === 0 ? (
          <span className="small faint">Add slots to define this construction's pattern.</span>
        ) : (
          pieces.map((p, i) => <span key={i} className={p.missing ? 'err small' : ''}>{i > 0 ? ' ' : ''}{p.text}</span>)
        )}
      </div>
    </div>
  );
}
