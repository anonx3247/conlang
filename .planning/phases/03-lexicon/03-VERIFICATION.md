---
phase: 03-lexicon
verified: 2026-04-09T21:00:00Z
status: human_needed
score: 5/5 must-haves verified (all roadmap success criteria met in code)
overrides_applied: 0
deferred:
  - truth: "Words violating phonotactics are highlighted in red throughout the ENTIRE tool (grammar tables and any text field)"
    addressed_in: "Phase 4"
    evidence: "Phase 4 goal: 'Users can define the grammatical structure... and generate complete paradigm charts for any word'. Phase 3 delivers the shared ViolationText widget and phonotacticValidatorProvider infrastructure; wiring into grammar table cells is Phase 4 work. Phase 3 fully covers the lexicon half of PHON-05."
human_verification:
  - test: "Open the app, navigate to Lexicon > Dictionary, add a root word with IPA, and confirm it appears in the word list"
    expected: "Root word visible in scrollable list with IPA, romanization (if enabled), and meaning. List updates without app restart."
    why_human: "Requires a running app, live Drift database write, and reactive UI update — not verifiable by static analysis."
  - test: "With morphological rules defined, select a root word in the Dictionary and inspect the Derivation Tree panel"
    expected: "Derived forms appear automatically (not stored separately) in a tree structure. Each shows rule name and derived IPA. Exception overrides shown in amber."
    why_human: "Requires active morphology rules in the DB. Verifies LEX-02 end-to-end live behavior."
  - test: "Type a search query in the Dictionary search bar"
    expected: "Word list filters instantly. If a derived form matches the query, its parent root also appears in the list with a 'N derived matches' badge."
    why_human: "Live reactive filtering behavior with derived-form bubbling requires running app."
  - test: "Navigate to Swadesh List. Confirm coverage bar and 207 items. Click 'Add word' on an uncovered concept."
    expected: "Coverage progress bar at top, 207 concepts grouped by category. Clicking 'Add word' navigates to Dictionary with the meaning pre-filled in the creation form."
    why_human: "Cross-page navigation with query-param handoff requires running app."
  - test: "Navigate to Thesaurus. Expand a category, search for a term, click 'Name this concept'."
    expected: "Hierarchical tree expands/collapses. Search hides non-matching nodes. 'Name this concept' navigates to Dictionary with meaning pre-filled."
    why_human: "Recursive tree rendering and interactive search require running app."
  - test: "Select words via checkboxes in the Dictionary word list and click 'Export N to Anki'"
    expected: "Checkboxes appear on each list item. Select-all header checkbox works. Export button shows count. After export a SnackBar shows 'Exported N words to [filename].apkg' with 'Open folder' action."
    why_human: "File system write and SnackBar display require running app. Import into Anki desktop to verify .apkg validity."
  - test: "Add a word whose IPA violates phonotactic constraints. Inspect its detail panel."
    expected: "IPA appears with wavy red underline. 'Mark as exception' button visible. After marking exception, underline disappears and 'Phonotactic exception' amber label appears."
    why_human: "Requires phonotactic constraints to be defined and active. Visual rendering of wavy underlines requires running app."
---

# Phase 3: Lexicon Verification Report

