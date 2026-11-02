import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import swadesh from '../../data/swadesh_list.json';
import thesaurus from '../../data/conlangers_thesaurus.json';
import type { Lexeme } from '../../core/types';
import { uiSet, useEngine } from '../../storage/store';
import { Icon, TextButton, ViolationText } from '../common';

interface Category {
  name: string;
  subcategories?: Category[];
  concepts?: string[];
}

function useOpenWord() {
  const navigate = useNavigate();
  return (id: number) => {
    uiSet('dictionary.selected', id);
    navigate('/lexicon/dictionary');
  };
}

function useAddWord() {
  const navigate = useNavigate();
  return (concept: string) => navigate(`/lexicon/dictionary?create=true&meaning=${encodeURIComponent(concept)}`);
}

function LinkedWord({ lexeme }: { lexeme: Lexeme }) {
  const engine = useEngine();
  const open = useOpenWord();
  const f = engine.form(lexeme.id);
  return (
    <button type="button" className="primary small" style={{ textDecoration: 'underline' }} onClick={() => open(lexeme.id)}>
      <ViolationText text={f.label} violations={f.label === f.phonetic ? engine.wordViolations(lexeme.id) : engine.wordViolations(lexeme.id).map((v) => ({ ...v, position: 0, length: f.label.length }))} />
    </button>
  );
}

export function SwadeshPage() {
  const engine = useEngine();
  const add = useAddWord();
  const index = engine.meaningIndex();
  const covered = swadesh.filter((i) => index.has(i.concept.toLowerCase())).length;
  const percent = swadesh.length ? Math.round((covered / swadesh.length) * 100) : 0;
  const groups = new Map<string, typeof swadesh>();
  for (const i of swadesh) groups.set(i.category, [...(groups.get(i.category) ?? []), i]);
  return (
    <div className="col fill" style={{ gap: 0 }}>
      <div className="col" style={{ padding: 16 }} data-testid="swadesh-coverage">
        <div className="bold">{covered}/{swadesh.length} — {percent}%</div>
        <div className="progress"><div style={{ width: `${percent}%` }} /></div>
      </div>
      {engine.doc.lexemes.length === 0 ? (
        <div className="center faint">No lexicon entries yet. Use this list to guide your first vocabulary choices.</div>
      ) : (
        <div className="grow scroll" style={{ padding: '0 16px 16px' }}>
          {[...groups.entries()].map(([category, items]) => (
            <div key={category}>
              <div className="small bold muted" style={{ padding: '10px 0 4px' }}>{category}</div>
              {items.map((item) => {
                const word = index.get(item.concept.toLowerCase());
                return (
                  <div key={item.id} className="row" style={{ padding: '2px 0', minHeight: 28 }}>
                    <Icon name={word ? 'check_circle' : 'radio_button_unchecked'} size={16} style={{ color: word ? 'var(--primary)' : 'var(--on-surface-4)' }} />
                    <span className="grow">{item.concept}</span>
                    {word ? <LinkedWord lexeme={word} /> : <TextButton onClick={() => add(item.concept)}>Add word</TextButton>}
                  </div>
                );
              })}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function matches(c: Category, q: string): boolean {
  if (!q) return true;
  return c.name.toLowerCase().includes(q) || (c.concepts ?? []).some((x) => x.toLowerCase().includes(q)) || (c.subcategories ?? []).some((s) => matches(s, q));
}

function CategoryNode({ c, path, depth, q, expanded, toggle }: { c: Category; path: string; depth: number; q: string; expanded: Set<string>; toggle: (p: string) => void }) {
  const engine = useEngine();
  const add = useAddWord();
  const index = engine.meaningIndex();
  const open = !!q || expanded.has(path);
  const indent = 16 + depth * 24;
  const header = (
    <button type="button" className="row" style={{ padding: `6px 16px 6px ${indent}px`, width: '100%' }} aria-expanded={open} onClick={() => toggle(path)}>
      <Icon name={open ? 'expand_more' : 'chevron_right'} size={16} />
      <span className={depth === 0 ? 'bold' : ''}>{c.name}</span>
    </button>
  );
  if (c.subcategories?.length) {
    return (
      <div>
        {header}
        {open && c.subcategories.filter((s) => matches(s, q)).map((s) => <CategoryNode key={s.name} c={s} path={`${path}/${s.name}`} depth={depth + 1} q={q} expanded={expanded} toggle={toggle} />)}
      </div>
    );
  }
  if (!c.concepts?.length) return <div className="small" style={{ paddingLeft: indent }}>{c.name}</div>;
  return (
    <div>
      {header}
      {open &&
        c.concepts.filter((x) => !q || x.toLowerCase().includes(q) || c.name.toLowerCase().includes(q)).map((concept) => {
          const word = index.get(concept.toLowerCase());
          return (
            <div key={concept} className="row small" style={{ padding: `2px 16px 2px ${indent + 24}px`, minHeight: 26 }}>
              <Icon name={word ? 'check' : 'add_circle_outline'} size={14} style={{ color: word ? 'var(--primary)' : 'var(--on-surface-4)' }} />
              <span className="grow">{concept}</span>
              {word ? <LinkedWord lexeme={word} /> : <TextButton onClick={() => add(concept)}>Name this concept</TextButton>}
            </div>
          );
        })}
    </div>
  );
}

export function ThesaurusPage() {
  const engine = useEngine();
  const [query, setQuery] = useState('');
  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const q = query.toLowerCase();
  const categories = (thesaurus as { categories: Category[] }).categories;
  const visible = useMemo(() => categories.filter((c) => matches(c, q)), [categories, q]);
  const toggle = (p: string) => {
    const next = new Set(expanded);
    if (next.has(p)) next.delete(p);
    else next.add(p);
    setExpanded(next);
  };
  return (
    <div className="col fill" style={{ gap: 0 }}>
      <div style={{ padding: 16 }}>
        <input type="search" placeholder="Search concepts..." aria-label="Search concepts" value={query} onChange={(e) => { setQuery(e.target.value); if (e.target.value) setExpanded(new Set()); }} />
      </div>
      <div className="grow scroll" data-testid="thesaurus">
        {visible.length === 0 ? (
          <div className="center faint">{engine.doc.lexemes.length ? 'No matching concepts.' : 'No lexicon entries yet. Browse categories to find concepts to name.'}</div>
        ) : (
          visible.map((c) => <CategoryNode key={c.name} c={c} path={c.name} depth={0} q={q} expanded={expanded} toggle={toggle} />)
        )}
      </div>
    </div>
  );
}
