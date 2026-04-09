# Phase 3: Lexicon - Research

**Researched:** 2026-04-09
**Domain:** Flutter/Drift lexicon UI, Anki .apkg export, phonotactic validation, Swadesh list, Conlanger's Thesaurus
**Confidence:** HIGH (codebase verified), MEDIUM (Anki schema)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Dictionary layout**
- D-01: Master-detail layout — scrollable word list on the left, detail panel on the right
- D-02: Word list supports a table view toggle (spreadsheet-style, sortable columns)
- D-03: POS filter chips/dropdown in the master panel
- D-04: Word list shows only root entries; derived forms appear in the detail panel
- D-05: Derivation chain as visual tree diagram in detail panel; irregular/exception forms in amber/orange
- D-06: New root words added via inline form in the detail panel ("+ New root" button). Fields: IPA, romanization, meaning, POS
- D-07: When romanization is enabled, romanized form is the primary input; IPA auto-derived from reverse romanization mappings; IPA field still manually editable
- D-08: Word generator "inspiration panel" shown alongside the word creation form; generates phonotactically valid candidates; clickable to fill IPA/romanization field

**Search & filtering**
- D-09: Instant client-side filter (no FTS5). Typing instantly filters visible list
- D-10: Searchable fields: meaning/gloss, IPA/romanization, part of speech
- D-11: Search matches roots and derived words; when a derived word matches, its root appears with the derived form highlighted in detail panel

**Semantic references**
- D-12: Lexicon sidebar has three sub-nav items: Dictionary, Swadesh List, Thesaurus
- D-13: Swadesh list as checklist of ~207 concepts; checked/green when matched; "Create" for unchecked; coverage progress shown
- D-14: Conlanger's Thesaurus as browsable hierarchical category tree; pre-extracted from PDF into bundled JSON
- D-15: Thesaurus tree has a search/filter bar
- D-16: Clicking "Create" from Swadesh/Thesaurus opens inline word creation form with meaning pre-filled

**Anki export**
- D-17: Card fields: front = IPA + romanization (if enabled); back = meaning/gloss; additional: POS, morphological context for derived words
- D-18: Selection-based export — user selects specific words (or "select all"), then exports as .apkg
- D-19: No audio field (TTS is v2 scope)

**Exception UI (carried from Phase 2)**
- D-20: Per-word exception management lives on the word detail page
- D-21: Schema and DAO already complete from Phase 2 — this phase adds the UI only

### Claude's Discretion
- Table view column configuration and sort behavior
- Exact word generator panel placement relative to the creation form
- Swadesh list data source and format (standard 207-item list)
- Thesaurus JSON extraction approach from fiatlingua.org PDF
- Empty state designs for new/empty lexicons
- How "select for export" works in the UI (checkboxes, multi-select, etc.)

### Deferred Ideas (OUT OF SCOPE)
- Paradigm tables / conjugation charts — Phase 4 (GRAM-03)
- Phonetic pattern search (e.g. "words ending in nasal", CVC structure)
- FTS5 full-text search — add if lexicon exceeds ~10k words
- Audio field on Anki cards — TTS is v2 scope

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LEX-01 | User can add, edit, and delete root words with meaning, POS, and IPA transcription | Lexemes table exists (ipa, romanization, meaning, partOfSpeech columns); LexemeDao to be created in 03-01; inline form in detail panel (D-06) |
| LEX-02 | User can view derived words from roots via morphological rules, with etymology tracing | MorphologyEngine.applyRule() already works; LexemeDao queries rootId chain; derivation tree widget in detail panel (D-05) |
| LEX-03 | User can search and filter by meaning, root, POS, or phonetic pattern | Client-side instant filter (D-09); searchable fields: meaning, IPA/romanization, POS (D-10); derived match bubbles root to list (D-11) |
| LEX-04 | User can reference the built-in Swadesh list | Bundled 207-item JSON asset; checklist UI with coverage progress (D-13) |
| LEX-05 | User can reference the integrated Conlanger's Thesaurus | Pre-extracted JSON from PDF bundled as asset; hierarchical tree UI (D-14) |
| LEX-06 | User can export vocabulary as Anki .apkg flashcards | archive 4.0.9 + sqlite3 2.9.4 already transitive deps; hand-build .apkg (zip of SQLite + media JSON); selection-based (D-18) |
| LEX-07 | User can generate new words that follow phonotactic constraints | WordGeneratorPanel already exists; adapt into "inspiration panel" (D-08) |
| PHON-05 | Words that violate phonotactics appear highlighted in red throughout the tool | WordGenerator.validateWord() + _ViolationText widget already exist in phonology; reuse for lexicon display; per-word exception toggle in word detail |

