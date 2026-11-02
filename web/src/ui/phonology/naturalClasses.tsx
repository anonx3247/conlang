import { useState } from 'react';
import * as cmd from '../../core/commands';
import { CLASS_ALIASES, DEFAULT_CLASSES, LENGTH_CLASSES } from '../../core/phonology';
import type { Id, NaturalClass, Phoneme } from '../../core/types';
import { run, useDoc } from '../../storage/store';
import { Chip, confirmDialog, Dialog, FilledButton, Icon, openDialog, TextButton, TextField } from '../common';

export function NaturalClassesPage() {
  const doc = useDoc();
  const aliasOf = (n: string) => Object.entries(CLASS_ALIASES).find(([, v]) => v === n)?.[0];
  const byId = new Map(doc.phonemes.map((p) => [p.id, p]));
  const classes = doc.naturalClasses.slice().sort((a, b) => a.name.localeCompare(b.name));
  const edit = (nc?: NaturalClass) => openDialog<void>((close) => <ClassDialog existing={nc} phonemes={doc.phonemes} close={() => close()} />);
  const remove = async (nc: NaturalClass) => {
    const ok = await confirmDialog({ title: 'Delete Natural Class', body: `Remove the class [${nc.name}]? Patterns referencing it will stop matching.` });
    if (ok) run((d) => cmd.deleteNaturalClass(d, nc.id));
  };
  return (
    <div className="col pad-lg" style={{ gap: 12 }}>
      <div className="row between">
        <h1 className="h-large">Natural Classes</h1>
        <TextButton icon="add" onClick={() => void edit()}>New Class</TextButton>
      </div>
      <div className="small muted">
        C, V, and the predefined phonological classes below are built-in. Aliases S, N, F, L and R stand for Stop, Nasal, Fricative, Liquid and Rhotic. Custom classes appear in every class picker.
      </div>
      <div className="row wrap">
        <Chip><span className="bold">[C]</span><span className="faint"> = all consonants</span></Chip>
        <Chip><span className="bold">[V]</span><span className="faint"> = all vowels</span></Chip>
        {Object.entries(DEFAULT_CLASSES).map(([name, members]) => (
          <span key={name} className="chip" style={{ whiteSpace: 'normal' }}>
            <span className="bold">[{name}]{aliasOf(name) ? ` / ${aliasOf(name)}` : ''}</span>
            <span className="faint"> = {members.join(' ')}</span>
          </span>
        ))}
        {Object.entries(LENGTH_CLASSES).map(([name, meaning]) => (
          <span key={name} className="chip" style={{ whiteSpace: 'normal' }} data-testid={`class-${name}`}>
            <span className="bold">[{name}]</span>
            <span className="faint"> = {meaning}</span>
          </span>
        ))}
      </div>
      <div className="hr" />
      {classes.length === 0 ? (
        <div className="small italic faint">No custom natural classes yet.</div>
      ) : (
        <div className="row wrap">
          {classes.map((nc) => (
            <Chip key={nc.id} onClick={() => void edit(nc)} onDelete={() => void remove(nc)}>
              <span className="bold">[{nc.name}]</span>
              {nc.phonemeIds.length > 0 && <span className="faint"> = {nc.phonemeIds.map((id) => byId.get(id)?.symbol).filter(Boolean).join(' ')}</span>}
            </Chip>
          ))}
        </div>
      )}
    </div>
  );
}

function ClassDialog({ existing, phonemes, close }: { existing?: NaturalClass; phonemes: Phoneme[]; close: () => void }) {
  const [name, setName] = useState(existing?.name ?? '');
  const [selected, setSelected] = useState<Set<Id>>(new Set(existing?.phonemeIds));
  const [error, setError] = useState<string | null>(null);
  const toggle = (id: Id) => {
    const next = new Set(selected);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    setSelected(next);
  };
  const save = () => {
    const problem = cmd.naturalClassNameProblem(name.trim());
    if (problem) {
      setError(problem);
      return;
    }
    run((d) => cmd.saveNaturalClass(d, existing?.id ?? null, name, [...selected].sort((a, b) => a - b)));
    close();
  };
  const group = (label: string, list: Phoneme[]) =>
    list.length > 0 && (
      <div className="col" style={{ gap: 4 }}>
        <div className="small bold">{label}</div>
        <div className="row wrap" style={{ gap: 6 }}>
          {list.map((p) => <Chip key={p.id} selected={selected.has(p.id)} onClick={() => toggle(p.id)}>{p.symbol}</Chip>)}
        </div>
      </div>
    );
  return (
    <Dialog
      title={existing ? 'Edit Natural Class' : 'New Natural Class'}
      onClose={close}
      actions={
        <>
          <TextButton onClick={close}>Cancel</TextButton>
          <FilledButton onClick={save}>{existing ? 'Save' : 'Create'}</FilledButton>
        </>
      }
    >
      <div className="note row"><Icon name="info_outline" size={14} /> C (all consonants) and V (all vowels) are built-in system classes.</div>
      <TextField autoFocus label="Class Name" placeholder="e.g. stop, nasal, liquid, obstruent" value={name} error={error} onChange={(v) => { setName(v); setError(null); }} />
      <div className="bold small">Phonemes</div>
      {phonemes.length === 0 && <div className="small muted">No phonemes in inventory yet. Add some phonemes first.</div>}
      {group('Consonants', phonemes.filter((p) => p.type === 'consonant'))}
      {group('Vowels', phonemes.filter((p) => p.type === 'vowel'))}
    </Dialog>
  );
}
