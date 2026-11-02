import { useState } from 'react';
import ipaSounds from '../../data/ipa_sounds.json';
import * as cmd from '../../core/commands';
import type { Id, Phoneme } from '../../core/types';
import { mutate, run, snack, useDoc, useEngine } from '../../storage/store';
import { Check, confirmDialog, Dialog, FilledButton, Icon, IconButton, openDialog, SelectField, Switch, TextButton, TextField } from '../common';
import { IpaField, IpaInput, isPlaceableVowel, vowelPosition, VowelTrapezoid } from '../ipa';

const MANNERS = ['plosive', 'nasal', 'trill', 'tap/flap', 'fricative', 'lateral fricative', 'approximant', 'lateral approximant', 'affricate', 'click', 'implosive', 'ejective'];
const PLACES = ['bilabial', 'labiodental', 'dental', 'alveolar', 'postalveolar', 'retroflex', 'palatal', 'velar', 'uvular', 'pharyngeal', 'glottal', 'labial-velar', 'labial-palatal'];
const HEIGHTS = ['close', 'near-close', 'close-mid', 'mid', 'open-mid', 'near-open', 'open'];
const BACKNESS = ['front', 'near-front', 'central', 'near-back', 'back'];
const SHORT_PLACE: Record<string, string> = { bilabial: 'Bi', labiodental: 'Ld', dental: 'De', alveolar: 'Al', postalveolar: 'Pa', retroflex: 'Rf', palatal: 'Pl', velar: 'Ve', uvular: 'Uv', pharyngeal: 'Ph', glottal: 'Gl', 'labial-velar': 'LV', 'labial-palatal': 'LP' };
const SHORT_MANNER: Record<string, string> = { plosive: 'Plosive', nasal: 'Nasal', trill: 'Trill', 'tap/flap': 'Tap/Flap', fricative: 'Fricative', 'lateral fricative': 'Lat. Fric.', approximant: 'Approx.', 'lateral approximant': 'Lat. Approx.', affricate: 'Affricate', click: 'Click', implosive: 'Implosive', ejective: 'Ejective' };
const cap = (s: string) => s[0].toUpperCase() + s.slice(1);

function PhonemeChip({ p }: { p: Phoneme }) {
  const engine = useEngine();
  const rom = engine.romanize(p.symbol);
  const title = p.type === 'consonant'
    ? [p.voicing, p.place, p.manner].filter(Boolean).join(' ')
    : [p.rounded ? 'rounded' : null, p.height, p.backness, 'vowel'].filter(Boolean).join(' ');
  return (
    <button type="button" className="chip" title={title} onClick={() => void openPhonemeDialog(p)} data-testid={`phoneme-${p.symbol}`} style={{ padding: '2px 6px', minHeight: 24 }}>
      <span>{rom}</span>
      {rom !== p.symbol && <span className="tiny faint">/{p.symbol}/</span>}
    </button>
  );
}

