---
phase: 04-grammar-morphology-revised
plan: 07
subsystem: lexicon, grammar, ui, router
tags: [derivations-sub-tab, lexicon-shell, pitfall-9, kind-filter, word-detail-paradigm, read-only-reflection, d27, d36, d37, d38]

# Dependency graph
requires:
  - phase: 04-grammar-morphology-revised
    plan: 01
    provides: MorphologicalRules.kind column (schema v8)
  - phase: 04-grammar-morphology-revised
    plan: 02
    provides: dimensionsForPosProvider, posListProvider
  - phase: 04-grammar-morphology-revised
    plan: 04
    provides: MigrationBanner shared widget, Lexicon shell already in router
  - phase: 04-grammar-morphology-revised
    plan: 05
    provides: RulesPage(kind: RuleKind?) parameterization + kind-aware RuleEditorDialog
  - phase: 04-grammar-morphology-revised
    plan: 06
    provides: ParadigmTableWidget (shared), posForLexeme (04-02 consumed via 04-06)
provides:
  - DerivationsPage (Lexicon → 4th sidebar sub-tab)
  - /lexicon/derivations GoRoute
  - LexiconShell 4th sidebar item 'Derivations'
  - WordDetailParadigmSection public widget embedded in WordDetailPanel
  - Pitfall #9 fix on computedDerivedFormsProvider (kind='derivational' guard)
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pattern: reuse shared RulesPage(kind: …) parameterization from 04-05 in a different surface (Lexicon) — no duplication of the CRUD + preview widget"
    - "Pattern: extract a public WordDetailParadigmSection widget so widget tests can pump the paradigm embed in isolation without standing up WordDetailPanel's full provider graph (romanization, phonotactic, morphology, deromanize, exceptions, violations)"
    - "Pattern: scope boundary — the RulesPage dialog's pre-existing RenderFlex overflow is suppressed via setUpAll FlutterError.onError filter in new test files; no attempt to fix the op-row layout (already logged in 04-05 deferred-items.md)"
    - "Pattern: single-line kind filter — pitfall #9 fix is one `if (dbRule.kind != RuleKind.derivational.dbString) continue;` guard inside the existing loop, matching the plan's 'do not rewrite the provider' directive"
    - "Pattern: guard-based embed with SizedBox.shrink() fallbacks — WordDetailParadigmSection composes three conditions (posList.loaded → posForLexeme → dims.isNotEmpty) and collapses silently at each failure so the word detail panel never shows an empty Paradigm card"

key-files:
  created:
    - lib/features/lexicon/presentation/derivations/derivations_page.dart
    - test/widget/grammar/lexicon_derivations_tab_test.dart
    - test/unit/lexicon/computed_derived_forms_kind_filter_test.dart
    - test/widget/grammar/word_detail_paradigm_test.dart
    - .planning/phases/04-grammar-morphology-revised/04-07-SUMMARY.md
  modified:
    - lib/features/lexicon/presentation/lexicon_shell.dart
    - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
    - lib/features/lexicon/data/lexeme_providers.dart
    - lib/router/app_router.dart

