---
phase: 04-grammar-morphology-revised
plan_wave: 20 (plans 20-01 through 20-03)
verified: 2026-04-12T19:35:03Z
status: gaps_found
score: 5/10 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 19/19
  gaps_closed:
    - "Standard form validation checks phonemic IPA form — now checks romanized form"
    - "Single-row paradigm table excessive trailing width — IntrinsicWidth wrapper added"
    - "Standard form violations on derived forms in derivation rule editor — _StandardFormDerivationWarning implemented"
  gaps_remaining:
    - "Marker binding summary shows raw level IDs — 04-19-01 fix was reverted by 04-20-03 rewrite of rules_page.dart"
    - "Level abbreviations not shown on regular inflection rules — 04-19-01 fix was reverted by 04-20-03 rewrite of rules_page.dart"
    - "Marker rows display name — 04-19-01 fix was reverted by 04-20-03 rewrite of rules_page.dart"
  regressions:
    - "rules_page.dart rewritten by 04-20-03 — lost D-56 inflectional grouped list, D-50 posScopeFilter, D-77 static preview removal, markers, binding summaries"
    - "inflections_page.dart compile error — references removed posScopeFilter parameter"
    - "rules_page_pos_grouping_test.dart compile errors — references removed groupInflectionalRulesByPosSet function and posScopeFilter"
gaps:
  - truth: "App compiles without errors (baseline requirement for all SCs)"
    status: failed
    reason: "inflections_page.dart has a compile error: 'The named parameter posScopeFilter isn't defined.' Plan 04-20-03 removed RulesPage.posScopeFilter but did not update inflections_page.dart. This prevents the entire app from building."
    artifacts:
      - path: "lib/features/grammar/presentation/inflections/inflections_page.dart"
        issue: "Line 237: references RulesPage(posScopeFilter: _selectedPosId) but RulesPage no longer has a posScopeFilter parameter"
      - path: "lib/features/morphology/presentation/rules/rules_page.dart"
        issue: "Rewritten by 04-20-03 — removed posScopeFilter parameter, _buildInflectionalGroupedList, groupInflectionalRulesByPosSet, all marker display code, all binding summary code"
      - path: "test/widget/grammar/rules_page_pos_grouping_test.dart"
        issue: "3 compile errors: references removed groupInflectionalRulesByPosSet function and posScopeFilter parameter"
    missing:
      - "Restore RulesPage.posScopeFilter parameter (D-50) or update inflections_page.dart to not pass it"
      - "Restore _buildInflectionalGroupedList with D-56 POS-set grouping for inflectional rules"
      - "Restore marker display code (marker.name, ∅ badge, marker rows) from 04-18-05 / 04-19-01"
      - "Restore level abbreviation resolution in binding summaries (levelAbbrMap) from 04-19-01"
      - "Restore feature binding display under regular rule names from 04-19-01"
      - "Remove re-added MorphologyPreviewPanel and VerticalDivider (deleted in D-77 / plan 04-15)"
      - "Fix test/widget/grammar/rules_page_pos_grouping_test.dart compile errors"
  - truth: "Marker binding summary shows actual level abbreviations (e.g. 'PRS . PFV') not raw level IDs"
    status: failed
    reason: "The 04-19-01 fix (levelAbbrMap, bindingSummary resolution) was removed when 04-20-03 rewrote rules_page.dart. The current file has no binding summary code, no level abbreviation resolution, and no marker references."
    artifacts:
      - path: "lib/features/morphology/presentation/rules/rules_page.dart"
        issue: "No bindingSummary(), no levelAbbrMap, no marker.name — all removed by 04-20-03 rewrite"
    missing:
      - "Restore the binding summary with level abbreviation resolution from the 04-19-01 version of rules_page.dart"
  - truth: "Level abbreviations show on regular inflection/derivation rules under their names in the rules list"
    status: failed
    reason: "The 04-19-01 fix (secondary Text with bindingSummary for inflectional rule featureBindings) was removed by 04-20-03 rewrite. Current rules_page.dart shows only rule.name for inflectional rules."
    artifacts:
      - path: "lib/features/morphology/presentation/rules/rules_page.dart"
        issue: "Rule card shows only Text(rule.name) with no secondary binding text"
    missing:
      - "Restore secondary Text widget showing feature binding abbreviations under rule names"
  - truth: "Marker rows display the user-inputted name (e.g. 'Indicative') instead of hardcoded 'Unmarked'"
    status: failed
    reason: "The schema fix (v11 Markers.name) and domain fix (MarkerDecl.name) from 04-19-01 are intact, but the UI rendering in rules_page.dart was reverted — marker rows are no longer rendered at all because the entire inflectional grouped list was removed."
    artifacts:
      - path: "lib/features/morphology/presentation/rules/rules_page.dart"
        issue: "No marker row rendering code exists — the _buildInflectionalGroupedList that contained marker rows was removed by 04-20-03"
    missing:
      - "Restore marker row rendering in the inflectional rules list"
  - truth: "D-77 static MorphologyPreviewPanel is removed from rules_page.dart"
    status: failed
    reason: "Plan 04-15 (D-77) explicitly deleted the static preview panel from rules_page.dart. Plan 04-20-03 re-added it by importing morphology_preview_panel.dart and placing it in a VerticalDivider + Expanded layout in the right pane."
    artifacts:
      - path: "lib/features/morphology/presentation/rules/rules_page.dart"
        issue: "Lines 372-381: re-adds VerticalDivider + MorphologyPreviewPanel that was deleted in D-77"
    missing:
      - "Remove the MorphologyPreviewPanel and VerticalDivider from rules_page.dart body — the live preview is in rule_editor_dialog.dart's preview_panel.dart per D-77"
