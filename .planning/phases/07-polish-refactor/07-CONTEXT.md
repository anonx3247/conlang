# Phase 7: Polish & Refactor - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix all outstanding UI nits, clean up dead code from culture wiki removal, refactor oversized files, and address safety concerns from the codebase audit. No new features — strictly polish, reorganization, and code quality improvements.

</domain>

<decisions>
## Implementation Decisions

### Phonology Tab Restructure (NIT-01, NIT-02, NIT-03)
- D-01: Phonology sub-tabs reordered to 3 tabs: Inventory → Natural Classes → Sound Rules. Natural classes become their own dedicated sub-tab (extracted from inventory page).
- D-02: Romanization section moved from its own sub-tab to a collapsible section below the consonant/vowel grids on the Inventory page.
- D-03: Phoneme inventory charts show romanization as the primary display, with `/phoneme/` in muted text to the right — only shown when they differ (e.g. skip for t→/t/, show for sh→/ʃ/).
- D-04: The alt-key hover behavior for showing phonemes is removed entirely — replaced by the inline display from D-03.

### Abbreviation Formatting (NIT-04)
- D-05: Abbreviations normalized to lowercase at save time (DB stores lowercase). Existing data migrated on next save/edit.
- D-06: Trailing period added to all abbreviation displays everywhere: POS pills, dimension chips, paradigm headers, rule binding summaries, lexicon badges. Both single-letter (v.) and multi-letter (adj., nom., sg.) get periods.
- D-07: Case-insensitive comparison when matching abbreviations — "V" and "v" treated as the same abbreviation.

### Draggable Panel Separators (NIT-05)
- D-08: All panel dividers throughout the app become draggable to resize panels. Applies to: Phonology sidebar/content, Grammar sidebar/content, Lexicon sidebar/content, Glossary drawer, and any other Row-based panel layouts.
- D-09: Use a thin draggable handle (4px wide, cursor changes to resize) with min/max constraints to prevent panels from collapsing to zero.

### Dead Code Cleanup (REFAC-01 part 1)
- D-10: Remove all orphaned culture wiki imports, unused culture providers/types in generated code, stale comments referencing culture tab.
- D-11: Verify no flutter_fancy_tree_view2 or flutter_markdown_plus remnants in pubspec.yaml, pubspec.lock, or source files (already removed — verify clean).
- D-12: Run dart fix --apply and flutter analyze to catch any remaining dead imports or unused variables.

### rule_editor_dialog.dart Refactor (REFAC-01 part 2)
- D-13: Extract _OpState, _CondState, _BranchState into separate files in a `rule_editor/` subdirectory.
- D-14: Break the monolithic widget into child widgets per section: condition editor, operation editor, preview panel, branch editor. Each file < 500 lines.
- D-15: Move DSL parsing helpers from the widget file to the domain layer (morphology_dsl.dart or a new file).
- D-16: Preserve all existing behavior — this is a pure refactor with no functional changes.

### getSingle() Safety Fix (from CONCERNS.md)
- D-17: Replace getSingle() with getSingleOrNull() + explicit null handling in critical paths: grammar_dao.dart, lexeme_dao.dart, morphology_dao.dart.
- D-18: Add meaningful error messages/logging when queries return unexpected null instead of crashing with StateError.

### Claude's Discretion
- Specific ResizablePanel widget implementation details
- Natural classes page layout (reuse existing natural class UI or redesign)
- Collapsible romanization section animation style
- File organization within rule_editor/ subdirectory

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/phonology/presentation/phonology_shell.dart` — current 2-tab shell to modify to 3 tabs
- `lib/features/phonology/presentation/inventory/inventory_page.dart` — contains natural classes inline, needs extraction
- `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` — 2486-line file to refactor
- `lib/shared/widgets/app_shell.dart` — already has glossary drawer pattern (Row with conditional SizedBox)

### Established Patterns
- StatefulShellRoute.indexedStack for sub-tab routing (PhonologyShell, GrammarShell, LexiconShell)
- ConsumerStatefulWidget for stateful UI with Riverpod
- GestureDetector for drag interactions (used in page_tree_sidebar.dart DnD)

### Integration Points
- PhonologyShell sub-tab routing in app_router.dart
- Abbreviation display in paradigm_table_widget.dart, dimension_editor_panel.dart, rules_page.dart, word_detail sections
- Panel layouts in all shell widgets (phonology_shell, grammar_shell, lexicon_shell)

</code_context>

<specifics>
## Specific Ideas

- Alt-key phoneme display (existing hover behavior) should be completely removed, not just hidden
- Draggable separators should feel native — thin handle, no visible bar until hover (just a cursor change)
- rule_editor_dialog refactor must not change any user-visible behavior — pure internal restructure

</specifics>

<deferred>
## Deferred Ideas

- Derivation examples/suggestions (genitive, superlative, etc.) — separate enhancement, not polish
- Gemination restriction notation — v2 feature
- Unsafe collection access patterns (.first, .last without isEmpty check) — v2 hardening
- Romanization bijection enforcement — v2 validation feature

</deferred>