key-decisions:
  - "Rule 1 defensive hardening on LexiconShell _SidebarTile: wrap the label Text in Expanded + TextOverflow.ellipsis, matching the GrammarShell pattern from 04-04. LexiconShell's original tile Row was laid out with bare Text widgets, which worked at runtime because the labels ('Dictionary', 'Swadesh List', 'Thesaurus') fit the 200px sidebar. Once plan 04-07 introduced a 4th entry ('Derivations') and widget tests started pumping LexiconShell into a constrained viewport, the 152px tile width triggered intrinsic-width overflow assertions. The Expanded + ellipsis pattern is the canonical fix and leaves the prod appearance visually identical."
  - "WordDetailParadigmSection is extracted as a public ConsumerWidget (not a private helper) so the Task 3 tests can pump it in isolation. WordDetailPanel has a heavy provider graph — romanization, phonotactic validator, morphology rule list, exception stream, deromanize, lexeme stream — and pumping it whole in a widget test would require stubbing every one. Extracting the paradigm section keeps the test surface minimal and the production behaviour identical (the section is composed inside the existing build method)."
  - "The kind filter on computedDerivedFormsProvider uses RuleKind.derivational.dbString (via a new import of rule_kind.dart in lexeme_providers.dart) rather than a raw string literal 'derivational'. Keeps the comparison symbolic and protected from a future refactor of the dbString values."
  - "DerivationsPage uses a distinct MigrationBanner settingsKey 'ui.migration_v8_banner_dismissed.derivations' — independent of the 'ui.migration_v8_banner_dismissed.inflectional' key used by InflectionalRulesPage (04-05). Dismissing one does not dismiss the other so each page independently teaches the user about its relocation."
  - "The widget test for Task 1 (derivations tab) uses an isolated minimal GoRouter mirroring the Lexicon branch, wrapped in a Scaffold — same technique as 04-04's grammar_router_test.dart. Pumping the real router would require the full ProviderScope + project selection + DB override chain."
  - "Task 3 tests seed a POS with NO dimensions (Adjective) for the negative case — Test 4 asserts that a lexeme whose POS text resolves to an existing POS row but that POS has zero dimensions still collapses the Paradigm section. This is the third guard in WordDetailParadigmSection and the most subtle one."
  - "Task 2 tests use a ProviderContainer.listen on morphologicalRuleListProvider with addTearDown(sub.close) — without an active listener, Drift's stream query never emits its first event and the synchronous Provider reads return an empty list. Same pitfall encountered in 04-06 Task 1 (paradigm_cell_override_test.dart) and documented in that plan's decisions."

patterns-established:
  - "Lexicon sub-tab for Phase 4 sibling surfaces: DerivationsPage mirrors InflectionalRulesPage (Grammar) by wrapping RulesPage(kind: …) behind a MigrationBanner. Same widget, different kind filter, different settingsKey."
  - "Public helper widget extraction for testable embeds: when a private build-method section needs widget-test coverage and the parent widget is heavy, extract a public ConsumerWidget in the same file so tests can target it directly."
  - "Kind filter on derivation tree: the canonical predicate for 'is this a rule that produces a new lexeme?' is `rule.kind == 'derivational'`. Anything that iterates over dbRules to produce DerivedFormResult instances must apply this guard."

requirements-completed: [GRAM-03, GRAM-06, GRAM-07]

# Metrics
duration: ~17min
completed: 2026-04-11
---

# Phase 4 Plan 07: Lexicon Derivations + Word Detail Paradigm Embed Summary

**Completes the Lexicon side of the Phase 4 UI migration: adds the 4th 'Derivations' sub-tab to the Lexicon sidebar (reusing `RulesPage(kind: RuleKind.derivational)` behind a dismissible migration banner), fixes pitfall #9 on `computedDerivedFormsProvider` by adding a single-line `kind != 'derivational'` guard so the lexicon derivation tree no longer pollutes with phantom inflectional forms, and embeds a read-only `ParadigmTableWidget` in the word detail panel below the derivation tree (per D-27, guarded on `posForLexeme` resolution + ≥1 dimension).**

## Performance

- **Duration:** ~17 minutes
- **Started:** 2026-04-11T05:04:17Z
- **Completed:** 2026-04-11T05:22:00Z (approx)
- **Tasks:** 3 (all TDD — RED commit then GREEN commit per task)
- **Files changed:** 9 (5 created, 4 modified)
- **Tests added:** 14 (5 lexicon_derivations_tab + 4 computed_derived_forms_kind_filter + 5 word_detail_paradigm)

## Accomplishments

### 1. Derivations sub-tab + 4th sidebar entry + route (Task 1)

- **New `DerivationsPage`** at `lib/features/lexicon/presentation/derivations/derivations_page.dart` (31 lines) — a `StatelessWidget` `Column` holding:
  - `MigrationBanner(settingsKey: 'ui.migration_v8_banner_dismissed.derivations')` — one-time notice explaining the relocation of morphological rules from the old Morphology tab
  - `Expanded(child: RulesPage(kind: RuleKind.derivational))` — the same shared editor surface used by Grammar → Inflectional Rules, parameterized with the derivational kind filter
