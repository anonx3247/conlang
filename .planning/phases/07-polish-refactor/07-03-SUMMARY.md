---
phase: 07-polish-refactor
plan: "03"
subsystem: morphology/grammar
tags: [refactor, safety, dart-analysis]
dependency_graph:
  requires: [07-01, 07-02]
  provides: [rule-editor-refactored, getSingle-safety]
  affects: [morphology-rule-editor, grammar-dao, lexeme-dao, morphology-dao]
tech_stack:
  added: []
  patterns: [free-function-extraction, widget-decomposition, parameter-passing-refactor]
key_files:
  created:
    - lib/features/morphology/presentation/rules/rule_editor/rule_editor_body.dart
    - lib/features/morphology/presentation/rules/rule_editor/form_state_models.dart
    - lib/features/morphology/presentation/rules/rule_editor/operation_editor.dart
    - lib/features/morphology/presentation/rules/rule_editor/condition_editor.dart
    - lib/features/morphology/presentation/rules/rule_editor/branch_editor.dart
    - lib/features/morphology/presentation/rules/rule_editor/pos_binding_editor.dart
    - lib/features/morphology/presentation/rules/rule_editor/standard_form_warning.dart
    - lib/features/morphology/presentation/rules/rule_editor/form_loader.dart
    - lib/features/morphology/presentation/rules/rule_editor/save_actions.dart
  modified:
    - lib/features/morphology/presentation/rules/rule_editor_dialog.dart
    - lib/features/grammar/data/grammar_dao.dart
    - lib/features/lexicon/data/lexeme_dao.dart
    - lib/features/morphology/data/morphology_dao.dart
    - lib/features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart
decisions:
  - "save_actions.dart uses free async functions with all parameters passed explicitly — avoids tying save logic to widget lifecycle while keeping zero behavior change"
  - "SaveResult value type carries validationError, saveBlockedReason, done — caller interprets and applies setState"
  - "Soft null handling (return early) in presentation layer; StateError with descriptive message in DAO layer"
metrics:
  duration: "~90 minutes"
  completed: "2026-04-12"
  tasks: 2
  files: 14
---

# Phase 07 Plan 03: Dead Code + getSingle Safety + Rule Editor Refactor Summary

Dead code removed, all `getSingle()` calls replaced with safe `getSingleOrNull()` equivalents, and the 2486-line `rule_editor_dialog.dart` decomposed into a `rule_editor/` subdirectory with 10 files each under 500 lines.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | getSingle() safety fixes (D-17, D-18) | `4c53f0f` | grammar_dao, lexeme_dao, morphology_dao, pos_dimensions_page |
| 2 | rule_editor_dialog.dart refactor (D-13–D-16) | `fca8b06` | rule_editor_dialog.dart + 9 new files in rule_editor/ |

## Task 1: getSingle() Safety

All Drift `getSingle()` calls replaced across four files:

- **grammar_dao.dart** — `nextLevelId` and `reassignLevelAndDelete`: `getSingleOrNull()` + `throw StateError(...)` with row ID in message
- **lexeme_dao.dart** — `promoteDerivation` rule lookup and parent lexeme lookup: same pattern
- **morphology_dao.dart** — `swapOrdering` (rule A and B) and `nextOrdering` COALESCE query: same pattern
- **pos_dimensions_page.dart** — COUNT query in `_deletePos`: `getSingleOrNull()` + `if (result == null) return;` (presentation layer soft handling)

## Task 2: Rule Editor Decomposition

Original `rule_editor_dialog.dart` (2486 lines) split into:

| File | Lines | Contents |
|------|-------|----------|
| `rule_editor_dialog.dart` | 89 | Thin Dialog shell only |
| `rule_editor_body.dart` | 484 | ConsumerStatefulWidget with form state + build |
| `form_state_models.dart` | 173 | OpType enum, OpState, CondState, BranchState |
| `operation_editor.dart` | 436 | OperationRow, _OpFields, PhonemeViolationRow |
| `condition_editor.dart` | 148 | ConditionEditor |
| `branch_editor.dart` | 129 | BranchEditor |
| `pos_binding_editor.dart` | 477 | InflectionalTopSection, DerivationalTopSection |
| `standard_form_warning.dart` | 209 | BijectionLockedView, StandardFormDerivationWarning |
| `form_loader.dart` | 212 | loadFormFromRow(), hydrateRomDisplay() |
| `save_actions.dart` | 215 | saveRule(), saveMarker() + SaveResult |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Wrong relative import depth for violation_text.dart**
- **Found during:** Task 2, analyze pass
- **Issue:** `operation_editor.dart` imported `../../../../shared/widgets/violation_text.dart` (4 levels) but the file is at 5 levels up from `rule_editor/`
- **Fix:** Changed to `../../../../../shared/widgets/violation_text.dart`
- **Files modified:** `operation_editor.dart`
- **Commit:** `fca8b06`

**2. [Rule 2 - Missing import] Violation class not imported in operation_editor.dart**
- **Found during:** Task 2, analyze pass
- **Issue:** `Violation` class is defined in `word_generator.dart`, not re-exported by `violation_text.dart`. Import was missing.
- **Fix:** Added `import '../../../../phonology/domain/word_generator.dart' show Violation;`
- **Files modified:** `operation_editor.dart`
- **Commit:** `fca8b06`

**3. [Rule 2 - Missing extraction] save_actions.dart not in original plan**
- **Found during:** Task 2, line count check after initial extraction
- **Issue:** After extracting POS editors, standard form warning, and form loader, `rule_editor_body.dart` was still 605 lines (over 500 limit) due to the inlined `_save()` and `_saveMarker()` methods
- **Fix:** Extracted save logic into `save_actions.dart` as `saveRule()` / `saveMarker()` free async functions with `SaveResult` value type
- **Files modified:** `rule_editor_body.dart`, new `save_actions.dart`
- **Commit:** `fca8b06`

**4. [Rule 1 - Bug] Unused _selectedPosIds field removed**
- **Found during:** Task 2, dart analyze pass
- **Issue:** `_selectedPosIds` field was assigned in multiple places but never read (legacy field from earlier refactor iteration)
- **Fix:** Removed field declaration and all assignment sites (3 locations)
- **Files modified:** `rule_editor_body.dart`
- **Commit:** `fca8b06`

## Known Stubs

None.

## Threat Flags

None — pure refactor and safety fixes, no new network endpoints or auth paths introduced.

## Self-Check: PASSED

- `4c53f0f` exists: FOUND
- `fca8b06` exists: FOUND
- `rule_editor_dialog.dart` (89 lines): FOUND
- `rule_editor/rule_editor_body.dart` (484 lines): FOUND
- `rule_editor/save_actions.dart`: FOUND
- `flutter analyze --no-pub lib/` reports no errors: PASSED (3 pre-existing unrelated warnings)