function ConsonantGrid({ consonants }: { consonants: Phoneme[] }) {
  const grid = new Map<string, Phoneme[]>();
  const key = (m: string, pl: string) => `${m}|${pl}`;
  for (const c of consonants) grid.set(key(c.manner ?? '', c.place ?? ''), [...(grid.get(key(c.manner ?? '', c.place ?? '')) ?? []), c]);
  const manners = [...MANNERS.filter((m) => consonants.some((c) => c.manner === m))];
  const places = PLACES.filter((pl) => consonants.some((c) => c.place === pl));
  const unplaced = consonants.filter((c) => !c.manner || !c.place || !MANNERS.includes(c.manner) || !PLACES.includes(c.place));
  return (
    <div className="col">
      <div className="scroll">
        <table className="paradigm" style={{ fontSize: 12 }} data-testid="consonant-grid">
          <thead>
            <tr>
              <th />
              {places.map((pl) => <th key={pl} title={pl} className="faint" style={{ fontWeight: 500 }}>{SHORT_PLACE[pl]}</th>)}
            </tr>
          </thead>
          <tbody>
            {manners.map((m) => (
              <tr key={m}>
                <th style={{ textAlign: 'left', fontWeight: 500 }}>{SHORT_MANNER[m]}</th>
                {places.map((pl) => {
                  const here = (grid.get(key(m, pl)) ?? []).slice().sort((a, b) => Number(a.voicing !== 'voiceless') - Number(b.voicing !== 'voiceless'));
                  return (
                    <td key={pl} style={{ minWidth: 56, height: 40, cursor: 'default' }}>
                      <div className="row" style={{ justifyContent: 'center', gap: 2, flexWrap: 'wrap' }}>
                        {here.map((p) => <PhonemeChip key={p.id} p={p} />)}
                      </div>
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {unplaced.length > 0 && (
        <div className="row wrap"><span className="small faint">Other:</span>{unplaced.map((p) => <PhonemeChip key={p.id} p={p} />)}</div>
      )}
    </div>
  );
}

function VowelChart({ vowels }: { vowels: Phoneme[] }) {
  const width = 460;
  const height = 200;
  const cells = new Map<string, Phoneme[]>();
  for (const v of vowels) if (isPlaceableVowel(v.height, v.backness)) cells.set(`${v.height}|${v.backness}`, [...(cells.get(`${v.height}|${v.backness}`) ?? []), v]);
  const unplaced = vowels.filter((v) => !isPlaceableVowel(v.height, v.backness));
  return (
    <div className="col">
      <div style={{ padding: '8px 16px 16px' }}>
        <VowelTrapezoid width={width} height={height}>
          {[...cells.entries()].map(([k, list]) => {
            const [h, b] = k.split('|');
            const pos = vowelPosition(h, b, width, height);
            const sorted = list.slice().sort((a, c) => Number(!!a.rounded) - Number(!!c.rounded));
            return (
              <div key={k} className="row" style={{ position: 'absolute', left: pos.x, top: pos.y, transform: 'translate(-50%,-50%)', gap: 2 }}>
                {sorted.map((p) => <PhonemeChip key={p.id} p={p} />)}
              </div>
            );
          })}
        </VowelTrapezoid>
      </div>
      {unplaced.length > 0 && (
        <div className="row wrap"><span className="small faint">Other:</span>{unplaced.map((p) => <PhonemeChip key={p.id} p={p} />)}</div>
      )}
    </div>
  );
}

export function InventoryPage() {
  const doc = useDoc();
  const consonants = doc.phonemes.filter((p) => p.type === 'consonant').sort((a, b) => a.symbol.localeCompare(b.symbol));
  const vowels = doc.phonemes.filter((p) => p.type === 'vowel').sort((a, b) => a.symbol.localeCompare(b.symbol));
  return (
    <div className="col pad-lg" style={{ gap: 16 }}>
      <div className="row between">
        <h1 className="h-large">Phoneme Inventory</h1>
        <FilledButton icon="add" onClick={() => void openPhonemeDialog()}>Add Phoneme</FilledButton>
      </div>
      {doc.phonemes.length > 0 && (
        <div className="row wrap" style={{ gap: 4 }}>
          {[...consonants, ...vowels].sort((a, b) => a.symbol.localeCompare(b.symbol)).map((p) => <PhonemeChip key={p.id} p={p} />)}
        </div>
      )}
      <h2 style={{ fontSize: 18, fontWeight: 500 }}>Consonants</h2>
      {consonants.length ? <ConsonantGrid consonants={consonants} /> : <div className="muted small">No consonants yet. Tap "Add Phoneme" to define your first consonant.</div>}
      <h2 style={{ fontSize: 18, fontWeight: 500 }}>Vowels</h2>
      {vowels.length ? <VowelChart vowels={vowels} /> : <div className="muted small">No vowels yet. Tap "Add Phoneme" to define your first vowel.</div>}
      <div className="hr" />
      <h2 style={{ fontSize: 18, fontWeight: 500 }}>Romanization</h2>
      <RomanizationSection />
    </div>
  );
}

// ---------------------------------------------------------------------------
// Phoneme dialog
// ---------------------------------------------------------------------------

function deriveSymbol(type: string, f: { manner: string | null; place: string | null; voicing: string | null; height: string | null; backness: string | null; rounded: boolean }): string | null {
  if (type === 'consonant') {
    if (!f.manner || !f.place || !f.voicing) return null;
    const voiced = f.voicing === 'voiced';
    return [...ipaSounds.pulmonic, ...ipaSounds.nonPulmonic].find((s) => s.manner === f.manner && s.place === f.place && s.voiced === voiced)?.symbol ?? null;
  }
  if (!f.height || !f.backness) return null;
  return ipaSounds.vowels.find((s) => s.height === f.height && s.backness === f.backness && !!s.rounded === f.rounded)?.symbol ?? null;
}

export function openPhonemeDialog(existing?: Phoneme) {
  return openDialog<void>((close) => <PhonemeDialog existing={existing} close={() => close()} />);
}

function PhonemeDialog({ existing, close }: { existing?: Phoneme; close: () => void }) {
  const engine = useEngine();
  const [typed, setTyped] = useState(existing?.symbol ?? '');
  const [custom, setCustom] = useState(existing?.symbol ?? '');
  const [type, setType] = useState<'consonant' | 'vowel'>(existing?.type ?? 'consonant');
  const [manner, setManner] = useState(existing?.manner ?? null);
  const [place, setPlace] = useState(existing?.place ?? null);
  const [voicing, setVoicing] = useState(existing?.voicing ?? null);
  const [height, setHeight] = useState(existing?.height ?? null);
  const [backness, setBackness] = useState(existing?.backness ?? null);
  const [rounded, setRounded] = useState(!!existing?.rounded);

  const derived = deriveSymbol(type, { manner, place, voicing, height, backness, rounded });
  const featuresComplete = type === 'consonant' ? !!manner && !!place && !!voicing : !!height && !!backness;
  const symbol = typed.trim() || derived || custom.trim();

  const onTyped = (v: string) => {
    setTyped(v);
    const t = v.trim();
    const features = cmd.featuresForSymbol(t) ?? (t.length > 1 ? cmd.featuresForSymbol([...t][0]) : null);
    if (!features) return;
    setType(features.type);
    setManner(features.manner ?? null);
    setPlace(features.place ?? null);
    setVoicing(features.voicing ?? null);
    setHeight(features.height ?? null);
    setBackness(features.backness ?? null);
    setRounded(!!features.rounded);
  };

  const save = async () => {
    if (!symbol) return;
    const input = { symbol, type, manner, place, voicing, height, backness, rounded };
    if (existing) {
      run((d) => cmd.updatePhoneme(d, existing.id, input));
    } else {
      run((d) => cmd.addPhoneme(d, input));
      if (engine.romanizationOn && !engine.doc.romanization.some((m) => m.phoneme === symbol)) {
        const latin = await openDialog<string>((c) => <RomPrompt symbol={symbol} close={c} />);
        if (latin) run((d) => cmd.saveRomanization(d, null, symbol, latin));
      }
    }
    close();
  };

  const remove = async () => {
    if (!existing) return;
    const ok = await confirmDialog({ title: 'Delete Phoneme', body: `Remove /${existing.symbol}/ from the inventory? Any natural classes referencing this phoneme will lose this member.` });
    if (ok) {
      run((d) => cmd.deletePhoneme(d, existing.id));
      close();
    }
  };

  const mapping = engine.doc.romanization.find((m) => m.phoneme === symbol);
  const allophones = symbol ? engine.allophones(symbol) : [];
  const opts = (list: string[]) => list.map((v) => ({ value: v, label: cap(v) }));

  return (
    <Dialog
      title={existing ? 'Edit Phoneme' : 'Add Phoneme'}
      onClose={close}
      actions={
        <>
          {existing && <TextButton danger onClick={() => void remove()} style={{ marginRight: 'auto' }}>Delete</TextButton>}
          <TextButton onClick={close}>Cancel</TextButton>
          <FilledButton onClick={() => void save()} disabled={!symbol}>{existing ? 'Save' : 'Add'}</FilledButton>
        </>
      }
    >
      <IpaField label="IPA Symbol (optional)" placeholder="Type or paste, e.g. b, ʃ, ɑ" help="Auto-fills features if recognized" value={typed} onChange={onTyped} autoFocus />
      <SelectField label="Type" value={type} options={[{ value: 'consonant' as const, label: 'Consonant' }, { value: 'vowel' as const, label: 'Vowel' }]} onChange={(v) => setType(v ?? 'consonant')} />
      {type === 'consonant' ? (
        <>
          <SelectField label="Manner of Articulation" value={manner} placeholder="" options={opts(MANNERS)} onChange={setManner} />
          <SelectField label="Place of Articulation" value={place} placeholder="" options={opts(PLACES)} onChange={setPlace} />
          <SelectField label="Voicing" value={voicing} placeholder="" options={opts(['voiced', 'voiceless'])} onChange={setVoicing} />
        </>
      ) : (
        <>
          <SelectField label="Vowel Height" value={height} placeholder="" options={opts(HEIGHTS)} onChange={setHeight} />
          <SelectField label="Backness" value={backness} placeholder="" options={opts(BACKNESS)} onChange={setBackness} />
          <Check checked={rounded} onChange={setRounded}>Rounded</Check>
        </>
      )}
      <div className="card" style={{ textAlign: 'center' }}>
        <div className="tiny faint">IPA Symbol</div>
        <div style={{ fontSize: 28 }} className={derived ? 'primary' : 'fainter'} data-testid="derived-symbol">{derived ?? (featuresComplete ? '?' : '—')}</div>
        {!derived && featuresComplete && <div className="small faint">Unknown combination</div>}
      </div>
      {!derived && featuresComplete && <TextField label="Custom IPA symbol" placeholder="Enter symbol manually" value={custom} onChange={setCustom} />}
      {symbol && (
        <div className="row small muted"><Icon name="translate" size={14} /> Romanization: {mapping ? <span className="bold">{mapping.latin}</span> : <span className="faint">No romanization defined</span>}</div>
      )}
      {allophones.length > 0 && (
        <div className="row small muted" data-testid="allophones"><Icon name="tune" size={14} /> Allophones: /{symbol}/ → [{allophones.map((a) => a.output).join(', ')}]</div>
      )}
    </Dialog>
  );
}

function RomPrompt({ symbol, close }: { symbol: string; close: (v?: string) => void }) {
  const [latin, setLatin] = useState('');
  return (
    <Dialog
      title={`Add romanization for /${symbol}/?`}
      onClose={() => close()}
      actions={
        <>
          <TextButton onClick={() => close()}>Skip</TextButton>
          <FilledButton onClick={() => close(latin.trim())}>Add</FilledButton>
        </>
      }
    >
      <TextField autoFocus label="Latin representation" placeholder="e.g. sh, zh, ng" value={latin} onChange={setLatin} onKeyDown={(e) => { if (e.key === 'Enter') close(latin.trim()); }} />
    </Dialog>
  );
}

// ---------------------------------------------------------------------------
// Romanization
// ---------------------------------------------------------------------------

function RomanizationSection() {
  const doc = useDoc();
  const engine = useEngine();
  const [editing, setEditing] = useState<Id | 'new' | null>(null);
  const [latin, setLatin] = useState('');
  const [ipa, setIpa] = useState('');

  const start = (id: Id | 'new', l = '', i = '') => {
    setEditing(id);
    setLatin(l);
    setIpa(i);
  };
  const save = () => {
    try {
      const created = mutate((d) => cmd.saveRomanization(d, editing === 'new' ? null : (editing as Id), ipa, latin));
      if (created) snack(`Phoneme /${created}/ added to inventory`);
      setEditing(null);
    } catch (e) {
      if (e instanceof cmd.CommandError) snack(e.message);
      else throw e;
    }
  };
  const editRow = (
    <div className="row" style={{ padding: '6px 0' }}>
      <div style={{ width: 120 }}><input type="text" autoFocus aria-label="Latin letter" placeholder="sh" value={latin} onChange={(e) => setLatin(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') save(); }} /></div>
      <div className="grow"><IpaInput aria-label="IPA sound" placeholder="/ʃ/" value={ipa} onChange={setIpa} onKeyDown={(e) => { if (e.key === 'Enter') save(); }} /></div>
      <IconButton icon="check" title="Save" onClick={save} />
      <IconButton icon="close" title="Cancel" onClick={() => setEditing(null)} />
    </div>
  );
  return (
    <div className="col" style={{ gap: 8 }}>
      {engine.bijectionViolations.length > 0 && (
        <div className="banner error" style={{ display: 'block' }}>
          <div className="bold">Romanization bijection conflict ({engine.bijectionViolations.length} issue{engine.bijectionViolations.length === 1 ? '' : 's'})</div>
          {engine.bijectionViolations.map((v, i) => <div key={i} className="small">• {v.detail}</div>)}
          <div className="small italic">Rule editing is blocked until these conflicts are resolved.</div>
        </div>
      )}
      <div className="row">
        <Icon name="translate" size={16} className="muted" />
        <span className="bold">Romanization</span>
        <span className="small faint">(Latin letters → IPA sounds)</span>
        <span className="grow" />
        <span className="small muted">Enabled</span>
        <Switch label="Romanization enabled" checked={doc.settings.romanizationEnabled} onChange={(v) => run((d) => cmd.setRomanizationEnabled(d, v))} />
      </div>
      {!doc.settings.romanizationEnabled ? (
        <div className="small faint">Romanization is disabled for this project.</div>
      ) : (
        <>
          {doc.romanization.length === 0 && editing === null ? (
            <div className="small muted">No romanization letters defined yet. Add a Latin letter and associate its default IPA sound.</div>
          ) : (
            <div>
              <div className="row small muted bold" style={{ padding: '6px 8px', background: 'var(--surface-low)', borderRadius: 6 }}>
                <span style={{ width: 120 }}>Latin letter</span>
                <span className="grow">IPA sound (default)</span>
              </div>
              {doc.romanization.map((m) =>
                editing === m.id ? (
                  <div key={m.id}>{editRow}</div>
                ) : (
                  <div key={m.id} className="row" style={{ padding: '2px 8px', borderBottom: '1px solid rgba(68,71,79,.4)' }} onClick={() => start(m.id, m.latin, m.phoneme)}>
                    <span style={{ width: 120 }} className="bold">{m.latin}</span>
                    <span className="grow">{m.phoneme}</span>
                    <IconButton icon="edit" size={16} title="Edit" onClick={(e) => { e.stopPropagation(); start(m.id, m.latin, m.phoneme); }} />
                    <IconButton icon="delete_outline" danger size={16} title="Delete" onClick={(e) => { e.stopPropagation(); run((d) => cmd.deleteRomanization(d, m.id)); }} />
                  </div>
                ),
              )}
              {editing === 'new' && editRow}
            </div>
          )}
          {editing === null && <div><TextButton icon="add" onClick={() => start('new')}>Add letter</TextButton></div>}
        </>
      )}
    </div>
  );
}