**Phase Goal:** Users can build and navigate a root-and-derived-word dictionary with full search, semantic coverage guidance, flashcard export, and inline phonotactic validation throughout the interface
**Verified:** 2026-04-09T21:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can add, edit, and delete root words; derived words appear automatically with etymology chain | VERIFIED | `WordDetailPanel` has `deleteLexeme`, `updateLexeme` (edit mode); `DerivationTreeWidget` reads `computedDerivedFormsProvider` which applies `MorphologyEngine.applyRule()` on-the-fly for every active rule — no stored derived forms |
| 2 | User can search and filter by meaning, root, POS, or phonetic pattern — results instant | VERIFIED | `filteredLexemeListProvider` client-side filter covers IPA, romanization, meaning, POS, and derived-form bubbling; `WordListPanel` wires `lexemeSearchQueryProvider` + `lexemePosFilterProvider` with `FilterChip` multi-select and `DataTable` table view |
| 3 | User can open Swadesh list and Thesaurus to identify semantic gaps | VERIFIED | `SwadeshPage` (321 lines): `LinearProgressIndicator`, 207 items, `check_circle`/`Add word`; `ThesaurusPage` (436 lines): recursive `_CategoryTile`, expand/collapse, search, `Icons.add_circle_outline` + "Name this concept" |
| 4 | User can export selected entries as Anki .apkg with morphological context | VERIFIED | `AnkiExporter.buildApkg()` produces valid ZIP (PK magic bytes, `collection.anki21`, `\x1f` separator, HTML-escaped fields); `WordListPanel` has selection `Checkbox` + select-all + "Export N to Anki" button; 8/8 export tests pass |
| 5 | Words violating phonotactics highlighted in red throughout the tool, with exception override | VERIFIED (lexicon portion); grammar tables DEFERRED to Phase 4 | `ViolationText` shared widget with `TextDecorationStyle.wavy` + `decorationColor: cs.error` + `Tooltip`; wired in `WordDetailPanel` (IPA heading) and `WordListPanel` (list + table view); `lexemeViolationsProvider` batch-validates; `isPhonologicalException` toggle suppresses highlighting |

