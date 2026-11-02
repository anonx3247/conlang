// Paradigm tables. Cells come entirely from engine.paradigm(); this file only
// lays them out and decides what a click opens.

import { useState } from 'react';
import * as cmd from '../../core/commands';
import type { ParadigmCell } from '../../core/engine';
import { formatAbbrUpper } from '../../core/notation';
import { cartesian, featureKey, sortedLevels, type FeatureSet } from '../../core/paradigm';
import type { Dimension, Id, Lexeme } from '../../core/types';
import { run, useEngine } from '../../storage/store';
import { Dialog, FilledButton, Icon, openDialog, Select, TextButton, TextField, ViolationText } from '../common';
import { openRuleEditor } from '../rules/ruleEditor';

export type ClickMode = 'ruleEditor' | 'wordOverride';

function CellView({ lexemeId, posId, features, mode }: { lexemeId: Id | null; posId: Id; features: FeatureSet; mode: ClickMode }) {
  const engine = useEngine();
  const cell: ParadigmCell | undefined = lexemeId === null ? undefined : engine.paradigm(lexemeId).cells.get(featureKey(features));
  const showRoman = (roman: string, phonemic: string) => engine.romanizationOn && !!roman && (engine.doc.romanization.length > 0 || roman !== phonemic);

  const onClick = () => {
    if (mode === 'wordOverride' && lexemeId !== null) {
      void openDialog<void>((close) => <CellOverrideDialog lexemeId={lexemeId} posId={posId} features={features} cell={cell} close={() => close()} />);
      return;
    }
    if (cell?.kind === 'unmarked') {
      void openRuleEditor({ kind: 'inflectional', marker: cell.marker });
      return;
    }
    const topRuleId = cell?.kind === 'filled' ? cell.rules[0]?.id : undefined;
    const existing = topRuleId !== undefined ? engine.rule(topRuleId) : undefined;
    void openRuleEditor(existing ? { kind: 'inflectional', existing } : { kind: 'inflectional', prefillBindings: features, prefillPosIds: [posId] });
  };

  let body: React.ReactNode;
  let title: string | undefined;
  if (!cell || cell.kind === 'uncovered') {
    title = cell?.reason;
    body = (
      <>
        <div className="cell faint">—</div>
        <Icon name="add_circle_outline" className="cell-add" />
      </>
    );
  } else if (cell.kind === 'ambiguous') {
    title = `Rules tie here: ${cell.rules.map((r) => r.name).join(', ')}. Give one a more specific binding.`;
    body = <div className="cell"><Icon name="error_outline" size={16} className="err" /></div>;
  } else {
    const violations = lexemeId === null ? [] : engine.cellViolations(lexemeId, cell);
    const description = cell.kind === 'filled' ? cell.rules.map((r) => engine.rule(r.id)?.description).filter(Boolean).join('\n') : '';
    title =
      cell.kind === 'filled' ? `${cell.rules.map((r) => r.name).join(' + ') || 'Base'}${cell.partial ? ' (some features have no rule)' : ''}${description ? `\n${description}` : ''}`
      : cell.kind === 'unmarked' ? `Unmarked: ${cell.marker.name}`
      : `Manual override${cell.notes ? `: ${cell.notes}` : ''}`;
    const klass = cell.kind === 'override' ? 'override' : cell.kind === 'unmarked' ? 'unmarked' : '';
    body = (
      <>
        <div className={`cell ${klass}`}>
          {showRoman(cell.roman, cell.phonemic) && <span className="rom">{cell.roman}</span>}
          <span className="ph">[<ViolationText text={cell.phonetic} violations={violations} />]</span>
        </div>
        {cell.kind === 'unmarked' && <span className="cell-corner">∅</span>}
        {cell.kind === 'override' && <Icon name="warning_amber" className="cell-corner amber" />}
      </>
    );
  }
  const featureLabel = engine.levelAbbrs(features).join(' ');
  return <td onClick={onClick} title={title} data-testid={`cell-${featureKey(features)}`} aria-label={featureLabel} role="button" tabIndex={0} onKeyDown={(e) => { if (e.key === 'Enter') onClick(); }}>{body}</td>;
}

