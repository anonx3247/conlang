import initSqlJs from 'sql.js';
import type { LegacyDatabase, Row } from './importSqlite';

export interface SqlJsOptions {
  /** Where the wasm binary lives. */
  locateFile?: (file: string) => string;
}

/** Opens a legacy project entirely in memory; nothing leaves the machine. */
export async function openLegacyDatabase(bytes: Uint8Array, options: SqlJsOptions = {}): Promise<LegacyDatabase & { close(): void }> {
  const SQL = await initSqlJs(options);
  const db = new SQL.Database(bytes);
  const known = new Set((db.exec("SELECT name FROM sqlite_master WHERE type='table'")[0]?.values ?? []).map((v) => String(v[0])));
  return {
    table(name: string): Row[] {
      if (!known.has(name)) return [];
      const res = db.exec(`SELECT * FROM "${name}"`)[0];
      if (!res) return [];
      return res.values.map((vals) => Object.fromEntries(res.columns.map((c, i) => [c, vals[i]])));
    },
    close: () => db.close(),
  };
}
