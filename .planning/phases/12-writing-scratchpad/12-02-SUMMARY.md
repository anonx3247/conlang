---
phase: 12-writing-scratchpad
plan: "02"
subsystem: scratchpad-ui
tags: [flutter, riverpod, go_router, interlinear, ui, material3]
dependency_graph:
  requires:
    - lib/features/scratchpad/data/scratchpad_providers.dart (scratchpadDaoProvider, scratchpadPhrasesProvider)
    - lib/features/scratchpad/data/gloss_index_provider.dart (glossIndexProvider)
    - lib/features/scratchpad/domain/phrase_tokenizer.dart (tokenizePhrase, PhraseToken)
    - lib/features/scratchpad/domain/gloss_match.dart (GlossMatch sealed hierarchy)
    - lib/features/lexicon/data/phonotactic_validation_provider.dart (phonotacticValidatorProvider)
    - lib/features/phonology/data/phonotactic_providers.dart (applyRewritePipelineProvider)
    - lib/db/app_database.dart (ScratchpadPhrase)
  provides:
    - ScratchpadPage (4th top-level tab, two-panel layout)
    - PhraseListPanel (sidebar phrase list with CRUD)
    - PhraseEditorPanel (text input + debounced parse/save + IPA toggle)
    - InterlinearBlock (Leipzig-format 4-tier interlinear display)
    - /scratchpad GoRouter route
  affects:
    - lib/shared/widgets/app_shell.dart (_tabs gains 4th entry)
    - lib/router/app_router.dart (4th StatefulShellBranch for /scratchpad)
tech_stack:
  added: []
  patterns:
    - ConsumerStatefulWidget with Timer-based debouncing (300ms parse, 1s save)
    - ValueKey on PhraseEditorPanel for forced rebuild when switching phrases
    - IntrinsicWidth column alignment for Leipzig interlinear token grid
    - ref.read for imperative calls, ref.watch for reactive IPA pipeline
key_files:
  created:
    - lib/features/scratchpad/presentation/scratchpad_page.dart
    - lib/features/scratchpad/presentation/phrase_list_panel.dart
    - lib/features/scratchpad/presentation/phrase_editor_panel.dart
    - lib/features/scratchpad/presentation/interlinear_block.dart
  modified:
    - lib/shared/widgets/app_shell.dart (4th tab item)
    - lib/router/app_router.dart (import + 4th StatefulShellBranch)
decisions:
  - "ValueKey(phraseId) on PhraseEditorPanel forces full widget rebuild when switching phrases, resetting all local timer/controller state cleanly"
  - "ref.read(glossIndexProvider) inside _triggerParse (not ref.watch) — parse is imperative, not reactive; avoids spurious rebuilds"
  - "IPA toggle is purely local UI state — not persisted, resets per phrase selection per CONTEXT.md"
  - "Three separate debounce timers: parse (300ms), text save (1s), translation save (1s) — all cancelled in dispose()"
metrics:
  duration: "~20 minutes"
  completed_date: "2026-04-15"
  tasks_completed: 3
  tasks_total: 3
  files_created: 4
  files_modified: 2
---

# Phase 12 Plan 02: Scratchpad UI Summary

**One-liner:** Complete Writing Scratchpad UI — 4th top-level tab with two-panel layout, Leipzig interlinear glossing, amber/red error highlighting, IPA toggle, auto-save, and phrase CRUD.

## What Was Built

### Task 1: AppShell tab, GoRouter branch, ScratchpadPage layout, PhraseListPanel

- Added `_TabItem(label: 'Scratchpad', icon: Icons.edit_note, enabled: true, phase: null)` as the 4th entry in `AppShell._tabs`.
- Added `import '../features/scratchpad/presentation/scratchpad_page.dart'` and a 4th `StatefulShellBranch` with `GoRoute(path: '/scratchpad')` to `app_router.dart`. Flat route (no nested shell) per RESEARCH.md Pattern 3.
- Created `ScratchpadPage`: `ConsumerStatefulWidget` with `_selectedPhraseId` local state. `Row` layout — 200px fixed `SizedBox` sidebar + `Expanded` editor. `ValueKey(_selectedPhraseId)` on `PhraseEditorPanel` forces full rebuild on phrase switch. Empty state shows "No phrases yet" with call-to-action copy.
- Created `PhraseListPanel`: `StatelessWidget` receiving `AsyncValue<List<ScratchpadPhrase>>`. `TextButton.icon` for "New Phrase". `ListView.builder` ordered newest-first (DAO stream). Selected phrase gets `primaryContainer` background. Em-dash for phrases with no text. Relative timestamps (just now / Xm / Xh / Xd ago).