human_verification:
  - test: "After compile error is fixed: open Grammar > Inflections, select a POS, verify paradigm table shows above and inflectional rules list shows below"
    expected: "Paradigm table renders with paradigm cells. Rules list below is scoped to the selected POS. Markers appear with user-given names and ∅ badge. Binding summaries show level abbreviations."
    why_human: "Stacked layout, marker rendering, and binding summary display require visual verification"
  - test: "Open Lexicon > Derivations, create a new word with matching POS"
    expected: "Auto-apply fires and derived forms appear in the derivation tree"
    why_human: "Reactive reconciliation timing and tree rendering need interactive testing"
  - test: "Click an empty paradigm cell in inflections view"
    expected: "RuleEditorDialog opens with POS pre-selected and dimension levels pre-filled from the cell position"
    why_human: "Pre-fill behavior requires interactive testing with real dimension data"
  - test: "Open derivational rule editor, select output POS with intrinsic dimensions"
    expected: "Dropdown per intrinsic dimension appears below output POS picker. Selected values persist on save and reload."
    why_human: "Dropdown rendering and persistence require interactive testing"
  - test: "In Lexicon Dictionary, search for a derived form using its romanized name"
    expected: "Search returns results matching the romanized derived form"
    why_human: "Search behavior depends on actual derived forms existing in the database"
---

# Phase 04 Plan 20-01 through 20-03: Verification Report

**Phase Goal:** Users can define grammatical structure through N-dimensional feature systems per part of speech, with inflectional morphology rules organized by those dimensions and paradigm generation -- the current Morphology tab merges into Grammar, and derivational morphology moves to Lexicon
**Plan Wave:** 04-20 (plans 20-01 through 20-03, gap closure wave 12)
**Verified:** 2026-04-12T19:35:03Z
**Status:** gaps_found
**Re-verification:** Yes -- after wave 12 gap closure (previous wave 18 had 6 gaps)

---

## Goal Achievement

### Re-verification: Gap Status from 04-18-VERIFICATION

