// App state and local persistence. Everything stays on this machine: a browser
// database holds the working copy, and where the browser allows it the project
// also lives in a real file on disk, which is what the MCP server reads.

import { useSyncExternalStore } from 'react';
import { applyCommand, CommandError } from '../core/commands';
import { engineFor, type LanguageEngine } from '../core/engine';
import { importLegacyProject, isSqliteFile } from '../core/legacy/importSqlite';
import { emptyProject, parseProjectReport, serializeProject, type ParsedProject, type ProjectDoc } from '../core/types';

export interface ProjectEntry {
  id: string;
  name: string;
  createdAt: string;
  lastOpenedAt: string;
  fileName: string | null;
}

export type FileStatus = 'none' | 'linked' | 'needs-permission';

export interface AppState {
  registry: ProjectEntry[];
  projectId: string | null;
  doc: ProjectDoc | null;
  fileStatus: FileStatus;
  saving: boolean;
  snack: { id: number; text: string } | null;
  /** Things the user has to read, such as what upgrading a project changed. */
  report: { title: string; lines: string[] } | null;
  ready: boolean;
}

const FILE_TYPES = [{ description: 'Conlang Project', accept: { 'application/json': ['.json'] } }];

export const canUseFiles = typeof window !== 'undefined' && 'showSaveFilePicker' in window;

interface FileHandle extends FileSystemFileHandle {
  queryPermission?(o: { mode: 'readwrite' }): Promise<PermissionState>;
  requestPermission?(o: { mode: 'readwrite' }): Promise<PermissionState>;
  remove?(): Promise<void>;
}

// ---------------------------------------------------------------------------
// IndexedDB
// ---------------------------------------------------------------------------

