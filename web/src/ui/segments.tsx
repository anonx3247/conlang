// Builds a sound sequence from parts: sounds, classes, optional items. This is
// the structured control used for every pattern in the app.

import { useState } from 'react';
import { DEFAULT_CLASSES, CLASS_ALIASES, LENGTH_CLASSES } from '../core/phonology';
import type { ClassSegment, Segment, TemplatePart } from '../core/types';
import { useEngine } from '../storage/store';
import { Icon } from './common';
import { IpaInput } from './ipa';

export function classOptions(userClasses: string[]): { value: string; label: string }[] {
  const aliasOf = (n: string) => Object.entries(CLASS_ALIASES).find(([, v]) => v === n)?.[0];
  const defaults = [...Object.keys(DEFAULT_CLASSES), ...Object.keys(LENGTH_CLASSES)].filter((n) => !userClasses.some((u) => u.toLowerCase() === n));
  return [
    { value: 'C', label: 'C — any consonant' },
    { value: 'V', label: 'V — any vowel' },
    ...userClasses.map((n) => ({ value: n, label: `[${n}]` })),
    ...defaults.map((n) => ({ value: n, label: aliasOf(n) ? `[${n}] / ${aliasOf(n)}` : `[${n}]` })),
  ];
}

export function useClassOptions() {
  const engine = useEngine();
  return classOptions(engine.doc.naturalClasses.map((c) => c.name));
}

function classLabel(name: string) {
  return /^[A-Z]$/.test(name) ? name : `[${name}]`;
}

/**
 * Phonemic text in a field shown romanized when romanization is on. The user's
 * own text stays on screen while typing, so `.` separators aren't reformatted.
 */
export function LiteralInput({ value, onChange, ...rest }: { value: string; onChange: (phonemic: string) => void } & Omit<React.InputHTMLAttributes<HTMLInputElement>, 'value' | 'onChange'>) {
  const engine = useEngine();
  const [text, setText] = useState(engine.fromPhonemic(value));
  const [lastEmitted, setLastEmitted] = useState(value);
  if (value !== lastEmitted) {
    setLastEmitted(value);
    setText(engine.fromPhonemic(value));
  }
  return (
    <IpaInput
      value={text}
      onChange={(t) => {
        setText(t);
        const phonemic = engine.toPhonemic(t);
        setLastEmitted(phonemic);
        onChange(phonemic);
      }}
      {...rest}
    />
  );
}

type Engine = ReturnType<typeof useEngine>;

/** C, V, S, N, F, L and R mean classes, unless this language uses that letter as a sound. */
function isClassLetter(ch: string, engine: Engine): boolean {
  if (ch !== 'C' && ch !== 'V' && !(ch in CLASS_ALIASES)) return false;
  return !engine.doc.romanization.some((m) => m.latin.includes(ch)) && !engine.doc.phonemes.some((p) => p.symbol === ch);
}

/** A field holding just a class name, typed as C, V or [name]. */
export function typedClass(text: string, engine: Engine): ClassSegment | null {
  const t = text.trim();
  if (isClassLetter(t, engine)) return { kind: 'class', name: t };
  const m = t.match(/^\[([^\]]+)\]$/);
  return m ? { kind: 'class', name: m[1] } : null;
}

/**
 * Turns typed text into chips as it's recognized. Returns what was understood
 * plus any unfinished text, such as an open "(" or "[", to leave in the field.
 */
export function readTyped(text: string, engine: Engine, allowBoundary: boolean, allowOptional: boolean, finish: boolean): { segments: Segment[]; rest: string } {
  const segments: Segment[] = [];
  let run = '';
  let optional = false;
  const flushRun = () => {
    if (!run) return;
    const seg: Segment = { kind: 'sound', text: engine.toPhonemic(run) };
    if (optional && allowOptional) seg.optional = true;
    segments.push(seg);
    run = '';
  };
  const addClass = (name: string) => {
    const seg: ClassSegment = { kind: 'class', name };
    if (optional && allowOptional) seg.optional = true;
    segments.push(seg);
  };
  let i = 0;
  let groupStart = -1;
  let groupCount = 0;
  while (i < text.length) {
    const ch = text[i];
    if (ch === '(') {
      flushRun();
      optional = true;
      groupStart = i;
      groupCount = segments.length;
      i++;
    } else if (ch === ')') {
      flushRun();
      optional = false;
      groupStart = -1;
      i++;
    } else if (ch === '[') {
      const close = text.indexOf(']', i);
      if (close < 0) {
        if (!finish) {
          flushRun();
          return { segments, rest: text.slice(i) };
        }
        run += text.slice(i);
        break;
      }
      flushRun();
      if (close > i + 1) addClass(text.slice(i + 1, close));
      i = close + 1;
    } else if (ch === '#' && allowBoundary) {
      flushRun();
      segments.push({ kind: 'boundary' });
      i++;
    } else if (isClassLetter(ch, engine)) {
      flushRun();
      addClass(ch);
      i++;
    } else if (ch === ' ') {
      flushRun();
      i++;
    } else {
      run += ch;
      i++;
    }
  }
  if (!finish && groupStart >= 0) {
    // Still inside "(": nothing is final until it closes.
    return { segments: segments.slice(0, groupCount), rest: text.slice(groupStart) };
  }
  // Plain sounds stay in the field while typing, so multi-letter sounds can be finished.
  if (!finish && run) return { segments, rest: run };
  flushRun();
  return { segments, rest: '' };
}