</phase_requirements>

---

## Summary

Phase 3 builds on a well-prepared foundation. The database schema (`Lexemes` table, `MorphologicalRuleExceptions` table, `PartsOfSpeech` table) is complete from prior phases. The morphology engine, phonotactic validation, word generator panel, and IPA keyboard widgets are all implemented and reusable. The main new work falls into five areas: (1) a LexemeDao and reactive providers, (2) the master-detail UI with derivation tree, (3) bundled Swadesh list and Thesaurus JSON assets with browsing UIs, (4) the Anki .apkg builder, and (5) phonotactic violation highlighting wired throughout the lexicon.

The most research-intensive item is the Anki .apkg export. No existing Dart library provides a clean hand-off — the `dart_anki` library is unmaintained. The correct approach is to hand-build a `.apkg` from scratch: the format is a ZIP containing a `collection.anki21` SQLite database (written with the `sqlite3` package, already a transitive dep) and a `media` JSON file, plus a `media` folder (empty for no-audio decks). The `archive` 4.0.9 package (also already a transitive dep) handles the ZIP encoding. This avoids adding new dependencies entirely.

The Conlanger's Thesaurus PDF (fiatlingua.org) cannot be parsed at runtime from PDF format. It must be pre-extracted to JSON and bundled as an asset. This extraction is a one-time manual/scripted task that must happen before or as part of Wave 0 (setup). The structure is a hierarchical category tree (semantic domains → subcategories → leaf concepts with notes on grammaticalization and polysemy).

**Primary recommendation:** No new pub dependencies needed. Use existing transitive `sqlite3` + `archive` packages for Anki export, existing `WordGenerator` + `_ViolationText` for phonotactic highlighting, and existing `WordGeneratorPanel` for the inspiration panel. All data layer work follows the established Drift DAO + manual Riverpod StreamProvider pattern.

---

## Standard Stack

### Core (all already in pubspec.yaml)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| drift | 2.30.0 | LexemeDao, reactive streams | Established pattern from Phases 1-2 |
| flutter_riverpod | 3.0.3 | lexemeListProvider, derivedWordsProvider | Established pattern; manual providers for Drift types |
| go_router | 17.2.0 | LexiconShell + sub-routes | Established StatefulShellRoute pattern |

### Supporting (transitive — no pubspec.yaml edit needed)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| sqlite3 | 2.9.4 | Write collection.anki21 SQLite DB in memory for Anki export | Anki .apkg builder only |
| archive | 4.0.9 | ZIP encode the .apkg file (SQLite + media JSON) | Anki .apkg builder only |

[VERIFIED: `flutter pub deps` shows `sqlite3 2.9.4` and `archive 4.0.9` as transitive dependencies of drift/drift_flutter]

### No New Dependencies Required

The entire phase can be implemented without adding any entry to `pubspec.yaml`. All required capabilities (SQLite, ZIP, phoneme validation, word generation, IPA keyboard) are already present in the dependency graph.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-built .apkg | dart_anki library | dart_anki has 2 commits, no active maintenance, parsing-focused not creation-focused — avoid |
| Bundled JSON for Thesaurus | Runtime PDF parse | Flutter has no PDF text-extraction library; PDF is binary-encoded — bundled JSON is only option |
| Client-side filter | FTS5 virtual table | FTS5 requires schema migration + more complex queries; deferred per D-09; adequate for <10k words |

---

## Architecture Patterns

### Recommended Project Structure