- **`LexiconShell._sidebarItems`** extended from 3 to 4 entries. New entry: `Derivations` / `Icons.transform` / `/lexicon/derivations`. Positioned after Thesaurus to match the plan's layout contract.
- **`LexiconShell._SidebarTile` Rule 1 hardening:** the tile's label `Text` is now wrapped in `Expanded` with `TextOverflow.ellipsis` (matching `GrammarShell` from 04-04). This is a defensive fix — at runtime the prior bare `Text` fit the 200px sidebar, but widget tests pumping `LexiconShell` into a constrained 152px tile row triggered intrinsic-width overflow on the longer labels once the 4th entry was added. The Expanded+ellipsis pattern eliminates the overflow and leaves the prod appearance identical.
- **`lib/router/app_router.dart`** — added a 4th `StatefulShellBranch` in the Lexicon branch pointing `/lexicon/derivations` at `const DerivationsPage()`, plus the matching import.
- **5 widget tests** in `test/widget/grammar/lexicon_derivations_tab_test.dart` lock the behaviour:
  1. LexiconShell exposes all 4 sidebar items
  2. `/lexicon/derivations` route renders `DerivationsPage`
  3. `DerivationsPage` mounts `MigrationBanner`
  4. With 2 inflectional + 1 derivational rule seeded, the page shows only the derivational (kind filter via `rulesByKindProvider`)
  5. Source-level: `lib/router/app_router.dart` contains the literal `/lexicon/derivations` + `DerivationsPage` references

### 2. Pitfall #9 fix — kind filter on computedDerivedFormsProvider (Task 2)

- **Single-line guard** added inside the `for (final dbRule in dbRules)` loop in `lib/features/lexicon/data/lexeme_providers.dart`:

  ```dart
  for (final dbRule in dbRules) {
    if (!dbRule.isActive) continue;
    // Phase 4 plan 04-07 / pitfall #9: ignore inflectional rules — they
    // belong to the paradigm viewer, not the lexicon derivation tree.
    if (dbRule.kind != RuleKind.derivational.dbString) continue;
    // ... rest unchanged ...
  }
  ```

- Imported `RuleKind` from `../../grammar/domain/rule_kind.dart`. No other changes.
- **4 unit tests** in `test/unit/lexicon/computed_derived_forms_kind_filter_test.dart` lock the behaviour:
  1. 1 derivational + 1 inflectional → exactly 1 DerivedFormResult (the derivational)
  2. Only inflectional rules → empty list
  3. Only derivational rules → full expected list (baseline preserved)
  4. Inactive derivational rules still excluded (pre-existing `isActive` guard preserved after the new kind filter)

Before this fix, paradigm-producing lexemes would accumulate phantom "derived forms" in the Lexicon derivation tree for every inflectional cell. After: the tree shows only true derivational outputs.

### 3. Word detail paradigm embed (Task 3)

- **New public `WordDetailParadigmSection` widget** appended to `word_detail_panel.dart` (69 lines). Interface:

  ```dart
  class WordDetailParadigmSection extends ConsumerWidget {
    const WordDetailParadigmSection({super.key, required this.word});
    final Lexeme word;
    ...
  }
  ```

- **Guard chain** (collapses to `SizedBox.shrink()` at each failed condition):
  1. `posListAsync.asData?.value ?? const []` — wait for the POS list
  2. `posForLexeme(word, posList)` returns a `PartsOfSpeechData` → otherwise collapse
  3. `dimensionsForPosProvider(pos.id).asData?.value ?? const []` then `dims.isNotEmpty` → otherwise collapse
- **Render** when all guards pass: a `Card` containing `Text('Paradigm', titleMedium)` + a `SizedBox(height: 320, child: ParadigmTableWidget(lexemeId: word.id, posId: pos.id))`. No `AxisConfigBar`, no `CoverageMatrixPanel` (strictly read-only per D-27).
- **`WordDetailPanel._buildViewMode`** mounts `WordDetailParadigmSection(word: lexeme)` between the derivation tree and the exceptions section.
- **5 widget tests** in `test/widget/grammar/word_detail_paradigm_test.dart` lock all the guard conditions:
  1. POS resolves + has ≥1 dim → Paradigm section + ParadigmTableWidget rendered
  2. Null `partOfSpeech` → no section
  3. Unmatched `partOfSpeech` text → no section
  4. POS with zero dimensions → no section
  5. Embed is read-only: `find.byType(AxisConfigBar)` and `find.byType(CoverageMatrixPanel)` both return zero matches

