---
phase: 04-grammar-morphology-revised
plan_wave: 18 (plans 18-01 through 18-05)
verified: 2026-04-12T20:00:00Z
status: gaps_found
score: 19/19 plan must-haves verified
overrides_applied: 0
gaps:
  - truth: "Standard form validation checks phonemic IPA form but should check romanized/phonemic form — patterns entered as romanized text do not match"
    status: failed
    reason: "standard_form_validation_provider.dart line 53 calls matcher.matches(lexeme.ipa, ...) using the stored IPA field. The StandardFormPatternDialog hint says 'e.g. ar, Vr' (IPA/phonemic) but user enters romanized text. The mismatch means a pattern of 'o' does not match lexeme.ipa that stores phonemic IPA '/o/' when rewrite rules map o→ø (phonetic), making the check fail on the wrong form."
    artifacts:
      - path: "lib/features/grammar/data/standard_form_validation_provider.dart"
        issue: "Line 53: matcher.matches(lexeme.ipa, branches, inventory) — runs against phonemic IPA instead of romanized form. Should run against lexeme.romanization (or resolveDisplayForms.rom) so patterns match what the user typed."
    missing:
      - "In standardFormViolationsProvider, resolve the romanized form via resolveDisplayForms or lexeme.romanization and pass that to matcher.matches instead of lexeme.ipa"
      - "OR: clearly document that patterns must be in IPA notation, and fix the StandardFormPatternDialog hint to reflect this"
  - truth: "Single-row paradigm table has appropriate width — no excessive trailing width when only one data row"
    status: failed
    reason: "_buildSingleDimTable wraps content in SingleChildScrollView(scrollDirection: Axis.horizontal) with a Column(crossAxisAlignment: CrossAxisAlignment.start). The SingleChildScrollView expands to the parent's full width even when the content (N levels × 80px) is narrower, producing a visible trailing empty space/line."
    artifacts:
      - path: "lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart"
        issue: "_buildSingleDimTable (line 578): SingleChildScrollView expands to parent width; fix with IntrinsicWidth wrapper or Align(alignment: Alignment.centerLeft) + fixed-width Column to prevent trailing empty space"
    missing:
      - "Wrap the Column inside _buildSingleDimTable with IntrinsicWidth() or Align(widthFactor: 1.0) to constrain the scroll view to its content width"
  - truth: "Standard form violations on derived forms surface in the derivation rule editor when output POS + level is known"
    status: failed
    reason: "Not implemented anywhere in plans 18-01 through 18-05. The rule_editor_dialog.dart has no standard-form preview for derivational rules. No provider, no UI hook, no connection between standardFormViolationsProvider and the derivation rule editor."
    artifacts:
      - path: "lib/features/morphology/presentation/rules/rule_editor_dialog.dart"
        issue: "No standard form violation preview in the derivation rule editor — the dialog shows only the morphological output preview, not whether that output violates any standard-form pattern for the target POS + intrinsic level"
    missing:
      - "In rule_editor_dialog.dart (derivational mode), when outputPosId and output intrinsic level are known, watch standardFormViolationsProvider for a sample derived form and show a warning if the derived form would violate any standard-form pattern"
  - truth: "Marker binding summary shows actual level abbreviations (e.g. 'PRS · PFV') not raw level IDs (e.g. 'lv1 · lv1')"
    status: failed
    reason: "rules_page.dart bindingSummary() at line 536 explicitly uses 'lv$id' for each level ID. The SUMMARY for 04-18-05 acknowledged this as a known limitation: 'Binding summary in list uses level IDs (lv42 style) — full dim name lookup would require extra provider reads not worth it for a list row.'"
    artifacts:
      - path: "lib/features/morphology/presentation/rules/rules_page.dart"
        issue: "Line 536: bindings.dims.values.map((id) => 'lv$id').join(' · ') — shows raw database IDs. Needs to resolve level abbreviations from dimensionsForPosProvider or a cached dim map."
    missing:
      - "Resolve level abbreviations in bindingSummary() by watching dimensionsForPosProvider(marker.posId) to get the Dimension list, then decode levelsJson to find the abbr for each level ID"
      - "Or add a cached posId → List<Dimension> lookup at the top of _buildInflectionalGroupedList to avoid per-marker provider reads"
  - truth: "Level abbreviations show on regular inflection/derivation rules under their names in the rules list"
    status: failed
    reason: "Regular rule rows in _buildInflectionalGroupedList (rules_page.dart lines 589-596) display only rule.name with no binding summary beneath. The featureBindings field exists on MorphologicalRule but is never rendered in the list view."
    artifacts:
      - path: "lib/features/morphology/presentation/rules/rules_page.dart"
        issue: "Rule card Row (line 589) shows only Text(rule.name) — no secondary text showing level abbreviations from rule.featureBindings"
    missing:
      - "Below rule.name in the rule card, add a secondary Text widget showing the feature binding abbreviations (same resolution logic as marker bindingSummary but using rule.featureBindings)"
  - truth: "Marker rows display the name inputted during creation (e.g. 'Indicative') instead of the hardcoded 'Unmarked' label"
    status: failed
    reason: "The Markers database table has no 'name' column. MarkerDecl domain class has only id, posId, and bindings fields. The RuleEditorDialog shows a rule name field in marker mode but _saveMarker() calls MarkerDao.insertMarker(posId: ..., bindings: ...) with no name parameter — the name is never persisted. The rules list hardcodes 'Unmarked' at line 697."
    artifacts:
      - path: "lib/db/app_database.dart"
        issue: "Markers table (line 247) has no TextColumn for name — schema migration required"
      - path: "lib/features/grammar/domain/marker.dart"
        issue: "MarkerDecl class has no name field"
      - path: "lib/features/grammar/data/marker_dao.dart"
        issue: "insertMarker/updateMarker signatures have no name parameter"
      - path: "lib/features/morphology/presentation/rules/rules_page.dart"
        issue: "Line 697: hardcoded 'Unmarked' text — no name field to display"
    missing:
      - "Add TextColumn get name to the Markers table with a migration (schema v12 or next version)"
      - "Update MarkerDecl to include a name field"
      - "Update MarkerDao.insertMarker and updateMarker to accept a name parameter"
      - "In RuleEditorDialog._saveMarker(), pass the current rule name text to MarkerDao"
      - "In rules_page.dart marker row, render marker.name instead of 'Unmarked'"
