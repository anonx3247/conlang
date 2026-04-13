---
phase: 10
plan: "02"
subsystem: grammar
tags: [particles, closed-class, analytic-grammar, riverpod, drift, flutter, ui]
dependency_graph:
  requires:
    - 10-01  # schema v15 (isClosedClass, glossTag columns + watchClosedClassWords)
  provides:
    - closedClassLexemeListProvider  # StreamProvider<List<Lexeme>> from particle_providers.dart
    - ParticlesPage                  # Full CRUD UI for closed-class words
    - ParticleDialog                 # Add/edit dialog with Leipzig gloss tag autocomplete
    - leipzigGlossCatalog            # 41-entry const list of LexicalGlossEntry
    - leipzigGlossAbbreviations      # Flat const List<String> for autocomplete
  affects:
    - Lexicon unified search (D-02: particles stored in Lexemes table, auto-visible)
    - Anki export (D-02: same table, same export pipeline)
tech_stack:
  added: []
  patterns:
    - ConsumerWidget / ConsumerStatefulWidget (Riverpod 3.x)
    - StreamProvider backed by Drift watchClosedClassWords()
    - Autocomplete<String> with case-insensitive substring filter
    - IpaTextField for IPA input (ipa_keyboard popup)
    - DropdownButtonFormField with initialValue: (Flutter 3.38+)
key_files:
  created:
    - lib/features/grammar/domain/leipzig_catalog.dart
    - lib/features/grammar/data/particle_providers.dart
    - lib/features/grammar/presentation/particles/particle_dialog.dart
    - test/unit/grammar/closed_class_dao_test.dart
  modified:
    - lib/features/grammar/presentation/particles/particles_page.dart
decisions:
  - IPA validation done imperatively in onPressed (not TextFormField validator) because IpaTextField wraps TextField, not TextFormField — snackbar error shown for empty IPA
  - GlossTag autocomplete uses internal Autocomplete controller synced to external _glossTagController via listener; this ensures freeform tags (not in list) are captured on save
  - POS sections ordered by posListProvider order (user-defined), falling back to alphabetical for orphan groups (particles with a POS name not in the current DB)
metrics:
  duration: "~25 minutes"
  completed: "2026-04-13"
  tasks_completed: 1
  files_changed: 5
---

# Phase 10 Plan 02: Particles Page — Full CRUD Implementation Summary

Delivers AGRAM-01: a working Particles page where users define closed-class words (particles, auxiliaries, determiners, conjunctions) with IPA forms, POS assignment, Leipzig gloss tags, and meanings. Particles are stored as `isClosedClass=true` Lexeme rows, automatically appearing in unified search and Anki export.

## What Was Built

### Leipzig Glossing Catalog (`lib/features/grammar/domain/leipzig_catalog.dart`)

41 `LexicalGlossEntry` items covering 14 semantic categories (Determination, Polarity, Aspect, Tense, Modality/TAM, Voice/Valence, Information, Pragmatics, Coordination, Adposition, Case function, Subordination, Evidentiality, Other). Each entry has `abbreviation`, `meaning`, and `category`. The flat `leipzigGlossAbbreviations` const list is used by the `Autocomplete<String>` widget.

Abbreviations included: ACC, AUX, CAUS, CERT, COMP, CONJ, COP, DAT, DEF, DET, DISJ, EMPH, EV, EXIST, FOC, FUT, GEN, INDF, INTJ, IPFV, LOC, MOD, NEG, PASS, PERF, POST, PREP, PRFV, PROG, PRS, PST, PTCL, Q, QUANT, RECIP, REFL, REL, SUB, TOP (39 in abbreviations list, 41 entries in full catalog with INDF + PRFV split from DEF/PERF).

### Particle Providers (`lib/features/grammar/data/particle_providers.dart`)

