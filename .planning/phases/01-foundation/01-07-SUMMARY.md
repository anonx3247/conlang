---
phase: 01-foundation
plan: 07
subsystem: phonology
tags: [petitparser, drift, riverpod, word-generator, phonotactics, dsl, parser, flutter]

# Dependency graph
requires:
  - phase: 01-05
    provides: phoneme inventory tables (Phonemes, NaturalClasses), DAOs, providers
  - phase: 01-06
    provides: romanization provider (romanizeProvider) for displaying romanized word forms

provides:
  - petitparser grammar for syllable template DSL — (C)V(C), [stop][nasal]V, V[tone:H]V
  - Constraint rule parser for LHS -> RHS notation — VN -> nasalised V, [stop][stop] -> forbidden
  - WordGenerator: random IPA word generation from templates + phoneme inventory
  - ValidationResult + Violation: constraint violation detection with char positions
  - PhonotacticDao: CRUD + reactive Drift streams for templates and constraints
  - phonotactic_providers.dart: full Riverpod provider graph (dao, templates, constraints, inventory, generated words)
  - TemplateEditor UI: list with parse status, active toggle, add/edit/delete dialogs, DSL help text
  - ConstraintEditor UI: list with forbidden/constraint icons, active toggle, add/edit/delete dialogs
  - WordGeneratorPanel UI: 20-word live preview, 300ms debounce, syllable count range slider, romanized forms, violation highlighting
  - SoundRulesPage: integrated left-column editors + right-column live preview layout

affects:
  - Phase 2 morphology engine (word generator reuse, phonotactic constraint checking on generated forms)
  - Phase 3 lexicon (generated words as borrowing candidates, phonotactic validation on entries)

# Tech tracking
tech-stack:
  added:
    - petitparser 7.0.2 (already in pubspec, now actively used for grammar parsing)
  patterns:
    - Sealed-class pattern matching for petitparser Result (Success/Failure) — required in petitparser 7.x (no isFailure getter)
    - Manual Riverpod providers (not @riverpod codegen) for all Drift-type-referencing providers — avoids build_runner InvalidTypeException
    - StreamProvider async* with .when() chaining for reactive DSL parsing
    - Provider<PhonemeInventory> deriving from three StreamProviders via .when() — sync snapshot for word generator
    - WordGenerator as stateless class (Random injectable) — pure function, easily testable
    - ref.listen() for debounced side effects (timer-based regeneration) instead of watch+build

key-files:
  created:
    - lib/features/phonology/domain/phonotactic_dsl.dart
    - lib/features/phonology/domain/word_generator.dart
    - lib/features/phonology/data/phonotactic_dao.dart
    - lib/features/phonology/data/phonotactic_dao.g.dart
    - lib/features/phonology/data/phonotactic_providers.dart
    - lib/features/phonology/presentation/sound_rules/template_editor.dart
    - lib/features/phonology/presentation/sound_rules/constraint_editor.dart
    - lib/features/phonology/presentation/sound_rules/word_generator_panel.dart
    - lib/features/phonology/presentation/sound_rules/sound_rules_shared.dart
    - test/phonotactic_dsl_smoke_test.dart
  modified:
    - lib/db/app_database.dart (registered PhonotacticDao)
    - lib/db/app_database.g.dart (regenerated)
    - lib/features/phonology/presentation/sound_rules/sound_rules_page.dart (replaced placeholder)

key-decisions:
  - "petitparser 7.x uses sealed Result class (Success/Failure) — no isFailure getter; use pattern matching or is Failure"
  - "flatten() in petitparser 7.x takes optional named param {String? message}, not positional — fixed extra_positional_arguments errors"
  - "Manual Riverpod providers throughout phonotactic_providers.dart — consistent with 01-05/01-06 decision to avoid riverpod_generator InvalidTypeException on Drift types"
  - "phonemeInventoryProvider is a plain Provider<PhonemeInventory> using .when() to read consonantListProvider, vowelListProvider, naturalClassListProvider — avoids async complexity, returns empty lists while loading"
  - "DSL grammar priority: [className] before single uppercase letter before IPA literal — PEG ordering prevents ambiguous matches"
  - "Private helpers moved to sound_rules_shared.dart — Dart private classes cannot be imported across files"
  - "WordGeneratorPanel uses ref.listen() + Timer debounce rather than reacting inside build() — prevents stuttering on every keystroke"

patterns-established:
  - "Phonotactic DSL: (C)V(C) template + VN -> nasalised V constraint share the same Slot type"
  - "Parse status displayed inline as green check / red X icon with error message — consistent across template and constraint editors"
  - "Debounce pattern: ref.listen() triggers Timer(300ms, _regenerate) — applies to any computationally expensive reactive update"

# Metrics
duration: 35min
completed: 2026-04-08
---

# Phase 01 Plan 07: Phonotactic DSL and Word Generator Summary

**petitparser grammar for syllable templates and constraint rules, WordGenerator producing IPA words from inventory, integrated Sound Rules page with live 300ms-debounced preview and violation highlighting**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-04-08T10:01:37Z
- **Completed:** 2026-04-08T10:36:00Z
- **Tasks:** 2
- **Files modified:** 13

## Accomplishments

