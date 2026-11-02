// Builds an Anki .apkg (a zip holding a SQLite collection) entirely locally.

import initSqlJs from 'sql.js';
import { zipSync, strToU8 } from 'fflate';
import type { LanguageEngine } from './engine';
import type { Id } from './types';

const MODEL_ID = 1_000_000_000;
const DECK_ID = 1_000_000_001;

export interface AnkiEntry {
  phonetic: string;
  roman: string;
  meaning: string;
  pos: string;
  context: string;
}

/** One card per word, using each word's real form. */
export function ankiEntries(engine: LanguageEngine, ids: Id[]): AnkiEntry[] {
  return ids.flatMap((id) => {
    const l = engine.lexeme(id);
    if (!l) return [];
    const f = engine.form(id);
    let context = '';
    if (f.chain.length) {
      const root = engine.form(f.chain[0].parentId);
      context = `Derived from [${root.phonetic}] via [${f.chain.map((c) => c.rule.name).join(', ')}]`;
    }
    return [{
      phonetic: f.phonetic,
      roman: engine.romanizationOn && f.roman !== f.phonetic ? f.roman : '',
      meaning: engine.glossOf(l),
      pos: engine.pos(l.posId)?.name ?? '',
      context,
    }];
  });
}

function escapeHtml(v: string): string {
  return v.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#x27;');
}

function csum(text: string): number {
  let hash = 5381;
  for (let i = 0; i < text.length; i++) hash = ((hash * 33) + text.charCodeAt(i)) % 0x100000000;
  return hash;
}

const SCHEMA = `
CREATE TABLE col (id INTEGER PRIMARY KEY, crt INTEGER NOT NULL, mod INTEGER NOT NULL, scm INTEGER NOT NULL, ver INTEGER NOT NULL, dty INTEGER NOT NULL, usn INTEGER NOT NULL, ls INTEGER NOT NULL, conf TEXT NOT NULL, models TEXT NOT NULL, decks TEXT NOT NULL, dconf TEXT NOT NULL, tags TEXT NOT NULL);
CREATE TABLE notes (id INTEGER PRIMARY KEY, guid TEXT NOT NULL, mid INTEGER NOT NULL, mod INTEGER NOT NULL, usn INTEGER NOT NULL, tags TEXT NOT NULL, flds TEXT NOT NULL, sfld TEXT NOT NULL, csum INTEGER NOT NULL, flags INTEGER NOT NULL, data TEXT NOT NULL);
CREATE TABLE cards (id INTEGER PRIMARY KEY, nid INTEGER NOT NULL, did INTEGER NOT NULL, ord INTEGER NOT NULL, mod INTEGER NOT NULL, usn INTEGER NOT NULL, type INTEGER NOT NULL, queue INTEGER NOT NULL, due INTEGER NOT NULL, ivl INTEGER NOT NULL, factor INTEGER NOT NULL, reps INTEGER NOT NULL, lapses INTEGER NOT NULL, left INTEGER NOT NULL, odue INTEGER NOT NULL, odid INTEGER NOT NULL, flags INTEGER NOT NULL, data TEXT NOT NULL);
CREATE TABLE revlog (id INTEGER PRIMARY KEY, cid INTEGER NOT NULL, usn INTEGER NOT NULL, ease INTEGER NOT NULL, ivl INTEGER NOT NULL, lastIvl INTEGER NOT NULL, factor INTEGER NOT NULL, time INTEGER NOT NULL, type INTEGER NOT NULL);
CREATE TABLE graves (usn INTEGER NOT NULL, oid INTEGER NOT NULL, type INTEGER NOT NULL);
`;

export async function buildApkg(deckName: string, entries: AnkiEntry[], locateFile?: (f: string) => string, nowMs = Date.now()): Promise<Uint8Array> {
  const SQL = await initSqlJs({ locateFile });
  const db = new SQL.Database();
  try {
    db.run(SCHEMA);
    const nowSec = Math.floor(nowMs / 1000);
    const field = (name: string, ord: number) => ({ name, ord, sticky: false, rtl: false, font: 'Arial', size: 20, media: [] });
    const models = {
      [MODEL_ID]: {
        id: MODEL_ID,
        name: 'Conlang Basic',
        type: 0,
        mod: nowSec,
        usn: -1,
        sortf: 0,
        did: DECK_ID,
        tmpls: [{ name: 'Card 1', ord: 0, qfmt: '{{Front}}', afmt: '{{FrontSide}}<hr id=answer>{{Back}}<br><small>{{POS}} {{Context}}</small>', bqfmt: '', bafmt: '', did: null, bfont: '', bsize: 0 }],
        flds: [field('Front', 0), field('Back', 1), field('POS', 2), field('Context', 3)],
        css: '.card { font-family: arial; font-size: 20px; text-align: center; }',
        latexPre: '',
        latexPost: '',
        req: [[0, 'any', [0]]],
        tags: [],
        vers: [],
      },
    };
    const decks = {
      [DECK_ID]: { id: DECK_ID, name: deckName, desc: '', mod: nowSec, usn: -1, lrnToday: [0, 0], revToday: [0, 0], newToday: [0, 0], timeToday: [0, 0], collapsed: false, browserCollapsed: false, extendNew: 10, extendRev: 50, conf: 1, dyn: 0 },
    };
    db.run('INSERT INTO col VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)', [1, nowSec, nowMs, nowMs, 11, 0, -1, 0, '{}', JSON.stringify(models), JSON.stringify(decks), '{}', '{}']);
    entries.forEach((e, i) => {
      const noteId = nowMs * 1000 + i;
      const front = e.roman ? `${escapeHtml(e.roman)}<br>[${escapeHtml(e.phonetic)}]` : escapeHtml(e.phonetic);
      const flds = [front, escapeHtml(e.meaning), escapeHtml(e.pos), escapeHtml(e.context)].join('\x1f');
      db.run('INSERT INTO notes VALUES (?,?,?,?,?,?,?,?,?,?,?)', [noteId, `conlang_${noteId}_${i}`, MODEL_ID, nowSec, -1, '', flds, e.phonetic, csum(e.phonetic), 0, '']);
      db.run('INSERT INTO cards VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)', [noteId + 500000, noteId, DECK_ID, 0, nowSec, -1, 0, 0, i + 1, 0, 0, 0, 0, 0, 0, 0, 0, '']);
    });
    const bytes = db.export();
    return zipSync({ 'collection.anki21': bytes, media: strToU8('{}') });
  } finally {
    db.close();
  }
}
