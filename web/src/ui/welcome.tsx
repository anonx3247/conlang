import { useState } from 'react';
import { canUseFiles, createProject, openProjectFile, openRecent, useApp } from '../storage/store';
import { Dialog, FilledButton, Icon, openDialog, OutlinedButton, relativeTime, TextButton, TextField } from './common';

export async function newProjectFlow() {
  const name = await openDialog<string>((close) => <NewProjectDialog close={close} />);
  if (name) await createProject(name);
}

function NewProjectDialog({ close }: { close: (v?: string) => void }) {
  const [name, setName] = useState('');
  const [error, setError] = useState<string | null>(null);
  const submit = () => {
    if (!name.trim()) setError('Project name cannot be empty');
    else close(name.trim());
  };
  return (
    <Dialog
      title="New Project"
      onClose={() => close()}
      actions={
        <>
          <TextButton onClick={() => close()}>Cancel</TextButton>
          <FilledButton onClick={submit}>Create</FilledButton>
        </>
      }
    >
      <TextField
        autoFocus
        label="Project name"
        placeholder="e.g. Elvish, Dothraki, My First Conlang"
        value={name}
        error={error}
        help={canUseFiles ? "You'll choose where its file is saved. It never leaves this computer." : 'Saved in this browser only. Use File → Download a Copy to back it up.'}
        onChange={(v) => { setName(v); setError(null); }}
        onKeyDown={(e) => { if (e.key === 'Enter') submit(); }}
      />
    </Dialog>
  );
}

export function WelcomeScreen() {
  const { registry } = useApp();
  const recent = registry.slice().sort((a, b) => b.lastOpenedAt.localeCompare(a.lastOpenedAt)).slice(0, 10);
  return (
    <div className="welcome">
      <div>
        <div style={{ textAlign: 'center' }}>
          <img src="/logo.png" width={96} height={96} alt="" style={{ borderRadius: 16 }} />
        </div>
        <h1 style={{ textAlign: 'center', fontSize: 28, fontWeight: 700, marginTop: 12 }}>Conlang Workbench</h1>
        <p className="muted" style={{ textAlign: 'center', margin: 0 }}>A professional conlang workbench</p>
        <div className="row" style={{ justifyContent: 'center', marginTop: 24 }}>
          <FilledButton icon="add" onClick={() => void newProjectFlow()}>New Project</FilledButton>
          <OutlinedButton icon="folder_open" onClick={() => void openProjectFile()}>Open Project</OutlinedButton>
        </div>
        <p className="help" style={{ textAlign: 'center' }}>Your projects stay on this computer. Older .conlang files can be opened too.</p>
        <div style={{ height: 24 }} />
        {recent.length === 0 ? (
          <div className="small fainter italic" style={{ textAlign: 'center' }}>No recent projects</div>
        ) : (
          <>
            <div className="muted small" style={{ letterSpacing: 0.5 }}>Recent Projects</div>
            {recent.map((p) => (
              <button key={p.id} type="button" className="list-row" style={{ borderRadius: 8 }} onClick={() => void openRecent(p.id)}>
                <Icon name="folder" size={18} style={{ color: 'var(--primary)', opacity: 0.8 }} />
                <span className="grow">
                  <div style={{ fontWeight: 500 }}>{p.name}</div>
                  <div className="small faint ellipsis">{p.fileName ?? 'Saved in this browser'}</div>
                </span>
                <span className="tiny fainter">{relativeTime(p.lastOpenedAt)}</span>
              </button>
            ))}
          </>
        )}
      </div>
    </div>
  );
}