## Router Delta

Before (3 Lexicon sub-routes):
```
/lexicon/dictionary → DictionaryPage
/lexicon/swadesh    → SwadeshPage
/lexicon/thesaurus  → ThesaurusPage
```

After (4 Lexicon sub-routes):
```
/lexicon/dictionary  → DictionaryPage
/lexicon/swadesh     → SwadeshPage
/lexicon/thesaurus   → ThesaurusPage
/lexicon/derivations → DerivationsPage   ← NEW (Phase 4 plan 04-07)
```

## LexiconShell Sidebar Delta

Before (3 items):
```
Dictionary     (Icons.menu_book)
Swadesh List   (Icons.checklist)
Thesaurus      (Icons.category)
```

After (4 items):
```
Dictionary     (Icons.menu_book)
Swadesh List   (Icons.checklist)
Thesaurus      (Icons.category)
Derivations    (Icons.transform)         ← NEW
```

Plus Rule 1 defensive hardening on `_SidebarTile`: label `Text` wrapped in `Expanded + TextOverflow.ellipsis` (prevents intrinsic-width overflow in constrained test viewports).

## WordDetailPanel Delta

Between the existing derivation tree and the exceptions section, `_buildViewMode` now mounts:

```dart
// Phase 4 plan 04-07 — read-only paradigm embed (D-27)
WordDetailParadigmSection(word: lexeme),
```

The section composes three provider reads (posList → posForLexeme → dimensionsForPosProvider) and only renders its Card when all three guards pass. Tapping a cell opens `CellOverrideDialog` (inherited from `ParadigmTableWidget` in 04-06).

## Task Commits

Each task was committed atomically as RED + GREEN pairs:

