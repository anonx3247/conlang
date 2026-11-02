import { useState } from 'react';
import * as cmd from '../../core/commands';
import { formatAbbrUpper } from '../../core/notation';
import type { Id, Marker, MorphRule, RuleKind } from '../../core/types';
import { run, useEngine } from '../../storage/store';
import { confirmDialog, FilledButton, Icon, IconButton, Select, Switch } from '../common';
import { openRuleEditor } from './ruleEditor';

function confirmDelete(name: string) {
  return confirmDialog({ title: 'Delete rule?', body: `Delete "${name}"? This cannot be undone. Words derived through it keep their current forms.` });
}

function bindingSummary(engine: ReturnType<typeof useEngine>, bindings: Record<string, Id>) {
  return Object.entries(bindings)
    .map(([d, l]) => {
      const level = engine.doc.dimensions.find((x) => x.id === Number(d))?.levels.find((x) => x.id === l);
      return level ? formatAbbrUpper(level.abbr) : `lv${l}`;
    })
    .join(' · ');
}

function RuleActions({ rule }: { rule: MorphRule }) {
  return (
    <>
      <Switch label="Rule active" checked={rule.active} onChange={(v) => run((d) => cmd.setRuleActive(d, rule.id, v))} />
      <IconButton icon="edit" title="Edit rule" onClick={() => void openRuleEditor({ kind: rule.kind, existing: rule })} />
      <IconButton icon="delete_outline" danger title="Delete rule" onClick={() => void confirmDelete(rule.name).then((ok) => { if (ok) run((d) => cmd.deleteRule(d, rule.id)); })} />
    </>
  );
}

function MarkerCard({ marker }: { marker: Marker }) {
  const engine = useEngine();
  const summary = bindingSummary(engine, marker.bindings);
  return (
    <div className="card row" style={{ margin: '0 16px 6px' }}>
      <span className="badge tertiary">∅</span>
      <div className="grow">
        <div>{marker.name}</div>
        {summary && <div className="small faint">{summary}</div>}
      </div>
      <IconButton icon="edit" title="Edit marker" onClick={() => void openRuleEditor({ kind: 'inflectional', marker })} />
      <IconButton icon="delete_outline" danger title="Delete marker" onClick={() => void confirmDelete('Unmarked marker').then((ok) => { if (ok) run((d) => cmd.deleteMarker(d, marker.id)); })} />
    </div>
  );
}

function InflectionalList({ scope }: { scope: Id | null }) {
  const engine = useEngine();
  const doc = engine.doc;
  const rules = doc.rules.filter((r) => r.kind === 'inflectional').sort((a, b) => a.order - b.order);
  const posName = (id: Id) => engine.pos(id)?.name ?? `POS#${id}`;

  const groups = new Map<string, { posIds: Id[]; rules: MorphRule[] }>();
  for (const r of rules) {
    const key = r.posIds.slice().sort((a, b) => a - b).join(',');
    const g = groups.get(key) ?? { posIds: r.posIds, rules: [] };
    g.rules.push(r);
    groups.set(key, g);
  }
  const header = (ids: Id[]) => (ids.length ? ids.map(posName).sort().join(' + ') : 'Unattached');
  const tier = (g: { posIds: Id[] }) => (g.posIds.length === 0 ? 2 : g.posIds.length === 1 ? 0 : 1);
  const ordered = [...groups.values()]
    .filter((g) => scope === null || g.posIds.includes(scope))
    .sort((a, b) => tier(a) - tier(b) || header(a.posIds).localeCompare(header(b.posIds)));

  const shownMarkerPos = new Set<Id>();
  const markersFor = (id: Id) => doc.markers.filter((m) => m.posId === id);
  const orphanPos = doc.partsOfSpeech.filter((p) => markersFor(p.id).length && (scope === null || p.id === scope) && !ordered.some((g) => g.posIds.includes(p.id)));

  if (!rules.length && !doc.markers.length) {
    return (
      <div className="center">
        <Icon name="auto_fix_high" size={48} style={{ color: 'var(--on-surface-4)' }} />
        <div className="h-title muted" style={{ fontWeight: 400 }}>No inflectional rules yet.</div>
        <div className="faint">Add one to get started.</div>
      </div>
    );
  }
  return (
    <div style={{ paddingBottom: 60 }}>
      {ordered.map((g) => (
        <div key={g.posIds.join(',')}>
          <div className="tiny muted bold" style={{ padding: '12px 16px 6px', letterSpacing: 1 }}>{header(g.posIds).toUpperCase()}</div>
          {g.rules.map((r) => {
            const unknown = engine.unknownPhonemesInRule(r);
            return (
              <div key={r.id} className="card row" style={{ margin: '0 16px 6px' }} data-testid={`rule-${r.name}`}>
                <div className="grow">
                  <div>{r.name}</div>
                  {Object.keys(r.bindings).length > 0 && <div className="small faint">{bindingSummary(engine, r.bindings)}</div>}
                </div>
                {unknown.length > 0 && <span title={`Contains unknown phoneme: '${unknown[0]}'`}><Icon name="warning_amber" size={16} className="amber" /></span>}
                <RuleActions rule={r} />
              </div>
            );
          })}
          {g.posIds.flatMap((id) => {
            if (shownMarkerPos.has(id)) return [];
            shownMarkerPos.add(id);
            return markersFor(id).map((m) => <MarkerCard key={m.id} marker={m} />);
          })}
        </div>
      ))}
      {orphanPos.map((p) => (
        <div key={p.id}>
          <div className="tiny muted bold" style={{ padding: '12px 16px 6px', letterSpacing: 1 }}>{p.name.toUpperCase()}</div>
          {markersFor(p.id).map((m) => <MarkerCard key={m.id} marker={m} />)}
        </div>
      ))}
    </div>
  );
}