```
lib/features/lexicon/
├── data/
│   ├── lexeme_dao.dart          # Drift DAO for Lexemes + exceptions
│   ├── lexeme_providers.dart    # StreamProviders + derived word computation
│   └── anki_exporter.dart       # .apkg builder (sqlite3 + archive)
├── domain/
│   └── lexeme_model.dart        # Optional: view-model for root+derived bundle
├── presentation/
│   ├── lexicon_shell.dart       # Sidebar (Dictionary, Swadesh, Thesaurus) + nested navigator
│   ├── dictionary/
│   │   ├── dictionary_page.dart        # Master-detail scaffold
│   │   ├── word_list_panel.dart        # Scrollable root list + search bar + POS filter
│   │   ├── word_detail_panel.dart      # Detail: IPA, meaning, tree, exceptions, export checkbox
│   │   ├── word_creation_form.dart     # Inline "+ New root" form
│   │   └── derivation_tree_widget.dart # Visual tree of derived forms
│   ├── swadesh/
│   │   └── swadesh_page.dart    # 207-item checklist with coverage progress
│   └── thesaurus/
│       └── thesaurus_page.dart  # Hierarchical category tree + search
```

```
assets/
├── ipa_audio/           # Phase 1 (existing)
├── swadesh_list.json    # 207 Swadesh items — add in Wave 0
└── conlangers_thesaurus.json  # Pre-extracted hierarchy — add in Wave 0
```

### Pattern 1: Drift DAO for Lexemes

Follow the established `DatabaseAccessor<AppDatabase>` pattern. The `LexemeDao` needs:
- `watchRoots()` — all lexemes where `rootId IS NULL`, ordered by IPA
- `watchDerivedForms(int rootId)` — all lexemes where `rootId = ?`
- `insertLexeme`, `updateLexeme`, `deleteLexeme`
- `watchAllLexemes()` — for violation scanning across entire lexicon

```dart
// Source: established pattern in lib/features/morphology/data/morphology_dao.dart
@DriftAccessor(tables: [Lexemes, MorphologicalRuleExceptions])
class LexemeDao extends DatabaseAccessor<AppDatabase>
    with _$LexemeDaoMixin {
  LexemeDao(super.db);

  Stream<List<Lexeme>> watchRoots() =>
      (select(lexemes)
        ..where((t) => t.rootId.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.ipa)]))
          .watch();

  Stream<List<Lexeme>> watchDerivedForms(String rootId) =>
      (select(lexemes)
        ..where((t) => t.rootId.equals(rootId)))
          .watch();
}
```

Note: `rootId` is stored as `TEXT` (nullable string) in the schema, not `INTEGER`. The FK is informal — query by string equality.

### Pattern 2: Manual Riverpod Providers for Drift Types

Do NOT use `@riverpod` codegen for any provider that references Drift-generated types (`Lexeme`, `LexemesCompanion`). Use plain `Provider` / `StreamProvider`.

```dart
// Source: established pattern in lib/features/phonology/data/phonotactic_providers.dart
final lexemeDaoProvider = Provider<LexemeDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db?.lexemeDao;
});

final rootLexemeListProvider = StreamProvider<List<Lexeme>>((ref) {
  final dao = ref.watch(lexemeDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchRoots();
});
```

### Pattern 3: LexiconShell mirrors MorphologyShell

Create `LexiconShell` following `MorphologyShell` exactly — left sidebar (~200px) + main content area. Three sidebar items: Dictionary (`/lexicon/dictionary`), Swadesh (`/lexicon/swadesh`), Thesaurus (`/lexicon/thesaurus`).

Router migration: replace the placeholder `_ComingSoonPage(section: 'Lexicon')` at `/lexicon` branch with a nested `StatefulShellRoute.indexedStack` for the three sub-routes. Enable the Lexicon tab in `AppShell._tabs`.

```dart
// Source: app_router.dart line 131-138 (current placeholder to replace)
// Branch 2: Lexicon — replace _ComingSoonPage with LexiconShell
StatefulShellBranch(
  routes: [
    GoRoute(path: '/lexicon', redirect: (_, _) => '/lexicon/dictionary'),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => LexiconShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/lexicon/dictionary', builder: (_, _) => const DictionaryPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/lexicon/swadesh', builder: (_, _) => const SwadeshPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/lexicon/thesaurus', builder: (_, _) => const ThesaurusPage()),
        ]),
      ],
    ),
  ],
),
```

### Pattern 4: Client-Side Filtering

Use a `StateProvider<String>` for the search query and `StateProvider<String?>` for the POS filter. Compute the filtered list in a `Provider` derived from `rootLexemeListProvider` + the filter state.