`closedClassLexemeListProvider` — `StreamProvider<List<Lexeme>>` that delegates to `LexemeDao.watchClosedClassWords()`. Returns an empty list when no project is open. Follows exact pattern from `lexeme_providers.dart`.

### Particles Page (`lib/features/grammar/presentation/particles/particles_page.dart`)

Replaces the Plan 01 placeholder with full implementation:

- `ConsumerWidget` watching `closedClassLexemeListProvider` + `posListProvider`
- `SingleChildScrollView(padding: EdgeInsets.all(24))` layout with `headlineSmall` title
- `FilledButton.icon` "Add Particle" button always visible at top
- Full empty state ("No particles yet" + body copy) when no particles exist
- POS-grouped sections via `_PosSection` widget: collapsible with expand/collapse chevron icon, header shows POS name (w600) + count, empty POS groups are hidden
- POS order follows `posListProvider` order; orphan groups fall back to alphabetical
- `_ParticleRow` uses `ListTile` with leading gloss tag `Chip` (`colorScheme.secondaryContainer`, max width 60px), IPA as title, meaning as subtitle, delete `IconButton` in error color
- Delete confirmation `AlertDialog`: "Delete particle?" / "'[ipa]' ([glossTag]) will be permanently deleted." / Cancel + Delete (FilledButton error style)
- Tap row → opens `ParticleDialog` in edit mode

### Particle Dialog (`lib/features/grammar/presentation/particles/particle_dialog.dart`)

`ConsumerStatefulWidget` — `ParticleDialog` with optional `existingParticle`:

- **IPA**: `IpaTextField` with label/hint, autofocus in add mode, validated imperatively
- **POS**: `DropdownButtonFormField<String>` populated from `posListProvider`, `initialValue:`
- **Gloss tag**: `Autocomplete<String>` with `optionsBuilder` filtering `leipzigGlossAbbreviations` by case-insensitive substring. `maxLength: 20` on underlying `TextFormField` with validator (T-10-01/T-10-02 threat mitigation). Allows freeform entry per D-04.
- **Meaning**: `TextFormField` with label
- Add mode: `insertLexeme` with `isClosedClass: const Value(true)`
- Edit mode: `updateLexeme` with `lexeme.copyWith(...)`
- Dialog title: "Add Particle" / "Edit Particle"

### Tests (`test/unit/grammar/closed_class_dao_test.dart`)

4 tests, all passing:
1. Closed-class lexeme appears in `watchClosedClassWords()` but NOT `watchRoots()`
2. Regular lexeme appears in `watchRoots()` but NOT `watchClosedClassWords()`
3. `glossTag` is persisted and retrieved correctly
4. Multiple particles ordered by `partOfSpeech` ASC then `ipa` ASC

## Deviations from Plan

### Auto-fixed Issues

None.

### Notes

The plan's `<read_first>` list included `lib/features/grammar/presentation/particles/particles_page.dart` — the file existed as a Plan 01 placeholder (5 lines) and was fully replaced as planned.

The plan mentions checking for a "shared IPA keyboard trigger pattern" — `IpaTextField` from `lib/features/phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart` is available and was used directly, matching the pattern from `rewrite_rule_editor.dart`.

## Known Stubs

None. All listed acceptance criteria fields are present and wired to live data.

## Threat Flags

No new threat surface beyond what was documented in the plan's threat model (T-10-01, T-10-02). Both mitigations applied: parameterized Drift queries (default) + `maxLength: 20` on gloss tag field.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| lib/features/grammar/domain/leipzig_catalog.dart | FOUND |
| lib/features/grammar/data/particle_providers.dart | FOUND |
| lib/features/grammar/presentation/particles/particles_page.dart | FOUND |
| lib/features/grammar/presentation/particles/particle_dialog.dart | FOUND |
| test/unit/grammar/closed_class_dao_test.dart | FOUND |
| Commit 1a3a7f2 | FOUND (verified via git log) |
| Tests (4/4) | PASSED |
