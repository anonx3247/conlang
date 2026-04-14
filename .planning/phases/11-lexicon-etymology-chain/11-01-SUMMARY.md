---
phase: 11-lexicon-etymology-chain
plan: "01"
subsystem: lexicon
tags: [data-layer, riverpod, dag-traversal, bug-fix, tdd]
dependency_graph:
  requires: []
  provides:
    - AncestryNode data model (lib/features/lexicon/domain/ancestry_node.dart)
    - ancestryChainProvider (lib/features/lexicon/data/lexeme_providers.dart)
    - allParentLinksProvider (lib/features/lexicon/data/lexeme_providers.dart)
    - buildAncestryNode() pure traversal function
    - watchAllParentLinks() DAO method
    - Fixed promotedDerivedFormProvider for multi-level chains
  affects:
    - Plan 11-02 (EtymologyChainSection widget depends on ancestryChainProvider)
    - Plan 11-03 (SearchableParentSelector also reads allParentLinksProvider)
tech_stack:
  added: []
  patterns:
    - Provider.family watching itself recursively with explicit ProviderFamily type annotation
    - Top-level package-visible pure function for direct unit testing
    - Map<int, String> ruleNameById instead of Drift row map to avoid type-hide conflict
key_files:
  created:
    - lib/features/lexicon/domain/ancestry_node.dart
    - test/unit/lexicon/ancestry_chain_test.dart
    - test/unit/lexicon/promoted_derivation_chain_test.dart
  modified:
    - lib/features/lexicon/data/lexeme_providers.dart
    - lib/features/grammar/data/lexeme_parents_dao.dart
    - lib/features/grammar/data/lexeme_parents_dao.g.dart
decisions:
  - "buildAncestryNode is a package-visible top-level function (no underscore) so unit tests can call it directly without a ProviderContainer"
  - "ruleById parameter type is Map<int, String> (name only) rather than the Drift MorphologicalRule row, to avoid the hide-MorphologicalRule import conflict in lexeme_providers.dart"
  - "ProviderFamily<PromotedDerivedForm?, int> explicit type annotation is required because Dart cannot infer the type of a variable whose initializer references itself recursively; import from package:riverpod/misc.dart"
metrics:
  duration: "~45 minutes"
  completed: "2026-04-14T20:48:50Z"
  tasks_completed: 1
  tasks_total: 1
  files_created: 3
  files_modified: 3
requirements:
  - LEX-09
---

# Phase 11 Plan 01: Ancestry Chain Data Layer Summary

Fixed the multi-level promoted derivation bug and built the complete ancestry chain data foundation: `AncestryNode` immutable model, `ancestryChainProvider` with DAG-safe cycle detection, `allParentLinksProvider`, `watchAllParentLinks()` DAO method, and `buildAncestryNode()` pure traversal function — all test-driven.

## What Was Built

### Bug Fix: Multi-Level Promoted Derivation Chain

`promotedDerivedFormProvider` was applying rule R2 to a parent's raw stored IPA when the parent was itself a promoted derivation. Promoted derivation rows store `ipa = parent.ipa` as a placeholder (per `promoteDerivation` design). So for chain A→B→C where both B and C are promoted:
- **Before:** C = R2(A.ipa) — wrong
- **After:** C = R2(R1(A.ipa)) = R2(B.computed_ipa) — correct

Fix: `promotedDerivedFormProvider` now watches `promotedDerivedFormProvider(parent.id)` unconditionally (to avoid riverpod_lint hook-ordering warnings), then uses the parent's computed IPA when the parent is itself a promoted derivation.

**Dart circularity issue:** A provider that watches itself creates a circular type inference problem for Dart. Resolved by:
1. Adding `import 'package:riverpod/misc.dart' show ProviderFamily;`
2. Annotating: `final ProviderFamily<PromotedDerivedForm?, int> promotedDerivedFormProvider = ...`

### AncestryNode Data Model

`lib/features/lexicon/domain/ancestry_node.dart` — immutable data class:
- `lexemeId`, `lexeme`, `edgeLabel`, `isRuleDerived`, `parents`
- `isCycle`: true only when this node appears in its own direct ancestor chain (NOT in a sibling DAG branch)
- `isTruncated`: true when max depth (10) was reached at this node
- `const` constructor, no `copyWith` (read-only tree)

### ancestryChainProvider

`Provider.family<AncestryNode?, int>` that:
1. Watches `allLexemeListProvider` for O(1) lexeme lookup
2. Watches `allParentLinksProvider` (new) for all manual parent links indexed by `childLexemeId`
3. Watches `morphologicalRuleListProvider` for rule name lookup
4. Calls `buildAncestryNode()` with the pre-built index maps

### allParentLinksProvider