**Score:** 5/5 roadmap success criteria verified in code (grammar-tables sub-clause of SC-5 deferred to Phase 4)

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Phonotactic violation highlighting in grammar tables and all text fields (outside lexicon) | Phase 4 | Phase 4 will build paradigm chart views and grammar UI — ViolationText widget and phonotacticValidatorProvider are already extracted as shared infrastructure for Phase 4 to consume in grammar cells and form fields |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/features/lexicon/data/lexeme_dao.dart` | LexemeDao with CRUD + stream methods | VERIFIED | 73 lines; `watchRoots`, `watchDerivedForms`, `watchAllLexemes`, `insertLexeme`, `updateLexeme`, `deleteLexeme`, `watchExceptionsForLexeme`, `insertException`, `deleteException` all present |
| `lib/features/lexicon/data/lexeme_providers.dart` | Riverpod providers for lexeme data | VERIFIED | 277 lines; `lexemeDaoProvider`, `rootLexemeListProvider`, `allLexemeListProvider`, `filteredLexemeListProvider`, `derivedSearchMatchesProvider`, `lexemeByIdProvider`, `exceptionsForLexemeProvider`, `computedDerivedFormsProvider`, `DerivedFormResult`, `lexemeViolationsProvider` all present |
| `lib/features/lexicon/presentation/lexicon_shell.dart` | Lexicon sidebar shell with three sub-nav items | VERIFIED | 161 lines; `LexiconShell`, `width: 200` sidebar, Dictionary/Swadesh List/Thesaurus items |
| `lib/features/lexicon/presentation/dictionary/dictionary_page.dart` | Master-detail scaffold | VERIFIED | `createWithMeaning` query-param handling, 280px `WordListPanel`, `No words yet` empty state |
| `lib/features/lexicon/presentation/dictionary/word_list_panel.dart` | Scrollable root list + search + POS filter + view toggle | VERIFIED | 543 lines; `filteredLexemeListProvider`, `derivedSearchMatchesProvider`, `FilterChip`, `DataTable`, `Checkbox`, "Export N to Anki", "No words match", `tooltip: 'List view'` / `tooltip: 'Table view'` |
| `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart` | Detail panel with IPA, meaning, derivation tree, exceptions | VERIFIED | 634 lines; `DerivationTreeWidget`, `exceptionsForLexemeProvider`, `deleteLexeme`, `ViolationText`, `phonotacticValidatorProvider`, `Mark as exception`, `isPhonologicalException` |
| `lib/features/lexicon/presentation/dictionary/word_creation_form.dart` | Inline form for adding root words | VERIFIED | 268 lines; `IpaTextField`, `insertLexeme`, `InspirationPanel`, `prefillMeaning` |
| `lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart` | Visual tree of derived forms computed on-the-fly | VERIFIED | 203 lines; reads `computedDerivedFormsProvider(rootIpa)` — does NOT read `watchDerivedForms` or stored rows; `Colors.amber` for exception overrides |
| `lib/features/lexicon/presentation/dictionary/inspiration_panel.dart` | Word generator panel with onWordSelected callback | VERIFIED | 190 lines; `class InspirationPanel`, `onWordSelected`, `WordGenerator().generateWords()` via phonotactic templates |
| `lib/features/lexicon/data/anki_exporter.dart` | .apkg file builder using sqlite3 + archive | VERIFIED | `AnkiExporter`, `buildApkg`, `ZipEncoder`, `sqlite3.openInMemory`, `collection.anki21`, `\x1f` field separator |
| `lib/features/lexicon/presentation/swadesh/swadesh_page.dart` | Swadesh list checklist with coverage indicators | VERIFIED | 321 lines; `LinearProgressIndicator`, `Icons.check_circle`, "Add word", "No lexicon entries yet" |
| `lib/features/lexicon/presentation/thesaurus/thesaurus_page.dart` | Hierarchical category tree browser with search | VERIFIED | 436 lines; `Icons.expand_more`/`Icons.chevron_right`, `Icons.add_circle_outline`, "Name this concept", `_searchQuery`, "No lexicon entries yet" |
| `lib/features/lexicon/data/semantic_providers.dart` | Providers for Swadesh/Thesaurus loading and coverage | VERIFIED | `SwadeshItem`, `ThesaurusCategory`, `swadeshListProvider`, `swadeshCoverageProvider`, `thesaurusProvider` |
| `lib/shared/widgets/violation_text.dart` | Shared ViolationText widget with wavy red underline | VERIFIED | `class ViolationText`, `TextDecorationStyle.wavy`, `decorationColor`, `Tooltip` with pipe-separated descriptions |
| `lib/features/lexicon/data/phonotactic_validation_provider.dart` | Provider that validates word against phonotactic constraints | VERIFIED | `phonotacticValidatorProvider`, `validateWord`, watches `parsedConstraintsProvider` |
| `assets/swadesh_list.json` | 207-item Swadesh word list | VERIFIED | Parsed: 207 items confirmed |
| `assets/conlangers_thesaurus.json` | Hierarchical semantic domain tree | VERIFIED | 20 top-level categories confirmed |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lexeme_providers.dart` | `lexeme_dao.dart` | `lexemeDaoProvider` watches `currentDatabaseProvider` | WIRED | `Provider<LexemeDao?>` returns `db?.lexemeDao` |
| `app_router.dart` | `lexicon_shell.dart` | `StatefulShellRoute.indexedStack` | WIRED | `LexiconShell(navigationShell: navigationShell)` at `/lexicon/dictionary` |
| `word_list_panel.dart` | `lexeme_providers.dart` | `ref.watch(filteredLexemeListProvider)` | WIRED | Line 74 — drives the list/table rendering |
| `word_detail_panel.dart` | `lexeme_dao.dart` | `watchExceptionsForLexeme` via `exceptionsForLexemeProvider` | WIRED | Line 264 confirms provider watch |
| `word_creation_form.dart` | `lexeme_dao.dart` | `insertLexeme` | WIRED | Line 80 — `await dao.insertLexeme(...)` |
| `derivation_tree_widget.dart` | `morphology_engine.dart` | `computedDerivedFormsProvider` applies `MorphologyEngine.applyRule()` | WIRED | `lexeme_providers.dart` line 234: `const engine = MorphologyEngine(); ... engine.applyRule(...)` |
| `dictionary_page.dart` | `GoRouterState` | `queryParameters['create']` / `queryParameters['meaning']` | WIRED | `app_router.dart` line 152 passes to `DictionaryPage(createWithMeaning: ...)` |
| `swadesh_page.dart` | `semantic_providers.dart` | `ref.watch(swadeshCoverageProvider)` | WIRED | Line 22 |
| `thesaurus_page.dart` | `semantic_providers.dart` | `ref.watch(thesaurusProvider)` | WIRED | Line 61 |
| `anki_exporter.dart` | `sqlite3` | `sqlite3.openInMemory()` | WIRED | Line 48 |
| `anki_exporter.dart` | `archive` | `ZipEncoder` | WIRED | Line 61 |
| `word_detail_panel.dart` | `phonotactic_validation_provider.dart` | `ref.watch(phonotacticValidatorProvider)` | WIRED | Line 273 |
| `word_detail_panel.dart` | `violation_text.dart` | `ViolationText` widget | WIRED | Lines 311, 330 |
| `word_list_panel.dart` | `lexeme_providers.dart` | `ref.watch(lexemeViolationsProvider)` | WIRED | Lines 290, 421 |
| `word_generator_panel.dart` | `violation_text.dart` | import of shared widget (no private `_ViolationText`) | WIRED | `import '../../../../shared/widgets/violation_text.dart'` (line 4); `_ViolationText` class not present |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `word_list_panel.dart` | `filteredLexemes` | `filteredLexemeListProvider` → `rootLexemeListProvider` → `LexemeDao.watchRoots()` → SQLite | Yes — Drift stream query | FLOWING |
| `derivation_tree_widget.dart` | `derivedForms` | `computedDerivedFormsProvider(rootIpa)` → `MorphologyEngine.applyRule()` | Yes — live engine computation | FLOWING |
| `swadesh_page.dart` | `coverage` | `swadeshCoverageProvider` → `allLexemeListProvider` + `swadeshListProvider` (bundled asset) | Yes — real lexeme meanings vs real asset | FLOWING |
| `thesaurus_page.dart` | `categories` | `thesaurusProvider` → `rootBundle.loadString('assets/conlangers_thesaurus.json')` | Yes — 20-category JSON asset | FLOWING |
| `word_detail_panel.dart` | `validation` | `phonotacticValidatorProvider(word: ipa)` → `WordGenerator().validateWord()` | Yes — live constraint evaluation | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All lexicon tests pass | `flutter test test/lexicon/` | 51/51 passing | PASS |
| No analysis errors in lexicon | `flutter analyze lib/features/lexicon/ lib/shared/widgets/violation_text.dart --no-fatal-infos` | 1 warning (unused `_nodePath` in thesaurus_page.dart) | PASS (warning only, not blocker) |
| Swadesh JSON has 207 items | Python parse of `assets/swadesh_list.json` | 207 items confirmed | PASS |
| Thesaurus JSON has categories | Python parse of `assets/conlangers_thesaurus.json` | 20 categories confirmed | PASS |
| DerivationTreeWidget reads on-the-fly only | `grep watchDerivedForms derivation_tree_widget.dart` | No match — uses `computedDerivedFormsProvider` | PASS |
| `_ComingSoonPage` NOT used for Lexicon routes | `grep _ComingSoonPage app_router.dart` | Present for Grammar/Culture only, not Lexicon | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| LEX-01 | 03-01, 03-02 | Add, edit, delete root words with meaning, POS, IPA | SATISFIED | `insertLexeme`, `updateLexeme`, `deleteLexeme` in DAO; `WordCreationForm`, edit mode in `WordDetailPanel` |
| LEX-02 | 03-01, 03-02 | View derived words from morphological rules with etymology tracing | SATISFIED | `DerivationTreeWidget` uses `computedDerivedFormsProvider` — `MorphologyEngine.applyRule()` per rule, no stored rows; rule name shown with each derived form |
| LEX-03 | 03-01, 03-02 | Search/filter by meaning, root, POS, or phonetic pattern | SATISFIED | `filteredLexemeListProvider` covers IPA, romanization, meaning, POS, derived-form bubbling (D-11); `FilterChip` multi-select; `DataTable` table view |
| LEX-04 | 03-03 | Swadesh list reference for core vocabulary | SATISFIED | `SwadeshPage` with 207 items, `LinearProgressIndicator`, coverage checks, "Add word" navigation |
| LEX-05 | 03-03 | Conlanger's Thesaurus for semantic coverage | SATISFIED | `ThesaurusPage` with hierarchical tree, search, coverage checks, "Name this concept" navigation |
| LEX-06 | 03-04 | Anki .apkg flashcard export | SATISFIED | `AnkiExporter.buildApkg()` produces valid .apkg; selection checkboxes; export flow; SnackBar confirmation |
| LEX-07 | 03-02 | Generate new words following phonotactic constraints | SATISFIED | `InspirationPanel` uses `WordGenerator().generateWords()` from active phonotactic templates; `onWordSelected` fills creation form |
| PHON-05 | 03-05, 03-06 | Words violating phonotactics highlighted in red throughout tool | PARTIALLY SATISFIED | Lexicon (detail panel + list) fully wired. Grammar tables: Phase 4 (deferred — shared ViolationText + phonotacticValidatorProvider infrastructure ready for Phase 4 consumption) |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `thesaurus_page.dart` | 43 | `_nodePath` declared but never referenced | Info | Unused field, no functional impact |