```dart
final lexemeSearchQueryProvider = StateProvider<String>((ref) => '');
final lexemePosFilterProvider = StateProvider<String?>((ref) => null);

final filteredLexemeListProvider = Provider<List<Lexeme>>((ref) {
  final roots = ref.watch(rootLexemeListProvider).asData?.value ?? [];
  final query = ref.watch(lexemeSearchQueryProvider).toLowerCase();
  final pos = ref.watch(lexemePosFilterProvider);
  // filter by query (ipa, romanization, meaning) and pos
  return roots.where((l) {
    final matchesQuery = query.isEmpty ||
        (l.ipa.toLowerCase().contains(query)) ||
        (l.romanization?.toLowerCase().contains(query) ?? false) ||
        (l.meaning?.toLowerCase().contains(query) ?? false);
    final matchesPos = pos == null || l.partOfSpeech == pos;
    return matchesQuery && matchesPos;
  }).toList();
});
```

For derived-word search hits (D-11): when the search query matches a derived form, root still appears in the list. This requires a separate `derivedMatchProvider` that scans all non-root lexemes — only trigger when query is non-empty to avoid full-scan cost.

### Pattern 5: Anki .apkg Builder

The `.apkg` format is a ZIP containing:
1. `collection.anki21` — SQLite database (schema v15+)
2. `media` — JSON object mapping media indices to filenames (empty `{}` for no-audio decks)

Build process using already-present transitive dependencies:

```dart
// Step 1: Create in-memory SQLite via sqlite3 package
final db = sqlite3.openInMemory();
db.execute('CREATE TABLE col (id INTEGER PRIMARY KEY, ..., models TEXT, decks TEXT, ...)');
db.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY, guid TEXT, mid INTEGER, mod INTEGER, usn INTEGER, tags TEXT, flds TEXT, sfld INTEGER, csum INTEGER, flags INTEGER, data TEXT)');
db.execute('CREATE TABLE cards (id INTEGER PRIMARY KEY, nid INTEGER, did INTEGER, ord INTEGER, mod INTEGER, usn INTEGER, type INTEGER, queue INTEGER, due INTEGER, ivl INTEGER, factor INTEGER, reps INTEGER, lapses INTEGER, left INTEGER, odue INTEGER, odid INTEGER, flags INTEGER, data TEXT)');
// Insert col row with models JSON (note type definition) and decks JSON
// Insert one notes row per exported lexeme
// Insert one cards row per note
final dbBytes = db.userVersion; // export bytes via serialize
db.dispose();

// Step 2: Build ZIP with archive package
final archive = Archive();
archive.addFile(ArchiveFile('collection.anki21', dbBytes.length, dbBytes));
archive.addFile(ArchiveFile('media', 2, utf8.encode('{}')));
final zipBytes = ZipEncoder().encode(archive);
// Write zipBytes to file with .apkg extension
```

[ASSUMED] The exact `sqlite3.openInMemory()` + serialize API — verify against sqlite3 2.9.4 docs before implementation. The pattern above reflects the standard sqlite3 Dart package API.

### Pattern 6: Phonotactic Violation Highlighting

The `_ViolationText` widget and `WordGenerator.validateWord()` already exist in `lib/features/phonology/`. Extract `_ViolationText` to a shared location (`lib/shared/widgets/violation_text.dart`) so it can be used in the lexicon without duplicating code. The phonotactic scan for a single word:

```dart
// Source: lib/features/phonology/presentation/sound_rules/word_generator_panel.dart (lines 161-165)
final validation = WordGenerator().validateWord(
  word: lexeme.ipa,
  constraints: constraints,  // from parsedConstraintsProvider
  inventory: inventory,       // from phonemeInventoryProvider
);
```

For the per-word exception toggle (D-20, D-21): the `MorphologicalRuleExceptions` schema is already ready. Add a simple UI on the word detail panel — a "Mark as exception" button that stores a special sentinel exception entry OR (preferred) add a dedicated `isPhonologicalException` boolean column to the `Lexemes` table in a schema v7 migration.