`StreamProvider<List<LexemeParentRow>>` backed by `watchAllParentLinks()` — streams the entire `lexeme_parents` table so ancestry traversal reacts to any link change anywhere in the lexicon.

### buildAncestryNode()

Package-visible top-level pure function (no `_` prefix). Takes:
- `Map<int, Lexeme> lexemeById`
- `Map<int, List<LexemeParentRow>> parentsByChild`
- `Map<int, String> ruleNameById` (name only — avoids the Drift type-hide conflict)
- `Set<int> visited` (per-branch immutable copy for DAG safety)
- `int depth` (truncates at 10)

DAG safety: uses `{...visited, lexemeId}` spread copy before recursing into each parent branch, so sibling branches don't contaminate each other's visited sets.

### watchAllParentLinks() DAO Method

Added to `LexemeParentsDao`: `Stream<List<LexemeParentRow>> watchAllParentLinks()` — backed by `select(lexemeParents).watch()`.

## Tests

### promoted_derivation_chain_test.dart (3 tests)

- B = R1(A.ipa) regression: single-level derivation still works correctly
- **Bug fix test:** C = R2(B.computed) not R2(A.ipa) for two-level chain
- Three-level chain D = R3(R2(R1(A))) computes correct final form

### ancestry_chain_test.dart (11 tests)

**Basic traversal:**
- Root word returns single node with empty parents
- Manual parent returns node with edge label "parent"
- Custom relationship label is preserved
- Three-level chain A→B→C returns correct nested structure
- Word with BOTH rule-derived AND manual parent returns both branches

**Cycle detection:**
- X→Y→X cycle: X node in Y's parent list is marked `isCycle=true`
- Diamond DAG: A appears as ancestor of both B and C (via different paths to D) — NOT marked as cycle

**Truncation:**
- Chain of 12 words truncates at depth 10 with `isTruncated=true`

**AncestryNode model:**
- Default values for optional fields
- isCycle flag
- isTruncated flag

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Dart type circularity in promotedDerivedFormProvider**
- **Found during:** Task 1 (GREEN phase)
- **Issue:** `promotedDerivedFormProvider` watches itself recursively via `ref.watch(promotedDerivedFormProvider(parent.id))`. Dart's type inference cannot determine the variable's type due to the self-reference. Compile error: "Can't infer the type of 'promotedDerivedFormProvider': circularity found during type inference."
- **Fix:** Added `import 'package:riverpod/misc.dart' show ProviderFamily;` and explicitly typed the variable as `final ProviderFamily<PromotedDerivedForm?, int> promotedDerivedFormProvider`. The `ProviderFamily` class is in `riverpod/misc.dart` (not re-exported from `flutter_riverpod`).
- **Files modified:** `lib/features/lexicon/data/lexeme_providers.dart`
- **Commit:** 1a82557

**2. [Rule 2 - Type conflict] MorphologicalRule type hidden in lexeme_providers.dart**
- **Found during:** Task 1 (GREEN phase)
- **Issue:** `lexeme_providers.dart` uses `hide MorphologicalRule` on its `app_database.dart` import (to prefer the DSL type of the same name). Adding `Map<int, MorphologicalRule>` (Drift row type) to `buildAncestryNode`'s signature caused a "Type not found" compile error.
- **Fix:** Changed `buildAncestryNode`'s `ruleById` parameter from `Map<int, MorphologicalRuleData>` (non-existent name) / `Map<int, MorphologicalRule>` (hidden type) to `Map<int, String>` (`ruleNameById`) — only the rule name string is needed for edge labels.
- **Files modified:** `lib/features/lexicon/data/lexeme_providers.dart`, `test/unit/lexicon/ancestry_chain_test.dart`
- **Commit:** 1a82557

## Threat Mitigations Applied

| Threat ID | Mitigation |
|-----------|------------|
| T-11-01 | Max depth=10 guard in `buildAncestryNode` returns truncation sentinel. Cycle detection via per-branch `visited` Set prevents infinite loops. Both verified by unit tests. |

## Known Stubs

None — this plan is pure data layer with no UI rendering. No display forms are hardcoded.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. Only a new DAO read method (`watchAllParentLinks`) on an existing table.

## Self-Check: PASSED

- `lib/features/lexicon/domain/ancestry_node.dart` — FOUND
- `lib/features/lexicon/data/lexeme_providers.dart` — FOUND (modified)
- `lib/features/grammar/data/lexeme_parents_dao.dart` — FOUND (modified)
- `test/unit/lexicon/ancestry_chain_test.dart` — FOUND
- `test/unit/lexicon/promoted_derivation_chain_test.dart` — FOUND
- Commit `1a82557` — FOUND (`git log --oneline | grep 1a82557`)
