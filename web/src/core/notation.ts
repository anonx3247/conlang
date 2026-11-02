// Romanization <-> phonemic conversion.
//
// `.` on the romanized side is a glyph separator: it emits nothing and resets
// longest-match, so `at.ha` and `atha` stay distinct when th -> θ exists.

import type { RomanizationMapping } from './types';

export type NotationMapping = { phoneme: string; latin: string };

function byLengthDesc(key: 'phoneme' | 'latin', mappings: NotationMapping[]): NotationMapping[] {
  return mappings
    .filter((m) => m[key].length > 0)
    .slice()
    .sort((a, b) => b[key].length - a[key].length);
}

function codePointAt(s: string, i: number): string {
  return String.fromCodePoint(s.codePointAt(i)!);
}

export function segmentPhonemic(phonemic: string, mappings: NotationMapping[]): string[] {
  const active = byLengthDesc('phoneme', mappings);
  const out: string[] = [];
  let i = 0;
  while (i < phonemic.length) {
    const m = active.find((x) => phonemic.startsWith(x.phoneme, i));
    if (m) {
      out.push(m.phoneme);
      i += m.phoneme.length;
    } else {
      const ch = codePointAt(phonemic, i);
      out.push(ch);
      i += ch.length;
    }
  }
  return out;
}

export function deromanize(rom: string, mappings: NotationMapping[]): string {
  const active = byLengthDesc('latin', mappings);
  let out = '';
  let i = 0;
  while (i < rom.length) {
    if (rom[i] === '.') {
      i++;
      continue;
    }
    const m = active.find((x) => rom.startsWith(x.latin, i));
    if (m) {
      out += m.phoneme;
      i += m.latin.length;
    } else {
      const ch = codePointAt(rom, i);
      out += ch;
      i += ch.length;
    }
  }
  return out;
}

export function romanize(phonemic: string, mappings: NotationMapping[]): string {
  if (!phonemic) return phonemic;
  const segments = segmentPhonemic(phonemic, mappings);
  const romOf = new Map<string, string>();
  for (const m of mappings) if (!romOf.has(m.phoneme)) romOf.set(m.phoneme, m.latin);
  let out = '';
  segments.forEach((seg, i) => {
    const rom = romOf.get(seg) ?? seg;
    if (i > 0) {
      const prev = segments[i - 1];
      if (romOf.has(prev) && romOf.has(seg)) {
        const reparsed = deromanize(romOf.get(prev)! + rom, mappings);
        if (reparsed !== prev + seg) out += '.';
      }
    }
    out += rom;
  });
  return out;
}

export type BijectionKind = 'duplicatePhoneme' | 'duplicateLatin' | 'nonRoundTrip';

export interface BijectionViolation {
  kind: BijectionKind;
  rowId: number | null;
  detail: string;
}

/** Returns why these mappings can't round-trip; empty means they can. */
export function validateBijection(rows: RomanizationMapping[]): BijectionViolation[] {
  const active = rows.filter((r) => r.phoneme && r.latin);
  const out: BijectionViolation[] = [];
  const group = (key: 'phoneme' | 'latin') => {
    const m = new Map<string, RomanizationMapping[]>();
    for (const r of active) m.set(r[key], [...(m.get(r[key]) ?? []), r]);
    return m;
  };
  for (const [sym, list] of group('phoneme')) {
    for (const row of list.slice(1)) {
      out.push({
        kind: 'duplicatePhoneme',
        rowId: row.id,
        detail: `Phoneme /${sym}/ is mapped by more than one row (rows: ${list.map((r) => r.id).join(', ')}).`,
      });
    }
  }
  for (const [latin, list] of group('latin')) {
    for (const row of list.slice(1)) {
      out.push({
        kind: 'duplicateLatin',
        rowId: row.id,
        detail: `Rom glyph "${latin}" is targeted by more than one phoneme (rows: ${list.map((r) => r.id).join(', ')}). No dot boundary can recover this ambiguity.`,
      });
    }
  }
  if (out.length) return out;
  for (const p of active) {
    if (deromanize(romanize(p.phoneme, active), active) !== p.phoneme) {
      return [{ kind: 'nonRoundTrip', rowId: null, detail: `Phoneme /${p.phoneme}/ does not round-trip.` }];
    }
    for (const q of active) {
      const input = p.phoneme + q.phoneme;
      const rom = romanize(input, active);
      const back = deromanize(rom, active);
      if (back !== input) {
        return [
          {
            kind: 'nonRoundTrip',
            rowId: null,
            detail: `Phoneme pair /${p.phoneme}/+/${q.phoneme}/ does not round-trip (rom="${rom}" → re-parsed as "${back}").`,
          },
        ];
      }
    }
  }
  return [];
}

/** Lowercase with a trailing period, e.g. "SG" -> "sg." */
export function formatAbbr(abbr: string | null | undefined): string {
  const n = (abbr ?? '').toLowerCase().replaceAll('.', '');
  return n ? `${n}.` : '';
}

/** Uppercase without period, e.g. "sg." -> "SG" */
export function formatAbbrUpper(abbr: string | null | undefined): string {
  return (abbr ?? '').toUpperCase().replaceAll('.', '');
}