| # | Original Gap | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Standard form check uses phonemic IPA, not romanized form | CLOSED | `standard_form_validation_provider.dart:55-56` now calls `romanize(lexeme.ipa)` and matches against `romForm` |
| 2 | Single-row paradigm table excessive trailing width | CLOSED | `paradigm_table_widget.dart:581` wraps content in `IntrinsicWidth()` |
| 3 | Standard form violations preview in derivation rule editor | CLOSED | `rule_editor_dialog.dart:1650` renders `_StandardFormDerivationWarning` widget (lines 2330-2455) |
| 4 | Marker binding summary shows raw level IDs | REGRESSED | Fix from 04-19-01 (levelAbbrMap, bindingSummary) was removed when 04-20-03 rewrote rules_page.dart |
| 5 | Level abbreviations not shown on regular rules | REGRESSED | Fix from 04-19-01 (secondary Text with binding display) was removed by 04-20-03 rewrite |
| 6 | Marker rows say 'Unmarked' instead of inputted name | REGRESSED | Schema/domain fixes intact (Markers.name column, MarkerDecl.name field) but UI rendering removed -- marker rows no longer exist in rules_page.dart |

**3 gaps closed, 3 gaps regressed.**

### Observable Truths -- Plan 20-01 Must-Haves

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Clicking empty paradigm cell opens RuleEditorDialog with POS pre-selected and dimension levels pre-filled | VERIFIED | `paradigm_table_widget.dart:726` passes `preFilledPosIds: {posId}`; `rule_editor_dialog.dart:227,252,366-368` implements `preFilledPosIds` parameter and initState seeding |
| 2 | Derivation rule editor shows intrinsic level picker when output POS has intrinsic dimensions | VERIFIED | `rule_editor_dialog.dart:324-325` declares `_outputIntrinsicLevels`; lines 1244-1309 render DropdownButtonFormField per intrinsic dim; save/load wired via `featureBindings.outputIntrinsic` |

### Observable Truths -- Plan 20-02 Must-Haves

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 3 | Creating a new word with matching POS auto-triggers derivation reconcile | VERIFIED | `word_creation_form.dart:241-243` calls `reconcile()` after `insertLexeme`; `word_detail_panel.dart:253-255` calls `reconcile()` after `updateLexeme` |
| 4 | Clicking derived word in derivation tree navigates to that word's detail page | VERIFIED | `derivation_tree_widget.dart:38,46,127,208,222,458-460` threads `onNavigateToWord` callback and wraps promoted rows in GestureDetector |
| 5 | Derived words created via rules show parent pill in Parents section | VERIFIED | `word_detail_panel.dart:1222-1238` checks `lexeme.derivedFromLexemeId` and renders rule-derived parent with "via RuleName" text |
| 6 | Searching for derived form's romanized name returns results | VERIFIED | `lexeme_providers.dart:175-178` computes `romForm = romanize(form)` and matches against both IPA and romanized form |

### Observable Truths -- Plan 20-03 Must-Haves

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 7 | POS can be deleted with confirmation dialog and word migration picker | VERIFIED | `pos_dimensions_page.dart:27-105` implements `_deletePos()` with `_PosDeleteDialog`, word count check, DropdownButton migration picker, and cascade delete |
| 8 | Custom dimension template appears at top and prompts for name before adding | VERIFIED | `dimension_template_picker.dart:91` renders `_customCard` before grouped templates; lines 142-165 show AlertDialog with TextField for name input |
| 9 | Derivation rules in rules list show input->output POS labels with abbreviations | VERIFIED | `rules_page.dart:87,211-215,237` builds posById map and renders "abbr. -> abbr." secondary text for derivational rules |

### BLOCKER: Compile Error Regression

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 10 | App compiles without errors | FAILED | `dart analyze lib/` reports 1 error in `inflections_page.dart:237`: `posScopeFilter` parameter was removed from `RulesPage` by 04-20-03 but `inflections_page.dart` still references it. Additionally, `test/widget/grammar/rules_page_pos_grouping_test.dart` has 3 compile errors referencing removed exports. |

**Score:** 5/10 truths verified (9 plan must-haves verified, but 5 failures from regressions + compile error)

---

### Root Cause Analysis

Plan 04-20-03 Task 3 asked to "show input->output POS labels on derivational rules in the rules list." The executor rewrote `rules_page.dart` from 689 lines to 424 lines, removing:

1. **`groupInflectionalRulesByPosSet` function** (D-56, plan 04-11) -- inflectional rules POS-set grouping
2. **`_buildInflectionalGroupedList` method** -- the entire inflectional-mode rendering path including markers, binding summaries, ∅ badges
3. **`posScopeFilter` parameter** (D-50, plan 04-13) -- used by inflections_page.dart
4. **`levelAbbrMap` and `bindingSummary()`** (04-19-01 gap fix) -- level abbreviation resolution
5. **Marker row rendering** (04-18-05 + 04-19-01) -- marker.name display, ∅ badge
6. **Phoneme violation icon** (D-81, plan 04-16) -- phoneme literal scanner warnings
7. **D-77 deletion was reversed** -- static MorphologyPreviewPanel and VerticalDivider re-added

This rewrote the file to what appears to be an earlier version of rules_page.dart (pre-04-11), losing ~10 plans worth of accumulated work.

---

### Required Artifacts -- Regression Check

| Artifact | Status | Details |
|----------|--------|---------|
| `lib/features/morphology/presentation/rules/rules_page.dart` | REGRESSED | Lost D-56 grouping, D-50 scope filter, D-77 preview removal, 04-18-05 markers, 04-19-01 binding summaries |
| `lib/features/grammar/presentation/inflections/inflections_page.dart` | BROKEN | Compile error on line 237: references removed `posScopeFilter` |
| `test/widget/grammar/rules_page_pos_grouping_test.dart` | BROKEN | 3 compile errors: missing function + missing parameter |
| `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` | VERIFIED | preFilledPosIds + outputIntrinsicLevels correctly added |
| `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` | VERIFIED | preFilledPosIds passed on cell click |
| `lib/features/grammar/domain/feature_bindings.dart` | VERIFIED | outputIntrinsic field with backward-compatible JSON parsing |
| `lib/features/lexicon/presentation/dictionary/word_creation_form.dart` | VERIFIED | reconcile() after insertLexeme |
| `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart` | VERIFIED | reconcile() after updateLexeme + rule-derived parent pill |
| `lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart` | VERIFIED | onNavigateToWord callback threaded and wired |
| `lib/features/lexicon/data/lexeme_providers.dart` | VERIFIED | romanize(form) in derived form search matching |
| `lib/features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart` | VERIFIED | POS delete with migration dialog |
| `lib/features/grammar/presentation/pos_dimensions/dimension_template_picker.dart` | VERIFIED | Custom at top with name prompt |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| paradigm_table_widget cell click | RuleEditorDialog.preFilledPosIds | constructor parameter | WIRED |
| RuleEditorDialog initState | _inflectionalPosSet seeding | widget.preFilledPosIds | WIRED |
| RuleEditorDialog derivational mode | _outputIntrinsicLevels dropdowns | dimensionsForPosProvider | WIRED |
| word_creation_form _save() | reconcile() | derivationPromotionServiceProvider | WIRED |
| derivation_tree_widget _DerivedRow | onNavigateToWord | GestureDetector tap | WIRED |
| word_detail_panel Parents section | lexeme.derivedFromLexemeId | rule-derived parent pill | WIRED |
| lexeme_providers search | romanize(form) | romanizeProvider | WIRED |
| pos_dimensions_page delete | _PosDeleteDialog + migration | morphologyDao.deletePos | WIRED |
| inflections_page | RulesPage.posScopeFilter | **BROKEN** -- parameter removed | NOT_WIRED |
| rules_page inflectional mode | _buildInflectionalGroupedList | **REMOVED** -- method deleted | NOT_WIRED |

### Requirements Coverage

