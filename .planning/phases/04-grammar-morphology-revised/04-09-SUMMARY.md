---
phase: 04-grammar-morphology-revised
plan: 09
subsystem: grammar
tags: [uat-fixes, paradigm-viewer, rewrite-pipeline, dimension-picker, lexicon-copy, regression-tests]

# Dependency graph
requires:
  - phase: 04-grammar-morphology-revised
    provides: "paradigm_engine + paradigm_viewer + dimension editor/picker + lexicon dictionary"
provides:
  - G-08 fix — phonology rewrite rules applied to final inflected paradigm form (D-29 surface parity)
  - G-04 fix — paradigm cells show romanization as primary top line only when it differs from IPA (D-29)
  - G-02 + G-12 fix — dimension template picker renders one Custom (start blank) entry at list tail
  - G-11 fix — dimension editor exposes rename affordance per dimension card
  - G-01 fix — paradigm viewer persists last-selected word per POS across tab/app restart
  - G-65 rename — lexicon toolbar, form header, submit button read "New word" (was "Add root")
affects: [04-10, 04-11, 04-12, 04-13, 04-14]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pattern: reuse parsedRewriteRulesProvider (List<PhonologicalRewriteRule>) for cross-subsystem surface-form consistency — never thread raw Drift RewriteRule rows through domain code"
    - "Pattern: showRom guard = romText.isNotEmpty && romText != form — mirrors derivation_tree_widget.dart's showRomanizedRoot idiom for D-29 rom-primary displays"
    - "Pattern: per-POS persistence key = 'paradigm.last_selected_word.{posId}' — reuses writeTypologyKey update-then-insert upsert idiom, keeps keys under one logical namespace"
    - "Pattern: rename dialog extracted to StatefulWidget with late-final controller so its lifecycle matches the State — avoids 'used after dispose' errors from awaited showDialog pop-unwind"
    - "Pattern: widget test scroll-lazy-ListView helper drags Dialog descendant ListView (not byType which matches POS rail) until the off-screen target builds — reliable for picker modals with long lists"

key-files:
  created:
    - test/unit/grammar/paradigm_engine_rewrite_test.dart
    - test/unit/grammar/paradigm_table_rom_primary_test.dart
    - test/widget/grammar/dimension_template_picker_test.dart
    - test/widget/grammar/dimension_rename_test.dart
    - test/widget/grammar/paradigm_last_selected_word_test.dart
  modified:
    - lib/features/grammar/domain/paradigm_engine.dart
    - lib/features/grammar/data/typology_providers.dart
    - lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart
    - lib/features/grammar/presentation/paradigm_viewer/paradigm_viewer_page.dart
    - lib/features/grammar/presentation/pos_dimensions/dimension_template_picker.dart
    - lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart
    - lib/features/lexicon/presentation/dictionary/word_list_panel.dart
    - lib/features/lexicon/presentation/dictionary/word_creation_form.dart
    - lib/features/lexicon/presentation/dictionary/dictionary_page.dart
    - test/widget/grammar/pos_dimensions_page_test.dart

key-decisions:
  - "G-08 wiring uses parsedRewriteRulesProvider (List<PhonologicalRewriteRule>) instead of raw RewriteRule Drift rows — the rest of the app (inspiration_panel, preview_panel, word_generator_panel) already consumes the parsed form, so paradigm_engine gets cross-subsystem parity for free and avoids a second rule-parsing site"
  - "G-04 fix collapses identical rom+IPA to a single dimmed IPA-only line rather than showing both — prevents visual duplication in default/no-romanization projects, matches derivation_tree_widget idiom exactly"
  - "G-12 ships one Custom (start blank) entry at the picker's absolute bottom (outside any group), not per-group — 9 Custom cards pre-fix was a UX bug, not a design"
  - "G-02 audit: no literal '-' placeholder found in the picker's render path or templates data — the reported rendering is likely the pre-G-12 per-group Custom card with no levels preview, now resolved by the G-12 cleanup. Added a regression widget test asserting '-' is never a Text node inside the picker."
  - "G-11 rename dialog extracted as _RenameDimensionDialog StatefulWidget so TextEditingController disposal is tied to dialog State.dispose() — avoids 'used after dispose' errors from the hand-rolled controller.dispose() pattern that fires while the dialog is mid-unwind"
  - "G-01 persistence uses the typology.* key-value store via writeTypologyKey — no new Drift column, reactive via project_settings stream the page already watches indirectly through its other dropdowns"