- petitparser 7.x grammar correctly parses syllable templates `(C)(C)V(C)`, natural class refs `[stop]`, tone markers `[tone:H]`, and constraint rules `VN -> nasalised V`
- WordGenerator produces random IPA words from templates + inventory with configurable syllable count range; validateWord() detects forbidden constraint violations with character positions
- PhonotacticDao provides full CRUD + reactive Drift streams for both tables; registered in AppDatabase
- Complete Riverpod provider chain: dao → active rows → parsed DSL → inventory snapshot → generated words
- Sound Rules page: left editors (template + constraint) with live parse status, right panel with 20 live words, romanized alongside IPA, red wavy underlines on violated patterns

## Task Commits

1. **Task 1: Phonotactic DSL parser and word generator engine** - `ff1e46d` (feat)
2. **Task 2: Sound rules page UI with template editor, constraint editor, and live word generator** - `25e55da` (feat)

## Files Created/Modified

- `lib/features/phonology/domain/phonotactic_dsl.dart` — petitparser grammar: Slot, ParsedTemplate, ConstraintRule, ParsedConstraint
- `lib/features/phonology/domain/word_generator.dart` — WordGenerator, PhonemeInventory, ValidationResult, Violation
- `lib/features/phonology/data/phonotactic_dao.dart` — Drift DAO for PhonotacticTemplates + PhonotacticConstraints
- `lib/features/phonology/data/phonotactic_providers.dart` — full Riverpod provider graph
- `lib/db/app_database.dart` — PhonotacticDao registered
- `lib/features/phonology/presentation/sound_rules/sound_rules_page.dart` — replaced placeholder, two-column layout
- `lib/features/phonology/presentation/sound_rules/template_editor.dart` — TemplateEditor with CRUD dialogs
- `lib/features/phonology/presentation/sound_rules/constraint_editor.dart` — ConstraintEditor with CRUD dialogs
- `lib/features/phonology/presentation/sound_rules/word_generator_panel.dart` — live preview with debounce
- `lib/features/phonology/presentation/sound_rules/sound_rules_shared.dart` — shared UI helpers
- `test/phonotactic_dsl_smoke_test.dart` — 11 smoke test assertions

## Decisions Made

- petitparser 7.x sealed Result: use `switch (result) { case Success(): ... case Failure(): ... }` — no `isFailure` getter exists in 7.x
- `flatten()` takes named param `{String? message}` in 7.x — was incorrectly using positional arg
- Private Dart classes cannot be imported across files — extracted shared helpers to `sound_rules_shared.dart`
- `phonemeInventoryProvider` is a sync `Provider` using `.when()` on three StreamProviders — cleaner than zip streams, returns empty lists while loading

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed petitparser 7.x API compatibility**
- **Found during:** Task 1 (dart analyze after creating phonotactic_dsl.dart)
- **Issue:** Used `isFailure` getter (removed in 7.x) and positional `flatten(message)` (now named param)
- **Fix:** Replaced with sealed-class pattern matching (`case Success()/Failure()`), changed `flatten(msg)` to `flatten(message: msg)` (unused), removed positional args
- **Files modified:** lib/features/phonology/domain/phonotactic_dsl.dart
- **Verification:** `dart analyze lib/features/phonology/domain/` — no issues
- **Committed in:** ff1e46d (Task 1 commit)

**2. [Rule 1 - Bug] Fixed `valueOrNull` not existing in riverpod 3.x**
- **Found during:** Task 1 (dart analyze on phonotactic_providers.dart)
- **Issue:** Used `.valueOrNull` getter which does not exist in `AsyncValue` in riverpod 3.x
- **Fix:** Replaced with `.when(data: (v) => v, loading: () => [], error: (_, e) => [])` pattern throughout
- **Files modified:** lib/features/phonology/data/phonotactic_providers.dart
- **Verification:** `dart analyze` — no errors
- **Committed in:** ff1e46d (Task 1 commit)

**3. [Rule 1 - Bug] Fixed private class export across files**
- **Found during:** Task 2 (dart analyze on constraint_editor.dart)
- **Issue:** Attempted to import private classes `_SectionHeader`, `_EmptyHint` etc. from template_editor.dart — Dart does not export private identifiers
- **Fix:** Extracted shared UI helpers to `sound_rules_shared.dart` with public names
- **Files modified:** lib/features/phonology/presentation/sound_rules/sound_rules_shared.dart (new), template_editor.dart, constraint_editor.dart
- **Verification:** `dart analyze lib/features/phonology/presentation/sound_rules/` — no errors
- **Committed in:** 25e55da (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (3 Rule 1 — language/API compatibility bugs)
**Impact on plan:** All fixes required for compilation. No scope creep. Smoke test added as Rule 2 (missing verification artifact for DSL parser).

## Issues Encountered

- petitparser 7.x has breaking API changes from 6.x: `Result` is now a sealed class, `flatten` changed to named parameter. Fixed via pattern matching.
- riverpod 3.x `AsyncValue` does not have `valueOrNull` — fixed with `.when()` pattern consistently throughout.

## Next Phase Readiness

- Phase 1 complete: all 7 plans executed. Foundation layer is fully operational.
- Database schema (all 6 tables) is stable and migration-ready
- Phoneme inventory, romanization, phonotactic templates + constraints all have reactive provider chains
- Word generator is reusable in Phase 2 (morphology) and Phase 3 (lexicon)
- Remaining concern: OGG audio playback on Windows not yet verified (Phase 1 blocker logged in STATE.md)

---
*Phase: 01-foundation*
*Completed: 2026-04-08*
