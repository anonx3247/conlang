---
phase: 12-writing-scratchpad
plan: "01"
subsystem: scratchpad-data-layer
tags: [drift, riverpod, sqlite, domain-model, gloss-index]
dependency_graph:
  requires:
    - lib/db/app_database.dart (schema v16)
    - lib/features/lexicon/data/lexeme_providers.dart (allLexemeListProvider, computedDerivedFormsProvider)
    - lib/features/grammar/data/typology_providers.dart (computedInflectedParadigmProvider, ParadigmChart)
    - lib/features/grammar/data/grammar_providers.dart (dimensionsForPosProvider)
    - lib/features/morphology/data/morphology_providers.dart (posListProvider)
    - lib/features/phonology/data/romanization_providers.dart (romanizeProvider)
  provides:
    - ScratchpadPhrases table at schema v17
    - ScratchpadDao (CRUD + watchAllPhrases)
    - scratchpadDaoProvider, scratchpadPhrasesProvider
    - GlossMatch sealed class hierarchy
    - PhraseToken + tokenizePhrase function
    - glossIndexProvider (pre-computed O(1) lookup map)
  affects:
    - lib/db/app_database.dart (schema version, annotation, migration, beforeOpen)
    - lib/db/app_database.g.dart (regenerated)
tech_stack:
  added: []
  patterns:
    - Drift table + DAO + @DriftAccessor pattern (established)
    - hand-written Riverpod providers (not riverpod_generator — per project convention 01-05)
    - sealed class hierarchy for discriminated union of token resolution results
    - O(1) pre-computed gloss index with putIfAbsent priority ordering
key_files:
  created:
    - lib/features/scratchpad/data/scratchpad_dao.dart
    - lib/features/scratchpad/data/scratchpad_dao.g.dart
    - lib/features/scratchpad/data/scratchpad_providers.dart
    - lib/features/scratchpad/data/gloss_index_provider.dart
    - lib/features/scratchpad/domain/gloss_match.dart
    - lib/features/scratchpad/domain/phrase_tokenizer.dart
  modified:
    - lib/db/app_database.dart (table, annotation, schemaVersion 16->17, migration, beforeOpen, getter)
    - lib/db/app_database.g.dart (regenerated)
decisions:
  - "glossIndexProvider uses putIfAbsent so exact lexeme matches always win over inflected/derived forms at the same surface string"
  - "Index keys include both IPA and romanization for each form so users can type in either notation"
  - "hasViolation is only set for known tokens — unknown tokens get amber treatment, not red underline (per CONTEXT.md)"
  - "FeatureSet imported from paradigm_engine.dart (not re-exported from typology_providers) via show clause"
metrics:
  duration: "~5 minutes"
  completed_date: "2026-04-15"
  tasks_completed: 2
  tasks_total: 2
  files_created: 6
  files_modified: 2
---

# Phase 12 Plan 01: Scratchpad Data Layer Summary

**One-liner:** Drift schema v17 with ScratchpadPhrases table, full CRUD DAO, and a pre-computed O(1) gloss index that maps every known IPA and romanization surface form to a sealed GlossMatch result.

## What Was Built

### Task 1: ScratchpadPhrases Drift table, v17 migration, DAO, and providers