**Decision needed:** The existing `MorphologicalRuleExceptions` table is designed for morphological rule exceptions, not phonological ones. PHON-05 requires a separate "mark word as phonotactic exception" mechanism. Options:
- Add `is_phonological_exception BOOLEAN DEFAULT 0` to `Lexemes` (schema v7) — cleanest
- Use a separate table — overkill for a boolean flag

The planner should pick the `Lexemes` column approach.

### Pattern 7: Derivation Tree Widget

The derivation tree displays root → level-1 derived → level-2 derived chains. Use a recursive widget that calls `watchDerivedForms(rootId)`. Limit recursion depth to 3 levels for performance (per DB schema: `rootId` is the immediate parent only, so multi-level chains require sequential lookups). Irregular/exception forms shown in `Colors.orange` per D-05.

### Anti-Patterns to Avoid

- **Using riverpod_generator (@riverpod) for Drift type providers:** Causes `InvalidTypeException` at build time. Use manual `Provider` / `StreamProvider`.
- **Nesting GoRouter routes as children rather than branches for lexicon sub-sections:** Use `StatefulShellRoute.indexedStack` for the three sidebar items — preserves scroll position and state.
- **Using FTS5 for search:** Deferred per D-09. Client-side filter is correct for Phase 3.
- **Parsing the Thesaurus PDF at runtime:** No Dart PDF text-extraction library available; must be pre-extracted to JSON asset.
- **Adding dart_anki library:** Unmaintained; hand-build .apkg instead.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ZIP archive creation | Custom ZIP byte writer | `archive` 4.0.9 (already transitive dep) | ZipEncoder handles deflate, CRC32, central directory |
| In-memory SQLite | Custom binary writer | `sqlite3` 2.9.4 (already transitive dep) | Full SQL interface, serialize to bytes |
| IPA keyboard input | New keyboard popup | `IpaTextField` from Phase 1 | Already exists, tested, handles overlay lifecycle |
| Word generation | New generator | `WordGenerator` + `WordGeneratorPanel` from Phase 1 | Already exists with phonotactic validation |
| Violation text rendering | New RichText builder | Extract `_ViolationText` from `word_generator_panel.dart` | Already implemented with wavy underline, span building |
| POS list | New fetch logic | `watchAllPos()` from `MorphologyDao` | Already returns `PartsOfSpeechData` stream |

---

## Runtime State Inventory

Phase 3 is a new feature addition, not a rename/refactor/migration. No runtime state inventory is needed.

**Step 2.5: SKIPPED** — No renames, no string replacements, no data migrations. The Lexemes table already exists in the schema with all needed columns. Schema version will bump to v7 only to add `isPhonologicalException` to Lexemes (see Pattern 6 above).

---

## Environment Availability Audit

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All UI work | Yes | 3.38.5 | — |
| Dart SDK | All code | Yes | 3.10.4 | — |
| archive (transitive) | Anki .apkg ZIP | Yes | 4.0.9 | — |
| sqlite3 (transitive) | Anki .apkg SQLite | Yes | 2.9.4 | — |
| fiatlingua.org Thesaurus PDF | Asset extraction | Manual task | — | Hand-author minimal JSON (risk) |

**Missing dependencies with no fallback:**
- None that block code execution.

**Missing dependencies with fallback:**
- Conlanger's Thesaurus JSON extraction is a one-time manual task that must be done before or as part of Wave 0 plan 03-03. If the PDF proves unextractable programmatically, a hand-authored summary JSON (~50 top-level categories) is an acceptable fallback for v1.

[VERIFIED: `flutter pub deps` grep confirms archive 4.0.9 and sqlite3 2.9.4 are present]

---

## Common Pitfalls

### Pitfall 1: rootId is TEXT not INTEGER in Lexemes

**What goes wrong:** Developers assume `rootId` is an integer FK and write `t.rootId.equals(someInt)`.
**Why it happens:** The schema comment says "ID as string for flexibility" — `rootId TEXT nullable`.
**How to avoid:** Query with `t.rootId.equals(id.toString())` and parse back with `int.tryParse()`.
**Warning signs:** Drift type error on `IntColumn` operations against `rootId`.

[VERIFIED: `app_database.dart` line 158: `TextColumn get rootId => text().nullable()()`]

### Pitfall 2: Drift DAO must be registered in AppDatabase

