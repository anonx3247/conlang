import { useEffect, useRef, useState } from 'react';
import * as cmd from '../core/commands';
import type { GlossedToken, PhraseAnalysis } from '../core/engine';
import type { Id, Phrase } from '../core/types';
import { flushSave, mutate, run, uiGet, uiSet, useDoc, useEngine } from '../storage/store';
import { EmptyState, Icon, IconButton, TextButton, ViolationText } from './common';

function relative(iso: string) {
  const d = new Date(iso);
  const diff = (Date.now() - d.getTime()) / 1000;
  if (diff < 60) return 'just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
  return `${d.getMonth() + 1}/${d.getDate()}/${d.getFullYear()}`;
}

export function ScratchpadPage() {
  const doc = useDoc();
  const [selected, setSelectedState] = useState<Id | null>(uiGet('scratchpad.selected', null));
  const setSelected = (id: Id | null) => {
    uiSet('scratchpad.selected', id);
    setSelectedState(id);
  };
  const phrases = doc.phrases.slice().sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  const current = doc.phrases.find((p) => p.id === selected) ?? null;
  return (
    <div className="row top fill grow" style={{ gap: 0 }}>
      <div className="col fill" style={{ width: 260, flex: 'none', background: 'var(--surface-low)', gap: 0 }}>
        <div style={{ padding: 8 }}><TextButton icon="add" style={{ width: '100%' }} onClick={() => setSelected(mutate((d) => cmd.createPhrase(d)))}>New Phrase</TextButton></div>
        <div className="grow scroll" data-testid="phrase-list">
          {phrases.length === 0 && <div className="center small faint">No phrases yet</div>}
          {phrases.map((p) => (
            <div key={p.id} className={`list-row ${p.id === selected ? 'sel' : ''}`} onClick={() => setSelected(p.id)}>
              <div className="grow" style={{ minWidth: 0 }}>
                <div className="ellipsis">{p.text || '—'}</div>
                <div className="tiny faint">{relative(p.updatedAt)}</div>
              </div>
              <IconButton
                icon="close"
                size={14}
                title="Delete phrase"
                onClick={(e) => {
                  e.stopPropagation();
                  run((d) => cmd.deletePhrase(d, p.id));
                  if (selected === p.id) setSelected(null);
                }}
              />
            </div>
          ))}
        </div>
      </div>
      <div className="vr fill" />
      <div className="grow fill" style={{ minWidth: 0 }}>
        {current ? (
          <PhraseEditor key={current.id} phrase={current} />
        ) : (
          <EmptyState icon="edit_note" title="No phrases yet" body={'Click "New Phrase" to start writing in your language.'} />
        )}
      </div>
    </div>
  );
}

function PhraseEditor({ phrase }: { phrase: Phrase }) {
  const engine = useEngine();
  const [text, setText] = useState(phrase.text);
  const [parsedText, setParsedText] = useState(phrase.text);
  const [translation, setTranslation] = useState(phrase.translation ?? '');
  const [showIpa, setShowIpa] = useState(false);
  const parseTimer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const textTimer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const transTimer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const pending = useRef<{ text?: string; translation?: string | null }>({});

  const flush = () => {
    if (!Object.keys(pending.current).length) return;
    const patch = pending.current;
    pending.current = {};
    run((d) => {
      if (d.phrases.some((p) => p.id === phrase.id)) cmd.updatePhrase(d, phrase.id, patch);
    });
    void flushSave();
  };
  useEffect(() => () => {
    clearTimeout(parseTimer.current);
    clearTimeout(textTimer.current);
    clearTimeout(transTimer.current);
    flush();
  }, []);

  const onText = (v: string) => {
    setText(v);
    clearTimeout(parseTimer.current);
    clearTimeout(textTimer.current);
    parseTimer.current = setTimeout(() => setParsedText(v), 300);
    pending.current.text = v;
    textTimer.current = setTimeout(flush, 1000);
  };
  const onTranslation = (v: string) => {
    setTranslation(v);
    clearTimeout(transTimer.current);
    pending.current.translation = v || null;
    transTimer.current = setTimeout(flush, 1000);
  };

  const analysis = engine.glossPhrase(parsedText);
  const { tokens } = analysis;
  return (
    <div className="col fill pad" data-testid="phrase-editor">
      <div className="row">
        <span className="grow" />
        <button type="button" title="Toggle IPA transcription" aria-pressed={showIpa} className={showIpa ? 'primary bold' : 'faint'} onClick={() => setShowIpa((s) => !s)}>/aɪ/</button>
      </div>
      <input type="text" autoFocus placeholder="Type a phrase in your language..." aria-label="Phrase" value={text} onChange={(e) => onText(e.target.value)} style={{ fontSize: 15, padding: '10px 12px' }} />
      {tokens.length > 0 && (
        <div className="grow scroll col" style={{ gap: 12, paddingTop: 8 }}>
          <div className="interlinear" data-testid="interlinear">
            {groupTokens(analysis).map((g) =>
              g.name === null ? (
                <TokenColumn key={g.start} token={g.tokens[0]} showIpa={showIpa} />
              ) : (
                <div key={g.start} className="construction-span" data-testid="construction-span">
                  <div className="interlinear">{g.tokens.map((t, i) => <TokenColumn key={i} token={t} showIpa={showIpa} />)}</div>
                  <div className="construction-name" data-testid="construction-name">{g.name}</div>
                </div>
              ),
            )}
          </div>
          <div className="hr" />
          <input type="text" placeholder="Add free translation…" aria-label="Free translation" value={translation} onChange={(e) => onTranslation(e.target.value)} className="italic" style={{ border: 0 }} />
        </div>
      )}
    </div>
  );
}

/** Tokens in order, with those a construction covers kept together under its name. */
function groupTokens({ tokens, constructions }: PhraseAnalysis) {
  const groups: { start: number; name: string | null; tokens: GlossedToken[] }[] = [];
  for (let i = 0; i < tokens.length; ) {
    const hit = constructions.find((m) => m.start === i);
    const end = hit ? hit.end : i + 1;
    groups.push({ start: i, name: hit ? hit.construction.name : null, tokens: tokens.slice(i, end) });
    i = end;
  }
  return groups;
}

function TokenColumn({ token: t, showIpa }: { token: GlossedToken; showIpa: boolean }) {
  const unknown = t.matches.length === 0;
  const others = t.otherReadings;
  const alternatives = others.length ? `Also: ${others.join(', ')}` : '';
  const title = unknown ? 'Unknown — not found in lexicon' : t.violations.length ? t.violations.map((v) => v.description).join(' | ') : alternatives;
  return (
    <div className="token" data-testid="token">
      <div className={`t1 ${unknown ? 'unknown' : ''}`} title={title}>
        {t.violations.length ? <span className="viol" style={{ color: 'inherit' }}>{t.raw}</span> : t.raw}
      </div>
      <div className={`t2 ${unknown ? 'fainter' : ''}`} data-testid="gloss">{t.gloss ?? '?'}{others.length > 0 && <Icon name="more_horiz" size={11} className="faint" />}</div>
      {showIpa && (
        <div className="t3" data-testid="token-ipa">/<ViolationText text={t.phonetic} violations={t.violations} />/</div>
      )}
    </div>
  );
}
