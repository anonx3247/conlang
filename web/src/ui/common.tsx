import { useEffect, useRef, useState, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { CommandError } from '../core/commands';
import type { Violation } from '../core/phonology';
import { clearReport, clearSnack, useApp } from '../storage/store';

export function Icon({ name, size, style, className }: { name: string; size?: number; style?: React.CSSProperties; className?: string }) {
  return (
    <span className={`material-icons ${className ?? ''}`} style={{ fontSize: size, ...style }} aria-hidden>
      {name}
    </span>
  );
}

export function IconButton(p: { icon: string; title: string; onClick?: (e: React.MouseEvent) => void; size?: number; danger?: boolean; selected?: boolean; disabled?: boolean }) {
  return (
    <button type="button" className={`icon-btn ${p.danger ? 'danger' : ''} ${p.selected ? 'sel' : ''}`} title={p.title} aria-label={p.title} onClick={p.onClick} disabled={p.disabled} style={p.size ? { fontSize: p.size } : undefined}>
      <Icon name={p.icon} />
    </button>
  );
}

type BtnProps = React.ButtonHTMLAttributes<HTMLButtonElement> & { icon?: string; danger?: boolean };
const makeBtn = (variant: string) =>
  function Btn({ icon, danger, children, className, ...rest }: BtnProps) {
    return (
      <button type="button" className={`btn ${variant} ${danger ? 'danger' : ''} ${className ?? ''}`} {...rest}>
        {icon && <Icon name={icon} size={16} />}
        {children}
      </button>
    );
  };
export const FilledButton = makeBtn('filled');
export const TonalButton = makeBtn('tonal');
export const OutlinedButton = makeBtn('outlined');
export const TextButton = makeBtn('text');

export function Switch({ checked, onChange, label }: { checked: boolean; onChange: (v: boolean) => void; label?: string }) {
  return (
    <label className="switch" title={label}>
      <input type="checkbox" role="switch" aria-label={label} checked={checked} onChange={(e) => onChange(e.target.checked)} />
      <span />
    </label>
  );
}

export function Check({ checked, onChange, children }: { checked: boolean; onChange: (v: boolean) => void; children: ReactNode }) {
  return (
    <label className="check">
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />
      <div>{children}</div>
    </label>
  );
}

export function Chip({ selected, onClick, children, title, onDelete }: { selected?: boolean; onClick?: () => void; children: ReactNode; title?: string; onDelete?: () => void }) {
  const del = onDelete && (
    <span className="material-icons x" role="button" aria-label="Remove" onClick={(e) => { e.stopPropagation(); onDelete(); }}>
      close
    </span>
  );
  if (!onClick) {
    return <span className={`chip ${selected ? 'sel' : ''}`} title={title}>{children}{del}</span>;
  }
  return (
    <button type="button" className={`chip ${selected ? 'sel' : ''}`} title={title} aria-pressed={selected} onClick={onClick}>
      {selected && <Icon name="check" size={14} />}
      {children}
      {del}
    </button>
  );
}

export function Field(p: { label?: ReactNode; help?: ReactNode; error?: string | null; children: ReactNode }) {
  return (
    <label className="field">
      {p.label && <span>{p.label}</span>}
      {p.children}
      {p.error ? <span className="field-error">{p.error}</span> : p.help ? <span className="help">{p.help}</span> : null}
    </label>
  );
}

export function TextField({ label, help, error, value, onChange, ...rest }: { label?: ReactNode; help?: ReactNode; error?: string | null; value: string; onChange: (v: string) => void } & Omit<React.InputHTMLAttributes<HTMLInputElement>, 'value' | 'onChange'>) {
  return (
    <Field label={label} help={help} error={error}>
      <input type="text" value={value} onChange={(e) => onChange(e.target.value)} className={error ? 'bad' : ''} aria-label={typeof label === 'string' ? label : undefined} {...rest} />
    </Field>
  );
}

export function SelectField<T extends string | number>({ label, help, error, value, options, onChange, placeholder }: {
  label?: ReactNode;
  help?: ReactNode;
  error?: string | null;
  value: T | null;
  options: { value: T; label: string }[];
  onChange: (v: T | null) => void;
  placeholder?: string;
}) {
  return (
    <Field label={label} help={help} error={error}>
      <Select value={value} options={options} onChange={onChange} placeholder={placeholder} ariaLabel={typeof label === 'string' ? label : undefined} />
    </Field>
  );
}

export function Select<T extends string | number>({ value, options, onChange, placeholder, inline, ariaLabel }: {
  value: T | null;
  options: { value: T; label: string }[];
  onChange: (v: T | null) => void;
  placeholder?: string;
  inline?: boolean;
  ariaLabel?: string;
}) {
  const index = options.findIndex((o) => o.value === value);
  return (
    <select
      className={inline ? 'select-inline' : ''}
      aria-label={ariaLabel}
      value={index < 0 ? '' : String(index)}
      onChange={(e) => onChange(e.target.value === '' ? null : options[Number(e.target.value)].value)}
    >
      {(placeholder !== undefined || index < 0) && <option value="">{placeholder ?? ''}</option>}
      {options.map((o, i) => (
        <option key={String(o.value)} value={String(i)}>{o.label}</option>
      ))}
    </select>
  );
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

type DialogRender = (close: (value?: unknown) => void) => ReactNode;
let pushDialog: ((render: DialogRender, resolve: (v: unknown) => void) => void) | null = null;

/** Opens a modal; resolves with what it closes with. */
export function openDialog<T = void>(render: (close: (value?: T) => void) => ReactNode): Promise<T | undefined> {
  return new Promise((resolve) => pushDialog?.(render as DialogRender, resolve as (v: unknown) => void));
}

export function DialogHost() {
  const [stack, setStack] = useState<{ id: number; render: DialogRender; resolve: (v: unknown) => void }[]>([]);
  const counter = useRef(0);
  useEffect(() => {
    pushDialog = (render, resolve) => setStack((s) => [...s, { id: ++counter.current, render, resolve }]);
    return () => {
      pushDialog = null;
    };
  }, []);
  return (
    <>
      {stack.map((d) => {
        const close = (value?: unknown) => {
          setStack((s) => s.filter((x) => x.id !== d.id));
          d.resolve(value);
        };
        return <div key={d.id}>{d.render(close)}</div>;
      })}
    </>
  );
}

export function Dialog({ title, children, actions, onClose, wide, className }: { title?: ReactNode; children: ReactNode; actions?: ReactNode; onClose: () => void; wide?: boolean; className?: string }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !document.querySelector('.ipa-pop')) {
        const all = document.querySelectorAll('.dialog');
        if (all[all.length - 1] === ref.current) onClose();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);
  return createPortal(
    <div className="overlay">
      <div ref={ref} className={`dialog ${wide ? 'wide' : ''} ${className ?? ''}`} role="dialog" aria-modal="true" aria-label={typeof title === 'string' ? title : undefined}>
        {title && <div className="dialog-title">{title}</div>}
        {wide ? children : <div className="dialog-body">{children}</div>}
        {actions && <div className="dialog-actions">{actions}</div>}
      </div>
    </div>,
    document.body,
  );
}

export function confirmDialog(o: { title: string; body: ReactNode; confirm?: string; danger?: boolean; cancel?: string }): Promise<boolean> {
  return openDialog<boolean>((close) => (
    <Dialog
      title={o.title}
      onClose={() => close(false)}
      actions={
        <>
          <TextButton onClick={() => close(false)}>{o.cancel ?? 'Cancel'}</TextButton>
          <FilledButton danger={o.danger ?? true} onClick={() => close(true)}>{o.confirm ?? 'Delete'}</FilledButton>
        </>
      }
    >
      <div>{o.body}</div>
    </Dialog>
  )).then((v) => !!v);
}

export function promptDialog(o: { title: string; label: string; initial?: string; confirm?: string; hint?: string }): Promise<string | undefined> {
  return openDialog<string>((close) => <PromptBody {...o} close={close} />);
}

function PromptBody({ title, label, initial, confirm, hint, close }: { title: string; label: string; initial?: string; confirm?: string; hint?: string; close: (v?: string) => void }) {
  const [value, setValue] = useState(initial ?? '');
  return (
    <Dialog
      title={title}
      onClose={() => close()}
      actions={
        <>
          <TextButton onClick={() => close()}>Cancel</TextButton>
          <FilledButton onClick={() => close(value.trim())}>{confirm ?? 'OK'}</FilledButton>
        </>
      }
    >
      <TextField autoFocus label={label} placeholder={hint} value={value} onChange={setValue} onKeyDown={(e) => { if (e.key === 'Enter') close(value.trim()); }} />
    </Dialog>
  );
}

export function errorText(e: unknown): string {
  if (e instanceof CommandError) return e.message;
  throw e;
}

export function Snackbar() {
  const { snack } = useApp();
  useEffect(() => {
    if (!snack) return;
    const t = setTimeout(clearSnack, 5000);
    return () => clearTimeout(t);
  }, [snack]);
  if (!snack) return null;
  return <div className="snackbar" role="status">{snack.text}</div>;
}

/** Stays until dismissed, unlike the snackbar, because each line says what changed in the user's project. */
export function ReportDialog() {
  const { report } = useApp();
  if (!report) return null;
  return (
    <Dialog title={report.title} onClose={clearReport} actions={<FilledButton onClick={clearReport}>OK</FilledButton>}>
      <div className="col" style={{ gap: 6, maxHeight: 360, overflow: 'auto' }} data-testid="report">
        {report.lines.map((line, i) => <div key={i}>{line}</div>)}
      </div>
    </Dialog>
  );
}

// ---------------------------------------------------------------------------
// Menus and layout helpers
// ---------------------------------------------------------------------------

export interface MenuEntry {
  label?: string;
  shortcut?: string;
  onClick?: () => void;
  disabled?: boolean;
  separator?: boolean;
  children?: MenuEntry[];
  danger?: boolean;
}

export function Menu({ label, items, testId }: { label: string; items: MenuEntry[]; testId?: string }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    if (!open) return;
    const off = () => setOpen(false);
    const t = setTimeout(() => window.addEventListener('click', off));
    return () => {
      clearTimeout(t);
      window.removeEventListener('click', off);
    };
  }, [open]);
  const rect = ref.current?.getBoundingClientRect();
  return (
    <>
      <button ref={ref} type="button" data-testid={testId} className={`menu-label ${open ? 'open' : ''}`} aria-haspopup="menu" aria-expanded={open} onClick={() => setOpen((o) => !o)}>
        {label}
      </button>
      {open && rect &&
        createPortal(
          <div className="menu" role="menu" style={{ left: rect.left, top: rect.bottom + 2 }}>
            {items.map((item, i) =>
              item.separator ? (
                <div key={i} className="menu-sep" />
              ) : (
                <button key={i} type="button" role="menuitem" className={`menu-item ${item.danger ? 'err' : ''}`} disabled={item.disabled} onClick={item.onClick}>
                  <span>{item.label}</span>
                  {item.shortcut && <span className="faint small">{item.shortcut}</span>}
                </button>
              ),
            )}
          </div>,
          document.body,
        )}
    </>
  );
}