### Task 2: PhraseEditorPanel with debounced parsing, auto-save, InterlinearBlock with all tiers

- Created `PhraseEditorPanel`: Loads phrase on init, populates text and translation controllers. Two debounce paths — 300ms parse debounce calls `tokenizePhrase` synchronously against the pre-built gloss index; 1s save debounce calls `dao.updateOriginalText`. Separate 1s debounce for translation saves. All three `Timer?` instances cancelled in `dispose()`. IPA toggle is `_showIpa` local bool. `autofocus: true` on the `TextField`. `ref.watch(applyRewritePipelineProvider)` for reactive IPA rewrite in build.
- Created `InterlinearBlock`: Leipzig 4-tier display. Tier 1 — original text with amber background tint (0.3 alpha, dark/light variant) for unknown tokens and red wavy underline (`TextDecorationStyle.wavy`, `colorScheme.error`) for phonotactic violations. Tier 2 — gloss labels in `labelSmall` w500, muted 0.4 alpha for "?" unknowns. Tier 3 (optional) — IPA in italic `labelSmall`, shown when `showIpa` is true. Tier 4 — inline `TextField` with italic bodyMedium 13px, `hintText: 'Add free translation…'` at 0.3 alpha. Horizontal `SingleChildScrollView` for long phrases. `IntrinsicWidth` per token column for alignment. Minimum 24px token cell width. Tier gap 2px per UI-SPEC exception.

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| `ValueKey(phraseId)` on PhraseEditorPanel | Guarantees clean state reset (timers, controllers, _loaded) when switching phrases — no stale data bleed |
| `ref.read` for parse trigger | Parse is imperative (called by timer callback), not reactive — `ref.read` avoids subscribing to the gloss index inside a non-build context |
| Three separate debounce timers | Text parse (300ms) must be faster than save (1s); translation save is independent of text save |
| IPA toggle as pure local state | Per-phrase session preference — no need to persist, resets naturally when switching phrases |
| Flat GoRoute for /scratchpad | Scratchpad has no sub-tabs, so StatefulShellBranch with single GoRoute suffices (RESEARCH.md Pattern 3) |

## Deviations from Plan

None — plan executed exactly as written. All code from the plan's `<action>` blocks was used as-is. Removed one unused `import '../domain/gloss_match.dart'` from `interlinear_block.dart` (the `GlossMatch` types are accessed transitively through `PhraseToken`, not directly).

## Known Stubs

None — all data flows are fully wired. The scratchpad reads from live Riverpod providers (glossIndexProvider, scratchpadPhrasesProvider) and writes to the real Drift DAO.

## Task 3: Human Verification — PASSED

Human verified the complete Writing Scratchpad feature on 2026-04-15. All 15 verification steps approved. User opened an existing project, confirmed the 4th Scratchpad tab, phrase CRUD, live interlinear glossing, unknown token amber highlighting, phonotactic violation red wavy underline, IPA toggle, free translation persistence, and auto-save all work as specified.

## Threat Flags

None — no new network endpoints, auth paths, or trust boundary crossings. All input flows through parameterized Drift queries (T-12-03 accepted). GlossIndex rebuild is O(N) for conlang-scale lexicons (T-12-04 accepted).

## Self-Check: PASSED

Files exist:
- lib/shared/widgets/app_shell.dart — FOUND (modified, 4th tab entry)
- lib/router/app_router.dart — FOUND (modified, 4th branch + import)
- lib/features/scratchpad/presentation/scratchpad_page.dart — FOUND
- lib/features/scratchpad/presentation/phrase_list_panel.dart — FOUND
- lib/features/scratchpad/presentation/phrase_editor_panel.dart — FOUND
- lib/features/scratchpad/presentation/interlinear_block.dart — FOUND

Commits exist:
- ddaf3f6: feat(12-02): AppShell 4th tab, GoRouter /scratchpad branch, ScratchpadPage layout, PhraseListPanel — FOUND
- 4435d77: feat(12-02): PhraseEditorPanel with debounced parsing/auto-save, InterlinearBlock with all 4 tiers — FOUND

flutter analyze lib/features/scratchpad/ lib/shared/widgets/app_shell.dart lib/router/app_router.dart: zero errors — PASSED
