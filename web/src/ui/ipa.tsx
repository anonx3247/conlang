import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import ipaSounds from '../data/ipa_sounds.json';
import { Field, Icon, IconButton } from './common';

const CATEGORIES: { label: string; symbols: string[] }[] = [
  {
    label: 'Consonants',
    symbols: 'p b t d ʈ ɖ c ɟ k g q ɢ ʔ m ɱ n ɳ ɲ ŋ ɴ ʙ r ʀ ɾ ɽ ɸ β f v θ ð s z ʃ ʒ ʂ ʐ ç ʝ x ɣ χ ʁ ħ ʕ h ɦ ɬ ɮ ʋ ɹ ɻ j ɰ l ɭ ʎ ʟ'.split(' '),
  },
  { label: 'Vowels', symbols: 'i y ɨ ʉ ɯ u e ø ɘ ɵ ɤ o e̞ ə ɵ̞ ɛ œ ɜ ɞ ʌ ɔ æ ɐ a ɶ ä ɑ ɒ ɪ ʏ ʊ'.split(' ') },
  { label: 'Diacritics', symbols: ['̥', '̬', 'ʰ', 'ʱ', '̤', '̰', '̪', '̺', '̻', '̟', '̠', '̈', '̽', '˞', '̃', 'ː', 'ˑ', '̩', '̯', '̋', '́', '̄', '̀', '̏', 'ʷ', 'ʲ', 'ˠ', 'ˤ', '̚', '.'] },
  { label: 'Supraseg.', symbols: 'ˈ ˌ ː ˑ ˥ ˦ ˧ ˨ ˩ ˥˩ ˩˥ ˧˥ ˥˧ ˩˧ ˧˩ ↗ ↘ ‿ | ‖'.split(' ') },
  { label: 'Other', symbols: 'ʘ ǀ ǁ ǂ ǃ ɓ ɗ ʄ ɠ ʛ pʼ tʼ kʼ sʼ ʃʼ ʼ ts dz tʃ dʒ tɕ dʑ mb nd ŋg ʍ w ɥ ʜ ʢ ɺ'.split(' ') },
];

const AUDIO = new Map<string, string>();
for (const s of [...ipaSounds.pulmonic, ...ipaSounds.vowels, ...ipaSounds.nonPulmonic]) if (s.audio) AUDIO.set(s.symbol, s.audio);

let player: HTMLAudioElement | null = null;

export function playIpa(symbol: string) {
  const file = AUDIO.get(symbol);
  if (!file) return;
  player?.pause();
  player = new Audio(`/ipa_audio/${file}`);
  void player.play().catch(() => undefined);
}

export const hasIpaAudio = (symbol: string) => AUDIO.has(symbol);

const KEYBOARD_W = 340;
const KEYBOARD_H = 230;

/** Near the field, without covering the buttons of the dialog it sits in. */
function keyboardPosition(anchor: HTMLElement) {
  const r = anchor.getBoundingClientRect();
  const clampTop = (t: number) => Math.max(4, Math.min(t, window.innerHeight - KEYBOARD_H - 4));
  const dialog = anchor.closest('.dialog')?.getBoundingClientRect();
  if (dialog) {
    if (dialog.right + 8 + KEYBOARD_W <= window.innerWidth) return { left: dialog.right + 8, top: clampTop(r.top) };
    if (dialog.left - 8 - KEYBOARD_W >= 0) return { left: dialog.left - 8 - KEYBOARD_W, top: clampTop(r.top) };
  }
  const left = Math.max(4, Math.min(r.left, window.innerWidth - KEYBOARD_W - 8));
  const limit = dialog ? dialog.bottom - 64 : window.innerHeight;
  const fitsBelow = r.bottom + 4 + KEYBOARD_H <= limit;
  const fitsAbove = r.top - 4 - KEYBOARD_H >= 0;
  return { left, top: fitsBelow || !fitsAbove ? clampTop(r.bottom + 4) : r.top - 4 - KEYBOARD_H };
}

