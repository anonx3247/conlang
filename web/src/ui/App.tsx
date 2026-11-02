import { useEffect, useState } from 'react';
import { Link, Navigate, NavLink, Outlet, Route, Routes, useLocation, useNavigate } from 'react-router-dom';
import { closeProject, createProject, deleteProject, exportProject, flushSave, openProjectFile, openRecent, reconnectFile, renameProject, restoreSession, saveAsProject, snack, useApp } from '../storage/store';
import { confirmDialog, DialogHost, Icon, IconButton, Menu, openDialog, promptDialog, ResizableDivider, ReportDialog, Snackbar, TextButton, useWidth, type MenuEntry } from './common';
import { GlossaryDrawer, useGlossary } from './glossary';
import { InventoryPage } from './phonology/inventory';
import { NaturalClassesPage } from './phonology/naturalClasses';
import { SoundRulesPage } from './phonology/soundRules';
import { IpaChartPanel } from './phonology/ipaChart';
import { PosDimensionsPage } from './grammar/posDimensions';
import { InflectionsPage } from './grammar/inflections';
import { ConstructionsPage } from './grammar/constructions';
import { TypologyPage } from './grammar/typology';
import { DictionaryPage } from './lexicon/dictionary';
import { SwadeshPage, ThesaurusPage } from './lexicon/references';
import { DerivationsPage } from './lexicon/derivations';
import { ScratchpadPage } from './scratchpad';
import { WelcomeScreen, newProjectFlow } from './welcome';
import { AiToolsDialog } from './aiTools';

const TABS = [
  { label: 'Phonology', icon: 'music_note', path: '/phonology' },
  { label: 'Grammar', icon: 'account_tree', path: '/grammar' },
  { label: 'Lexicon', icon: 'menu_book', path: '/lexicon' },
  { label: 'Scratchpad', icon: 'edit_note', path: '/scratchpad' },
];

// Each tab reopens where it was left.
const lastInTab = new Map<string, string>();

function isMac() {
  return navigator.platform.toLowerCase().includes('mac');
}

function FileStatusBadge() {
  const { fileStatus, saving, registry, projectId } = useApp();
  const entry = registry.find((e) => e.id === projectId);
  const where = fileStatus === 'linked' ? `Saved to ${entry?.fileName ?? 'file'}` : fileStatus === 'needs-permission' ? 'Saved in this browser; file needs reconnecting' : 'Saved in this browser only';
  return (
    <span className="row" style={{ gap: 6 }} title={where}>
      {fileStatus === 'needs-permission' ? (
        <TextButton onClick={() => void reconnectFile()}>Reconnect file</TextButton>
      ) : (
        <Icon name={saving ? 'sync' : fileStatus === 'linked' ? 'description' : 'storage'} size={14} style={{ color: 'var(--on-surface-3)' }} />
      )}
      <Icon name="folder" size={14} style={{ color: 'var(--primary)', opacity: 0.7 }} />
      <span className="small bold muted" data-testid="project-name">{entry?.name}</span>
    </span>
  );
}

function useFileMenu(): MenuEntry[] {
  const { projectId, registry } = useApp();
  const open = !!projectId;
  const recent = registry.slice().sort((a, b) => b.lastOpenedAt.localeCompare(a.lastOpenedAt)).slice(0, 10);
  const mod = isMac() ? '⌘' : 'Ctrl+';
  const rename = async () => {
    const entry = registry.find((e) => e.id === projectId);
    const name = await promptDialog({ title: 'Rename Project', label: 'Project name', initial: entry?.name, confirm: 'Rename' });
    if (name) await renameProject(name);
  };
  const remove = async () => {
    if (!projectId) return;
    const ok = await confirmDialog({ title: 'Delete Project?', body: 'This will permanently delete the project and all its data, including its file if the browser allows it. This action cannot be undone.' });
    if (ok) await deleteProject(projectId);
  };
  return [
    { label: 'New Project...', shortcut: 'Alt+N', onClick: () => void newProjectFlow() },
    { label: 'Open Project...', shortcut: `${mod}O`, onClick: () => void openProjectFile() },
    { separator: true },
    ...(recent.length
      ? recent.map((e) => ({ label: `Open Recent: ${e.name}`, onClick: () => void openRecent(e.id) }))
      : [{ label: 'No Recent Projects', disabled: true }]),
    { separator: true },
    { label: 'Save As...', shortcut: `${isMac() ? '⇧⌘' : 'Ctrl+Shift+'}S`, disabled: !open, onClick: () => void saveAsProject() },
    { label: 'Rename Project...', disabled: !open, onClick: () => void rename() },
    { label: 'Download a Copy', disabled: !open, onClick: exportProject },
    { separator: true },
    { label: 'Close Project', shortcut: 'Alt+W', disabled: !open, onClick: closeProject },
    { label: 'Delete Project...', disabled: !open, danger: true, onClick: () => void remove() },
  ];
}