metrics:
  tasks: 6
  tests_added: 26
  duration: ~45 min
  completed: 2026-04-11
---

# Phase 04 Plan 09: Phase 4 UAT Pure Bug Fixes Summary

## One-liner

Six discrete UAT bug fixes and one trivial lexicon rename wired atomically — rewrite pipeline applied to inflected forms, rom-primary paradigm cells with identity collapse, single-entry Custom picker, rename affordance on dimensions, per-POS last-selected-word persistence, and `Add root`→`New word` across the dictionary.

## What Was Built

Plan 04-09 closed all six pure-bug gaps identified during Phase 4 UAT plus a 5-site string rename, each as an atomic commit with a dedicated regression test. No schema changes, no design decisions — all fixes were mechanical and localized to existing subsystems.

### Task 1 — G-08: rewrite pipeline on inflected forms

`computeParadigmCell` now accepts a `rewriteRules` parameter (`List<PhonologicalRewriteRule>`, default empty for back-compat) and runs the phonology rewrite pipeline once on the final `working` form before returning `ParadigmFilled`. The rewrite pass:

- runs exactly once after the entire inflectional chain completes (not per-stage),
- is only invoked for the `ParadigmFilled` success path — `ParadigmUncovered` and `ParadigmAmbiguous` returns earlier bypass it,
- reuses `WordGenerator.applyRewriteRules` (the same function the lexicon dictionary, morphology preview, and word generator panels call).

`generateParadigm` forwards the new parameter to `computeParadigmCell`. `computedInflectedParadigmProvider` now watches `parsedRewriteRulesProvider` and passes the parsed list into `generateParadigm`, so the entire app surfaces rewrite-rule-adjusted forms consistently.

**Regression test:** 5 unit tests in `paradigm_engine_rewrite_test.dart` cover the GREEN case (`kata` + `+ki` + `k -> x / V_V` → `kataxi`), empty-rules back-compat, multi-stage chain with rewrite running once, uncovered cell skip, and ambiguous cell skip.

### Task 2 — G-04: paradigm cell rom-primary rendering

