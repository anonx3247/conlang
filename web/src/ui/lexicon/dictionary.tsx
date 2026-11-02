import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { ankiEntries, buildApkg } from '../../core/anki';
import * as cmd from '../../core/commands';
import { formatAbbr } from '../../core/notation';
import type { Id, PartOfSpeech } from '../../core/types';
import { canUseFiles, mutate, saveBytesAs, snack, uiGet, uiSet, useEngine } from '../../storage/store';
import { Check, Chip, EmptyState, FilledButton, Icon, IconButton, OutlinedButton, ResizableDivider, SelectField, TextButton, TextField, useWidth, ViolationText } from '../common';
import { IpaField } from '../ipa';
import { SyllableRange } from '../phonology/soundRules';
import { GlossTagInput, ParentSelector, sharedTagWarning, WordKindSwitch } from '../words';
import { WordDetailPanel } from './wordDetail';

export function DictionaryPage() {
  const engine = useEngine();
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const createMeaning = params.get('create') === 'true' ? (params.get('meaning') ?? '') : null;
  const [selected, setSelectedState] = useState<Id | null>(uiGet('dictionary.selected', null));
  const [creating, setCreating] = useState(createMeaning !== null);
  const [selectionMode, setSelectionMode] = useState(false);
  const [forExport, setForExport] = useState<Set<Id>>(new Set());
  const [width, drag] = useWidth(280, 200, 400);

  const setSelected = (id: Id | null) => {
    uiSet('dictionary.selected', id);
    setSelectedState(id);
  };
  useEffect(() => {
    if (createMeaning !== null) {
      setCreating(true);
      setSelected(null);
    }
  }, [createMeaning]);

  const doneCreating = (newId?: Id) => {
    navigate('/lexicon/dictionary', { replace: true });
    setCreating(false);
    if (newId) setSelected(newId);
  };

  const exportAnki = async () => {
    if (!forExport.size) {
      snack('Select at least one word to export.');
      return;
    }
    try {
      const bytes = await buildApkg('Conlang Workbench', ankiEntries(engine, [...forExport]), () => '/sql-wasm.wasm');
      const name = `conlang_export_${Date.now()}.apkg`;
      if (await saveBytesAs(name, bytes, 'Anki Package', '.apkg')) {
        snack(`Exported ${forExport.size} words to ${canUseFiles ? 'your chosen file' : name}`);
        setSelectionMode(false);
        setForExport(new Set());
      }
    } catch (e) {
      snack(`Export failed: ${(e as Error).message}`);
    }
  };

  let right: React.ReactNode;
  if (creating) {
    right = <WordCreationForm key={createMeaning ?? 'new'} prefillMeaning={createMeaning ?? undefined} onDone={doneCreating} />;
  } else if (selected !== null && engine.lexeme(selected)) {
    right = <WordDetailPanel key={selected} lexemeId={selected} onDeleted={() => setSelected(null)} onNavigate={setSelected} />;
  } else {
    right = <EmptyState icon="menu_book" title={engine.doc.lexemes.length ? 'Select a word' : 'No words yet'} body={engine.doc.lexemes.length ? 'Pick a word from the list to see its details.' : 'Start building your vocabulary. Click "New word" to add your first word.'} />;
  }

  return (
    <div className="row top fill" style={{ gap: 0 }}>
      <div style={{ width, flex: 'none', height: '100%', background: 'var(--surface-low)' }}>
        <WordList
          selected={selected}
          onSelect={(id) => { setCreating(false); setSelected(id); }}
          onNew={() => { setCreating(true); setSelected(null); }}
          selectionMode={selectionMode}
          setSelectionMode={(v) => { setSelectionMode(v); setForExport(new Set()); }}
          forExport={forExport}
          setForExport={setForExport}
          onExport={() => void exportAnki()}
        />
      </div>
      <ResizableDivider onDrag={drag} />
      <div className="grow fill scroll">{right}</div>
    </div>
  );
}

function posLabel(pos: PartOfSpeech | undefined) {
  return pos ? formatAbbr(pos.abbr) : '';
}