function DerivationalList() {
  const engine = useEngine();
  const doc = engine.doc;
  const [pos, setPos] = useState<Id | null>(null);
  const rules = doc.rules.filter((r) => r.kind === 'derivational').sort((a, b) => a.order - b.order);
  const filtered = pos === null ? rules : rules.filter((r) => r.inputPosId === pos);
  return (
    <div className="col" style={{ gap: 0 }}>
      <div className="row" style={{ padding: 12 }}>
        <span className="small muted">Filter by POS:</span>
        <Select inline ariaLabel="Filter by POS" value={pos ?? 0} options={[{ value: 0, label: 'All' }, ...doc.partsOfSpeech.map((p) => ({ value: p.id, label: p.name }))]} onChange={(v) => setPos(v ? Number(v) : null)} />
      </div>
      {filtered.length === 0 ? (
        <div className="center">
          <Icon name="auto_fix_high" size={48} style={{ color: 'var(--on-surface-4)' }} />
          <div className="h-title muted" style={{ fontWeight: 400 }}>{rules.length ? 'No rules match the selected POS.' : 'No morphological rules yet.'}</div>
          {!rules.length && <div className="faint">Add one to get started.</div>}
        </div>
      ) : (
        <div style={{ padding: '0 16px 60px' }}>
          {filtered.map((r) => {
            const i = rules.indexOf(r);
            const from = formatAbbrUpper(engine.pos(r.inputPosId)?.abbr);
            const to = formatAbbrUpper(engine.pos(r.outputPosId)?.abbr);
            return (
              <div key={r.id} className="card row" style={{ marginBottom: 6 }} data-testid={`rule-${r.name}`}>
                <div className="grow">
                  <div className="row" style={{ gap: 6 }}>{r.name}<span className={`badge ${r.autoApply ? 'tertiary' : ''}`}>{r.autoApply ? 'Automatic' : 'Case by case'}</span></div>
                  {(from || to) && <div className="small faint">{from || '?'} → {to || '?'}</div>}
                </div>
                <IconButton icon="arrow_upward" size={16} title="Move up" disabled={i === 0} onClick={() => run((d) => cmd.moveRule(d, r.id, -1))} />
                <IconButton icon="arrow_downward" size={16} title="Move down" disabled={i === rules.length - 1} onClick={() => run((d) => cmd.moveRule(d, r.id, 1))} />
                <RuleActions rule={r} />
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

export function RulesPage({ kind, scope = null }: { kind: RuleKind; scope?: Id | null }) {
  return (
    <div className="fill" style={{ position: 'relative' }}>
      <div className="scroll fill">{kind === 'inflectional' ? <InflectionalList scope={scope} /> : <DerivationalList />}</div>
      <FilledButton icon="add" style={{ position: 'absolute', right: 16, bottom: 16, height: 44, borderRadius: 14 }} onClick={() => void openRuleEditor({ kind, prefillPosIds: kind === 'inflectional' && scope ? [scope] : undefined })}>Add Rule</FilledButton>
    </div>
  );
}