- Added `ScratchpadPhrases` table class to `app_database.dart` with 5 columns: `id`, `originalText`, `freeTranslation` (nullable), `createdAt`, `updatedAt`. No `projectId` column — each project IS a separate SQLite file.
- Registered `ScratchpadPhrases` in `@DriftDatabase` tables list and `ScratchpadDao` in daos list.
- Bumped `schemaVersion` from 16 to 17.
- Added `if (from < 17)` migration block calling `m.createTable(scratchpadPhrases)`.
- Added `beforeOpen` safety net with `CREATE TABLE IF NOT EXISTS scratchpad_phrases (...)` — matches pattern used for all previous tables.
- Added `ScratchpadDao get scratchpadDao` accessor on `AppDatabase`.
- Created `ScratchpadDao` with `@DriftAccessor(tables: [ScratchpadPhrases])`: `watchAllPhrases` (newest-first stream), `getPhraseById`, `createPhrase`, `updateOriginalText`, `updateFreeTranslation`, `deletePhrase`.
- Created `scratchpad_providers.dart` with hand-written `scratchpadDaoProvider` (Provider<ScratchpadDao?>) and `scratchpadPhrasesProvider` (StreamProvider<List<ScratchpadPhrase>>).
- Ran `build_runner build` — codegen succeeded, generating `app_database.g.dart` and `scratchpad_dao.g.dart`.

### Task 2: GlossMatch domain types, GlossIndex provider, and PhraseTokenizer

- Created `gloss_match.dart` with sealed class `GlossMatch` and four subtypes: `ExactLexemeMatch`, `InflectedFormMatch`, `DerivedFormMatch`, `UnknownToken`. Each implements `glossLabel` (Leipzig-format) and `ipa` getters.
- Created `phrase_tokenizer.dart` with `PhraseToken` (text, match, hasViolation, isUnknown) and `tokenizePhrase` function that whitespace-splits input, resolves each token via the gloss index, and checks phonotactic validity.
- Created `gloss_index_provider.dart` with `glossIndexProvider = Provider<Map<String, GlossMatch>>` that:
  - Watches `allLexemeListProvider` reactively
  - For each lexeme: indexes exact IPA + romanization forms
  - For each inflected paradigm cell (ParadigmFilled only): indexes phonetic surface, phonemic, and romanized-phonemic forms with Leipzig abbreviations from `decodeLevelsJson`
  - For each derived form: indexes derived IPA + romanization
  - Uses `putIfAbsent` throughout so exact matches win over inflected/derived at the same key

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| `putIfAbsent` for all index writes | First write wins — exact root forms take priority over inflected/derived forms sharing the same surface string |
| Dual IPA + romanization keys | Users may type in either notation; both must resolve to the same match |
| `FeatureSet` imported with `show` from `paradigm_engine.dart` | Not re-exported from `typology_providers.dart`; explicit `show` clause avoids namespace pollution |
| `hasViolation` false for UnknownToken | Unknown tokens get amber highlight; red underline reserved for known-but-violating forms |
| Hand-written providers (no @riverpod) | Established project convention 01-05: riverpod_generator cannot resolve Drift part-file types at codegen time |

## Deviations from Plan

None — plan executed exactly as written. The only deviation was adding the missing `paradigm_engine.dart` import for `FeatureSet` which the plan's code omitted but was required for compilation.

## Known Stubs

None — this plan is purely data layer infrastructure. No UI rendering, no placeholder text.

## Threat Flags

None — no new network endpoints, auth paths, or trust boundary crossings introduced. All data is local SQLite via parameterized Drift queries (T-12-01, T-12-02 from plan threat model, both accepted).

## Self-Check: PASSED

Files exist:
- lib/db/app_database.dart — FOUND (modified)
- lib/features/scratchpad/data/scratchpad_dao.dart — FOUND
- lib/features/scratchpad/data/scratchpad_dao.g.dart — FOUND
- lib/features/scratchpad/data/scratchpad_providers.dart — FOUND
- lib/features/scratchpad/data/gloss_index_provider.dart — FOUND
- lib/features/scratchpad/domain/gloss_match.dart — FOUND
- lib/features/scratchpad/domain/phrase_tokenizer.dart — FOUND

Commits exist:
- 413a21f: feat(12-01): ScratchpadPhrases table v17 migration, DAO, and providers — FOUND
- 1605bb5: feat(12-01): GlossMatch domain types, GlossIndexProvider, and PhraseTokenizer — FOUND

flutter analyze: zero errors in lib/ files — PASSED