function Keyboard({ anchor, onPick, onClose }: { anchor: HTMLElement; onPick: (s: string) => void; onClose: () => void }) {
  const [tab, setTab] = useState(0);
  const style = keyboardPosition(anchor);
  return createPortal(
    <div className="ipa-pop" style={style} onMouseDown={(e) => e.preventDefault()} data-testid="ipa-keyboard">
      <div className="ipa-tabs">
        {CATEGORIES.map((c, i) => (
          <button key={c.label} type="button" className={`ipa-tab ${i === tab ? 'sel' : ''}`} onClick={() => setTab(i)}>{c.label}</button>
        ))}
        <span className="grow" />
        <IconButton icon="close" title="Close IPA keyboard" size={14} onClick={onClose} />
      </div>
      <div className="ipa-grid">
        {CATEGORIES[tab].symbols.map((s, i) => (
          <button key={i} type="button" className="ipa-key" title={s} onClick={() => { playIpa(s); onPick(s); }}>{s}</button>
        ))}
      </div>
    </div>,
    document.body,
  );
}

export interface IpaInputProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, 'value' | 'onChange'> {
  value: string;
  onChange: (v: string) => void;
}

/** A text input that shows the IPA keyboard while focused. */
export function IpaInput({ value, onChange, ...rest }: IpaInputProps) {
  const ref = useRef<HTMLInputElement>(null);
  const [open, setOpen] = useState(false);
  const caret = useRef<number | null>(null);

  useEffect(() => {
    if (caret.current !== null && ref.current) {
      ref.current.setSelectionRange(caret.current, caret.current);
      caret.current = null;
    }
  });

  const insert = (s: string) => {
    const el = ref.current!;
    const start = el.selectionStart ?? value.length;
    const end = el.selectionEnd ?? value.length;
    caret.current = start + s.length;
    onChange(value.slice(0, start) + s + value.slice(end));
    el.focus();
  };

  return (
    <>
      <input
        ref={ref}
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        {...rest}
        onFocus={(e) => { setOpen(true); rest.onFocus?.(e); }}
        onBlur={(e) => { setOpen(false); rest.onBlur?.(e); }}
        onKeyDown={(e) => {
          if (e.key === 'Escape' && open) { setOpen(false); e.stopPropagation(); return; }
          rest.onKeyDown?.(e);
        }}
      />
      {open && ref.current && <Keyboard anchor={ref.current} onPick={insert} onClose={() => setOpen(false)} />}
    </>
  );
}

export function IpaField({ label, help, error, ...rest }: IpaInputProps & { label?: React.ReactNode; help?: React.ReactNode; error?: string | null }) {
  return (
    <Field label={label} help={help} error={error}>
      <IpaInput aria-label={typeof label === 'string' ? label : undefined} className={error ? 'bad' : ''} {...rest} />
    </Field>
  );
}

const HEIGHT_Y: Record<string, number> = { close: 0, 'near-close': 1 / 7, 'close-mid': 2 / 7, mid: 3 / 7, 'open-mid': 4 / 7, 'near-open': 5 / 7, open: 6 / 7 };
const BACK_X: Record<string, number> = { front: 0, 'near-front': 0.25, central: 0.5, 'near-back': 0.75, back: 1 };

export function vowelPosition(height: string, backness: string, w: number, h: number) {
  const yf = HEIGHT_Y[height] ?? 0;
  const xf = BACK_X[backness] ?? 0;
  return { x: xf * w * (1 - 0.45 * yf), y: yf * h };
}

export function isPlaceableVowel(height?: string | null, backness?: string | null) {
  return !!height && !!backness && height in HEIGHT_Y && backness in BACK_X;
}

/** The IPA vowel trapezoid with height guides; children are positioned over it. */
export function VowelTrapezoid({ width, height, children }: { width: number; height: number; children: React.ReactNode }) {
  const right = (yf: number) => width * (1 - 0.45 * yf);
  return (
    <div className="trapezoid" style={{ width, height }}>
      <svg width={width} height={height} aria-hidden>
        <polygon points={`0,0 ${width},0 ${right(1)},${height} 0,${height}`} fill="none" stroke="rgba(142,144,153,.5)" />
        {[2 / 7, 4 / 7].map((f) => (
          <line key={f} x1={0} y1={f * height} x2={right(f)} y2={f * height} stroke="rgba(142,144,153,.15)" />
        ))}
        <line x1={width / 2} y1={0} x2={right(1) / 2} y2={height} stroke="rgba(142,144,153,.15)" />
      </svg>
      {children}
    </div>
  );
}

export { Icon };