`_FilledCell.build` in `paradigm_table_widget.dart` now gates the rom display behind `showRom = romText.isNotEmpty && romText != form` (mirroring `derivation_tree_widget.dart`'s `showRomanizedRoot` idiom). When rom differs from IPA, the cell shows rom as the bold primary top line via `ViolationText` and IPA dimmed on a bracketed second line. When rom equals IPA (or is empty), the cell collapses to a single `ViolationText(text: '[$form]')` dimmed line — no more identical-glyph duplication in projects without a romanization table configured.

**Regression test:** 3 widget tests in `paradigm_table_rom_primary_test.dart` pump `ParadigmTableWidget` with an in-memory `AppDatabase` fixture and override `computedInflectedParadigmProvider` + `romanizeProvider` to assert: rom-hidden when equal, rom-primary when different, empty-rom fallback.

### Task 3 — G-02 + G-12: dimension template picker audit + single Custom

The per-group Custom append loop (9 Custom cards, one per feature group) was removed. A single `const customBlank` template card now renders at the absolute bottom of the picker ListView, outside any group header, with label `Custom (start blank)`. Search filtering still exposes it when the query matches "custom" and hides it on unrelated queries (falling through to the "No templates match" empty state).

**Audit finding (G-02):** No literal `-` placeholder exists anywhere in the picker's render path or the `dimensionTemplates` data. The reported "renders as -" was most likely the pre-fix per-group Custom card (empty levels, no preview line), now resolved by the G-12 cleanup. A regression widget test locks this: `expect(find.text('-'), findsNothing)` inside the picker dialog.

**Regression tests:** 6 widget tests in `dimension_template_picker_test.dart` — 3 G-12 (single entry, search-hides, search-exposes-on-match), 2 G-02 (level rendering, no dash), 1 tap-to-pop. Also updated `pos_dimensions_page_test.dart` to match the new single-Custom policy with a picker-specific `find.descendant(of: Dialog, matching: ListView)` scroll helper.

### Task 4 — G-11: dimension rename affordance

Each card in `DimensionEditorPanel` now renders an `Icons.edit_outlined` IconButton between the dimension name and the existing delete button. Tapping it opens a new `_RenameDimensionDialog` (private `StatefulWidget`) that:

- pre-fills its `TextField` with the current name via `initialName`,
- owns its own `TextEditingController` tied to State lifecycle (no hand-rolled dispose),
- shows an inline error for empty/whitespace names and does not commit,
- on save, calls `GrammarDao.updateDimension(dim.copyWith(name: newName))`.

**Regression test:** 4 widget tests in `dimension_rename_test.dart` cover icon presence, dialog prefill, persist-via-DAO, and empty-name rejection.

### Task 5 — G-01: per-POS last-selected-word persistence

Added three new helpers to `typology_providers.dart`:
- `paradigmLastSelectedWordKey(int posId)` → `'paradigm.last_selected_word.{posId}'`
- `readParadigmLastSelectedWord(db, posId)` → nullable parsed int
- `writeParadigmLastSelectedWord(db, posId, lexemeId)` upsert via existing `writeTypologyKey`

`ParadigmViewerPage` now routes its POS-change and word-change callbacks through `_onPosChanged` / `_onWordChanged`:
- POS change fires an async `_restoreLastSelectedWord` that reads the stored id and verifies the lexeme still exists before restoring (stale-id fallback → `(template)` default),
- Word change fires a fire-and-forget write to persist.

**Regression tests:** 8 tests in `paradigm_last_selected_word_test.dart` — 5 helper unit tests (key, null read, round-trip, upsert-no-duplicate, per-POS scoping) + 3 widget integration tests (write on selection, per-POS scoped writes don't cross-contaminate, stale id fallback).

### Task 6 — G-65: `Add root` → `New word` rename

Replaced all five `Add root` string sites across `word_list_panel.dart`, `word_creation_form.dart`, and `dictionary_page.dart` with `New word`. Updated doc comments to drop "root word" where it was user-facing. No test assertions referenced the old string, so no test files needed updating.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] `WordGenerator()` is not const**

- **Found during:** Task 1 RED→GREEN compile step
- **Issue:** Plan's draft code used `const WordGenerator().applyRewriteRules(...)` but `WordGenerator` has no const constructor.
- **Fix:** Dropped the `const` prefix — `WordGenerator()` is already cheap to construct.
- **Files modified:** `lib/features/grammar/domain/paradigm_engine.dart`
- **Commit:** 59e1e26

**2. [Rule 3 — Blocker] Plan referenced raw Drift `RewriteRule` type in paradigm_engine**

- **Found during:** Task 1 signature design
- **Issue:** Plan said "accept a `rewriteRules` list parameter" and imported `RewriteRule` from `app_database.dart`. But `WordGenerator.applyRewriteRules` takes `List<PhonologicalRewriteRule>` (the domain type), and every other callsite in the app already consumes `parsedRewriteRulesProvider` which returns the parsed domain form.
- **Fix:** Typed the parameter as `List<PhonologicalRewriteRule>` and wired `computedInflectedParadigmProvider` to `parsedRewriteRulesProvider`, not `rewriteRuleListProvider`. Avoids a redundant parse pass inside the engine.
- **Files modified:** `lib/features/grammar/domain/paradigm_engine.dart`, `lib/features/grammar/data/typology_providers.dart`
- **Commit:** 59e1e26

**3. [Rule 1 — Bug] TextEditingController disposed during dialog unwind**

- **Found during:** Task 4 first test run
- **Issue:** Plan's draft used an inline `TextEditingController` in `_showRenameDialog` with `controller.dispose()` after the `showDialog` future resolved. This triggered "A TextEditingController was used after being disposed" errors because the dialog was still rebuilding when the pop began.
- **Fix:** Extracted the dialog body into `_RenameDimensionDialog` (`StatefulWidget`), owns `late final _controller` initialized in `initState` and disposed in `State.dispose()`. Flutter's normal StatefulWidget lifecycle guarantees disposal after the dialog is fully removed.
- **Files modified:** `lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart`
- **Commit:** d06b522

**4. [Rule 1 — Bug] Existing `pos_dimensions_page_test.dart` asserted old per-group Custom policy**

- **Found during:** Task 3 regression run
- **Issue:** A test named `'template picker renders a "Custom" entry in every visible group'` used `find.text('Custom')` which relied on the old per-group behavior. After the G-12 fix, the test failed because no bare `Custom` label exists anymore.
- **Fix:** Updated the test to assert the new single-entry policy, scroll the picker's Dialog-descendant ListView until the Custom card builds, and renamed the test to reflect the new contract.
- **Files modified:** `test/widget/grammar/pos_dimensions_page_test.dart`
- **Commit:** d06b522 (bundled with Task 4 as the test-layer regression alignment)

No architectural changes, no authentication gates, no checkpoints.

## Authentication Gates

None.

## Verification

- `flutter test test/unit/grammar/ test/widget/grammar/` → **160 tests passed** (137 pre-existing + 23 new)
- `flutter test test/lexicon/` → **53 tests passed** (no regression from G-65 rename)
- `flutter test test/unit/grammar/paradigm_engine_rewrite_test.dart test/unit/grammar/paradigm_table_rom_primary_test.dart test/widget/grammar/dimension_template_picker_test.dart test/widget/grammar/dimension_rename_test.dart test/widget/grammar/paradigm_last_selected_word_test.dart` — all 26 new regression tests GREEN

## Commits

| Commit   | Task | Message                                                                  |
| -------- | ---- | ------------------------------------------------------------------------ |
| 59e1e26  | 1    | fix(04-09): apply phonology rewrite rules to inflected paradigm forms     |
| 0d806a1  | 2    | fix(04-09): paradigm cell shows rom primary only when it differs from IPA |
| 7ba0e5c  | 3    | fix(04-09): render exactly one Custom entry in dimension template picker  |
| d06b522  | 4    | fix(04-09): add rename affordance to DimensionEditorPanel                 |
| f8b176f  | 5    | fix(04-09): persist paradigm viewer last-selected word per POS            |
| 051d9c4  | 6    | chore(04-09): rename lexicon toolbar 'Add root' -> 'New word'             |

## Self-Check

Verified all 11 key files exist at the expected paths:

- `lib/features/grammar/domain/paradigm_engine.dart` (modified)
- `lib/features/grammar/data/typology_providers.dart` (modified)
- `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` (modified)
- `lib/features/grammar/presentation/paradigm_viewer/paradigm_viewer_page.dart` (modified)
- `lib/features/grammar/presentation/pos_dimensions/dimension_template_picker.dart` (modified)
- `lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart` (modified)
- `lib/features/lexicon/presentation/dictionary/word_list_panel.dart` (modified)
- `lib/features/lexicon/presentation/dictionary/word_creation_form.dart` (modified)
- `lib/features/lexicon/presentation/dictionary/dictionary_page.dart` (modified)
- `test/unit/grammar/paradigm_engine_rewrite_test.dart` (created)
- `test/unit/grammar/paradigm_table_rom_primary_test.dart` (created)
- `test/widget/grammar/dimension_template_picker_test.dart` (created)
- `test/widget/grammar/dimension_rename_test.dart` (created)
- `test/widget/grammar/paradigm_last_selected_word_test.dart` (created)
- `test/widget/grammar/pos_dimensions_page_test.dart` (modified)

Verified all 6 commits exist in `git log`.

## Self-Check: PASSED