const DB_NAME = 'conlang-workbench';

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => {
      for (const s of ['registry', 'docs', 'handles']) req.result.createObjectStore(s);
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function idb<T>(store: string, mode: IDBTransactionMode, fn: (s: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  const db = await openDb();
  return new Promise<T>((resolve, reject) => {
    const req = fn(db.transaction(store, mode).objectStore(store));
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

const dbGet = <T,>(store: string, key: string) => idb<T | undefined>(store, 'readonly', (s) => s.get(key));
const dbPut = (store: string, key: string, value: unknown) => idb(store, 'readwrite', (s) => s.put(value, key));
const dbDel = (store: string, key: string) => idb(store, 'readwrite', (s) => s.delete(key));
const dbAll = <T,>(store: string) => idb<T[]>(store, 'readonly', (s) => s.getAll());

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

let state: AppState = { registry: [], projectId: null, doc: null, fileStatus: 'none', saving: false, snack: null, report: null, ready: false };
const listeners = new Set<() => void>();
let snackCounter = 0;
let saveTimer: ReturnType<typeof setTimeout> | null = null;
let pollTimer: ReturnType<typeof setInterval> | null = null;
let handle: FileHandle | null = null;
let lastSynced = { text: '', modified: 0 };

function set(patch: Partial<AppState>) {
  state = { ...state, ...patch };
  listeners.forEach((l) => l());
}

function subscribe(l: () => void) {
  listeners.add(l);
  return () => listeners.delete(l);
}

export function useApp(): AppState {
  return useSyncExternalStore(subscribe, () => state);
}

export function useDoc(): ProjectDoc {
  const { doc } = useApp();
  if (!doc) throw new Error('No project open');
  return doc;
}

export function useEngine(): LanguageEngine {
  return engineFor(useDoc());
}

export function getEngine(): LanguageEngine {
  if (!state.doc) throw new Error('No project open');
  return engineFor(state.doc);
}

export function snack(text: string) {
  set({ snack: { id: ++snackCounter, text } });
}

export function clearSnack() {
  set({ snack: null });
}

export function clearReport() {
  set({ report: null });
}

/** After opening a project in an older format: tells the user what changed and saves the new format. */
function finishUpgrade(parsed: ParsedProject) {
  if (!parsed.migrated) return;
  if (parsed.warnings.length) set({ report: { title: `${parsed.doc.name} was upgraded`, lines: parsed.warnings } });
  scheduleSave();
}

/** Applies a command. A CommandError is shown to the user and returns undefined. */
export function run<T>(command: (d: ProjectDoc) => T): T | undefined {
  try {
    return mutate(command);
  } catch (e) {
    if (e instanceof CommandError) {
      snack(e.message);
      return undefined;
    }
    throw e;
  }
}

/** Applies a command and lets errors reach the caller, for inline form errors. */
export function mutate<T>(command: (d: ProjectDoc) => T): T {
  if (!state.doc) throw new Error('No project open');
  const { doc, result } = applyCommand(state.doc, command);
  set({ doc });
  scheduleSave();
  return result;
}

function scheduleSave() {
  set({ saving: true });
  if (saveTimer) clearTimeout(saveTimer);
  saveTimer = setTimeout(() => void flushSave(), 300);
}

export async function flushSave() {
  if (saveTimer) clearTimeout(saveTimer);
  saveTimer = null;
  const { doc, projectId } = state;
  if (!doc || !projectId) return;
  const text = serializeProject(doc);
  await dbPut('docs', projectId, text);
  if (handle && state.fileStatus === 'linked') {
    try {
      await writeHandle(handle, text);
    } catch {
      set({ fileStatus: 'needs-permission' });
      snack('Could not write the project file. Your work is safe in this browser; use Reconnect file.');
    }
  }
  set({ saving: false });
}

async function writeHandle(h: FileHandle, text: string) {
  const w = await h.createWritable();
  await w.write(text);
  await w.close();
  const f = await h.getFile();
  lastSynced = { text, modified: f.lastModified };
}

/** Picks up edits made to the file outside the app, such as by the MCP server. */
async function pollFile() {
  if (!handle || state.fileStatus !== 'linked' || saveTimer) return;
  try {
    const f = await handle.getFile();
    if (f.lastModified === lastSynced.modified) return;
    const text = await f.text();
    const parsed = parseProjectReport(text);
    lastSynced = { text, modified: f.lastModified };
    if (text === serializeProject(state.doc!)) return;
    set({ doc: parsed.doc });
    await dbPut('docs', state.projectId!, text);
    snack('Project updated from file.');
    finishUpgrade(parsed);
  } catch {
    // Unreadable or mid-write: the next poll tries again.
  }
}

async function updateEntry(id: string, patch: Partial<ProjectEntry>) {
  const entry = state.registry.find((e) => e.id === id);
  if (!entry) return;
  const next = { ...entry, ...patch };
  await dbPut('registry', id, next);
  set({ registry: state.registry.map((e) => (e.id === id ? next : e)) });
}

async function loadRegistry() {
  const all = await dbAll<ProjectEntry>('registry');
  set({ registry: all, ready: true });
}

function newProjectId() {
  return Date.now().toString(36).padStart(10, '0') + Math.floor(Math.random() * 1296).toString(36);
}

async function activate(id: string, doc: ProjectDoc, h: FileHandle | null, status: FileStatus) {
  handle = h;
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = h ? setInterval(() => void pollFile(), 1500) : null;
  if (h && status === 'linked') {
    const f = await h.getFile();
    lastSynced = { text: await f.text(), modified: f.lastModified };
  }
  sessionStorage.setItem('conlang.openProject', id);
  set({ projectId: id, doc, fileStatus: status, saving: false });
  await updateEntry(id, { lastOpenedAt: new Date().toISOString(), name: doc.name });
}

async function register(doc: ProjectDoc, h: FileHandle | null): Promise<string> {
  const id = newProjectId();
  const now = new Date().toISOString();
  const entry: ProjectEntry = { id, name: doc.name, createdAt: doc.createdAt, lastOpenedAt: now, fileName: h?.name ?? null };
  await dbPut('registry', id, entry);
  await dbPut('docs', id, serializeProject(doc));
  if (h) await dbPut('handles', id, h);
  set({ registry: [...state.registry, entry] });
  return id;
}

function suggestedFileName(name: string) {
  return `${name.replace(/[/\\:*?"<>|]/g, '').trim() || 'MyLanguage'}.conlang.json`;
}

function isAbort(e: unknown) {
  return e instanceof DOMException && e.name === 'AbortError';
}

// ---------------------------------------------------------------------------
// Project actions
// ---------------------------------------------------------------------------

/** Creates a project. On supporting browsers the user picks where its file lives. */
export async function createProject(name: string): Promise<void> {
  const clean = name.trim() || 'My Language';
  await flushSave();
  const doc = emptyProject(clean);
  let h: FileHandle | null = null;
  if (canUseFiles) {
    try {
      h = (await window.showSaveFilePicker({ suggestedName: suggestedFileName(clean), types: FILE_TYPES })) as FileHandle;
      await writeHandle(h, serializeProject(doc));
    } catch (e) {
      if (isAbort(e)) return;
      throw e;
    }
  }
  const id = await register(doc, h);
  await activate(id, doc, h, h ? 'linked' : 'none');
}

/** Reads a chosen file: a JSON project, or a legacy SQLite project to convert. */
async function docFromFile(file: File): Promise<ParsedProject & { legacy: boolean }> {
  const bytes = new Uint8Array(await file.arrayBuffer());
  if (isSqliteFile(bytes)) {
    const { openLegacyDatabase } = await import('../core/legacy/sqlJsAdapter');
    const db = await openLegacyDatabase(bytes, { locateFile: () => '/sql-wasm.wasm' });
    const { doc, warnings } = importLegacyProject(db, file.name.replace(/\.conlang$/i, ''));
    db.close();
    return { doc, warnings, migrated: false, legacy: true };
  }
  return { ...parseProjectReport(new TextDecoder().decode(bytes)), legacy: false };
}

async function pickFile(): Promise<{ file: File; handle: FileHandle | null } | null> {
  if (canUseFiles) {
    try {
      const [h] = await window.showOpenFilePicker({ types: [{ description: 'Conlang Project', accept: { 'application/json': ['.json'], 'application/octet-stream': ['.conlang'] } }] });
      return { file: await h.getFile(), handle: h as FileHandle };
    } catch (e) {
      if (isAbort(e)) return null;
      throw e;
    }
  }
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json,.conlang';
    input.onchange = () => resolve(input.files?.[0] ? { file: input.files[0], handle: null } : null);
    input.oncancel = () => resolve(null);
    input.click();
  });
}

export async function openProjectFile(): Promise<void> {
  const picked = await pickFile();
  if (!picked) return;
  await openChosenFile(picked.file, picked.handle);
}

/** Opens a File object. Exported for drag-and-drop style callers and tests. */
export async function openChosenFile(file: File, h: FileHandle | null): Promise<void> {
  try {
    await flushSave();
    const parsed = await docFromFile(file);
    const { doc, warnings, legacy } = parsed;
    let link = legacy ? null : h;
    if (link?.requestPermission && (await link.requestPermission({ mode: 'readwrite' })) !== 'granted') link = null;
    if (legacy && canUseFiles) {
      try {
        link = (await window.showSaveFilePicker({ suggestedName: suggestedFileName(doc.name), types: FILE_TYPES })) as FileHandle;
        await writeHandle(link, serializeProject(doc));
      } catch (e) {
        if (!isAbort(e)) throw e;
        link = null;
      }
    }
    if (link) {
      for (const entry of state.registry) {
        const existing = await dbGet<FileHandle>('handles', entry.id);
        if (existing && (await existing.isSameEntry(link))) {
          await activate(entry.id, doc, link, 'linked');
          finishUpgrade(parsed);
          return;
        }
      }
    }
    const id = await register(doc, link);
    await activate(id, doc, link, link ? 'linked' : 'none');
    if (legacy && warnings.length) set({ report: { title: `Imported ${doc.name}. The original file was not changed.`, lines: warnings } });
    else if (legacy) snack(`Imported ${doc.name}. The original file was not changed.`);
    finishUpgrade(parsed);
  } catch (e) {
    snack(`Failed to open project: ${(e as Error).message}`);
  }
}

export async function openRecent(id: string): Promise<void> {
  await flushSave();
  const text = await dbGet<string>('docs', id);
  const h = (await dbGet<FileHandle>('handles', id)) ?? null;
  let parsed = text ? parseProjectReport(text) : null;
  let status: FileStatus = 'none';
  if (h) {
    try {
      const perm = (await h.requestPermission?.({ mode: 'readwrite' })) ?? 'granted';
      if (perm === 'granted') {
        parsed = parseProjectReport(await (await h.getFile()).text());
        status = 'linked';
      } else {
        status = 'needs-permission';
      }
    } catch {
      status = 'needs-permission';
    }
  }
  if (!parsed) {
    const name = state.registry.find((e) => e.id === id)?.name ?? 'project';
    snack(`Cannot open "${name}": its data was not found.`);
    await forget(id);
    return;
  }
  await activate(id, parsed.doc, h, status);
  finishUpgrade(parsed);
  if (status === 'needs-permission') snack('Opened the copy saved in this browser. Use Reconnect file to sync with the file.');
}

/** Silently restores the project open before a page reload. */
export async function restoreSession() {
  await loadRegistry();
  const id = sessionStorage.getItem('conlang.openProject');
  if (!id || !state.registry.some((e) => e.id === id)) return;
  const text = await dbGet<string>('docs', id);
  if (!text) return;
  const h = (await dbGet<FileHandle>('handles', id)) ?? null;
  let status: FileStatus = 'none';
  if (h) status = (await h.queryPermission?.({ mode: 'readwrite' })) === 'granted' ? 'linked' : 'needs-permission';
  const parsed = parseProjectReport(text);
  await activate(id, parsed.doc, h, status);
  finishUpgrade(parsed);
}

export async function reconnectFile() {
  if (!handle || !state.doc) return;
  const perm = (await handle.requestPermission?.({ mode: 'readwrite' })) ?? 'granted';
  if (perm !== 'granted') return;
  set({ fileStatus: 'linked' });
  await writeHandle(handle, serializeProject(state.doc));
  snack('Reconnected to file.');
}

export function closeProject() {
  void flushSave();
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = null;
  handle = null;
  sessionStorage.removeItem('conlang.openProject');
  set({ projectId: null, doc: null, fileStatus: 'none' });
}

export async function saveAsProject(): Promise<void> {
  if (!state.doc) return;
  await flushSave();
  let h: FileHandle | null = null;
  if (canUseFiles) {
    try {
      h = (await window.showSaveFilePicker({ suggestedName: suggestedFileName(state.doc.name), types: FILE_TYPES })) as FileHandle;
    } catch (e) {
      if (isAbort(e)) return;
      snack(`Save As failed: ${(e as Error).message}`);
      return;
    }
  }
  const doc = structuredClone(state.doc);
  if (h) await writeHandle(h, serializeProject(doc));
  else doc.name = `${doc.name} copy`;
  const id = await register(doc, h);
  await activate(id, doc, h, h ? 'linked' : 'none');
}

export async function renameProject(name: string) {
  const clean = name.trim();
  if (!clean) return;
  mutate((d) => {
    d.name = clean;
  });
  if (state.projectId) await updateEntry(state.projectId, { name: clean });
}

/** Removes a project from this browser, and its file where permitted. */
export async function deleteProject(id: string) {
  const h = await dbGet<FileHandle>('handles', id);
  if (id === state.projectId) closeProject();
  try {
    await h?.remove?.();
  } catch {
    snack('The project was removed from the app, but its file could not be deleted.');
  }
  await forget(id);
}

async function forget(id: string) {
  await dbDel('registry', id);
  await dbDel('docs', id);
  await dbDel('handles', id);
  set({ registry: state.registry.filter((e) => e.id !== id) });
}

export function downloadBytes(name: string, bytes: Uint8Array | string, type = 'application/octet-stream') {
  const url = URL.createObjectURL(new Blob([bytes as BlobPart], { type }));
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}

/** Saves a copy of the current project through the browser's download. */
export function exportProject() {
  if (!state.doc) return;
  downloadBytes(suggestedFileName(state.doc.name), serializeProject(state.doc), 'application/json');
}

/** Saves bytes through a file picker when available, else a download. */
export async function saveBytesAs(name: string, bytes: Uint8Array, description: string, extension: string): Promise<boolean> {
  if (canUseFiles) {
    try {
      const h = await window.showSaveFilePicker({ suggestedName: name, types: [{ description, accept: { 'application/octet-stream': [extension] } }] });
      const w = await h.createWritable();
      await w.write(bytes as BlobPart);
      await w.close();
      return true;
    } catch (e) {
      if (isAbort(e)) return false;
      throw e;
    }
  }
  downloadBytes(name, bytes);
  return true;
}

if (typeof window !== 'undefined') {
  window.addEventListener('beforeunload', () => void flushSave());
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) void flushSave();
    else void pollFile();
  });
}

/** Page state that should survive moving between tabs, reset per project. */
const uiMemory = new Map<string, unknown>();
let uiMemoryProject: string | null = null;
export function uiGet<T>(key: string, initial: T): T {
  if (uiMemoryProject !== state.projectId) {
    uiMemory.clear();
    uiMemoryProject = state.projectId;
  }
  return (uiMemory.has(key) ? uiMemory.get(key) : initial) as T;
}
export function uiSet(key: string, value: unknown) {
  uiMemory.set(key, value);
}
