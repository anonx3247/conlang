---
phase: 08-gemination-restrictions
plan: 01
subsystem: phonology-engine
tags: [gemination, phonotactics, schema-migration, dsl, word-generator]
dependency_graph:
  requires: []
  provides:
    - GeminationConstraint model and !GG DSL parser
    - Schema v14 with type column on PhonotacticConstraints
    - Gemination-aware word generator and validator
  affects:
    - lib/features/phonology/domain/phonotactic_dsl.dart
    - lib/features/phonology/domain/word_generator.dart
    - lib/features/phonology/data/phonotactic_providers.dart
    - lib/features/lexicon/data/phonotactic_validation_provider.dart
    - lib/db/app_database.dart
tech_stack:
  added: []
  patterns:
    - TDD (RED→GREEN) for all gemination logic
    - Additive optional parameter pattern for backward-compatible API extension
    - D-03 mutual exclusion: GeminationPosition.everywhere dominates all others
key_files:
  created:
    - test/phonology/gemination_test.dart
  modified:
    - lib/features/phonology/domain/phonotactic_dsl.dart
    - lib/features/phonology/domain/word_generator.dart
    - lib/features/phonology/data/phonotactic_providers.dart
    - lib/features/lexicon/data/phonotactic_validation_provider.dart
    - lib/db/app_database.dart
    - lib/db/app_database.g.dart
decisions:
  - "Coda heuristic: geminate before vowel is onset (not coda) — fixed during TDD green phase"
  - "Backward-compatible: geminationConstraints defaults to [] in both generateWords and validateWord"
  - "parsedConstraintsProvider now filters to type='sequence' to avoid double-processing gemination rows"
metrics:
  duration: ~25min
  completed: 2026-04-12
  tasks_completed: 2
  tasks_total: 2
  files_modified: 7
---

# Phase 08 Plan 01: Gemination Restrictions — Domain + Schema Summary

Schema v14 with PhonotacticConstraints.type column, GeminationConstraint DSL model with !GG parser, and gemination-aware word generator + validator.

## What Was Built

### Task 1: Schema v14 + Gemination DSL Model + Parser

**Schema migration:**
- Added `TextColumn get type` to `PhonotacticConstraints` (default `'sequence'`). New gemination rows use `'gemination'`.
- Bumped `schemaVersion` to 14 with `from < 14` migration block using `m.addColumn`.
- Ran `build_runner build --delete-conflicting-outputs` to regenerate Drift code.

**Gemination domain model (in `phonotactic_dsl.dart`):**
- `enum GeminationPosition { everywhere, coda, onset, initial, final_ }` — `final_` avoids Dart keyword conflict, displays as "final".
- `class GeminationConstraint` with `Set<GeminationPosition> positions` and `String source`. `toSource()` serializes to `!GG` or `!GG/pos1,pos2`.
- `class ParsedGeminationConstraint` (success/failure mirror of existing `ParsedConstraint`).
- `parseGeminationConstraint(String input)` — parses `!GG`, `!GG/coda`, `!GG/onset,initial`, etc. Applies D-03 mutual exclusion (everywhere dominates).
- `serializeGeminationPositions` / `deserializeGeminationPositions` round-trip helpers for the DB `position` column.

### Task 2: Gemination Detection + Provider Wiring

**WordGenerator extensions (in `word_generator.dart`):**
- `geminationConstraints` optional parameter added to both `generateWords()` and `validateWord()` (default `[]` for backward compatibility).
- `_checkGemination()` private method: O(n) scan over tokenized word. Detects adjacent identical consonants. Position heuristics:
  - `initial`: pair at token index 0
  - `final_`: pair at last two tokens
  - `onset`: at word start OR immediately after a vowel
  - `coda`: at word end OR followed by a consonant (pair before a vowel is onset, not coda)
  - `everywhere`: always fires
- Violation `ruleDescription`: `'gemination violation (everywhere)'` / `'gemination violation (coda)'` etc. for descriptive UI tooltips.

**Provider wiring (in `phonotactic_providers.dart`):**
- `parsedConstraintsProvider` now filters to `type == 'sequence'` to avoid double-processing gemination rows.
- New `parsedGeminationConstraintsProvider`: watches `activeConstraintsProvider`, filters `type == 'gemination'`, parses via `parseGeminationConstraint`, returns `List<GeminationConstraint>`.
- `generatedWordsProvider` passes `geminationConstraints` to `WordGenerator.generateWords()`.

**Validation provider (in `phonotactic_validation_provider.dart`):**
- `phonotacticValidatorProvider` now also watches `parsedGeminationConstraintsProvider` and passes them to `validateWord()` so ViolationText throughout the app catches gemination violations.

## Test Coverage

26 unit tests in `test/phonology/gemination_test.dart`:
- DSL parsing (8 tests): `!GG`, `!GG/coda`, `!GG/onset,initial`, invalid input, `!GG/final`, `!GG/everywhere`, D-03 mutual exclusion
- Round-trip serialization (5 tests): `toSource()` for all position combos, `toSource → parse → toSource` stable
- Position serialization helpers (6 tests): everywhere/coda/multiple-positions round-trips, `final_` ↔ `"final"` mapping, empty string default
- WordGenerator detection (7 tests): `kk` everywhere, `kk` coda-only+word-initial (allowed), `kk` word-final, `generateWords` filtering, no false positive on `kt`, multi-char `t͡ʃt͡ʃ`, initial and onset position constraints

All 26 gemination tests pass. All 102 phonology suite tests pass (no regressions).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Coda heuristic incorrectly flagged onset geminates**

- **Found during:** Task 2 TDD green phase (test: "allows kk when only coda restricted and kk is word-initial")
- **Issue:** Initial `isCoda` implementation used `nextIsVowel` as a coda signal, but a consonant cluster before a vowel is phonologically in onset position, not coda.
- **Fix:** Revised heuristic: `isCoda = isAtWordEnd || nextIsConsonant || (!nextIsVowel && nextTokenIdx < phonemes.length)`. Onset = word-initial OR follows a vowel. Coda = word-final OR followed by consonant.
- **Files modified:** `lib/features/phonology/domain/word_generator.dart`
- **Commit:** 7246bc1

## Known Stubs

None — all data flows from DB through providers to generator/validator. The `type` column has a `'sequence'` default so existing rows are unaffected. Plan 02 (UI) will add the constraint entry form to create `type='gemination'` rows.

## Threat Flags

None — no new network endpoints or auth paths introduced. The `type` column is local SQLite only; column values are validated at parse time (T-08-01 accepted per plan threat model).

## Self-Check: PASSED

- `lib/db/app_database.dart` exists and contains `schemaVersion => 14` and `from < 14`
- `lib/features/phonology/domain/phonotactic_dsl.dart` exists and contains `class GeminationConstraint`, `parseGeminationConstraint`, `GeminationPosition`
- `lib/features/phonology/domain/word_generator.dart` exists and contains `geminationConstraints`, `_checkGemination`, `gemination violation`
- `lib/features/phonology/data/phonotactic_providers.dart` exists and contains `parsedGeminationConstraintsProvider`
- `lib/features/lexicon/data/phonotactic_validation_provider.dart` exists and contains `gemination`
- `test/phonology/gemination_test.dart` exists with 26 passing tests
- Commits: `0030e66` (Task 1), `7246bc1` (Task 2)
