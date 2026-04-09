---
phase: 03-lexicon
plan: "06"
subsystem: lexicon
tags: [phonotactics, violation-highlighting, exception-toggle, riverpod]
dependency_graph:
  requires: ["03-02", "03-05"]
  provides: ["lexemeViolationsProvider", "phonotactic-highlighting-in-lexicon", "exception-toggle"]
  affects: ["word_detail_panel", "word_list_panel", "lexeme_providers"]
tech_stack:
  added: []
  patterns:
    - "ViolationText widget reused from shared/widgets for lexicon IPA display"
    - "phonotacticValidatorProvider called once per detail panel render, not per-list-item"
    - "lexemeViolationsProvider batch-validates all lexemes using Riverpod caching"
key_files:
  created: []
  modified:
    - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
    - lib/features/lexicon/data/lexeme_providers.dart
    - lib/features/lexicon/presentation/dictionary/word_list_panel.dart
decisions:
  - "ViolationText takes violations: List<Violation> (not validationResult: ValidationResult) — actual Plan 05 API differs from plan spec interface; used actual widget signature"
  - "phonotactic_validation_provider.dart is in lib/features/lexicon/data/ not lib/features/phonology/data/ — corrected import path"
  - "lexemeViolationsProvider import for ValidationResult uses word_generator.dart (phonology domain) — ValidationResult defined there alongside Violation"
  - "isPhonologicalException copyWith takes bool? not Value<bool> — Drift generates plain nullable bool for non-nullable bool columns with defaults"
metrics:
  duration: "~15 min"
  completed: "2026-04-09T20:19:30Z"
  tasks_completed: 1
  files_modified: 3
requirements:
  - PHON-05
---

# Phase 3 Plan 06: Phonotactic Violation Highlighting in Lexicon Summary

Wired phonotactic violation highlighting (wavy red underlines via `ViolationText`) throughout the lexicon word detail panel and word list, with a per-word phonotactic exception toggle for loanwords and intentional rule breaks. Added `lexemeViolationsProvider` for batch validation across the full lexicon.

## What Was Built

**WordDetailPanel** (`word_detail_panel.dart`):
- IPA text (both primary heading and sub-label when romanization is shown) now uses `ViolationText` instead of plain `Text`
- When a violation is detected and the word is not already marked as an exception, a "Mark as exception" `TextButton` with `Icons.warning_amber_outlined` prefix appears below the IPA
- When `lexeme.isPhonologicalException == true`, IPA renders as plain text (no wavy underline) and shows an amber "Phonotactic exception" label + "Remove exception" button
- Exception status is toggled via `lexemeDaoProvider.updateLexeme(lexeme.copyWith(isPhonologicalException: true/false))`

**lexeme_providers.dart**:
- Added `lexemeViolationsProvider`: a `Provider<Map<int, ValidationResult>>` that batch-validates all non-exception lexemes using `allLexemeListProvider` + `phonotacticValidatorProvider`. Only recomputes on lexeme or constraint changes (Riverpod caching — T-03-12 mitigation).

**WordListPanel** (`word_list_panel.dart`):
- List view items: IPA cell replaced with `ViolationText`, violations sourced from `lexemeViolationsProvider`
- Table view IPA column: `DataCell` uses `ViolationText` instead of plain `Text`
- Exception words automatically get an empty violations list (they are excluded from `lexemeViolationsProvider`)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Wrong ViolationText constructor signature in plan spec**
- **Found during:** Task 1 — reading actual `violation_text.dart` from Plan 05 output
- **Issue:** Plan spec declared `ViolationText({ required ValidationResult validationResult })` but actual widget (Plan 05) uses `violations: List<Violation>` (extracted from `ValidationResult.violations`)
- **Fix:** Called `validate(word: lexeme.ipa)` to get `ValidationResult`, then passed `validation.violations` to `ViolationText`
- **Files modified:** `word_detail_panel.dart`, `word_list_panel.dart`
- **Commit:** efc8590

**2. [Rule 1 - Bug] Wrong import path for phonotactic_validation_provider.dart**
- **Found during:** Task 1 — `flutter analyze` reported `uri_does_not_exist`
- **Issue:** Plan spec referenced `lib/features/phonology/data/phonotactic_validation_provider.dart` but the actual file is at `lib/features/lexicon/data/phonotactic_validation_provider.dart`
- **Fix:** Corrected both imports to use the actual file location
- **Files modified:** `word_detail_panel.dart`, `lexeme_providers.dart`
- **Commit:** efc8590

**3. [Rule 1 - Bug] isPhonologicalException copyWith uses bool? not Value<bool>**
- **Found during:** Task 1 — reading generated `app_database.g.dart`
- **Issue:** Plan spec's `lexeme.copyWith(isPhonologicalException: const Value(false))` would fail; Drift generates `bool?` for this parameter
- **Fix:** Used `lexeme.copyWith(isPhonologicalException: false/true)` directly
- **Files modified:** `word_detail_panel.dart`
- **Commit:** efc8590

## Known Stubs

None. All data flows are wired to live providers.

## Threat Flags

No new security surface introduced. `lexemeViolationsProvider` operates on user's own local data. T-03-12 (DoS via full-lexicon scan) mitigated via Riverpod caching as planned.

## Self-Check

**Created files:**
- N/A (no new files)

**Modified files:**
- `/Users/neosapien/dev/conlang/lib/features/lexicon/presentation/dictionary/word_detail_panel.dart` — exists
- `/Users/neosapien/dev/conlang/lib/features/lexicon/data/lexeme_providers.dart` — exists
- `/Users/neosapien/dev/conlang/lib/features/lexicon/presentation/dictionary/word_list_panel.dart` — exists

**Commits:**
- efc8590 — feat(03-06): wire phonotactic violation highlighting into lexicon with exception toggle

## Self-Check: PASSED