**What goes wrong:** `LexemeDao` is created but `AppDatabase` does not reference it — `db.lexemeDao` throws NoSuchMethodError.
**Why it happens:** Drift requires DAOs to be listed in `@DriftDatabase(daos: [...])` AND as getter methods in the database class.
**How to avoid:** Add `LexemeDao` to both the `@DriftDatabase` annotation's `daos:` list and add a `LexemeDao get lexemeDao => LexemeDao(this);` getter to `AppDatabase`. Regenerate with `build_runner`.

[VERIFIED: `app_database.dart` line 182 shows existing daos list pattern]

### Pitfall 3: AppShell tab still disabled after adding routes

**What goes wrong:** The Lexicon tab remains greyed out and unclickable even after routes are wired.
**Why it happens:** `AppShell._tabs` has `enabled: false` for the Lexicon tab — must be changed to `enabled: true, phase: null`.
**How to avoid:** Update `_tabs` in `app_shell.dart` as part of the router migration plan.

[VERIFIED: `app_shell.dart` line 26: `_TabItem(label: 'Lexicon', ..., enabled: false, phase: 'Phase 3')`]

### Pitfall 4: Anki collection.anki21 requires specific col table JSON

**What goes wrong:** The `col` table row is missing required JSON keys in `models` or `decks` fields — Anki silently fails to import or shows empty deck.
**Why it happens:** The `col` row JSON has undocumented required fields (`sortf`, `latexPre`, `latexPost`, `req` on models; `conf`, `extendNew`, etc. on decks).
**How to avoid:** Use the minimal confirmed schema: one `col` row with a model that has one template; set all numeric fields to their documented defaults (0 or -1). Test import into Anki desktop before completing the plan.
**Warning signs:** Anki imports 0 cards, or deck appears with 0 notes.