function Table2D({ lexemeId, posId, rowDim, colDim, slice, mode }: { lexemeId: Id | null; posId: Id; rowDim: Dimension; colDim: Dimension; slice: FeatureSet; mode: ClickMode }) {
  return (
    <div className="scroll">
      <table className="paradigm" data-testid="paradigm-table">
        <thead>
          <tr>
            <th />
            {sortedLevels(colDim).map((c) => <th key={c.id} title={c.name}>{formatAbbrUpper(c.abbr)}</th>)}
          </tr>
        </thead>
        <tbody>
          {sortedLevels(rowDim).map((r) => (
            <tr key={r.id}>
              <th title={r.name}>{formatAbbrUpper(r.abbr)}</th>
              {sortedLevels(colDim).map((c) => (
                <CellView key={c.id} lexemeId={lexemeId} posId={posId} mode={mode} features={{ ...slice, [rowDim.id]: r.id, [colDim.id]: c.id }} />
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Table1D({ lexemeId, posId, dim, mode }: { lexemeId: Id | null; posId: Id; dim: Dimension; mode: ClickMode }) {
  return (
    <div className="scroll">
      <table className="paradigm" data-testid="paradigm-table">
        <thead>
          <tr>{sortedLevels(dim).map((l) => <th key={l.id} title={l.name}>{formatAbbrUpper(l.abbr)}</th>)}</tr>
        </thead>
        <tbody>
          <tr>{sortedLevels(dim).map((l) => <CellView key={l.id} lexemeId={lexemeId} posId={posId} mode={mode} features={{ [dim.id]: l.id }} />)}</tr>
        </tbody>
      </table>
    </div>
  );
}

function sliceLabel(extras: Dimension[], slice: FeatureSet) {
  return extras.map((d) => formatAbbrUpper(d.levels.find((l) => l.id === slice[d.id])?.abbr) || '?').join(' · ');
}

/** Axis dimensions as rows, columns and tabs; dropdown once tabs would overflow. */
function AxisTables({ lexemeId, posId, axes, mode, stacked }: { lexemeId: Id | null; posId: Id; axes: Dimension[]; mode: ClickMode; stacked?: boolean }) {
  const engine = useEngine();
  const [active, setActive] = useState(0);
  if (axes.length === 0) return <div className="faint small">No non-intrinsic dimensions.</div>;
  if (axes.length === 1) return <Table1D lexemeId={lexemeId} posId={posId} dim={axes[0]} mode={mode} />;
  const stored = engine.axesFor(posId);
  const rowDim = axes.find((d) => d.id === stored.rows?.id) ?? axes[0];
  const colDim = axes.find((d) => d.id === stored.cols?.id && d.id !== rowDim.id) ?? axes.find((d) => d.id !== rowDim.id)!;
  const extras = axes.filter((d) => d.id !== rowDim.id && d.id !== colDim.id);
  const slices = cartesian(extras);
  if (slices.length === 1) return <Table2D lexemeId={lexemeId} posId={posId} rowDim={rowDim} colDim={colDim} slice={slices[0]} mode={mode} />;
  if (stacked) {
    return (
      <div className="col">
        {slices.map((s) => (
          <div key={featureKey(s)} className="col" style={{ gap: 4 }}>
            <div className="small muted bold">{sliceLabel(extras, s)}</div>
            <Table2D lexemeId={lexemeId} posId={posId} rowDim={rowDim} colDim={colDim} slice={s} mode={mode} />
          </div>
        ))}
      </div>
    );
  }
  const current = slices[Math.min(active, slices.length - 1)];
  return (
    <div className="col">
      {slices.length <= 6 ? (
        <div className="row wrap" style={{ gap: 0, borderBottom: '1px solid var(--outline-variant)' }} role="tablist">
          {slices.map((s, i) => (
            <button key={featureKey(s)} type="button" role="tab" aria-selected={i === active} className={`ipa-tab ${i === active ? 'sel' : ''}`} style={{ padding: '8px 12px' }} onClick={() => setActive(i)}>{sliceLabel(extras, s)}</button>
          ))}
        </div>
      ) : (
        <div className="row small">
          <span>Slice:</span>
          <Select inline ariaLabel="Slice" value={active} options={slices.map((s, i) => ({ value: i, label: sliceLabel(extras, s) }))} onChange={(v) => setActive(Number(v))} />
        </div>
      )}
      <Table2D lexemeId={lexemeId} posId={posId} rowDim={rowDim} colDim={colDim} slice={current} mode={mode} />
    </div>
  );
}

function combinationLabel(intrinsic: Dimension[], combo: FeatureSet) {
  return intrinsic.map((d) => {
    const level = d.levels.find((l) => l.id === combo[d.id]);
    return level ? `${d.name}: ${level.name}` : null;
  }).filter(Boolean).join(', ');
}

function SliceSection({ posId, label, pool, axes, mode }: { posId: Id; label: string; pool: Lexeme[]; axes: Dimension[]; mode: ClickMode }) {
  const engine = useEngine();
  const [selected, setSelected] = useState<Id | null>(null);
  const effective = pool.find((l) => l.id === selected)?.id ?? pool[0]?.id ?? null;
  const violations = effective !== null ? engine.wordViolations(effective) : [];
  const form = effective !== null ? engine.form(effective) : null;
  return (
    <div className="col" style={{ gap: 6, marginBottom: 16 }} data-testid="intrinsic-slice">
      <div className="row wrap">
        <span className="bold small">{label}</span>
        {pool.length > 0 && (
          <Select inline ariaLabel={`Word for ${label}`} value={effective} options={pool.map((l) => ({ value: l.id, label: engine.form(l.id).label }))} onChange={setSelected} />
        )}
        {form && violations.length > 0 && <span className="small">[<ViolationText text={form.phonetic} violations={violations} />]</span>}
      </div>
      {pool.length === 0 ? (
        <div className="small faint">No word with [{label}] intrinsic levels yet. Create one to view this paradigm.</div>
      ) : (
        <AxisTables lexemeId={effective} posId={posId} axes={axes} mode={mode} stacked />
      )}
    </div>
  );
}

export function ParadigmTable({ lexemeId, posId, mode, restrictTo }: { lexemeId: Id | null; posId: Id; mode: ClickMode; restrictTo?: Id[] }) {
  const engine = useEngine();
  const dims = engine.dimensionsForPos(posId);
  if (!dims.length) return <div className="center faint">This POS has no dimensions. Add dimensions to build a paradigm.</div>;

  const word = lexemeId !== null ? engine.lexeme(lexemeId) : undefined;
  if (word) {
    const p = engine.paradigm(word.id);
    if (p.reason) return <div className="small err">{p.reason}</div>;
  }
  const skipped = word?.skippedDimensionIds ?? [];
  const axes = dims.filter((d) => !d.intrinsic && !skipped.includes(d.id));
  const intrinsic = dims.filter((d) => d.intrinsic);

  if (!intrinsic.length) {
    const effective = lexemeId ?? engine.wordsForPos(posId)[0]?.id ?? null;
    return <AxisTables lexemeId={effective} posId={posId} axes={axes} mode={mode} />;
  }

  if (word) {
    const levels = engine.intrinsicLevels(word);
    const combo: FeatureSet = {};
    for (const d of intrinsic) if (levels[d.id] !== undefined) combo[d.id] = levels[d.id];
    const label = combinationLabel(intrinsic, combo);
    return (
      <div className="col" style={{ gap: 6 }}>
        {label && <div className="small bold">{label}</div>}
        <AxisTables lexemeId={word.id} posId={posId} axes={axes} mode={mode} stacked />
      </div>
    );
  }

  if (!axes.length) {
    const words = engine.wordsForPos(posId);
    if (!words.length) return <div className="center faint">No words for this POS yet.</div>;
    return (
      <div className="col">
        <div className="small faint">All dimensions are intrinsic — no paradigm axes. Base forms listed below.</div>
        {words.map((l) => <div key={l.id}>{engine.form(l.id).label}</div>)}
      </div>
    );
  }

  const grouped = engine.wordsByIntrinsicCombination(posId);
  return (
    <div className="scroll fill">
      {cartesian(intrinsic).map((combo) => {
        let pool = grouped.get(featureKey(combo)) ?? [];
        if (restrictTo?.length) {
          pool = pool.filter((l) => restrictTo.includes(l.id));
          if (!pool.length) return null;
        }
        return <SliceSection key={featureKey(combo)} posId={posId} label={combinationLabel(intrinsic, combo)} pool={pool} axes={axes} mode={mode} />;
      })}
    </div>
  );
}

function CellOverrideDialog({ lexemeId, posId, features, cell, close }: { lexemeId: Id; posId: Id; features: FeatureSet; cell: ParadigmCell | undefined; close: () => void }) {
  const engine = useEngine();
  const existing = cell?.kind === 'override' ? cell : null;
  const [rom, setRom] = useState(existing?.roman ?? '');
  const [ipa, setIpa] = useState(existing?.phonemic ?? '');
  const [ipaTouched, setIpaTouched] = useState(!!existing);
  const uncovered = !cell || cell.kind === 'uncovered';
  const rules = cell?.kind === 'filled' ? cell.rules : [];
  return (
    <Dialog
      title="Edit cell"
      onClose={close}
      actions={
        <>
          <TextButton onClick={close}>Cancel</TextButton>
          <FilledButton
            onClick={() => {
              if (ipa.trim()) run((d) => cmd.saveCellOverride(d, lexemeId, features, ipa, rom || null));
              close();
            }}
          >
            Save Override
          </FilledButton>
        </>
      }
    >
      <div className="small muted">{engine.levelAbbrs(features).join(' · ')}</div>
      {rules.length > 0 && <div className="small faint">Currently from: {rules.map((r) => engine.rule(r.id)?.description ? `${r.name} — ${engine.rule(r.id)!.description}` : r.name).join(', ')}</div>}
      <TextField autoFocus label="Romanization" value={rom} onChange={(v) => { setRom(v); if (!ipaTouched) setIpa(engine.deromanize(v)); }} />
      <TextField label="IPA" value={ipa} onChange={(v) => { setIpa(v); setIpaTouched(true); }} />
      {uncovered && <div><TextButton onClick={() => { close(); void openRuleEditor({ kind: 'inflectional', prefillBindings: features, prefillPosIds: [posId] }); }}>Create a rule for this cell</TextButton></div>}
      {existing && <div><TextButton danger onClick={() => { run((d) => cmd.clearCellOverride(d, lexemeId, features)); close(); }}>Clear override</TextButton></div>}
    </Dialog>
  );
}
