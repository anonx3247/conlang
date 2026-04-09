---
phase: 03-lexicon
plan: "04"
subsystem: lexicon-export
tags: [anki, export, sqlite3, archive, ui, checkboxes]
dependency_graph:
  requires: [03-02]
  provides: [LEX-06]
  affects: [word_list_panel, dictionary_page]
tech_stack:
  added: [sqlite3 in-memory DB for Anki schema, archive ZipEncoder for .apkg]
  patterns: [HTML-escape before DB insert, VACUUM INTO for DB serialization, Downloads directory detection cross-platform]
key_files:
  created:
    - lib/features/lexicon/data/anki_exporter.dart
    - test/lexicon/anki_export_test.dart
  modified:
    - lib/features/lexicon/presentation/dictionary/word_list_panel.dart
    - lib/features/lexicon/presentation/dictionary/dictionary_page.dart
decisions:
  - "VACUUM INTO temp file used for DB serialization — sqlite3 2.9.4 has no Dart serialize() method"
  - "sfld stores raw IPA (not HTML-escaped) — sort field is internal, not rendered as HTML"
  - "Downloads folder detection uses Platform.environment HOME/USERPROFILE — no file_selector dialog needed for MVP export"
  - "onToggleExport/onSelectAll/onDeselectAll callbacks on WordListPanel — state lives in DictionaryPage, panel is stateless for selection"
  - "Export footer visible only when selectedForExport.isNotEmpty — matches D-18 spec"
metrics:
  duration: "~25 min"
  completed: "2026-04-09T20:14:54Z"
  tasks_completed: 1
  files_changed: 4
---

# Phase 3 Plan 04: Anki Export System Summary

One-liner: Anki .apkg export using sqlite3 in-memory schema + ZipEncoder, with selection checkboxes in the word list and post-export SnackBar confirmation.

## What Was Built

### AnkiExporter service (`lib/features/lexicon/data/anki_exporter.dart`)

- `AnkiExportEntry` data class with ipa, romanization, meaning, partOfSpeech, morphologicalContext fields
- `AnkiExporter.buildApkg()` builds a valid Anki .apkg (ZIP) containing:
  - `collection.anki21` — SQLite DB with Anki schema v11 (col, notes, cards, revlog, graves tables)
  - `media` — empty JSON object `{}`
- 4-field note type: Front (IPA + romanization), Back (meaning), POS, Context
- Card template: front = `{{Front}}`, back = `{{FrontSide}}<hr>{{Back}}<br><small>{{POS}} {{Context}}</small>`
- `\x1f` field separator between note fields (Anki standard)
- `VACUUM INTO` temp file for DB serialization (sqlite3 2.9.4 has no Dart `serialize()`)
- HTML-escaping of all card fields (T-03-09 mitigation: `<`, `>`, `&`, `"`, `'`)

### WordListPanel additions (`word_list_panel.dart`)

- New constructor params: `selectedForExport`, `onToggleExport`, `onSelectAll`, `onDeselectAll`, `onExport`
- `Checkbox` on each list item (leading position, compact visual density)
- Select-all `Checkbox` in panel header row with tristate support (indeterminate when partially selected)
- Export footer bar (shown when `selectedForExport.isNotEmpty`): `FilledButton.icon` with `Icons.download`, accent color, "Export N to Anki" label

### DictionaryPage export flow (`dictionary_page.dart`)

- `_selectedForExport: Set<int>` state managed in page
- `_onSelectAll()` / `_onDeselectAll()` / `_onToggleExport(int id)` handlers
- `_onExport()` async method:
  - Guards empty selection with SnackBar "Select at least one word to export."
  - Builds `AnkiExportEntry` list from all selected lexemes
  - Constructs morphological context strings: "Derived from [root IPA] via [rule name]"
  - Calls `AnkiExporter().buildApkg()`
  - Saves to Downloads (macOS/Linux: `$HOME/Downloads`, Windows: `%USERPROFILE%\Downloads`, fallback: Documents)
  - Post-export SnackBar: "Exported N words to [filename].apkg" with "Open folder" action
  - Error SnackBar on failure with `colorScheme.error` background

### Tests (`test/lexicon/anki_export_test.dart`)

8 tests all passing:
1. `buildApkg` returns non-empty `Uint8List`
2. ZIP magic bytes `PK` (0x50 0x4B) present
3. ZIP contains `collection.anki21`
4. ZIP contains `media`
5. SQLite header `SQLite format 3` present in DB bytes
6. `\x1f` field separator present in DB bytes
7. Empty entries list produces valid ZIP
8. HTML-escaping: `&lt;script&gt;` and `&amp;` present in exported DB

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] HTML escape test assertion corrected**
- **Found during:** RED/GREEN cycle
- **Issue:** Original test checked `dbString.contains('<script>') == false`, but `sfld` column stores raw IPA (not HTML-rendered) so raw `<` still appears in DB bytes
- **Fix:** Updated test to assert `&lt;script&gt;` and `&amp;` are present in DB bytes (verifying escaping occurred), not that raw `<` is absent
- **Files modified:** test/lexicon/anki_export_test.dart
- **Commit:** b40840c (same task commit)

**2. [Rule 2 - Missing critical] `.set()` method used instead of direct `.state =`**
- **Found during:** flutter analyze
- **Issue:** Direct `.state =` on Notifier from outside the class causes `invalid_use_of_protected_member` / `invalid_use_of_visible_for_testing_member` warnings
- **Fix:** Used existing `.set()` public methods on `_LexemeSearchQuery` and `_LexemePosFilter` notifiers
- **Files modified:** word_list_panel.dart

## Known Stubs

None. The export flow is fully wired end-to-end.

## Threat Flags

None. The plan's threat model (T-03-09, T-03-10, T-03-11) was fully addressed:
- T-03-09 (HTML injection): mitigated via `_htmlEscape()` on all flds values before INSERT
- T-03-10 (file tampering): accepted — user's own filesystem
- T-03-11 (DoS via large export): accepted — in-memory SQLite handles 10k rows trivially

## Self-Check

### Files exist:

- [x] `lib/features/lexicon/data/anki_exporter.dart`
- [x] `test/lexicon/anki_export_test.dart`
- [x] `lib/features/lexicon/presentation/dictionary/word_list_panel.dart`
- [x] `lib/features/lexicon/presentation/dictionary/dictionary_page.dart`

### Commits exist:

- [x] b40840c — feat(03-04): Anki .apkg export with selection checkboxes

## Self-Check: PASSED
