---
phase: 04-grammar-morphology-revised
verified: 2026-04-11T00:00:00Z
status: human_needed
score: 7/7 roadmap truths verified (14/14 plans shipped)
overrides_applied: 0
requirements_covered: [GRAM-01, GRAM-02, GRAM-03, GRAM-04, GRAM-05, GRAM-06, GRAM-07]
plans_verified: 14
plans_deferred: 3  # 04-15, 04-16, 04-17 — roadmap placeholders only, no PLAN.md files
re_verification:
  previous_status: human_needed
  previous_score: 7/7
  previous_scope: 7 plans (04-01..04-07)
  new_scope: 14 plans (04-01..04-14)
  gaps_closed: []
  gaps_remaining: []
  regressions: []
  notes: "Previous verification (2026-04-10) covered plans 04-01..04-07 only. Seven additional gap-closure plans (04-08..04-14) were added and executed between 2026-04-10 and 2026-04-11 to address 19 UAT gaps and 23 D-43..D-65 decisions. This verification re-runs against the full 14-plan phase contract."
human_verification:
  - test: "Open Grammar → Inflections sub-tab with a POS that has 3+ dimensions and a selected lexeme"
    expected: "Top pane (~55%) shows ParadigmTableWidget with clickMode.ruleEditor; bottom pane (~45%) shows RulesPage filtered to the selected POS. Clicking any cell opens RuleEditorDialog with feature bindings pre-filled from the cell's axis position; clicking a filled cell edits the existing rule."
    why_human: "Stacked layout proportions, scroll behavior inside each pane, and the click-to-edit flow are interactive UI behaviors that widget tests approximate but cannot fully validate"
  - test: "Create a multi-POS inflectional rule (e.g. Noun + Adjective) via Grammar → Inflections → Add"
    expected: "RuleEditorDialog shows a multi-POS FilterChip picker (not a single Target POS dropdown). After saving, the rule appears EXACTLY ONCE in the POS-set grouped rules list under its {Noun, Adjective} group — not duplicated under each constituent POS. The v9 junction table backfill survives a migrating v8 project correctly."
    why_human: "Multi-select affordance legibility, group header clarity, and interactive save flow require visual inspection"
  - test: "Bookmark or type `/grammar/paradigm` and `/grammar/inflectional` directly in the browser/nav"
    expected: "Both routes render a hard 404 page (no redirect, no migration banner). Page shows 'Page not found' + the URL + a 'Back to Grammar' button that routes to `/grammar/pos`"
    why_human: "Router errorBuilder render quality and the 'Back to Grammar' button styling require visual inspection"
  - test: "Open Lexicon → Dictionary and select a word whose POS has ≥1 derivational rule with autoApply=false"
    expected: "Word detail panel shows a `Suggestions` section with clickable chips for each eligible unbound rule. Clicking a chip creates a promoted Lexeme row (LexemeDao.promoteDerivation). The chip disappears on the next rebuild because a matching (parent, rule) Lexeme row now exists."
    why_human: "Chip visibility after click, spacing, and promotion persistence reactivity require interactive testing"
  - test: "Open Lexicon → Dictionary, select a root word, then enter a meaning into an initially-computed derivation row in the derivation tree"
    expected: "Typing confirms a promotion (LexemeDao.promoteDerivation creates a new Lexeme row). Clearing the meaning demotes it (LexemeDao.demoteDerivation removes the row). Editing rom or ipa on a promoted derivation triggers an inline 'Editing this form will unlink it from rule X — continue?' warning dialog. Editing meaning/notes does NOT trigger the warning and does NOT detach."
    why_human: "Inline field commit timing, warning dialog copy, and reactive row removal require interactive testing"
  - test: "Create a derivational rule with `Auto-apply to all matching words` checked in the RuleEditorDialog"
    expected: "Every matching-POS parent lexeme gets a promoted Lexeme row automatically with gloss `\"{parentMeaning} ({rule.name})\"` — exact format. Parents with no meaning defer promotion (no `null (Actor)` rows appear). Editing the rule's source updates all dependent lexemes reactively."
    why_human: "DerivationPromotionService reconcile timing + templated gloss format + 100-lexeme reactivity require runtime validation"
  - test: "Open Lexicon → Dictionary and check a word's creation form: toggle the `This root only exists through derivations` checkbox, select parents via the new Parents multi-select picker, and save"
    expected: "Lexemes.rootOnlyViaDerivations is persisted; LexemeParents rows are inserted one per picked parent. Dictionary sidebar list renders the new lexeme with reduced opacity / italic style. The lexeme is still findable via search, still clickable, and still openable for editing."
    why_human: "Multi-select picker visual, muted row styling vs normal rows, and search visibility require inspection"
  - test: "In Grammar → Inflections select a POS with ≥1 unmarked cell (a cell whose feature set matches a Marker row but no inflectional rule)"
    expected: "The cell renders as the bare root in muted gray with a trailing ∅ badge — distinct from uncovered em-dash and from normal derived cells. Resolution order override → rule → marker → uncovered is respected. On exact-specificity tie between a marker and a rule, the rule wins."
    why_human: "ParadigmUnmarked visual distinctness (muted gray + ∅ glyph vs em-dash vs normal) requires visual inspection"
  - test: "Open an existing project created under v8 (post-Phase-4 initial, pre gap-closure)"
    expected: "No user-visible errors. v9 onUpgrade has run: InflectionalRulePOS junction is backfilled with one row per existing inflectional rule using current input_pos_id; derivational rows NOT backfilled; Markers table exists and empty; LexemeParents table exists and empty; MorphologicalRules.autoApply column defaults to 0 on every row; new Lexemes columns default to NULL / false."
    why_human: "v8→v9 migration flow can only be validated on a real v8 project database at runtime"
  - test: "Open an existing project created under v7 (pre-Phase-4 schema) and verify end-to-end migration chain"
    expected: "A `project.db.v7.bak` file appears next to project.db; v8 migration runs (existing rules reclassified to kind='derivational'); then v9 migration runs (no inflectional rules exist yet so InflectionalRulePOS is empty). All migrated rules appear under Lexicon → Derivations; migration banner is visible on first open."
    why_human: "v7→v8→v9 migration chain validation requires a real v7 seeded project database"