---

# Phase 04 Plan 18-01 through 18-05: Verification Report

**Phase Goal:** Users can create and manage dimensional POS features, inflectional rules, paradigm generation, and morphology tab merge.
**Plan Wave:** 04-18 (plans 18-01 through 18-05, executed 2026-04-12)
**Verified:** 2026-04-12T20:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths — Plan Must-Haves

All 19 must-haves across the 5 plans are VERIFIED in the codebase. The plan-level goals were achieved.

| # | Plan | Truth | Status | Evidence |
|---|------|-------|--------|----------|
| 1 | 18-01 | Editing a promoted derivation shows derived IPA/rom, not root's | VERIFIED | `_startEditing` reads `promotedDerivedFormProvider` + `resolveDisplayForms` at line 141-144 |
| 2 | 18-01 | [bracket] display shows post-rewrite phonetic form | VERIFIED | `word_list_panel.dart` lines 380, 494, 544, 659 use `applyRewritePipelineProvider` |
| 3 | 18-01 | POS pill shows intrinsic level e.g. 'Noun (Masculine)' | VERIFIED | `_IntrinsicPosBadge` ConsumerWidget at line 1296; wired at line 665 |
| 4 | 18-01 | Parent pills are clickable and navigate to parent's card | VERIFIED | `WordDetailParentsSection` accepts `onNavigateToWord` callback; `ActionChip` renders |
| 5 | 18-02 | Level chip edit/standard-form icons are clickable | VERIFIED | `_LevelChip` custom Container widget replaces `InputChip`; each icon has own `InkWell` |
| 6 | 18-02 | Phonetic preview integrates into IPA section (helperText) | VERIFIED | `word_creation_form.dart` uses `helperText: showPhonetic ? '[$phonetic]' : null` |
| 7 | 18-02 | Confirmation dialog before deleting dimension/level | VERIFIED | `AlertDialog` confirmation before D-86 dependency check and `dao.deleteDimension` |
| 8 | 18-03 | 1-dim paradigm renders single-row table (not error) | VERIFIED | `_buildSingleDimTable` called when `dims.length == 1` at line 136 |
| 9 | 18-03 | Word detail paradigm shows only that word's intrinsic slice | VERIFIED | `_buildStackedIntrinsicSlices` detects `lexemeId != -1`, decodes `intrinsicLevelsJson`, renders single slice |
| 10 | 18-03 | Grammar tab paradigm allows multi-word selection | VERIFIED | `Set<int> _selectedLexemeIds` + `FilterChip` list in `inflections_page.dart`; `lexemeIds` param passed to `ParadigmTableWidget` |
| 11 | 18-04 | Words must have POS assigned (validation error on save) | VERIFIED | `_posError` state field + check in `_save()` at line 144-147 in `word_creation_form.dart` |
| 12 | 18-04 | Words with intrinsic dims must have levels assigned | VERIFIED | `_intrinsicLevelErrors` check in `_save()` in `word_creation_form.dart` |
| 13 | 18-04 | rootOnlyViaDerivations words exempt from POS requirement | VERIFIED | `!_rootOnlyViaDerivations &&` guard in `_save()` and `_saveEdit()` |
| 14 | 18-04 | Words without intrinsic level show warning icon after dimension marked intrinsic | VERIFIED | `missingIntrinsicAssignmentCountProvider` wired to `Icons.warning_amber_outlined` in dimension card |
| 15 | 18-04 | Word detail edit mode phonetic preview in IPA field (helperText) | VERIFIED | `word_detail_panel.dart` Builder block at line 803-845 uses `helperText: showPhonetic ? '[$phonetic]' : null` |
| 16 | 18-05 | RuleEditorDialog has 'Leave as unmarked' checkbox (inflectional only) | VERIFIED | `CheckboxListTile` at line 1467 shown only when `widget.kind == RuleKind.inflectional` |
| 17 | 18-05 | In marker mode, operations and preview are hidden; bindings remain | VERIFIED | `if (!_leaveAsUnmarked)` guards around branch cards and preview panel at lines 1488, 1518 |
| 18 | 18-05 | Saving in marker mode writes to MarkerDao, not MorphologyDao | VERIFIED | `_saveMarker()` called when `_leaveAsUnmarked == true` at line 563-564 |
| 19 | 18-05 | Markers appear in rules list with ∅ badge; tap opens editor in marker mode | VERIFIED | `markersForPosProvider` polled per-POS in `_buildInflectionalGroupedList`; ∅ badge rendered; tap opens `RuleEditorDialog` with `markerId` |

