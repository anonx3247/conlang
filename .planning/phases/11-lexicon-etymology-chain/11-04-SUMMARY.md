---
phase: 11-lexicon-etymology-chain
plan: "04"
subsystem: lexicon
tags: [gap-closure, uat-fix, display, promoted-derivation, searchable-parent-selector]
dependency_graph:
  requires: ["11-02", "11-03"]
  provides: ["UAT-Test-1-fix"]
  affects: [searchable_parent_selector]
tech_stack:
  added: []
  patterns: ["promotedDerivedFormProvider + resolveDisplayForms for display-layer derived form resolution"]
key_files:
  created: []
  modified:
    - lib/features/lexicon/presentation/dictionary/searchable_parent_selector.dart
decisions:
  - "Use ref.read (not ref.watch) for promotedDerivedFormProvider in Autocomplete callbacks — avoids N provider subscriptions; allLexemeListProvider watch already drives rebuilds"
metrics:
  duration_minutes: 10
  completed_date: "2026-04-15"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 1
requirements:
  - LEX-09
---

# Phase 11 Plan 04: SearchableParentSelector Derived Form Display Summary

**One-liner:** Wired `promotedDerivedFormProvider` + `resolveDisplayForms` into `SearchableParentSelector` so autocomplete, search filter, and pills show computed derived forms instead of raw D-58 placeholder values.

## What Was Built

`SearchableParentSelector` previously read `lx.romanization` and `lx.ipa` directly, which for promoted-derivation lexemes stores the parent's IPA as a placeholder (D-58 design). This made the autocomplete dropdown show the parent's phonemes for derived words — the UAT Test 1 issue.

Three changes were made to `_SearchableParentSelectorState`:

1. **`_labelForLexeme` helper** — new private method that calls `ref.read(promotedDerivedFormProvider(lx.id))` and passes the result to `resolveDisplayForms`, then formats the `rom` field with meaning (matching the existing label format).

2. **`_displayStringForOption`** — simplified to a single-line delegation to `_labelForLexeme`.

3. **`optionsBuilder` search predicate** — the `.where` clause now calls `resolveDisplayForms` via `ref.read(promotedDerivedFormProvider)` per candidate, matching against `forms.rom` and `forms.ipa` instead of raw `lx.romanization` and `lx.ipa`. The `.take(20)` DoS cap is preserved.

4. **Selected pills** (`Wrap` section) — replaced the inline label computation with `_labelForLexeme(lx)`.

No new imports were required — `promotedDerivedFormProvider` and `resolveDisplayForms` are already exported from `lexeme_providers.dart`.

## Commits

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Wire promotedDerivedFormProvider into SearchableParentSelector | 17231af |

## Verification

- `dart analyze lib/features/lexicon/presentation/dictionary/searchable_parent_selector.dart` — **No issues found**
- UAT Test 1 gap closed: autocomplete shows computed derived forms (not parent placeholders)
- Search filtering matches against resolved romanization/IPA of derived words
- Selected pills display the correct derived form

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. This is a purely display-layer change: no new data inputs, network calls, schema changes, or trust boundaries.

## Self-Check: PASSED

- [x] `lib/features/lexicon/presentation/dictionary/searchable_parent_selector.dart` — modified and committed
- [x] Commit `17231af` exists in git log
- [x] `dart analyze` reports zero errors
