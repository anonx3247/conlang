import { useState } from 'react';
import * as cmd from '../../core/commands';
import { formatAbbrUpper } from '../../core/notation';
import type { Id } from '../../core/types';
import { run, uiGet, uiSet, useEngine } from '../../storage/store';
import { Chip, EmptyState, IconButton, Select, TextButton } from '../common';
import { RulesPage } from '../rules/rulesPage';
import { ParadigmTable } from './paradigm';

export function InflectionsPage() {
  const engine = useEngine();
  const doc = engine.doc;
  const [posId, setPosIdState] = useState<Id | null>(uiGet('inflections.pos', null));
  const [restrict, setRestrict] = useState<Id[]>([]);
  const [showCoverage, setShowCoverage] = useState(false);
  const posOptions = doc.partsOfSpeech.slice().sort((a, b) => a.name.localeCompare(b.name)).map((p) => ({ value: p.id, label: p.name }));
  const dims = posId !== null ? engine.dimensionsForPos(posId) : [];
  const hasIntrinsic = dims.some((d) => d.intrinsic);
  const words = posId !== null ? engine.wordsForPos(posId) : [];
  const remembered = posId !== null ? doc.settings.lastSelectedWord[posId] : undefined;
  const selectedWord = remembered !== undefined && engine.lexeme(remembered) ? remembered : null;

  const setPosId = (v: Id | null) => {
    uiSet('inflections.pos', v);
    setPosIdState(v);
    setRestrict([]);
  };
  const axes = posId !== null ? engine.axesFor(posId) : null;

  return (
    <div className="col fill" style={{ gap: 0 }}>
      {doc.settings.backfillBanners.map((b) => (
        <div key={b.dimId} className="banner">
          <span className="grow small">Review {b.count} words with auto-assigned default level for {b.dimName}.</span>
          <TextButton onClick={() => run((d) => cmd.dismissBackfillBanner(d, b.dimId))}>Review</TextButton>
          <TextButton onClick={() => run((d) => cmd.dismissBackfillBanner(d, b.dimId))}>Dismiss</TextButton>
        </div>
      ))}
      <div className="row wrap" style={{ padding: '10px 16px' }}>
        <span>POS:</span>
        <Select inline ariaLabel="POS" value={posId} placeholder="Select a POS" options={posOptions} onChange={setPosId} />
        {posId !== null && (hasIntrinsic ? (
          <div className="row wrap grow" style={{ gap: 6 }}>
            <span className="small muted">Words:</span>
            {words.length === 0 && <span className="small faint">No words for this POS yet.</span>}
            {words.map((l) => (
              <Chip key={l.id} selected={restrict.includes(l.id)} onClick={() => setRestrict(restrict.includes(l.id) ? restrict.filter((x) => x !== l.id) : [...restrict, l.id])}>{engine.form(l.id).label}</Chip>
            ))}
          </div>
        ) : (
          <div className="grow" style={{ maxWidth: 320 }}>
            <Select ariaLabel="Word" value={selectedWord ?? 0} options={[{ value: 0, label: '(template)' }, ...words.map((l) => ({ value: l.id, label: engine.form(l.id).label }))]} onChange={(v) => { if (v) run((d) => cmd.setLastSelectedWord(d, posId, Number(v))); else run((d) => { delete d.settings.lastSelectedWord[posId]; }); }} />
          </div>
        ))}
        {posId !== null && <IconButton icon="grid_view" title="Coverage" selected={showCoverage} onClick={() => setShowCoverage((s) => !s)} />}
      </div>
      {axes && axes.all.length >= 2 && (
        <div className="row small" style={{ padding: '0 16px 8px' }} data-testid="axis-config">
          <span>Rows:</span>
          <Select inline ariaLabel="Rows" value={axes.rows?.id ?? null} options={axes.all.map((d) => ({ value: d.id, label: d.name }))} onChange={(v) => { if (v !== null) run((d) => cmd.setParadigmAxes(d, posId!, v, axes.cols?.id === v ? null : (axes.cols?.id ?? null))); }} />
          <span>Columns:</span>
          <Select inline ariaLabel="Columns" value={axes.cols?.id ?? null} options={axes.all.filter((d) => d.id !== axes.rows?.id).map((d) => ({ value: d.id, label: d.name }))} onChange={(v) => { if (v !== null) run((d) => cmd.setParadigmAxes(d, posId!, axes.rows?.id ?? null, v)); }} />
        </div>
      )}
      <div className="row top" style={{ flex: 55, minHeight: 0, gap: 0 }}>
        <div className="grow fill scroll" style={{ padding: '0 16px 12px' }}>
          {posId === null ? (
            <EmptyState icon="table_chart" title="Select a POS to view its paradigm." />
          ) : hasIntrinsic ? (
            <ParadigmTable lexemeId={null} posId={posId} mode="ruleEditor" restrictTo={restrict} />
          ) : (
            <ParadigmTable lexemeId={selectedWord} posId={posId} mode="ruleEditor" />
          )}
        </div>
        {posId !== null && showCoverage && <CoveragePanel posId={posId} />}
      </div>
      <div className="hr" />
      <div style={{ flex: 45, minHeight: 0 }}><RulesPage kind="inflectional" scope={posId} /></div>
    </div>
  );
}

function CoveragePanel({ posId }: { posId: Id }) {
  const engine = useEngine();
  const matrix = engine.coverage(posId);
  return (
    <div className="col fill" style={{ width: 240, flex: 'none', gap: 0, borderLeft: '1px solid var(--outline-variant)' }} data-testid="coverage">
      <div className="tiny bold muted" style={{ padding: '10px 12px', letterSpacing: 1 }}>COVERAGE</div>
      {matrix.axes.length === 0 ? (
        <div className="small faint" style={{ padding: 12 }}>No inflectional rules define axes for this POS yet.</div>
      ) : (
        <div className="grow scroll">
          {matrix.cells.map((c) => (
            <div key={c.key} className="row small" style={{ padding: '2px 12px' }}>
              <span className="dot" style={{ background: c.covered ? 'var(--green)' : 'var(--error)' }} title={c.covered ? 'Covered' : 'Not covered'} />
              <span className="muted">
                {matrix.axes.map((id) => {
                  const d = engine.doc.dimensions.find((x) => x.id === id)!;
                  const l = d.levels.find((x) => x.id === c.features[id]);
                  return `${d.name}=${formatAbbrUpper(l?.abbr) || l?.name || '?'}`;
                }).join(', ')}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