function WordList(p: {
  selected: Id | null;
  onSelect: (id: Id) => void;
  onNew: () => void;
  selectionMode: boolean;
  setSelectionMode: (v: boolean) => void;
  forExport: Set<Id>;
  setForExport: (s: Set<Id>) => void;
  onExport: () => void;
}) {
  const engine = useEngine();
  const [query, setQueryState] = useState<string>(uiGet('dictionary.query', ''));
  const [posFilter, setPosFilterState] = useState<Set<Id>>(uiGet('dictionary.pos', new Set<Id>()));
  const [table, setTable] = useState(false);
  const [showAutomatic, setShowAutomaticState] = useState<boolean>(uiGet('dictionary.automatic', false));
  const setShowAutomatic = (v: boolean) => { uiSet('dictionary.automatic', v); setShowAutomaticState(v); };
  const hasAutomatic = engine.doc.rules.some((r) => r.autoApply && r.active);
  const [sort, setSort] = useState<{ col: number; asc: boolean }>({ col: 0, asc: true });
  const setQuery = (v: string) => { uiSet('dictionary.query', v); setQueryState(v); };
  const setPosFilter = (v: Set<Id>) => { uiSet('dictionary.pos', v); setPosFilterState(v); };
  const [particlesOnly, setParticlesOnlyState] = useState<boolean>(uiGet('dictionary.particles', false));
  const setParticlesOnly = (v: boolean) => { uiSet('dictionary.particles', v); setParticlesOnlyState(v); };
  const entries = engine.wordList(query, posFilter, showAutomatic, particlesOnly);
  const ids = entries.map((e) => e.lexeme.id);
  const allSelected = ids.length > 0 && ids.every((id) => p.forExport.has(id));
  const posList = engine.doc.partsOfSpeech.slice().sort((a, b) => a.name.localeCompare(b.name));

  const sorted = useMemo(() => {
    const val = (id: Id) => {
      const l = engine.lexeme(id)!;
      const f = engine.form(id);
      return [f.label, f.phonetic, engine.pos(l.posId)?.name ?? '', engine.glossOf(l)][sort.col];
    };
    return ids.slice().sort((a, b) => val(a).localeCompare(val(b)) * (sort.asc ? 1 : -1));
  }, [ids.join(','), engine, sort]);

  const header = (label: string, col: number) => (
    <th onClick={() => setSort({ col, asc: sort.col === col ? !sort.asc : true })} aria-sort={sort.col === col ? (sort.asc ? 'ascending' : 'descending') : 'none'}>
      {label} {sort.col === col && <Icon name={sort.asc ? 'arrow_upward' : 'arrow_downward'} size={11} />}
    </th>
  );
  const toggle = (id: Id) => {
    const next = new Set(p.forExport);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    p.setForExport(next);
  };

  return (
    <div className="col fill" style={{ gap: 0 }}>
      <div style={{ padding: '12px 12px 6px' }}><FilledButton icon="add" style={{ width: '100%' }} onClick={p.onNew}>New word</FilledButton></div>
      <div style={{ padding: '0 12px 6px' }}>
        <input type="search" placeholder="Search..." aria-label="Search words" value={query} onChange={(e) => setQuery(e.target.value)} />
      </div>
      {posList.length > 0 && (
        <div className="row" style={{ padding: '0 12px 6px', gap: 4, overflowX: 'auto', flex: 'none' }}>
          <Chip selected={posFilter.size === 0 && !particlesOnly} onClick={() => { setPosFilter(new Set()); setParticlesOnly(false); }}>All</Chip>
          <Chip selected={particlesOnly} title="Gloss-only words" onClick={() => setParticlesOnly(!particlesOnly)}>Particles</Chip>
          {posList.map((pos) => (
            <Chip key={pos.id} selected={posFilter.has(pos.id)} onClick={() => { const n = new Set(posFilter); if (n.has(pos.id)) n.delete(pos.id); else n.add(pos.id); setPosFilter(n); }}>{pos.name}</Chip>
          ))}
        </div>
      )}
      {hasAutomatic && (
        <div className="row" style={{ padding: '0 12px 6px' }}>
          <Chip selected={showAutomatic} title="Words generated by automatic rules. They always appear in search and on each word's page." onClick={() => setShowAutomatic(!showAutomatic)}>Show automatic words</Chip>
        </div>
      )}
      <div className="row" style={{ padding: '0 12px 6px', gap: 4 }}>
        {p.selectionMode ? (
          <input type="checkbox" title={allSelected ? 'Deselect all' : 'Select all'} aria-label={allSelected ? 'Deselect all' : 'Select all'} checked={allSelected} ref={(el) => { if (el) el.indeterminate = !allSelected && ids.some((id) => p.forExport.has(id)); }} onChange={() => p.setForExport(allSelected ? new Set() : new Set(ids))} />
        ) : (
          <OutlinedButton icon="file_download" disabled={!ids.length} style={{ minHeight: 26, padding: '0 8px', fontSize: 11 }} onClick={() => p.setSelectionMode(true)}>Export to Anki</OutlinedButton>
        )}
        <span className="grow tiny faint" style={{ textAlign: 'right' }} data-testid="word-count">{ids.length} word{ids.length === 1 ? '' : 's'}</span>
        <IconButton icon="list" size={18} title="List view" selected={!table} onClick={() => setTable(false)} />
        <IconButton icon="table_rows" size={18} title="Table view" selected={table} onClick={() => setTable(true)} />
      </div>
      <div className="grow scroll" data-testid="word-list">
        {ids.length === 0 ? (
          <div className="center small faint">{query ? `No words match "${query}"` : 'No words yet. Click "New word" to add your first word.'}</div>
        ) : table ? (
          <table className="data">
            <thead><tr>{p.selectionMode && <th />}{header('Word', 0)}{header('IPA', 1)}{header('POS', 2)}{header('Meaning', 3)}</tr></thead>
            <tbody>
              {sorted.map((id) => {
                const l = engine.lexeme(id)!;
                const f = engine.form(id);
                return (
                  <tr key={id} className={(p.selectionMode ? p.forExport.has(id) : p.selected === id) ? 'sel' : ''} onClick={() => (p.selectionMode ? toggle(id) : p.onSelect(id))}>
                    {p.selectionMode && <td><input type="checkbox" readOnly checked={p.forExport.has(id)} aria-label="Select for export" /></td>}
                    <td className={f.status === 'broken' ? 'err' : f.ipaOverridden ? 'overridden' : ''}>{f.label}</td>
                    <td className="ipa">{f.status === 'ok' ? `[${f.phonetic}]` : ''}</td>
                    <td>{engine.pos(l.posId)?.name}</td>
                    <td>{engine.glossOf(l)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        ) : (
          entries.map(({ lexeme: l, derivedMatchCount, automatic }) => {
            const f = engine.form(l.id);
            const label = posLabel(engine.pos(l.posId));
            const sel = p.selected === l.id;
            return (
              <div key={l.id} className={`list-row ${sel ? 'sel' : ''}`} style={{ opacity: l.rootOnly ? 0.45 : 1 }} onClick={() => p.onSelect(l.id)} data-testid={`word-${f.label}`}>
                {p.selectionMode && <input type="checkbox" aria-label="Select for export" checked={p.forExport.has(l.id)} onClick={(e) => e.stopPropagation()} onChange={() => toggle(l.id)} />}
                <div className="grow" style={{ minWidth: 0 }}>
                  <div className="row" style={{ gap: 4 }}>
                    <span className={`grow ellipsis ${sel ? 'bold' : ''} ${f.status === 'broken' ? 'err' : f.ipaOverridden ? 'overridden' : ''}`} title={f.reason}>{f.label}{label ? ` (${label})` : ''}</span>
                    {automatic && <span className="badge tertiary" title="Generated by a rule, not stored">auto</span>}
                    {derivedMatchCount > 0 && <span className="badge">{derivedMatchCount} derived match{derivedMatchCount === 1 ? '' : 'es'}</span>}
                  </div>
                  {f.status === 'ok' && <div className="small ipa ellipsis">[<ViolationText text={f.phonetic} violations={engine.wordViolations(l.id)} />]</div>}
                  {engine.glossOf(l) && <div className="small muted ellipsis" data-testid="word-gloss">{engine.glossOf(l)}</div>}
                </div>
              </div>
            );
          })
        )}
      </div>
      {p.selectionMode && (
        <div className="col" style={{ padding: 8, borderTop: '1px solid var(--outline-variant)', gap: 4 }}>
          <FilledButton icon="download" disabled={!p.forExport.size} onClick={p.onExport}>Export {p.forExport.size} to Anki</FilledButton>
          <TextButton onClick={() => p.setSelectionMode(false)}>Cancel selection</TextButton>
        </div>
      )}
    </div>
  );
}

/** Keeps romanization and IPA in sync until the user hand-edits the IPA. */
export function useWordFields(initial: { rom: string; ipa: string; manual: boolean }) {
  const engine = useEngine();
  const [rom, setRomState] = useState(initial.rom);
  const [ipa, setIpaState] = useState(initial.ipa);
  const [manual, setManual] = useState(initial.manual);
  return {
    rom,
    ipa,
    manual,
    setRom: (v: string) => {
      setRomState(v);
      if (!manual) setIpaState(engine.deromanize(v));
    },
    setIpa: (v: string) => {
      setIpaState(v);
      setManual(v !== engine.deromanize(rom));
    },
    setBoth: (r: string, i: string) => {
      setRomState(r);
      setIpaState(i);
      setManual(false);
    },
  };
}

export function WordFormFields({ fields, ipaError }: { fields: ReturnType<typeof useWordFields>; ipaError?: string | null }) {
  const engine = useEngine();
  const phonetic = fields.ipa ? engine.phonetic(fields.ipa) : '';
  const help = fields.ipa && phonetic !== fields.ipa ? `[${phonetic}]` : undefined;
  if (!engine.romanizationOn) return <IpaField label="IPA *" placeholder="e.g. /kala/" value={fields.ipa} onChange={fields.setIpa} error={ipaError} help={help} />;
  return (
    <>
      <TextField autoFocus label="Romanization *" placeholder="e.g. kala" help="IPA is auto-derived from this" value={fields.rom} onChange={fields.setRom} />
      <IpaField label={fields.manual ? 'IPA (manual override)' : 'IPA (auto-derived — edit to override)'} placeholder="e.g. /kala/" value={fields.ipa} onChange={fields.setIpa} error={ipaError} help={help} />
    </>
  );
}

export function IntrinsicFields({ posId, values, errors, onChange }: { posId: Id | null; values: Record<string, Id>; errors: Record<string, string>; onChange: (dimId: Id, level: Id | null) => void }) {
  const engine = useEngine();
  if (posId === null) return null;
  const pos = engine.pos(posId);
  return (
    <>
      {engine.dimensionsForPos(posId).filter((d) => d.intrinsic).map((dim) => (
        <SelectField
          key={dim.id}
          label={dim.name}
          value={values[dim.id] ?? null}
          placeholder=""
          help={`Intrinsic — fixed for every ${pos?.name}`}
          error={errors[dim.id]}
          options={dim.levels.map((l) => ({ value: l.id, label: `${l.name} (${formatAbbr(l.abbr)})` }))}
          onChange={(v) => onChange(dim.id, v)}
        />
      ))}
    </>
  );
}

function WordCreationForm({ prefillMeaning, onDone }: { prefillMeaning?: string; onDone: (id?: Id) => void }) {
  const engine = useEngine();
  const fields = useWordFields({ rom: '', ipa: '', manual: false });
  const [meaning, setMeaning] = useState(prefillMeaning ?? '');
  const [particle, setParticle] = useState(false);
  const [tag, setTag] = useState('');
  const [tagError, setTagError] = useState<string | null>(null);
  const [posId, setPosId] = useState<Id | null>(null);
  const [levels, setLevels] = useState<Record<string, Id>>({});
  const [rootOnly, setRootOnly] = useState(false);
  const [parents, setParents] = useState<Id[]>([]);
  const [ipaError, setIpaError] = useState<string | null>(null);
  const [posError, setPosError] = useState<string | null>(null);
  const [intrinsicErrors, setIntrinsicErrors] = useState<Record<string, string>>({});

  const save = () => {
    setIpaError(null);
    setPosError(null);
    setTagError(null);
    const ipa = fields.ipa.trim();
    if (!ipa) {
      setIpaError('IPA is required');
      return;
    }
    if (particle && !tag.trim()) {
      setTagError('A gloss tag is required');
      return;
    }
    if (!rootOnly && !particle && posId === null) {
      setPosError('Part of speech is required');
      return;
    }
    const missing: Record<string, string> = {};
    if (posId !== null && !particle) {
      for (const d of engine.dimensionsForPos(posId).filter((x) => x.intrinsic)) {
        if (levels[d.id] === undefined) missing[d.id] = `Required — every ${engine.pos(posId)?.name} must have a fixed ${d.name}.`;
      }
    }
    setIntrinsicErrors(missing);
    if (Object.keys(missing).length) return;
    try {
      const id = mutate((d) => cmd.addWord(d, { phonemic: ipa, roman: fields.rom, meaning: particle ? null : meaning, glossTag: particle ? tag : null, posId, rootOnly, intrinsicLevels: levels, parentIds: parents }));
      onDone(id);
    } catch (e) {
      if (e instanceof cmd.CommandError) snack(`Failed to save word: ${e.message}`);
      else throw e;
    }
  };

  return (
    <div className="row top fill" style={{ gap: 0 }}>
      <div className="col scroll fill pad-lg" style={{ flex: 6, gap: 14 }}>
        <h1 className="h-large">New word</h1>
        <WordFormFields fields={fields} ipaError={ipaError} />
        <WordKindSwitch particle={particle} onChange={setParticle} />
        {particle ? (
          <GlossTagInput value={tag} onChange={(v) => { setTag(v); setTagError(null); }} error={tagError} warning={sharedTagWarning(engine, tag)} />
        ) : (
          <TextField label="Meaning" placeholder="e.g. water, to run" value={meaning} onChange={setMeaning} />
        )}
        {engine.doc.partsOfSpeech.length > 0 && (
          <SelectField label={particle ? 'Part of speech' : 'Part of speech *'} value={posId} placeholder={particle ? 'Particle' : '— none —'} error={posError} options={engine.doc.partsOfSpeech.map((p) => ({ value: p.id, label: p.name }))} onChange={(v) => { setPosId(v); setPosError(null); setLevels({}); setIntrinsicErrors({}); }} />
        )}
        <IntrinsicFields posId={posId} values={levels} errors={intrinsicErrors} onChange={(dim, level) => { const next = { ...levels }; if (level === null) delete next[dim]; else next[dim] = level; setLevels(next); setIntrinsicErrors({ ...intrinsicErrors, [dim]: '' }); }} />
        <Check checked={rootOnly} onChange={setRootOnly}>
          <div>This root only exists through derivations</div>
          <div className="help">The word stays in the dictionary list muted, and is still findable via search</div>
        </Check>
        <div className="small bold">Parents (etymology)</div>
        <ParentSelector selected={parents} onChange={setParents} />
        <div className="row">
          <FilledButton onClick={save}>New word</FilledButton>
          <TextButton onClick={() => onDone()}>Cancel</TextButton>
        </div>
      </div>
      <div className="vr fill" />
      <div className="fill" style={{ flex: 4, minWidth: 0 }}>
        <InspirationPanel onPick={(raw) => fields.setBoth(engine.romanize(raw), raw)} />
      </div>
    </div>
  );
}

function InspirationPanel({ onPick }: { onPick: (raw: string) => void }) {
  const engine = useEngine();
  const [min, setMin] = useState(1);
  const [max, setMax] = useState(3);
  const [seed, setSeed] = useState(0);
  const words = useMemo(() => {
    void seed;
    return engine.generate(12, min, max);
  }, [engine, min, max, seed]);
  return (
    <div className="col fill" style={{ gap: 0 }}>
      <div className="row" style={{ padding: '16px 16px 8px' }}>
        <div className="grow">
          <div className="h-section">Inspiration</div>
          <div className="small faint">Tap a word to use it.</div>
        </div>
        <IconButton icon="refresh" title="Regenerate" onClick={() => setSeed((s) => s + 1)} />
      </div>
      <div style={{ padding: '0 16px 8px' }}><SyllableRange min={min} max={max} onChange={(a, b) => { setMin(a); setMax(b); }} /></div>
      <div className="grow scroll" data-testid="inspiration">
        {words.length === 0 && <div className="center small faint">Define templates and add phonemes to see word suggestions.</div>}
        {words.map((raw, i) => {
          const phonetic = engine.phonetic(raw);
          const label = engine.labelFor(raw);
          const violations = engine.violationsOf(phonetic);
          return (
            <button key={i} type="button" className="list-row" onClick={() => onPick(raw)}>
              {label !== phonetic ? (
                <>
                  <span className="bold">{label}</span>
                  <span className="ipa small">[<ViolationText text={phonetic} violations={violations} />]</span>
                </>
              ) : (
                <ViolationText text={phonetic} violations={violations} />
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}