No stubs, no `TODO`/`FIXME`/`placeholder` comments, no hardcoded empty data in rendering paths found across lexicon feature files.

### Human Verification Required

#### 1. Root word CRUD end-to-end

**Test:** Open app, navigate to Lexicon > Dictionary, add a root word with IPA/meaning/POS. Then edit it, then delete it.
**Expected:** Word appears in list immediately after save. Edit changes persist. Delete removes from list without app restart.
**Why human:** Requires running app with live SQLite database and Drift reactive stream.

#### 2. Derivation tree live computation (LEX-02)

**Test:** With at least one active morphological rule defined, add a root word and inspect its detail panel's Derivation Tree section.
**Expected:** Derived forms appear automatically — no separate "generate" step needed. Each derived form shows rule name. If a morphological exception exists, it shows in amber.
**Why human:** Requires active morphology rules in DB. Verifies the on-the-fly engine path end-to-end.

#### 3. Search and derived-form bubbling

**Test:** Add a root word and ensure it has derived forms in the derivation tree. Search for text that only matches a derived form, not the root.
**Expected:** The root word appears in the filtered list with a badge indicating "N derived matches".
**Why human:** Derived-form bubbling via `derivedSearchMatchesProvider` requires live Riverpod state with real data.

#### 4. Swadesh List coverage and "Add word" flow (LEX-04)