**Plan Score:** 19/19 must-haves verified.

---

### User-Reported Issues (Required Gap Capture)

Six issues reported during execution. All 6 are confirmed unresolved in the current codebase.

| # | Issue | Status | Root Cause |
|---|-------|--------|-----------|
| 1 | Standard form check uses phonemic IPA, not romanized form | FAILED | `standard_form_validation_provider.dart:53` passes `lexeme.ipa` to matcher |
| 2 | Single-row paradigm table has excessive trailing width | FAILED | `SingleChildScrollView` expands to parent width; no `IntrinsicWidth` constraint |
| 3 | Standard form violations should preview in derivation rule editor | FAILED | No implementation in rule_editor_dialog.dart for derivational standard-form preview |
| 4 | Marker binding summary shows raw level IDs ('lv1 · lv1') | FAILED | `rules_page.dart:536` uses `'lv$id'` — no level abbreviation resolution |
| 5 | Level abbreviations not shown on regular inflection/derivation rules | FAILED | Rule card (line 589) renders only `rule.name` — no feature binding display |
| 6 | Marker rows say 'Unmarked' instead of inputted name | FAILED | `Markers` table has no `name` column; `MarkerDecl` has no `name` field; name never persisted |

---

### Artifacts Verified

| Artifact | Status | Notes |
|----------|--------|-------|
| `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart` | VERIFIED | `_startEditing` fix, `_IntrinsicPosBadge`, `_posError`, helperText preview |
| `lib/features/lexicon/presentation/dictionary/word_list_panel.dart` | VERIFIED | `applyRewritePipelineProvider` bracket fix in list and table views |
| `lib/features/lexicon/presentation/dictionary/dictionary_page.dart` | VERIFIED | `onNavigateToWord: _onWordSelected` wired |
| `lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart` | VERIFIED | `_LevelChip`, confirmation dialogs, `missingIntrinsicAssignmentCountProvider` warning |
| `lib/features/lexicon/presentation/dictionary/word_creation_form.dart` | VERIFIED | helperText preview, `_posError`, POS mandatory validation |
| `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` | VERIFIED | `_buildSingleDimTable`, word-detail intrinsic filter, `lexemeIds` param, D-103 marker cell click |
| `lib/features/grammar/presentation/inflections/inflections_page.dart` | VERIFIED | `Set<int> _selectedLexemeIds`, FilterChip multi-select, `lexemeIds` param pass-through |
| `lib/features/grammar/data/grammar_providers.dart` | VERIFIED | `missingIntrinsicAssignmentCountProvider` present |
| `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` | VERIFIED | `_leaveAsUnmarked`, marker mode UI, `_saveMarker()` path |
| `lib/features/morphology/presentation/rules/rules_page.dart` | VERIFIED (with gap) | Markers merged into list, ∅ badge, tap-to-edit; binding summary uses raw IDs (gap #4) |
| `lib/features/grammar/data/standard_form_validation_provider.dart` | FAILED | Uses `lexeme.ipa` not romanized form (gap #1) |
| `lib/features/grammar/domain/marker.dart` | FAILED | No `name` field (gap #6) |
| `lib/db/app_database.dart` (Markers table) | FAILED | No `name` column in Markers table (gap #6) |

---

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `word_detail_panel._startEditing` | `promotedDerivedFormProvider` | `resolveDisplayForms` | WIRED |
| `word_list_panel bracket display` | `applyRewritePipelineProvider` | `ref.watch` hoisted above loop | WIRED |
| `dimension_editor_panel _LevelChip` | `_LevelEditDialog / StandardFormPatternDialog` | Direct `InkWell.onTap` | WIRED |
| `word_creation_form save` | POS validation | `_posError` null check | WIRED |
| `inflections_page FilterChip` | `ParadigmTableWidget.lexemeIds` | `_selectedLexemeIds.toList()` | WIRED |
| `rule_editor_dialog _leaveAsUnmarked` | `MarkerDao.insertMarker/updateMarker` | `_saveMarker()` branch | WIRED |
| `rules_page marker row tap` | `RuleEditorDialog` marker mode | `markerId: marker.id, markerBindings: marker.bindings` | WIRED |
| `paradigm_table_widget ParadigmUnmarked cell` | `RuleEditorDialog` marker mode | `if (localCell is ParadigmUnmarked)` at line 688 | WIRED |
| `standard_form_validation_provider` | `lexeme.ipa` (phonemic) | NOT romanized form | BROKEN (gap #1) |
| `rules_page bindingSummary` | level abbreviations | Raw IDs only | BROKEN (gap #4) |
| `RuleEditorDialog._saveMarker` | `marker.name` persistence | No name field in schema | BROKEN (gap #6) |

---

### Requirements Coverage

| Requirement | Plans | Status | Evidence |
|-------------|-------|--------|----------|
| GRAM-01 (POS with dimensions) | 18-01, 18-02, 18-04 | SATISFIED | POS pill, level chip fix, POS validation |
| GRAM-02 (inflectional rules with dimension levels) | 18-02, 18-04, 18-05 | SATISFIED | Dimension editor, validation, marker CRUD |
| GRAM-03 (paradigm charts) | 18-03, 18-05 | SATISFIED | 1-dim rendering, intrinsic slice, marker cell click |
| GRAM-04 (language typology / paradigm) | 18-01, 18-03 | SATISFIED | Intrinsic level badge, word-detail filter |
| GRAM-05 (paradigm cell overrides) | 18-03 | SATISFIED | Multi-word selection, single-row table |
| LEX-01 (add/edit/delete words) | 18-04 | SATISFIED | POS mandatory validation on word save |

---

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `standard_form_validation_provider.dart:53` | Uses `lexeme.ipa` (phonemic IPA) for standard form check instead of romanized form | BLOCKER | Standard form violations fire against wrong form — patterns entered as romanized text will fail even for valid words |
| `rules_page.dart:536` | `'lv$id'` raw ID string in binding summary | BLOCKER | Marker binding summary is unreadable to users ("lv42 · lv18" means nothing without level name resolution) |
| `rules_page.dart:697` | Hardcoded `'Unmarked'` label for all marker rows | BLOCKER | All markers appear identical regardless of names the user intended; no schema column to store the name |
| `paradigm_table_widget.dart:578` | `SingleChildScrollView` without `IntrinsicWidth` in `_buildSingleDimTable` | WARNING | Trailing empty space in single-row paradigm table |

---

### Gaps Summary

Six gaps identified, all stemming from user-reported issues during execution. The plan must-haves were fully implemented and correct. The gaps represent functionality the user explicitly expected that was either not covered by the plans or was knowingly deferred by the executor with an acknowledged trade-off.

**Root cause grouping:**

**Group A — Marker name persistence (issues #4, #6):** The `Markers` table schema has no `name` column. This means marker rows cannot display a user-given name, and the binding summary must fall back to raw IDs. Both issues share the same schema root cause and require a single migration + domain model update to fix.

**Group B — Standard form check surface (issue #1):** The validator runs against `lexeme.ipa` (stored phonemic IPA) rather than the romanized form. If patterns are entered as romanized text ("o"), they will not match IPA symbols ("ø"). The fix requires either (a) running the check against the romanized form, or (b) documenting clearly that patterns must be in IPA notation and updating the dialog hint.

**Group C — Missing features not in 04-18 scope (issues #3, #5):**
- Standard form preview in the derivation rule editor (issue #3) requires connecting `standardFormViolationsProvider` to the rule editor's preview panel for derivational mode — no implementation exists.
- Level abbreviations under regular rule names (issue #5) requires rendering `rule.featureBindings` as a secondary line in the rule card — currently only `rule.name` is shown.

**Group D — Layout issue (issue #2):** The single-row paradigm table has excessive trailing width due to `SingleChildScrollView` expanding to parent width. An `IntrinsicWidth` wrapper would constrain it.

---

### Human Verification Required

The following items require interactive testing and cannot be verified programmatically.

**1. Chip Hit-Test Fix (18-02)**
- **Test:** In dimension editor, tap the edit icon on a level chip. Tap the standard-form icon on an intrinsic dimension chip.
- **Expected:** Edit icon opens the rename dialog directly; standard-form icon opens the pattern dialog. Neither requires a secondary tap.
- **Why human:** Hit-test behavior on custom Container widgets requires physical touch/click testing.

**2. Confirmation Dialogs Behavior (18-02)**
- **Test:** Delete a dimension level and a dimension. Observe dialog presentation and dismissal.
- **Expected:** AlertDialog with "Delete level?" or "Delete dimension?" title appears; Cancel returns to editor; Delete (red) proceeds.
- **Why human:** Dialog appearance timing, button color, and dismissal animation need visual verification.

**3. Single-Row Paradigm (18-03) — if issue #2 is fixed**
- **Test:** Create a POS with exactly 1 non-intrinsic dimension; view paradigm.
- **Expected:** A single row of cells (one per level) with header row above; no "minimum 2 dimensions" error.
- **Why human:** Visual layout and scrollability need interactive testing.

**4. Intrinsic POS Badge (18-01)**
- **Test:** Open word detail for a word whose POS has intrinsic dimensions and levels assigned.
- **Expected:** POS chip reads "Noun (Masculine)" not just "Noun".
- **Why human:** Requires live data with intrinsic levels configured.

**5. Marker CRUD Workflow (18-05)**
- **Test:** Open RuleEditorDialog → inflectional → check "Leave as unmarked" → select bindings → Save. Then tap the resulting ∅ row to reopen. Then click a ∅ paradigm cell.
- **Expected:** Marker appears in list with ∅ badge; reopening shows bindings pre-loaded; paradigm cell click opens marker edit dialog.
- **Why human:** Full end-to-end flow with DB state and reactive rebuilds needs interactive verification.

---

_Verified: 2026-04-12T20:00:00Z_
_Verifier: Claude (gsd-verifier)_