export function ResizableDivider({ onDrag }: { onDrag: (dx: number) => void }) {
  return (
    <div
      className="divider"
      role="separator"
      onPointerDown={(e) => {
        let last = e.clientX;
        const target = e.currentTarget;
        target.setPointerCapture(e.pointerId);
        const move = (ev: PointerEvent) => {
          onDrag(ev.clientX - last);
          last = ev.clientX;
        };
        const up = () => {
          target.removeEventListener('pointermove', move);
          target.removeEventListener('pointerup', up);
        };
        target.addEventListener('pointermove', move);
        target.addEventListener('pointerup', up);
      }}
    />
  );
}

export function useWidth(initial: number, min: number, max: number) {
  const [width, setWidth] = useState(initial);
  return [width, (dx: number) => setWidth((w) => Math.min(max, Math.max(min, w + dx)))] as const;
}

/** Text with wavy red underlines on violating spans. */
export function ViolationText({ text, violations, className, style }: { text: string; violations: Violation[]; className?: string; style?: React.CSSProperties }) {
  if (!violations.length) return <span className={className} style={style}>{text}</span>;
  const bad = new Set<number>();
  for (const v of violations) for (let i = v.position; i < v.position + v.length && i < text.length; i++) bad.add(i);
  const spans: ReactNode[] = [];
  let i = 0;
  while (i < text.length) {
    const flagged = bad.has(i);
    let j = i;
    while (j < text.length && bad.has(j) === flagged) j++;
    spans.push(flagged ? <span key={i} className="viol">{text.slice(i, j)}</span> : text.slice(i, j));
    i = j;
  }
  return <span className={className} style={style} title={violations.map((v) => v.description).join(' | ')}>{spans}</span>;
}

export function EmptyState({ icon, title, body, children }: { icon?: string; title: string; body?: string; children?: ReactNode }) {
  return (
    <div className="center">
      {icon && <Icon name={icon} size={48} style={{ color: 'var(--on-surface-4)' }} />}
      <div className="h-title muted" style={{ fontWeight: 400 }}>{title}</div>
      {body && <div className="faint small" style={{ maxWidth: 420 }}>{body}</div>}
      {children}
    </div>
  );
}

export function relativeTime(iso: string): string {
  const diff = (Date.now() - new Date(iso).getTime()) / 1000;
  if (diff < 60) return 'just now';
  const plural = (n: number, w: string) => `${n} ${w}${n === 1 ? '' : 's'} ago`;
  if (diff < 3600) return plural(Math.floor(diff / 60), 'minute');
  if (diff < 86400) return plural(Math.floor(diff / 3600), 'hour');
  if (diff < 604800) return plural(Math.floor(diff / 86400), 'day');
  return iso.slice(0, 10);
}