---

# Phase 4: Grammar & Morphology (revised) — Verification Report (v2)

**Phase Goal:** Users can model rich inflectional paradigms with N-dimensional grammatical features (number, gender, tense, aspect, mood, etc.) and see every derived form computed automatically from per-POS dimensions + kind-aware morphological rules. The Morphology tab is retired and the rule editor is reused within Grammar (inflectional) and Lexicon (derivational).

**Verified:** 2026-04-11
**Status:** human_needed (14/14 plans shipped; all automated invariants PASS; 10 interactive UI/UX and migration items remain for human validation)
**Re-verification:** Yes — expanded scope (7 → 14 plans) after gap-closure wave

## Scope Delta vs Previous Verification (2026-04-10)

| Scope | Previous | This pass |
|---|---|---|
| Plans verified | 04-01..04-07 (7) | 04-01..04-14 (14) |
| Schema version | v8 | v9 |
| Requirement IDs | GRAM-01..07 | GRAM-01..07 (same) |
| Gap decisions executed | — | D-43..D-65 (23) |
| UAT gaps closed | — | G-01..G-19 (19) |
| Deferred plans | — | 04-15, 04-16, 04-17 (out of scope, roadmap placeholders only) |
| Automated test count | 152 | 497 pass + 2 pre-existing failures |

## Goal Achievement