| Requirement | Source Plans | Status | Evidence |
|-------------|-------------|--------|----------|
| GRAM-01 | 20-03 | SATISFIED | POS delete lifecycle with word migration |
| GRAM-02 | 20-01 | PARTIALLY BLOCKED | preFilledPosIds works but inflections_page compile error prevents use |
| GRAM-03 | 20-01 | PARTIALLY BLOCKED | Paradigm cell click wiring works but inflections_page compile error prevents rendering |
| GRAM-04 | (prior waves) | SATISFIED | Typology page intact |
| GRAM-05 | 20-01 | PARTIALLY BLOCKED | Cell override infrastructure intact but inflections_page blocked |
| GRAM-06 | 20-03 | REGRESSED | MorphologyPreviewPanel (D-77 deleted) was re-added to rules_page |
| GRAM-07 | 20-02 | SATISFIED | Derivation lifecycle complete: auto-apply, navigation, parent pill, search |
| LEX-01 | 20-02 | SATISFIED | Word creation triggers reconcile |
| LEX-02 | 20-02 | SATISFIED | Derived word etymology navigation |
| LEX-03 | 20-02 | SATISFIED | Romanized derived form search |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/features/grammar/presentation/inflections/inflections_page.dart` | 237 | Compile error: undefined_named_parameter `posScopeFilter` | BLOCKER | App cannot build |
| `lib/features/morphology/presentation/rules/rules_page.dart` | 372-381 | Re-added D-77-deleted MorphologyPreviewPanel + VerticalDivider | BLOCKER | Reverts D-77 architectural decision |
| `lib/features/morphology/presentation/rules/rules_page.dart` | entire file | Lost ~265 lines of inflectional grouped list, marker display, binding summaries | BLOCKER | Reverts work from plans 04-11, 04-13, 04-16, 04-18-05, 04-19-01 |
| `test/widget/grammar/rules_page_pos_grouping_test.dart` | 115,142,275 | 3 compile errors from removed exports | BLOCKER | Test suite cannot compile |

### Human Verification Required

1. **Inflections stacked layout (after compile fix)**
   - **Test:** Open Grammar > Inflections, select a POS, verify paradigm + rules layout
   - **Expected:** Paradigm table above, inflectional rules below scoped to selected POS, markers with names and ∅ badges
   - **Why human:** Stacked layout proportions, marker rendering, binding summaries need visual check

2. **Paradigm cell pre-fill**
   - **Test:** Click an empty paradigm cell
   - **Expected:** RuleEditorDialog opens with POS pre-selected and levels pre-filled
   - **Why human:** Pre-fill behavior requires interactive testing

3. **Derivation auto-apply**
   - **Test:** Create a new word matching an auto-apply derivational rule
   - **Expected:** Derived forms appear automatically in derivation tree
   - **Why human:** Reactive reconciliation timing needs interactive testing

4. **Output intrinsic level picker**
   - **Test:** Open derivational rule editor with output POS having intrinsic dimensions
   - **Expected:** Level picker dropdowns appear, persist on save/reload
   - **Why human:** Dropdown rendering and persistence cycle needs interactive testing

5. **Derived word navigation + parent pill**
   - **Test:** Click a promoted derived word in the derivation tree
   - **Expected:** Navigates to that word's detail; parent pill shows "via RuleName"
   - **Why human:** Navigation callback and pill rendering need interactive testing

### Gaps Summary

**1 compile error BLOCKER + 4 regressions from plan 04-20-03.**

Plan 04-20-03 rewrote `rules_page.dart` instead of surgically adding derivational POS labels. The rewrite removed the entire inflectional-mode rendering path (D-56 grouping, D-50 POS scope filter, markers, binding summaries) and re-added the static MorphologyPreviewPanel that was explicitly deleted in D-77.

The compile error in `inflections_page.dart` prevents the app from building. The 3 test compile errors prevent the test suite from running.

All 9 new plan must-haves from 20-01, 20-02, and 20-03 are verified at the code level, but the app is unbuildable due to the regression.

**Priority fix:** Restore `rules_page.dart` to the pre-04-20-03 version (commit `66ddd7f`) and then surgically apply the 04-20-03 Task 3 changes (posById map + derivational POS label) without removing existing code.

---

_Verified: 2026-04-12T19:35:03Z_
_Verifier: Claude (gsd-verifier)_