export function SegmentEditor({ value, onChange, allowBoundary, allowOptional = true, placeholder, label, testId }: {
  value: Segment[];
  onChange: (s: Segment[]) => void;
  allowBoundary?: boolean;
  allowOptional?: boolean;
  placeholder?: string;
  label?: string;
  testId?: string;
}) {
  const engine = useEngine();
  const options = useClassOptions();
  const [text, setText] = useState('');

  const commit = () => {
    if (!text.trim()) return;
    const { segments } = readTyped(text, engine, !!allowBoundary, allowOptional, true);
    if (segments.length) onChange([...value, ...segments]);
    setText('');
  };

  /** Recognized classes become chips right away; other sounds wait for Enter or leaving the field. */
  const onType = (typed: string) => {
    const { segments, rest } = readTyped(typed, engine, !!allowBoundary, allowOptional, false);
    if (segments.length) onChange([...value, ...segments]);
    setText(rest);
  };

  const toggleOptional = (i: number) => {
    const s = value[i];
    if (s.kind === 'boundary') return;
    onChange(value.map((x, j) => (j === i ? { ...s, optional: !s.optional } : x)));
  };

  return (
    <div className="seg-editor" data-testid={testId} aria-label={label}>
      {value.map((s, i) => {
        const shown = s.kind === 'boundary' ? '#' : s.kind === 'class' ? classLabel(s.name) : engine.fromPhonemic(s.text);
        const optional = s.kind !== 'boundary' && !!s.optional;
        return (
          <span key={i} className={`seg-chip ${s.kind === 'class' ? 'class' : ''} ${optional ? 'optional' : ''}`} title={s.kind === 'sound' ? `/${s.text}/` : s.kind === 'boundary' ? 'word edge' : undefined}>
            {optional ? `(${shown})` : shown}
            {allowOptional && s.kind !== 'boundary' && (
              <button type="button" title={optional ? 'Make required' : 'Make optional'} aria-label={optional ? 'Make required' : 'Make optional'} onClick={() => toggleOptional(i)}>
                <Icon name={optional ? 'radio_button_checked' : 'radio_button_unchecked'} size={12} />
              </button>
            )}
            <button type="button" title="Remove" aria-label={`Remove ${shown}`} onClick={() => onChange(value.filter((_, j) => j !== i))}>
              <Icon name="close" size={13} />
            </button>
          </span>
        );
      })}
      <IpaInput
        value={text}
        placeholder={value.length ? '' : placeholder ?? 'sound'}
        aria-label={label ? `${label}: add sound` : 'Add sound'}
        onChange={onType}
        onBlur={commit}
        onKeyDown={(e) => {
          if (e.key === 'Enter') { e.preventDefault(); commit(); }
          if (e.key === 'Backspace' && !text && value.length) onChange(value.slice(0, -1));
        }}
      />
      <select
        className="select-inline"
        aria-label={label ? `${label}: add class` : 'Add class'}
        style={{ border: 0, width: 88, flex: 'none' }}
        value=""
        onChange={(e) => {
          if (e.target.value === '#') onChange([...value, { kind: 'boundary' }]);
          else if (e.target.value) onChange([...value, { kind: 'class', name: e.target.value } as ClassSegment]);
        }}
      >
        <option value="">+ class</option>
        {options.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
        {allowBoundary && <option value="#"># — word edge</option>}
      </select>
    </div>
  );
}

/** Root-and-pattern templates: consonant slots mixed with fixed sounds. */
export function TemplateEditor({ value, onChange }: { value: TemplatePart[]; onChange: (p: TemplatePart[]) => void }) {
  const engine = useEngine();
  const [text, setText] = useState('');
  const commit = () => {
    const t = text.trim();
    if (!t) return;
    onChange([...value, { kind: 'sound', text: engine.toPhonemic(t) }]);
    setText('');
  };
  return (
    <div className="col" style={{ gap: 4 }}>
      <div className="seg-editor" aria-label="Root template">
        {value.map((p, i) => (
          <span key={i} className={`seg-chip ${p.kind === 'slot' ? 'class' : ''}`}>
            {p.kind === 'slot' ? `C${p.index}` : engine.fromPhonemic(p.text)}
            <button type="button" aria-label="Remove" onClick={() => onChange(value.filter((_, j) => j !== i))}><Icon name="close" size={13} /></button>
          </span>
        ))}
        <IpaInput value={text} placeholder={value.length ? '' : 'vowel or sound'} aria-label="Add sound" onChange={setText} onBlur={commit} onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); commit(); } }} />
        <select
          className="select-inline"
          aria-label="Add consonant slot"
          style={{ border: 0, width: 88, flex: 'none' }}
          value=""
          onChange={(e) => { if (e.target.value) onChange([...value, { kind: 'slot', index: Number(e.target.value) }]); }}
        >
          <option value="">+ slot</option>
          {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => <option key={n} value={n}>Root consonant {n}</option>)}
        </select>
      </div>
      <span className="help">C1, C2… are the root's consonants in order; other parts are fixed sounds.</span>
    </div>
  );
}