### Observable Truths (ROADMAP.md Phase 4 Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can define custom POS with N grammatical dimensions, each with K levels | VERIFIED | `Dimensions` table (schema v8) at `lib/db/app_database.dart:131`; `GrammarDao` with `watchDimensionsForPos`/`insertDimension`/`updateDimension`/`updateDimensionLevels`; `PosDimensionsPage` + `DimensionEditorPanel` + `DimensionTemplatePicker` (22 templates across 9 groups); G-11 rename affordance at `dimension_editor_panel.dart:120` (`_showRenameDialog` → `dao.updateDimension`); `grammar_dao_test.dart`, `dimension_templates_test.dart`, `dimension_rename_test.dart` all pass |
| 2 | User can attach inflectional rules to dimension levels that stack hierarchically with auto-generated combined forms | VERIFIED | `featureBindings` column + `FeatureBindingsConverter` on `MorphologicalRules`; `RuleEditorDialog` kind-aware with FilterChip picker (inflectional) and multi-POS picker (plan 04-11); `computeParadigmCell` in `paradigm_engine.dart:51` with multi-pass D-10/D-11 feature consumption + D-45 resolution order (override → rule → marker → uncovered); `binding_translator.dart` handles cross-POS feature binding translation (G-67 fix); `translateBindingsByName` is invoked at `morphology_providers.dart:149` inside `inflectionalRulesForPosProvider`; G-08 phonological rewrite pipeline applied at `paradigm_engine.dart:167`; `paradigm_engine_test.dart`, `paradigm_engine_rewrite_test.dart`, `marker_resolution_test.dart` all pass |
| 3 | User can override any cell in the paradigm table with a manual exception form | VERIFIED | `ParadigmCellOverrides` table (v8); `ParadigmCellOverrideDao` with canonical `featureSetKey`; `CellOverrideDialog` preserved in Lexicon wordOverride context per D-54 (deleted from Grammar per plan 04-13 which uses clickMode.ruleEditor instead); amber override rendering in `paradigm_table_widget.dart`; `ParadigmClickMode { ruleEditor, wordOverride }` enum drives context-aware click handler; `paradigm_cell_override_test.dart` passes |
| 4 | User can select any lexicon word and view a fully generated paradigm chart | VERIFIED | New `InflectionsPage` (Grammar > Inflections sub-tab, plan 04-13) — stacked POS picker + Word picker + ParadigmTableWidget (top ~55%) + RulesPage (bottom ~45%); `computedInflectedParadigmProvider(lexemeId)` wires lexeme → dims → rules → `ParadigmChart`; D-25 TabBar(≤6)/DropdownButton(>6) affordance for 3+ dim POS at `paradigm_table_widget.dart:116`; `WordDetailParadigmSection` read-only embed in Lexicon Dictionary at `word_detail_panel.dart:558`; G-01 per-POS last-selected word persistence at `inflections_page.dart:61` (`readParadigmLastSelectedWord` → `project_settings`); G-04 rom-primary cell rendering confirmed in `paradigm_table_rom_primary_test.dart` |
| 5 | User can record language-level typology choices (alignment, word order, modality) | VERIFIED | `TypologyPage` with three `DropdownButtonFormField` controls wired to `writeTypologyKey` auto-save; `typology.alignment`, `typology.word_order`, `typology.modality` persist via `project_settings`; `typology_providers_test.dart` passes |
| 6 | The standalone Morphology tab is removed; rule editor UI is reused within Grammar (inflectional) and Lexicon (derivational) | VERIFIED | `app_shell.dart` `_tabs` has no Morphology entry (4 top tabs: Phonology/Grammar/Lexicon/Culture); physical deletions confirmed (`lib/features/morphology/presentation/morphology_shell.dart`, `lib/features/morphology/presentation/pos/`, `lib/features/grammar/presentation/inflectional_rules/`, `lib/features/grammar/presentation/paradigm_viewer/paradigm_viewer_page.dart` — none exist on disk); `RulesPage` parameterized with `kind: RuleKind?` + `posScopeFilter: int?`; consumed by `InflectionsPage` (inflectional) and `DerivationsPage` (derivational); `RuleEditorDialog` has `required this.kind` + `preFilledBindings` + `autoApply` checkbox (derivational mode) + multi-POS FilterChip picker (inflectional mode) |
| 7 | Existing morphology rules migrate to lexicon derivational rules; derivational rules appear in Lexicon with romanization | VERIFIED | v7→v8 `onUpgrade` reclassifies existing rules to `kind='derivational'` (integration tests pass); v8→v9 `onUpgrade` backfills InflectionalRulePOS junction table from `kind='inflectional'` rows only (migration_v8_to_v9_test.dart exists); `/lexicon/derivations` route + 4th sidebar entry in `lexicon_shell.dart`; `DerivationsPage` wraps `RulesPage(kind: RuleKind.derivational)`; `computedDerivedFormsProvider` kind filter at `lexeme_providers.dart:305` (`if (dbRule.kind != RuleKind.derivational.dbString) continue;` — pitfall #9 lock); D-61 strict POS filter adds `rule.input_pos_id == word.pos_id`; `romanizeProvider` used for display; `computed_derived_forms_kind_filter_test.dart` + `computed_derived_forms_pos_filter_test.dart` both pass |

**Score: 7/7 roadmap truths verified**

### Per-Plan Must-Have Verification (14 Plans)

Each plan's `must_haves.truths` and `must_haves.artifacts` cross-referenced against codebase. All 14 plans pass.

| Plan | Focus | Artifacts on disk? | Must-haves shipped? | Tests? | Status |
|---|---|---|---|---|---|
| 04-01 | Schema v8 + migration + FeatureBindings | YES | YES | `migration_v7_to_v8_test.dart`, `feature_bindings_converter_test.dart` | VERIFIED |
| 04-02 | Grammar data layer (dimensions, templates, GrammarDao, posForLexeme, kind-aware morphology DAO) | YES | YES | `dimension_templates_test.dart`, `grammar_dao_test.dart`, `pos_resolver_test.dart` | VERIFIED |
| 04-03 | Paradigm engine (D-10/D-11), tiebreak detector, typology/paradigm axes providers | YES | YES | `paradigm_engine_test.dart`, `paradigm_generation_test.dart`, `tiebreak_detector_test.dart`, `typology_providers_test.dart` | VERIFIED |
| 04-04 | Grammar shell + PosDimensionsPage + TypologyPage + MigrationBanner + router surgery | YES | YES | `grammar_router_test.dart`, `pos_dimensions_page_test.dart`, `typology_page_test.dart` | VERIFIED |
| 04-05 | Kind-aware RuleEditorDialog + live tiebreak banner + RulesPage parameterization | YES | YES | `rule_editor_dialog_kind_test.dart` | VERIFIED |
| 04-06 | Paradigm Viewer + ParadigmTableWidget + CellOverrideDialog + CoverageMatrixPanel + AxisConfigBar + ParadigmCellOverrideDao | YES | YES (CellOverrideDialog preserved in Lexicon context per D-54; Grammar-side Paradigm Viewer later subsumed into InflectionsPage per plan 04-13 with equivalent functionality) | `paradigm_cell_override_test.dart`, `paradigm_table_widget_test.dart` | VERIFIED |
| 04-07 | Lexicon Derivations sub-tab + pitfall #9 fix + word detail paradigm embed | YES | YES | `lexicon_derivations_tab_test.dart`, `computed_derived_forms_kind_filter_test.dart`, `word_detail_paradigm_test.dart` | VERIFIED |
| 04-08 | Schema v9: Markers + InflectionalRulePOS + LexemeParents tables + MorphologicalRules.autoApply + Lexemes.derivedFrom/Via/rootOnlyViaDerivations + v8→v9 onUpgrade with InflectionalRulePOS backfill | YES (schema v9 at `app_database.dart:407`; all 3 new tables at lines 236/258/290; autoApply column at 187; v9 onUpgrade at 500; beforeOpen safety net at 685) | YES | `migration_v8_to_v9_test.dart` | VERIFIED |
| 04-09 | Bug fixes + trivial UI: G-01 per-POS last-selected word, G-02 template picker audit, G-04 rom-primary cell render, G-08 rewrite pipeline, G-11 dimension rename, G-12 single Custom entry, G-65 `New word` label | YES (G-08 rewrite at `paradigm_engine.dart:167`; G-11 rename dialog at `dimension_editor_panel.dart:120`; G-65 `New word` at `word_list_panel.dart:114`) | YES | `paradigm_engine_rewrite_test.dart`, `paradigm_table_rom_primary_test.dart`, `dimension_template_picker_test.dart`, `dimension_rename_test.dart`, `paradigm_last_selected_word_test.dart` | VERIFIED |
| 04-10 | Unmarked cells (G-03): MarkerDao + markersForPosProvider + paradigm engine marker resolution (D-45/D-46) + ParadigmUnmarked cell variant | YES (MarkerDao registered at `app_database.dart:396`; `marker_dao.dart` + `marker.dart` + `markersForPosProvider` at `grammar_providers.dart:68`; ParadigmUnmarked in `paradigm_cell.dart`) | YES | `marker_dao_test.dart`, `marker_resolution_test.dart`, `unmarked_cell_render_test.dart` | VERIFIED |
| 04-11 | Multi-POS inflectional rules (G-05, G-09): InflectionalRulePOSDao + junction-based rule lookup + multi-POS picker in RuleEditorDialog + D-56 POS-set grouping | YES (InflectionalRulePOSDao registered at `app_database.dart:394`; `inflectional_rule_pos_dao.dart`; `inflectionalRulePOSDaoProvider` at `grammar_providers.dart:81`) | YES | `inflectional_rule_pos_dao_test.dart`, `rule_editor_multi_pos_test.dart`, `rules_page_pos_grouping_test.dart` | VERIFIED |
| 04-12 | Derivation data/engine (G-13, G-14/17/18/19): D-61 POS filter, D-57 promoted derivations, D-58 implicit detach + 100-lexeme reactivity, D-59 autoApply reconcile service, D-62 LexemeParentsDao | YES (`lexeme_parents_dao.dart`; `lexemeParentsDaoProvider` at `grammar_providers.dart:112`; `derivation_promotion_service.dart` with `autoApply` watcher) | YES | `computed_derived_forms_pos_filter_test.dart`, `promoted_derivation_test.dart`, `auto_apply_derivation_test.dart`, `lexeme_parents_dao_test.dart` | VERIFIED |
| 04-13 | Inflections sub-tab restructure (G-06, G-07, G-10): Grammar sidebar 4→3 entries, new InflectionsPage with stacked paradigm+rules, ParadigmClickMode enum, RuleEditorDialog.preFilledBindings, router hard 404 on retired routes, CellOverrideDialog preserved in Lexicon only | YES (`inflections_page.dart`; `grammar_shell.dart` has exactly 3 sidebar items; `app_router.dart:77-102` errorBuilder returns hard 404; Grammar branch has 3 sub-routes at 160/168/176; `/grammar/paradigm` + `/grammar/inflectional` both return 404) | YES | `inflections_page_test.dart`, `paradigm_click_mode_test.dart`, `rule_editor_prefilled_bindings_test.dart`, `grammar_router_404_test.dart` | VERIFIED |
| 04-14 | Derivation overhaul UI (G-14/15/16/17/18/19): D-60 suggestion chips, D-62 parents section + multi-select picker, D-63 rootOnlyViaDerivations checkbox + muted Dictionary render, D-64 POS abbreviation badges, D-59 autoApply checkbox in derivational RuleEditorDialog, D-57/D-58 per-derivation meaning field with promote/demote + implicit-detach warning | YES (Suggestions in `word_detail_panel.dart:557` `WordDetailSuggestionsSection`; `_rootOnlyViaDerivations` checkbox in `word_creation_form.dart:291`; Parents picker in `word_creation_form.dart:308`; `autoApply` checkbox in `rule_editor_dialog.dart:919`; `promoteDerivation` call at `derivation_tree_widget.dart:255`) | YES | `word_detail_suggestions_test.dart`, `word_detail_parents_test.dart`, `word_detail_pos_badge_test.dart`, `root_only_via_derivations_test.dart`, `auto_apply_rule_editor_test.dart`, `derived_form_meaning_edit_test.dart`, `implicit_detach_warning_test.dart` | VERIFIED |

**Plans deferred (out of scope this pass):** 04-15, 04-16, 04-17 exist as roadmap placeholders only (no PLAN.md files on disk). They are scheduled for future discuss+plan waves per ROADMAP.md.

### Codebase Invariant Checks (from task prompt)

| # | Invariant | Evidence | Status |
|---|---|---|---|
| 1 | Grammar tab has exactly 3 sub-tabs (POS & Dimensions, Inflections, Typology) | `grammar_shell.dart:23-39` `_sidebarItems` list has exactly 3 `_SidebarItem` entries: `POS & Dimensions` / `Inflections` / `Typology` | PASS |
| 2 | `/grammar/paradigm` and `/grammar/inflectional` routes return hard 404 | `app_router.dart:77-102` `errorBuilder` renders a 404 Scaffold with 'Page not found' + URL + 'Back to Grammar' button. Grammar branch at lines 147-184 defines only 3 sub-routes: `/grammar/pos`, `/grammar/inflections`, `/grammar/typology`. Neither `/grammar/paradigm` nor `/grammar/inflectional` is registered → falls through to errorBuilder. Comment at line 73-76 documents the intentional hard-404 design per D-53. | PASS |
| 3 | InflectionalRulePOS, LexemeParents, Markers v9 tables in `app_database.dart` | Line 236 `class Markers extends Table`, line 258 `class InflectionalRulePOS extends Table`, line 290 `class LexemeParents extends Table`; all three registered in `@DriftDatabase` tables list; schema version at line 407 `schemaVersion => 9` | PASS |
| 4 | MarkerDao, InflectionalRulePOSDao, LexemeParentsDao all registered in the daos list | `app_database.dart:394-396`: `InflectionalRulePOSDao, // v9 gap D-55`, `LexemeParentsDao, // v9 gap D-62`, `MarkerDao, // v9 gap D-44 (re-registered after 04-11 regression)` — all three present | PASS |
| 5 | `markerDaoProvider` / `markersForPosProvider` / `inflectionalRulePOSDaoProvider` / `lexemeParentsDaoProvider` all present in `grammar_providers.dart` | `grammar_providers.dart:60` `markerDaoProvider`, `:68` `markersForPosProvider`, `:81` `inflectionalRulePOSDaoProvider`, `:112` `lexemeParentsDaoProvider` — all 4 providers defined | PASS |
| 6 | `translateBindingsByName` + G-67 wave 3a-bis fix in place in `morphology_providers.dart`'s `inflectionalRulesForPosProvider` | `morphology_providers.dart:102` `inflectionalRulesForPosProvider` definition; line 149 `final translated = translateBindingsByName(...)` inside the stream body. The provider resolves rules for a target posId, snapshots each rule's authoring POS dims, then calls `translateBindingsByName` with `original / authPosDims / queryPosDims`. If translation returns null (structurally unreachable rule on target POS), the rule is dropped. Docstring at lines 85-100 documents the G-67 design. | PASS |
| 7 | All per-plan tests pass; full run = 497 pass + 2 pre-existing failures in `phonotactic_dsl_smoke_test.dart` and `widget_test.dart` (both in deferred-items.md) | `flutter test` final line `+497 -2: Some tests failed.` — exact 497 pass count matches task prompt. 2 failures reported: (a) `Failed to load "test/phonotactic_dsl_smoke_test.dart": Failed assertion: line 72 pos 10: '!c1.rule!.isForbidden'` — pre-existing Phonotactic DSL parser bug documented in `deferred-items.md` §04-01 (reproduced on base commit `ea062a6` BEFORE Phase 4); (b) `Failed to load "test/widget_test.dart"` — pre-existing Flutter scaffolding stub referencing non-existent `MyApp`. Both are pre-existing, not Phase 4 regressions. | PASS |

All 7 invariants from the task prompt confirmed.

### Required Artifacts (complete inventory, all 14 plans)

| Artifact | Expected | Status |
|---|---|---|
| `lib/db/app_database.dart` | Schema v9 with v7→v8→v9 migrations, 3 new v9 tables, 4 new v9 columns | VERIFIED — 768 lines, schemaVersion => 9 |
| `lib/features/project/data/project_backup.dart` | `backupProjectDbIfNeeded` helper | VERIFIED |
| `lib/features/grammar/domain/feature_bindings.dart` | `FeatureBindings` + `FeatureBindingsConverter` | VERIFIED |
| `lib/features/grammar/domain/rule_kind.dart` | `RuleKind` enum | VERIFIED |
| `lib/features/grammar/domain/dimension_level.dart` | `DimensionLevel` + JSON helpers | VERIFIED |
| `lib/features/grammar/domain/inflectional_rule.dart` | `InflectionalRule` view-model | VERIFIED |
| `lib/features/grammar/domain/pos_resolver.dart` | `posForLexeme` | VERIFIED |
| `lib/features/grammar/domain/paradigm_cell.dart` | `ParadigmFilled` / `ParadigmUncovered` / `ParadigmAmbiguous` / `ParadigmUnmarked` (v9) | VERIFIED |
| `lib/features/grammar/domain/paradigm_engine.dart` | `computeParadigmCell` with markers + rewrite pipeline | VERIFIED |
| `lib/features/grammar/domain/tiebreak_detector.dart` | `findDuplicateSpecificityConflicts` | VERIFIED |
| `lib/features/grammar/domain/paradigm_axes.dart` | `ParadigmAxes` | VERIFIED |
| `lib/features/grammar/domain/marker.dart` | `Marker` domain value type (plan 04-10) | VERIFIED |
| `lib/features/grammar/domain/binding_translator.dart` | `translateBindingsByName` for cross-POS feature translation (G-67) | VERIFIED |
| `lib/features/grammar/data/dimension_templates.dart` | 22 const templates across 9 groups | VERIFIED |
| `lib/features/grammar/data/grammar_dao.dart` | Dimensions CRUD | VERIFIED |
| `lib/features/grammar/data/grammar_providers.dart` | All 8 providers including markerDao/markersForPos/inflectionalRulePOS/lexemeParents | VERIFIED |
| `lib/features/grammar/data/paradigm_cell_override_dao.dart` | Override CRUD + canonical featureSetKey | VERIFIED |
| `lib/features/grammar/data/paradigm_coverage_provider.dart` | `paradigmCoverageMatrixProvider` | VERIFIED |
| `lib/features/grammar/data/typology_providers.dart` | Typology + paradigm axes + `computedInflectedParadigmProvider` | VERIFIED |
| `lib/features/grammar/data/marker_dao.dart` | MarkerDao (plan 04-10) | VERIFIED |
| `lib/features/grammar/data/inflectional_rule_pos_dao.dart` | InflectionalRulePOSDao (plan 04-11) | VERIFIED |
| `lib/features/grammar/data/lexeme_parents_dao.dart` | LexemeParentsDao (plan 04-12) | VERIFIED |
| `lib/features/grammar/presentation/grammar_shell.dart` | 3-sub-tab shell (D-48 collapse) | VERIFIED |
| `lib/features/grammar/presentation/pos_dimensions/*.dart` | POS + dimensions editor with rename affordance | VERIFIED |
| `lib/features/grammar/presentation/inflections/inflections_page.dart` | Stacked paradigm+rules page (plan 04-13) | VERIFIED |
| `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` | Shared widget with ParadigmClickMode | VERIFIED |
| `lib/features/grammar/presentation/paradigm_viewer/axis_config_bar.dart` | Axis selector | VERIFIED |
| `lib/features/grammar/presentation/paradigm_viewer/cell_override_dialog.dart` | Preserved for Lexicon context per D-54 | VERIFIED |
| `lib/features/grammar/presentation/paradigm_viewer/coverage_matrix_panel.dart` | Coverage matrix | VERIFIED |
| `lib/features/grammar/presentation/typology/typology_page.dart` | Typology auto-save form | VERIFIED |
| `lib/features/grammar/presentation/shared/migration_banner.dart` | Dismissible banner | VERIFIED |
| `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` | Kind-aware editor + preFilledBindings + autoApply checkbox + multi-POS picker | VERIFIED |
| `lib/features/morphology/presentation/rules/rules_page.dart` | Parameterized with kind + posScopeFilter | VERIFIED |
| `lib/features/morphology/application/derivation_promotion_service.dart` | autoApply reconcile service (plan 04-12) | VERIFIED |
| `lib/features/lexicon/presentation/lexicon_shell.dart` | 4-sub-tab shell | VERIFIED |
| `lib/features/lexicon/presentation/derivations/derivations_page.dart` | Derivations sub-tab | VERIFIED |
| `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart` | Suggestions + Parents sections + paradigm embed | VERIFIED |
| `lib/features/lexicon/presentation/dictionary/word_creation_form.dart` | rootOnlyViaDerivations checkbox + Parents picker | VERIFIED |
| `lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart` | Meaning field + promote/demote + detach warning + POS badges | VERIFIED |
| `lib/features/lexicon/data/lexeme_providers.dart` | kind filter + D-61 POS filter | VERIFIED |
| `lib/features/lexicon/data/lexeme_dao.dart` | promoteDerivation / demoteDerivation / detachFromRule | VERIFIED |
| `lib/router/app_router.dart` | 3-route Grammar branch + errorBuilder hard 404 | VERIFIED |
| `lib/shared/widgets/app_shell.dart` | 4-top-tab list (no Morphology) | VERIFIED |
| **Physical deletions** | morphology_shell.dart, morphology/presentation/pos/, grammar/presentation/inflectional_rules/, paradigm_viewer_page.dart | VERIFIED (all absent from disk) |

### Key Link Verification

| From | To | Via | Status |
|---|---|---|---|
| `app_shell.dart` _tabs | (no Morphology) | Physical removal from const list | WIRED |
| `app_router.dart` Grammar branch | `GrammarShell` + 3 sub-routes | StatefulShellBranch | WIRED |
| `app_router.dart` errorBuilder | Hard 404 on unregistered routes | GoRouter errorBuilder | WIRED |
| `grammar_shell.dart` sidebar | POS / Inflections / Typology | 3-entry _SidebarItem list | WIRED |
| `InflectionsPage` | `computedInflectedParadigmProvider` | via ParadigmTableWidget | WIRED |
| `InflectionsPage` | `RulesPage(kind: inflectional, posScopeFilter)` | bottom pane | WIRED |
| `ParadigmTableWidget` (clickMode.ruleEditor) | `RuleEditorDialog(preFilledBindings)` | cell click handler | WIRED |
| `ParadigmTableWidget` (clickMode.wordOverride) | `CellOverrideDialog` | Lexicon wordOverride path | WIRED |
| `RuleEditorDialog` inflectional | multi-POS FilterChip picker | `inflectionalRulePOSDaoProvider` | WIRED |
| `RuleEditorDialog` derivational | `autoApply` checkbox | `MorphologicalRules.autoApply` column | WIRED |
| `RulesPage` | `rulesByKindProvider(kind)` + `posScopeFilter` | junction-based lookup | WIRED |
| `morphology_providers.dart::inflectionalRulesForPosProvider` | `translateBindingsByName` | cross-POS feature translation (G-67) | WIRED |
| `DerivationsPage` | `RulesPage(kind: derivational)` | Column composition | WIRED |
| `WordDetailSuggestionsSection` | `LexemeDao.promoteDerivation` | chip onTap | WIRED |
| `word_creation_form.dart::save` | `LexemeParentsDao.insertParent` | multi-parent commit | WIRED |
| `DerivationPromotionService` | `autoApply=true` rules + `LexemeDao.promoteDerivation` | watcher reconcile | WIRED |
| `lexeme_providers.dart::computedDerivedFormsProvider` | `RuleKind.derivational.dbString` filter + D-61 POS filter | strict equality | WIRED |
| `app_database.dart` v9 onUpgrade | v9 tables + columns + InflectionalRulePOS backfill | m.addColumn + customStatement | WIRED |
| `app_database.dart` v9 beforeOpen | idempotent ALTER TABLE + CREATE TABLE IF NOT EXISTS | safety net | WIRED |

### Data-Flow Trace (Level 4)

All wired artifacts that render dynamic data trace to real DB-backed data sources. Spot-checks:

| Artifact | Data Source | Real Data? |
|---|---|---|
| `InflectionsPage` paradigm table | `computedInflectedParadigmProvider(lexemeId)` → 5-provider composition → `generateParadigm` → real DB rows | YES |
| `InflectionsPage` rules list | `rulesByKindProvider(inflectional)` + `posScopeFilter` → junction-based query | YES |
| `WordDetailSuggestionsSection` | `morphologicalRuleListProvider` filtered by `autoApply=false + kind=derivational + inputPosId match` | YES |
| `word_creation_form.dart` Parents picker | `lexemeListProvider` (real Drift stream) | YES |
| `RuleEditorDialog` multi-POS picker | `posListProvider` (real stream) | YES |
| `ParadigmTableWidget` override cells | `ParadigmCellOverrideDao.watchOverridesForLexeme` | YES |
| `DerivationPromotionService` | real `MorphologicalRules.autoApply=true` + `lexemeListProvider` | YES |
| `translateBindingsByName` in `inflectionalRulesForPosProvider` | `dimensionsForPosProvider(authPosId)` + `dimensionsForPosProvider(queryPosId)` — real streams | YES |

No hollow wiring detected.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full Flutter test suite | `flutter test` | 497 passed + 2 pre-existing failures | PASS (matches deferred-items.md) |
| Schema version == 9 | `grep 'schemaVersion =>' lib/db/app_database.dart` | `int get schemaVersion => 9;` at line 407 | PASS |
| No Morphology top tab | `grep Morphology lib/shared/widgets/app_shell.dart` | No `_TabItem` entry for Morphology | PASS |
| No `/morphology` routes | `grep /morphology lib/router/app_router.dart` | 0 matches | PASS |
| No `/grammar/paradigm` registered | `grep /grammar/paradigm lib/router/app_router.dart` | Appears only in comments documenting the hard 404 design (lines 73-76, 142-146) — NOT registered as a GoRoute | PASS |
| No `/grammar/inflectional` registered | `grep /grammar/inflectional lib/router/app_router.dart` | Same — comments only, not a GoRoute | PASS |
| morphology_shell.dart deleted | `ls` | File does not exist | PASS |
| morphology/presentation/pos/ deleted | `ls` | Directory does not exist | PASS |
| grammar/presentation/inflectional_rules/ deleted | `ls` | Directory does not exist | PASS |
| grammar/presentation/paradigm_viewer/paradigm_viewer_page.dart deleted | `ls` | File does not exist | PASS |
| Grammar sidebar has 3 entries | `grep _SidebarItem lib/features/grammar/presentation/grammar_shell.dart` | Exactly 3 entries (POS & Dimensions / Inflections / Typology) | PASS |
| v9 tables registered in @DriftDatabase | `grep -E '(Markers|InflectionalRulePOS|LexemeParents)' lib/db/app_database.dart` | All 3 tables defined, 3 DAOs registered | PASS |
| 4 grammar_providers registered | `grep -E 'markerDao\|markersForPos\|inflectionalRulePOS\|lexemeParents' lib/features/grammar/data/grammar_providers.dart` | All 4 providers present | PASS |
| `translateBindingsByName` called in `inflectionalRulesForPosProvider` | `grep -n translateBindingsByName lib/features/morphology/data/morphology_providers.dart` | Line 149 inside `inflectionalRulesForPosProvider` (defined at line 102) | PASS |
| `kind != RuleKind.derivational` pitfall #9 filter | `grep -n 'kind != RuleKind.derivational' lib/features/lexicon/data/lexeme_providers.dart` | Line 305 match | PASS |
| Dimension template count ≥20 | 22 const templates across 9 groups in `dimension_templates.dart` | 22 (>= 20) | PASS |

### Requirements Coverage

| Requirement | Description | Source Plans | Status | Evidence |
|---|---|---|---|---|
| **GRAM-01** | Define POS with N×K dimensions | 04-01, 04-02, 04-04, 04-08, 04-09 | SATISFIED | Dimensions table v8, GrammarDao, PosDimensionsPage + dimension editor with rename, 22 template catalog |
| **GRAM-02** | Inflectional rules on dimension levels, stacking hierarchically | 04-02, 04-03, 04-05, 04-08, 04-10, 04-11, 04-13 | SATISFIED | FeatureBindings + computeParadigmCell multi-pass engine with D-45 resolution order; junction-based multi-POS rules; InflectionsPage stacked layout; binding_translator for G-67 cross-POS translation |
| **GRAM-03** | Generate full paradigm charts | 04-03, 04-06, 04-07, 04-09, 04-10 | SATISFIED | computedInflectedParadigmProvider, ParadigmTableWidget (D-25 affordance), InflectionsPage + WordDetailParadigmSection, G-08 rewrite pipeline, ParadigmUnmarked render |
| **GRAM-04** | Typology settings | 04-03, 04-04 | SATISFIED | TypologyPage auto-save, writeTypologyKey, 3 keys in project_settings |
| **GRAM-05** | Override any paradigm cell | 04-03, 04-06, 04-13 | SATISFIED | ParadigmCellOverrides table, ParadigmCellOverrideDao, CellOverrideDialog (preserved in Lexicon context per D-54), amber rendering, ParadigmClickMode.wordOverride |
| **GRAM-06** | Morphology tab removed; rule editor reused | 04-01, 04-02, 04-04, 04-05, 04-07, 04-08, 04-11, 04-13 | SATISFIED | AppShell tabs updated, morphology_shell + pos_page physically deleted, RulesPage parameterized (kind + posScopeFilter), both InflectionsPage and DerivationsPage consume it |
| **GRAM-07** | Existing rules migrate to derivational; Derivations tab with romanization | 04-01, 04-07, 04-08, 04-12, 04-14 | SATISFIED | v7→v8 reclassification + v8→v9 InflectionalRulePOS backfill; `/lexicon/derivations` route; computedDerivedFormsProvider kind filter (pitfall #9) + D-61 POS filter; autoApply reconcile; Suggestions chips + parents section; romanized via romanizeProvider |

All 7 Phase 4 formal requirement IDs satisfied.

**Note on plan frontmatter `requirements` fields:** Plans 04-08 through 04-14 also list `G-XX` (UAT gap IDs) and `D-XX` (decision IDs) in their frontmatter `requirements:` arrays. These are NOT formal requirement IDs registered in `REQUIREMENTS.md` — they are project-internal gap/decision identifiers. The formal Phase 4 requirement contract in `REQUIREMENTS.md` consists of exactly `GRAM-01..GRAM-07`, and all 7 are satisfied. The G-XX / D-XX labels serve as intra-phase traceability only.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `lib/features/grammar/domain/paradigm_cell.dart` | 9 | `placeholder` in doc comment | Info | Docstring describing `ParadigmUncovered` as a "placeholder" — intentional terminology |

No blocker or warning anti-patterns. No `TODO`/`FIXME`/`XXX`/`HACK` markers in Phase 4 files. No empty `return null` / `return []` in rendered paths. No console.log-only implementations.

### Known Deferred Items (from deferred-items.md)

1. **Pre-existing `test/phonotactic_dsl_smoke_test.dart` failure** — phonotactic DSL parser bug reproduced on base commit `ea062a6` BEFORE Phase 4 began. Owner: phonology subsystem. NOT a Phase 4 regression.
2. **Pre-existing `test/widget_test.dart` stub** — untracked Flutter scaffolding referencing non-existent `MyApp`. NOT a Phase 4 regression.
3. **Pre-existing RuleEditorDialog op-row overflow (165px at 820px width)** — surfaced by plan 04-05 widget tests, suppressed in-test via `FlutterError.onError` filter. Desktop windows are wider than 820px in production. Not blocking any Phase 4 behavior.
4. **Pre-existing compile gap `markersForPosProvider` / `marker_dao_test.dart`** — logged in deferred-items.md from plan 04-12; marker_dao_test uses `db.markerDao` getter never authored. Current state: plan 04-10 was re-run and MarkerDao is now properly registered at `app_database.dart:396` with a getter generated by Drift codegen. The test file still runs because the full test suite reports only 2 failures (the pre-existing ones above), meaning the marker_dao_test compile gap was fixed as part of the MarkerDao re-registration commit `19167f1`. Status: RESOLVED (no longer in the 2 residual failures).
5. **Pre-existing worktree orphan files (inflectional_rules_page.dart + paradigm_viewer_page.dart)** — logged in deferred-items.md from plan 04-14. Status: RESOLVED. Both files confirmed absent on disk (`ls` exit code 1). Plan 04-13 router surgery commit `b31900a` physically deleted them.

### Deferred Plans (out of scope this verification)

| Plan | Status | Rationale |
|---|---|---|
| 04-15 | Roadmap placeholder only | Notation-layer unification (G-66); needs own discuss+plan pass |
| 04-16 | Roadmap placeholder only | Rules list UX + per-level rename; needs own discuss+plan pass |
| 04-17 | Roadmap placeholder only | Intrinsic dimensions per POS (new concept); needs own discuss+plan pass |

These 3 plans are tracked in ROADMAP.md but have no PLAN.md files. They are intentionally out of scope for this verification per the task prompt.

### Human Verification Required

All 14 plans' automated code-layer invariants pass. 10 interactive UI/UX and migration items require human testing (see `human_verification` frontmatter). Categories:

1. **Inflections sub-tab stacked layout + cell-to-rule edit** (plan 04-13)
2. **Multi-POS inflectional rules UI + POS-set grouping** (plan 04-11)
3. **Hard 404 on retired Grammar routes** (plan 04-13 / D-53)
4. **Derivation Suggestions chips + applied-suggestion filter** (plan 04-14 / D-60)
5. **Per-derivation meaning field + promote/demote + implicit-detach warning** (plan 04-14 / D-57/D-58)
6. **Auto-apply derivational rule + templated gloss reconcile** (plan 04-14 / D-59)
7. **rootOnlyViaDerivations checkbox + muted Dictionary render + Parents multi-select** (plan 04-14 / D-62/D-63)
8. **ParadigmUnmarked render (bare root + ∅ badge)** (plan 04-10 / D-47)
9. **v8→v9 migration on a real v8 project** (plan 04-08)
10. **v7→v8→v9 migration chain on a real v7 project** (plan 04-01 + plan 04-08 composed)

### Gaps Summary

**No automated gaps found.** All 7 ROADMAP success criteria map to verified artifacts with verified wiring and verified data flow. All 14 plans shipped their declared `must_haves.truths` and `must_haves.artifacts`. All 7 invariants from the task prompt pass. All 497 Phase 4 automated tests pass (2 pre-existing failures documented in deferred-items.md and confirmed NOT Phase 4 regressions).

The phase goal — "Users can model rich inflectional paradigms with N-dimensional grammatical features... The Morphology tab is retired and the rule editor is reused within Grammar (inflectional) and Lexicon (derivational)" — is fully realized at the code + data + wiring + test layers.

The 10 human verification items exist because Phase 4 is a UI-heavy phase whose outcome quality depends on visual rendering, interactive affordances, reactive UI behavior, and end-to-end migration flows that widget tests approximate but cannot exhaustively validate. Each item is concrete enough that a human tester can complete it in under 5 minutes.

---

*Verified: 2026-04-11*
*Verifier: Claude (gsd-verifier)*
*Re-verification: Yes — expanded scope from 7 to 14 plans*
