import { useSyncExternalStore } from 'react';
import glossary from '../data/glossary.json';
import { Icon, IconButton } from './common';

interface Entry {
  term: string;
  category: string;
  definition: string;
  seeAlso: string[];
  example: string;
}

const ENTRIES = glossary as Entry[];
const CATEGORIES = ['Phonology', 'Morphology', 'Syntax', 'Semantics', 'Typology'];

let state = { open: false, query: '', category: null as string | null, expanded: null as string | null };
const listeners = new Set<() => void>();
function set(patch: Partial<typeof state>) {
  state = { ...state, ...patch };
  listeners.forEach((l) => l());
}
function useState_() {
  return useSyncExternalStore((l) => { listeners.add(l); return () => listeners.delete(l); }, () => state);
}

export function useGlossary() {
  const s = useState_();
  return {
    open: s.open,
    toggle: () => (state.open ? set({ open: false }) : set({ open: true, category: null })),
    openCategory: (category: string) => set({ open: true, category }),
  };
}

function chipColors(category: string): React.CSSProperties {
  switch (category) {
    case 'Phonology': return { background: 'var(--primary-container)', color: 'var(--on-primary-container)' };
    case 'Morphology': return { background: 'var(--secondary-container)', color: 'var(--on-secondary-container)' };
    case 'Syntax': return { background: 'var(--tertiary-container)', color: 'var(--on-tertiary-container)' };
    case 'Semantics': return { background: 'var(--error-container)', color: 'var(--on-error-container)' };
    default: return { background: 'var(--surface-highest)' };
  }
}

export function GlossaryDrawer() {
  const s = useState_();
  const q = s.query.toLowerCase();
  const filtered = ENTRIES.filter(
    (e) =>
      (!q || e.term.toLowerCase().includes(q) || e.definition.toLowerCase().includes(q) || e.example.toLowerCase().includes(q)) &&
      (!s.category || e.category === s.category),
  );
  return (
    <div className="col fill" style={{ background: 'var(--surface-container)', gap: 0 }} data-testid="glossary">
      <div className="row between pad" style={{ paddingBottom: 8 }}>
        <span className="h-section">Glossary</span>
        <IconButton icon="close" title="Close glossary" onClick={() => set({ open: false })} />
      </div>
      <div style={{ padding: '0 12px 8px' }}>
        <input type="search" placeholder="Search terms..." aria-label="Search terms" value={s.query} onChange={(e) => set({ query: e.target.value })} />
      </div>
      <div className="row wrap" style={{ padding: '0 12px 8px', gap: 4 }}>
        {CATEGORIES.map((c) => (
          <button key={c} type="button" className={`chip ${s.category === c ? 'sel' : ''}`} onClick={() => set({ category: s.category === c ? null : c })}>{c}</button>
        ))}
      </div>
      <div className="grow scroll">
        {filtered.length === 0 && <div className="center faint">No matching terms</div>}
        {filtered.map((e) => {
          const expanded = s.expanded === e.term;
          return (
            <div key={e.term} className="hr">
              <button type="button" className="list-row" onClick={() => set({ expanded: expanded ? null : e.term })} aria-expanded={expanded}>
                <Icon name={expanded ? 'expand_more' : 'chevron_right'} size={16} />
                <span className="grow bold">{e.term}</span>
                <span className="badge" style={chipColors(e.category)}>{e.category}</span>
              </button>
              {expanded && (
                <div className="col" style={{ padding: '0 14px 12px 36px', fontSize: 12 }}>
                  <div>{e.definition}</div>
                  {e.example && <div className="italic muted">{e.example}</div>}
                  {e.seeAlso.length > 0 && (
                    <div className="row wrap" style={{ gap: 4 }}>
                      <span className="faint small">See also:</span>
                      {e.seeAlso.map((r) => (
                        <button key={r} type="button" className="chip" onClick={() => set({ query: r, category: null, expanded: r })}>{r}</button>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