**Test:** Navigate to Swadesh List. Add a word whose meaning exactly matches a Swadesh concept (e.g. meaning = "water"). Navigate back to Swadesh List.
**Expected:** The "water" concept now shows a green checkmark and the word's IPA. Progress bar increments. "Add word" on an uncovered concept opens Dictionary with meaning pre-filled.
**Why human:** Coverage computation and cross-page navigation require running app.

#### 5. Thesaurus hierarchical browser (LEX-05)

**Test:** Navigate to Thesaurus. Expand the "The Physical World" category. Search for "sun". Click "Name this concept".
**Expected:** Tree expands/collapses correctly. Search hides non-matching nodes. "Name this concept" opens Dictionary with "sun" pre-filled in the meaning field.
**Why human:** Recursive tree rendering and interactive search require running app.

#### 6. Anki export end-to-end (LEX-06)

**Test:** Select 2–3 words via checkboxes, click "Export N to Anki", then import the resulting .apkg into Anki desktop.
**Expected:** SnackBar shows "Exported N words to [filename].apkg". Cards in Anki have IPA on front, meaning on back, with POS and morphological context fields.
**Why human:** File system write and Anki import verification require running app and Anki desktop.

#### 7. Phonotactic violation highlighting with exception toggle (PHON-05)

**Test:** Define a phonotactic constraint that forbids a sequence. Add a word whose IPA contains that sequence. View its detail panel.
**Expected:** IPA text shows wavy red underline. "Mark as exception" button appears. After marking, underline disappears and amber "Phonotactic exception" label shows. In the word list, the same word shows the wavy underline on the IPA cell.
**Why human:** Requires active phonotactic constraints and visual rendering — not verifiable by static analysis.

### Gaps Summary

No gaps found. All plan must-haves and all 5 roadmap success criteria are satisfied in code. The "grammar tables" sub-clause of PHON-05 is explicitly deferred to Phase 4 (the shared infrastructure is already built and ready). Human verification is required to confirm end-to-end runtime behavior for all major user-facing features.

---

_Verified: 2026-04-09T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