[CITED: https://github.com/ankidroid/Anki-Android/wiki/Database-Structure]

### Pitfall 5: schema v7 migration needs beforeOpen safety-net

**What goes wrong:** Hot-restart bumps schema version without completing migration — existing databases miss the new column.
**Why it happens:** Established pattern from prior phases — all `onUpgrade` changes must also have a matching `try/catch` `ALTER TABLE` in `beforeOpen`.
**How to avoid:** When adding `is_phonological_exception` to `Lexemes`, add both the `onUpgrade` block (from < 7) and a safety-net `ALTER TABLE lexemes ADD COLUMN "is_phonological_exception" INTEGER NOT NULL DEFAULT 0` in `beforeOpen`.

[VERIFIED: `app_database.dart` lines 270-289 show established safety-net pattern]

### Pitfall 6: WordGeneratorPanel reads its own providers — adaptation needed for inspiration panel

**What goes wrong:** Copying `WordGeneratorPanel` unchanged into word creation form causes duplicate provider reads and misses the "click to fill" callback.
**Why it happens:** The existing panel is standalone with no output callback — it just displays words.
**How to avoid:** Either wrap with a thin adapter widget that adds `onWordSelected: (String ipa) {}` callback, or pass the callback as a constructor parameter and wire it to the word list tiles.

[VERIFIED: `word_generator_panel.dart` — no onWordSelected callback exists currently]

---

## Code Examples

### LexemeDao skeleton

```dart
// Pattern: lib/features/morphology/data/morphology_dao.dart
@DriftAccessor(tables: [Lexemes, MorphologicalRuleExceptions])
class LexemeDao extends DatabaseAccessor<AppDatabase>
    with _$LexemeDaoMixin {
  LexemeDao(super.db);

  Stream<List<Lexeme>> watchRoots() =>
      (select(lexemes)
        ..where((t) => t.rootId.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.ipa)]))
          .watch();

  Stream<List<Lexeme>> watchDerivedForms(String rootId) =>
      (select(lexemes)
        ..where((t) => t.rootId.equals(rootId)))
          .watch();

  Future<int> insertLexeme(LexemesCompanion c) =>
      into(lexemes).insert(c);

  Future<bool> updateLexeme(Lexeme l) =>
      update(lexemes).replace(l);

  Future<int> deleteLexeme(int id) =>
      (delete(lexemes)..where((t) => t.id.equals(id))).go();
}
```

### Anki .apkg structure (minimal)

```
conlang_export.apkg  (ZIP)
├── collection.anki21   (SQLite database, schema v15)
│   Tables: col, notes, cards, revlog, graves
│   col row: id=1, models=JSON{noteTypeId: {...flds, tmpls}}, decks=JSON{deckId: {...name}}
│   notes rows: one per exported word (flds = "IPA\x1fMeaning")
│   cards rows: one per note (nid, did, ord=0)
└── media               (JSON: "{}")
```

Field separator in `flds` column: `\x1f` (Unicode Unit Separator, 0x1F).

[CITED: https://github.com/ankidroid/Anki-Android/wiki/Database-Structure]

### Swadesh list JSON asset format (recommended)

```json
[
  { "id": 1, "concept": "I", "category": "Pronouns" },
  { "id": 2, "concept": "you", "category": "Pronouns" },
  ...
]
```

207 items. The standard Swadesh-207 list is widely documented. Source the list from Wikipedia's Swadesh list article or academic sources.

### Conlanger's Thesaurus JSON asset format (recommended)

```json
{
  "categories": [
    {
      "name": "The Physical World",
      "subcategories": [
        {
          "name": "Cosmology",
          "concepts": ["sky", "sun", "moon", "star", "earth", "wind", "rain"]
        }
      ]
    }
  ]
}
```

The PDF has approximately 15-20 top-level semantic domains. Pre-extraction is a one-time manual task. If programmatic extraction is needed, `pdftotext` (command-line) or Python `pdfminer.six` outside the app can produce the JSON for bundling.

[ASSUMED] Exact top-level category count and names — the PDF uses FlateDecode compression which prevented direct text extraction in this session. The structure is a semantic domain hierarchy based on the author's description. Actual category names require reading the PDF with a proper PDF viewer.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual Provider everywhere | @riverpod codegen | Phases 1-2 | Still using manual providers for Drift types — do not change |
| FTS5 for search | Client-side filter (D-09) | Phase 3 decision | Simpler, adequate for expected lexicon sizes |
| Anki 2.0 (collection.anki2) | Anki 2.1 (collection.anki21) | 2018 | Must target .anki21 for modern Anki desktop |

**Deprecated/outdated:**
- `dart_anki` library: 2-commit personal project, no maintenance — do not use.
- `collection.anki2`: Legacy dummy file in modern .apkg — target `collection.anki21`.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Thesaurus PDF has ~15-20 top-level semantic domains in a hierarchical structure | Code Examples | Low — structure can be verified by opening PDF; pre-extraction task scope may change |
| A2 | `sqlite3.openInMemory()` + serialize to bytes API works as described in Pattern 5 | Architecture Patterns | Medium — if sqlite3 2.9.4 API differs, Anki export implementation needs adjustment; verify against sqlite3 pub.dev docs before implementing 03-04 |
| A3 | `is_phonological_exception` boolean on `Lexemes` is the right mechanism for PHON-05 exception override | Architecture Patterns (Pattern 6) | Low — an alternative separate table is equally valid; the planner should confirm the approach |
| A4 | `ArchiveFile` + `ZipEncoder().encode(archive)` returns `Uint8List` in archive 4.0.9 | Standard Stack | Low — archive is widely used; API is stable; verify return type before writing to file |

---

## Open Questions

1. **Conlanger's Thesaurus PDF extraction**
   - What we know: PDF is publicly available at fiatlingua.org; it contains a hierarchical semantic wordlist; PDF is FlateDecode-compressed text
   - What's unclear: Whether the PDF text layer is extractable with standard tools without running an external process
   - Recommendation: Plan 03-03 should include a Wave 0 task: "Extract thesaurus to JSON using pdftotext or Python script, bundle as `assets/conlangers_thesaurus.json`". If infeasible, hand-author a 20-category skeleton covering the most common semantic fields.

2. **Phonotactic exception toggle mechanism**
   - What we know: D-20 says exception UI lives on word detail page; D-21 says schema is done for morphological exceptions; PHON-05 requires per-word phonotactic exception
   - What's unclear: The existing `MorphologicalRuleExceptions` table is for morphological rules, not phonotactic exceptions — a separate mechanism is needed
   - Recommendation: Add `is_phonological_exception INTEGER NOT NULL DEFAULT 0` to `Lexemes` table in schema v7 migration. This is the minimal approach.

3. **Lexeme.id vs rootId string FK**
   - What we know: `rootId` is `TEXT nullable` in the schema (stored as string)
   - What's unclear: Whether the intent is to store the integer `id` serialized as string, or some other identifier
   - Recommendation: Store `lexeme.id.toString()` as `rootId`. The DAO queries with string equality. No schema change needed.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled with Flutter 3.38.5) |
| Config file | pubspec.yaml (flutter_test dev dep) |
| Quick run command | `flutter test test/morphology_engine_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LEX-01 | LexemeDao CRUD round-trip | unit | `flutter test test/lexeme_dao_test.dart -x` | Wave 0 |
| LEX-02 | Derivation tree: root+rules produces correct derived forms | unit | `flutter test test/derivation_tree_test.dart -x` | Wave 0 |
| LEX-03 | Client-side filter: match by ipa/meaning/pos, miss on non-match | unit | `flutter test test/lexeme_filter_test.dart -x` | Wave 0 |
| LEX-04 | Swadesh list: 207 items load, coverage count correct | unit | `flutter test test/swadesh_test.dart -x` | Wave 0 |
| LEX-05 | Thesaurus: JSON asset parses, tree structure non-empty | unit | `flutter test test/thesaurus_test.dart -x` | Wave 0 |
| LEX-06 | .apkg builder: zip contains collection.anki21 + media; notes count matches input | unit | `flutter test test/anki_exporter_test.dart -x` | Wave 0 |
| LEX-07 | Word generator panel: generates phonotactically valid candidates | unit | already covered by phonotactic_dsl_smoke_test.dart | Yes |
| PHON-05 | validateWord() returns violations for forbidden sequences | unit | already covered by phonotactic_dsl_smoke_test.dart | Yes |

### Sampling Rate
- **Per task commit:** `flutter test test/<task_test>.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/lexeme_dao_test.dart` — covers LEX-01
- [ ] `test/derivation_tree_test.dart` — covers LEX-02
- [ ] `test/lexeme_filter_test.dart` — covers LEX-03
- [ ] `test/swadesh_test.dart` — covers LEX-04
- [ ] `test/thesaurus_test.dart` — covers LEX-05
- [ ] `test/anki_exporter_test.dart` — covers LEX-06
- [ ] `assets/swadesh_list.json` — 207-item Swadesh list asset
- [ ] `assets/conlangers_thesaurus.json` — pre-extracted thesaurus hierarchy

---

## Sources

### Primary (HIGH confidence)
- `lib/db/app_database.dart` — Lexemes, MorphologicalRuleExceptions, PartsOfSpeech table definitions verified
- `lib/features/morphology/data/morphology_dao.dart` — Drift DAO pattern verified
- `lib/features/morphology/domain/morphology_engine.dart` — MorphologyEngine.applyRule() verified
- `lib/features/phonology/presentation/sound_rules/word_generator_panel.dart` — WordGeneratorPanel, _ViolationText verified
- `lib/features/phonology/data/phonotactic_providers.dart` — Provider patterns verified
- `lib/shared/widgets/app_shell.dart` — Tab enabled/disabled state verified
- `lib/router/app_router.dart` — Lexicon placeholder route structure verified
- `pubspec.yaml` — dependencies and dev_dependencies verified
- `flutter pub deps` output — archive 4.0.9 and sqlite3 2.9.4 confirmed as transitive deps

### Secondary (MEDIUM confidence)
- [Anki-Android Database Structure Wiki](https://github.com/ankidroid/Anki-Android/wiki/Database-Structure) — col, notes, cards table schema verified
- [archive pub.dev package](https://pub.dev/packages/archive) — version 4.0.9 confirmed current

### Tertiary (LOW confidence)
- [dart_anki GitHub](https://github.com/yoroshikun/dart_anki) — assessed as unmaintained; do not use
- Conlanger's Thesaurus structure — PDF content not extractable in this session; structure inferred from author descriptions

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages verified via codebase + pub deps
- Architecture: HIGH — patterns verified directly in existing code
- Anki export: MEDIUM — schema verified via official wiki; sqlite3 serialize API assumed
- Thesaurus structure: LOW — PDF not parseable in this session; extraction approach is manual

**Research date:** 2026-04-09
**Valid until:** 2026-05-09 (stable stack)