1. **Task 1 RED** — `8042127` test(04-07): add failing tests for Lexicon Derivations sub-tab (RED)
2. **Task 1 GREEN** — `e347a5d` feat(04-07): Lexicon Derivations sub-tab + 4th sidebar entry + route
3. **Task 2 RED** — `41e3045` test(04-07): add failing tests for computedDerivedFormsProvider kind filter (RED)
4. **Task 2 GREEN** — `397fd45` fix(04-07): filter computedDerivedFormsProvider to derivational rules only (pitfall #9)
5. **Task 3 RED** — `fa7080a` test(04-07): add failing tests for Lexicon word detail paradigm embed (RED)
6. **Task 3 GREEN** — `6f02b94` feat(04-07): embed ParadigmTableWidget in Lexicon word detail panel (D-27)

## Test Results

| Test File | Tests | Status |
|-----------|-------|--------|
| test/widget/grammar/lexicon_derivations_tab_test.dart | 5 | PASSING (new) |
| test/unit/lexicon/computed_derived_forms_kind_filter_test.dart | 4 | PASSING (new) |
| test/widget/grammar/word_detail_paradigm_test.dart | 5 | PASSING (new) |
| test/widget/grammar/** (regression) | 46+ | PASSING |
| test/unit/grammar/** (regression) | 78+ | PASSING |
| test/unit/lexicon/** (regression) | 4+ | PASSING |
| test/lexicon/** (regression) | 53 | PASSING |
| **Plan 04-07 total new** | **14** | **PASSING** |

`flutter test --no-pub test/widget/grammar/ test/unit/grammar/ test/unit/lexicon/ test/lexicon/` reports 191 passing, 0 failing.

Full suite `flutter test --no-pub test/` has 1 pre-existing failure in `test/phonotactic_dsl_smoke_test.dart` (line 72 assertion `!c1.rule!.isForbidden`) — **reproduces on the base commit without any 04-07 changes**, documented in `deferred-items.md` since plan 04-01. Out of scope for 04-07.

## Analyzer

`flutter analyze --no-fatal-warnings lib/features/lexicon/data/lexeme_providers.dart` → **No issues found**.

`flutter analyze --no-fatal-warnings lib/features/lexicon/ lib/router/app_router.dart` reports 9 items, **all pre-existing** and unrelated to plan 04-07 changes:

- `deprecated_member_use` on `DropdownButtonFormField.value:` in `word_creation_form.dart:233`, `word_detail_panel.dart:191` (inside unrelated `_addException` dialog), `word_detail_panel.dart:701` (inside unrelated edit-mode POS dropdown) — Flutter 3.38 deprecated `value:` in favour of `initialValue:`
- `prefer_const_constructors` on `word_detail_panel.dart:432` (pre-existing)
- `unused_element` `_nodePath` in `thesaurus_page.dart:43` (pre-existing)
- 4 × `unnecessary_underscores` in `app_router.dart` lexicon routes (the existing `(_, __)` lambdas; pre-existing, noted in 04-04 summary)

None of these are introduced by this plan's changes. The 3 new files (`derivations_page.dart`, `lexicon_derivations_tab_test.dart`, `word_detail_paradigm_test.dart`) and the single-line lexeme_providers.dart edit are lint-clean.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] LexiconShell _SidebarTile intrinsic-width overflow**

- **Found during:** Task 1 GREEN (first widget test run of lexicon_derivations_tab_test.dart)
- **Issue:** The plan's scope was adding a 4th sidebar entry. When the widget test pumped the freshly-extended LexiconShell, the 152px tile Row (inside the 200px sidebar minus padding) overflowed on the longer labels ('Swadesh List', 'Derivations'). The bare `Text` widget takes its intrinsic width, and inside a constrained Row this fires the RenderFlex overflow assertion. My `setUpAll` `FlutterError.onError` filter swallowed the error messages but the test framework still recorded them as "unexpected exceptions", failing the test.
- **Fix:** Wrap the `Text` in `Expanded` + `TextOverflow.ellipsis`, matching the GrammarShell `_SidebarTile` pattern from 04-04. The prod appearance is visually identical — none of the labels are long enough to actually trigger the ellipsis — but the layout no longer depends on the labels fitting the intrinsic width.
- **Files modified:** `lib/features/lexicon/presentation/lexicon_shell.dart`
- **Committed in:** `e347a5d` (Task 1 GREEN)

No other deviations. The plan's action snippets were executed almost verbatim; the only substantive adjustments were:

- **Task 1:** Plan snippet suggested importing the router builder with `(_, _)` but app_router.dart uses `(_, __)` for the Lexicon branches — matched the existing style to avoid lint noise.
- **Task 2:** Plan's "Alternative (preferred)" path — `RuleKind.derivational.dbString` — was taken directly rather than the raw `'derivational'` string, per the plan's own preference hint.
- **Task 3:** Rather than inlining a `Consumer(builder: ...)` inside `_buildViewMode`, extracted the full guard chain as a top-level public `WordDetailParadigmSection` ConsumerWidget in the same file. The plan explicitly listed this as an acceptable fallback ("an acceptable fallback is to extract the new Paradigm section as a standalone widget") and it was necessary to make the widget tests mountable in isolation.

**Total deviations:** 1 auto-fixed Rule 1 UI bug. No scope changes. No Rule 4 architectural decisions required.

## Issues Encountered

- **First-run flutter tool crash:** `flutter test` on a cold worktree crashed with `StateError: Bad state: No element` in `testCompilerBuildNativeAssets`. Resolved by `flutter pub get`. Same pre-existing issue documented in 04-01/04-02/04-03/04-04/04-05/04-06 summaries.
- **Worktree base mismatch:** Initial `git merge-base HEAD e906c4c8` returned `923ed63` (an older base). Ran `git reset --soft e906c4c8` + `git checkout HEAD -- .` to restore the working tree to the expected base commit before starting plan work. Same pattern as 04-05's first-run recovery.
- **Pre-existing `test/phonotactic_dsl_smoke_test.dart` failure:** A top-level `main()` assertion `!c1.rule!.isForbidden` fires on line 72 when parsing `VN -> nasalised V`. **Reproduced on the base commit e906c4c8 without any 04-07 changes**, documented in deferred-items.md since plan 04-01. Out of scope for plan 04-07.
- **RuleEditorDialog op-row overflow:** Pre-existing 165px overflow surfaced whenever `RulesPage` is pumped in a widget test (plan 04-05 documented this in deferred-items.md). The new Task 1 tests install the same `FlutterError.onError` filter in `setUpAll` to ignore these messages.

## User Setup Required

None. Changes are all code + tests. Users running the app will see:

- A new "Derivations" sub-tab in the Lexicon sidebar on next launch
- All existing Phase 3 morphological rules (which have `kind='derivational'` by default from the schema v8 migration in 04-01) now appear under **Lexicon → Derivations** instead of the deleted Morphology tab
- A migration banner explaining the relocation, dismissible via the X button
- Their derivation tree is now clean of any phantom paradigm cell outputs
- If a word's POS matches a PartsOfSpeech row that has ≥1 dimension, a new **Paradigm** card appears in the word detail panel below the derivation tree (read-only reflection of the Grammar tab's axis config)

## Phase 4 Requirements Coverage

After this plan, the Phase 4 GRAM-0N requirement coverage is:

| Requirement | Covered By | Status |
|-------------|-----------|--------|
| GRAM-01 (POS & dimensions UI) | 04-04 | Complete |
| GRAM-02 (kind-aware rule editor) | 04-05 | Complete |
| GRAM-03 (paradigm viewer + word detail embed) | 04-06 + **04-07** | Complete |
| GRAM-04 (typology settings) | 04-04 | Complete |
| GRAM-05 (cell overrides) | 04-06 | Complete |
| GRAM-06 (Morphology tab deleted, rules relocated to Grammar + Lexicon) | 04-04 + 04-05 + **04-07** | Complete |
| GRAM-07 (derivations migrate with romanization) | **04-07** | Complete |

All 7 Phase 4 GRAM requirements have implementing plans. Plan 04-07 closes out GRAM-03 (Lexicon half), GRAM-06 (Lexicon relocation), and GRAM-07.

## Phase 4 Artifact List (Handoff)

**Schema + data layer (Plans 01–03):**
- `MorphologicalRules.kind / featureBindings / inputPosId / outputPosId` columns (schema v8, plan 01)
- `ParadigmCellOverrides` table (plan 01)
- `Dimensions` table + `DimensionLevel` value type + `dimension_templates` catalog (plan 02)
- `GrammarDao`, `dimensionsForPosProvider`, `grammarDaoProvider` (plan 02)
- `FeatureBindings` type, `RuleKind` enum, `InflectionalRule` view-model, `MorphologyDao.insertRuleWithKind / watchRulesByKind / watchInflectionalRulesForPos` (plans 01 + 02)
- `rulesByKindProvider`, `inflectionalRulesForPosProvider`, `posListProvider` (plan 02)
- `posForLexeme` resolver (plan 02)
- `ParadigmEngine`, `computedInflectedParadigmProvider`, `ParadigmChart`, `ParadigmAxes`, `paradigmAxesProvider`, `writeParadigmAxes`, `typologySettingsProvider`, `writeTypologyKey`, `findDuplicateSpecificityConflicts`, `TiebreakConflict` (plan 03)

**UI layer (Plans 04–07):**
- `GrammarShell`, `/grammar/pos`, `/grammar/inflectional`, `/grammar/paradigm`, `/grammar/typology` routes (plan 04)
- `PosDimensionsPage`, `DimensionEditorPanel`, `showPosCrudDialog`, `showDimensionTemplatePicker` (plan 04)
- `TypologyPage` auto-save form (plan 04)
- `MigrationBanner` shared widget (plan 04)
- Kind-aware `RuleEditorDialog(kind: RuleKind)` with FilterChip feature-binding picker + Input/Output POS dropdowns + live tiebreak banner (plan 05)
- Parameterized `RulesPage(kind: RuleKind?)` (plan 05)
- Real `InflectionalRulesPage` replacing 04-04 stub (plan 05)
- `ParadigmCellOverrideDao` + `paradigmCoverageMatrixProvider` + `featureSetKeyForOverride` (plan 06)
- `ParadigmTableWidget`, `AxisConfigBar`, `CellOverrideDialog`, `CoverageMatrixPanel` (plan 06)
- Real `ParadigmViewerPage` replacing 04-04 stub (plan 06)
- **`DerivationsPage` + `/lexicon/derivations` + 4th `LexiconShell` sidebar entry (plan 07)**
- **`WordDetailParadigmSection` embedded in `WordDetailPanel` (plan 07)**
- **`computedDerivedFormsProvider` kind filter fix (plan 07, pitfall #9)**

**Test coverage:** Phase 4 ships ~55+ widget/unit tests across `test/widget/grammar/**` and `test/unit/grammar/**` and `test/unit/lexicon/computed_derived_forms_kind_filter_test.dart`.

## Next Plan Readiness

Phase 4 is now feature-complete. All GRAM-0N requirements have shipped. Plan 04-07 is the final plan in Phase 4.

Downstream consumers can now:
- Author derivational rules via Lexicon → Derivations (with Input/Output POS dropdowns)
- Author inflectional rules via Grammar → Inflectional Rules (with feature-binding chip picker)
- Configure POS dimensions via Grammar → POS & Dimensions
- View computed paradigms (with override cells, coverage matrix, uncovered-cell rule shortcut) via Grammar → Paradigm Viewer
- See inline read-only paradigms for each word in Lexicon → Dictionary → word detail
- Configure project-level typology settings via Grammar → Typology

## Threat Flags

None. All three tasks are local-DB + UI changes. No new network endpoints, no new file paths, no schema changes, no new trust boundaries.

All threats from the plan's `<threat_model>` are covered:

- **T-04-19** (Tampering: inflectional forms leaking into the derivation tree, pitfall #9) → **mitigated** by Task 2's kind filter guard. Test 1 of `computed_derived_forms_kind_filter_test.dart` locks this: 1 derivational + 1 inflectional → exactly 1 DerivedFormResult.
- **T-04-20** (Information disclosure: word detail paradigm across projects) → **mitigated**. Both `posListProvider` and `dimensionsForPosProvider` key off `currentDatabaseProvider`, scoped to the active project DB.
- **T-04-21** (DoS: huge paradigm per visible word) → **mitigated**. `WordDetailParadigmSection` only renders for the currently-selected word in the detail panel, and `computedInflectedParadigmProvider` is cached per-lexemeId by Riverpod.
- **T-04-22** (Elevation of privilege: deep link without project) → **accepted per plan**. When no project is open, `posListProvider` emits an empty list and `WordDetailParadigmSection` collapses to `SizedBox.shrink()`. `/lexicon/derivations` inherits the Lexicon branch's empty-state handling.

No new STRIDE flags to add to the register.

## Self-Check: PASSED

All claimed files and commits verified to exist:

**Files created (5):**
- FOUND: lib/features/lexicon/presentation/derivations/derivations_page.dart
- FOUND: test/widget/grammar/lexicon_derivations_tab_test.dart
- FOUND: test/unit/lexicon/computed_derived_forms_kind_filter_test.dart
- FOUND: test/widget/grammar/word_detail_paradigm_test.dart
- FOUND: .planning/phases/04-grammar-morphology-revised/04-07-SUMMARY.md

**Files modified (4):**
- FOUND: lib/features/lexicon/presentation/lexicon_shell.dart
- FOUND: lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
- FOUND: lib/features/lexicon/data/lexeme_providers.dart
- FOUND: lib/router/app_router.dart

**Commits (6):**
- FOUND: 8042127 test(04-07): add failing tests for Lexicon Derivations sub-tab (RED)
- FOUND: e347a5d feat(04-07): Lexicon Derivations sub-tab + 4th sidebar entry + route
- FOUND: 41e3045 test(04-07): add failing tests for computedDerivedFormsProvider kind filter (RED)
- FOUND: 397fd45 fix(04-07): filter computedDerivedFormsProvider to derivational rules only (pitfall #9)
- FOUND: fa7080a test(04-07): add failing tests for Lexicon word detail paradigm embed (RED)
- FOUND: 6f02b94 feat(04-07): embed ParadigmTableWidget in Lexicon word detail panel (D-27)

---
*Phase: 04-grammar-morphology-revised*
*Completed: 2026-04-11*