function editCommand(cmd: 'cut' | 'copy' | 'paste' | 'selectAll') {
  if (cmd === 'paste') {
    void navigator.clipboard.readText().then((t) => document.execCommand('insertText', false, t)).catch(() => snack('Your browser blocked paste here. Use the keyboard shortcut.'));
  } else {
    document.execCommand(cmd);
  }
}

function AppShell() {
  const { projectId } = useApp();
  const location = useLocation();
  const navigate = useNavigate();
  const file = useFileMenu();
  const { open: glossaryOpen, toggle: toggleGlossary } = useGlossary();
  const [glossaryWidth, dragGlossary] = useWidth(320, 240, 500);
  const mod = isMac() ? '⌘' : 'Ctrl+';

  useEffect(() => {
    const tab = TABS.find((t) => location.pathname.startsWith(t.path));
    if (tab) lastInTab.set(tab.path, location.pathname + location.search);
  }, [location]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const m = e.metaKey || e.ctrlKey;
      const k = e.key.toLowerCase();
      if (m && !e.shiftKey && k === 'o') { e.preventDefault(); void openProjectFile(); }
      if (m && e.shiftKey && k === 's' && projectId) { e.preventDefault(); void saveAsProject(); }
      if (m && !e.shiftKey && k === 's') { e.preventDefault(); void flushSave().then(() => snack('Saved.')); }
      if (e.altKey && e.code === 'KeyN') { e.preventDefault(); void newProjectFlow(); }
      if (e.altKey && e.code === 'KeyW' && projectId) { e.preventDefault(); closeProject(); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [projectId]);

  return (
    <div className="app">
      <header className="topbar">
        <Menu label="File" items={file} testId="menu-file" />
        <Menu
          label="Edit"
          items={[
            { label: 'Cut', shortcut: `${mod}X`, onClick: () => editCommand('cut') },
            { label: 'Copy', shortcut: `${mod}C`, onClick: () => editCommand('copy') },
            { label: 'Paste', shortcut: `${mod}V`, onClick: () => editCommand('paste') },
            { label: 'Select All', shortcut: `${mod}A`, onClick: () => editCommand('selectAll') },
          ]}
        />
        <Menu
          label="View"
          items={[
            { label: glossaryOpen ? 'Hide Glossary' : 'Show Glossary', disabled: !projectId, onClick: () => toggleGlossary() },
            { label: 'AI Tools (MCP)...', onClick: () => void openDialog((close) => <AiToolsDialog onClose={() => close()} />) },
          ]}
        />
        <span style={{ width: 12 }} />
        {projectId &&
          TABS.map((t) => (
            <button
              key={t.path}
              type="button"
              className={`tab ${location.pathname.startsWith(t.path) ? 'sel' : ''}`}
              onClick={() => {
                const current = location.pathname.startsWith(t.path);
                navigate(current ? t.path : (lastInTab.get(t.path) ?? t.path));
              }}
            >
              <Icon name={t.icon} size={16} />
              {t.label}
            </button>
          ))}
        <span className="grow" />
        {projectId ? (
          <>
            <IconButton icon="help_outline" title="Glossary" onClick={() => toggleGlossary()} />
            <span style={{ width: 4 }} />
            <FileStatusBadge />
          </>
        ) : (
          <span className="small fainter italic">No project open</span>
        )}
        <span style={{ width: 16 }} />
      </header>
      <div className="main">
        {projectId ? (
          <>
            <div className="grow fill" style={{ display: 'flex' }}><Outlet /></div>
            {glossaryOpen && (
              <>
                <ResizableDivider onDrag={(d) => dragGlossary(-d)} />
                <div style={{ width: glossaryWidth, flex: 'none' }}><GlossaryDrawer /></div>
              </>
            )}
          </>
        ) : (
          <div className="grow"><WelcomeScreen /></div>
        )}
      </div>
    </div>
  );
}

interface SideItem {
  label: string;
  icon: string;
  to: string;
}

function SubShell({ title, items, glossaryCategory, glossaryTip, right }: { title: string; items: SideItem[]; glossaryCategory: string; glossaryTip: string; right?: React.ReactNode }) {
  const [width, drag] = useWidth(200, 140, 320);
  const { openCategory } = useGlossary();
  return (
    <div className="shell">
      <nav className="sidebar" style={{ width }}>
        <div className="sidebar-head">
          {title}
          <IconButton icon="help_outline" title={glossaryTip} size={16} onClick={() => openCategory(glossaryCategory)} />
        </div>
        {items.map((it) => (
          <NavLink key={it.to} to={it.to} className={({ isActive }) => `side-item ${isActive ? 'sel' : ''}`}>
            <Icon name={it.icon} />
            <span className="ellipsis">{it.label}</span>
          </NavLink>
        ))}
      </nav>
      <ResizableDivider onDrag={drag} />
      <div className="page"><Outlet /></div>
      {right}
    </div>
  );
}

function PhonologyShell() {
  const [width, drag] = useWidth(360, 280, 600);
  return (
    <SubShell
      title="PHONOLOGY"
      glossaryCategory="Phonology"
      glossaryTip="Glossary: Phonology terms"
      items={[
        { label: 'Inventory', icon: 'grid_on', to: '/phonology/inventory' },
        { label: 'Natural Classes', icon: 'category', to: '/phonology/natural-classes' },
        { label: 'Sound Rules', icon: 'rule', to: '/phonology/sound-rules' },
      ]}
      right={
        <>
          <ResizableDivider onDrag={(d) => drag(-d)} />
          <aside style={{ width, flex: 'none' }}><IpaChartPanel /></aside>
        </>
      }
    />
  );
}

function GrammarShell() {
  return (
    <SubShell
      title="GRAMMAR"
      glossaryCategory="Morphology"
      glossaryTip="Glossary: Grammar terms"
      items={[
        { label: 'Parts of Speech', icon: 'category', to: '/grammar/pos' },
        { label: 'Inflections', icon: 'auto_fix_high', to: '/grammar/inflections' },
        { label: 'Constructions', icon: 'view_stream', to: '/grammar/constructions' },
        { label: 'Typology', icon: 'language', to: '/grammar/typology' },
      ]}
    />
  );
}

function LexiconShell() {
  return (
    <SubShell
      title="LEXICON"
      glossaryCategory="Semantics"
      glossaryTip="Glossary: Lexicon terms"
      items={[
        { label: 'Dictionary', icon: 'menu_book', to: '/lexicon/dictionary' },
        { label: 'Swadesh List', icon: 'checklist', to: '/lexicon/swadesh' },
        { label: 'Thesaurus', icon: 'category', to: '/lexicon/thesaurus' },
        { label: 'Derivations', icon: 'transform', to: '/lexicon/derivations' },
      ]}
    />
  );
}

function NotFound() {
  const location = useLocation();
  return (
    <div className="center grow">
      <Icon name="error_outline" size={64} />
      <div className="h-title">Page not found</div>
      <div className="muted">{location.pathname}</div>
      <Link className="btn text" to="/grammar/pos">Back to Grammar</Link>
    </div>
  );
}

export function App() {
  const [booted, setBooted] = useState(false);
  useEffect(() => {
    void restoreSession().finally(() => setBooted(true));
  }, []);
  if (!booted) return null;
  return (
    <>
      <Routes>
        <Route element={<AppShell />}>
          <Route index element={<Navigate to="/phonology/inventory" replace />} />
          <Route path="phonology" element={<PhonologyShell />}>
            <Route index element={<Navigate to="inventory" replace />} />
            <Route path="inventory" element={<InventoryPage />} />
            <Route path="natural-classes" element={<NaturalClassesPage />} />
            <Route path="sound-rules" element={<SoundRulesPage />} />
          </Route>
          <Route path="grammar" element={<GrammarShell />}>
            <Route index element={<Navigate to="pos" replace />} />
            <Route path="pos" element={<PosDimensionsPage />} />
            <Route path="inflections" element={<InflectionsPage />} />
            <Route path="constructions" element={<ConstructionsPage />} />
            <Route path="typology" element={<TypologyPage />} />
          </Route>
          <Route path="lexicon" element={<LexiconShell />}>
            <Route index element={<Navigate to="dictionary" replace />} />
            <Route path="dictionary" element={<DictionaryPage />} />
            <Route path="swadesh" element={<SwadeshPage />} />
            <Route path="thesaurus" element={<ThesaurusPage />} />
            <Route path="derivations" element={<DerivationsPage />} />
          </Route>
          <Route path="scratchpad" element={<ScratchpadPage />} />
          <Route path="*" element={<NotFound />} />
        </Route>
      </Routes>
      <DialogHost />
      <Snackbar />
      <ReportDialog />
    </>
  );
}

export { createProject };
