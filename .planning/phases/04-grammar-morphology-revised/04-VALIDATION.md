---
phase: 4
slug: grammar-morphology-revised
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-10
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> See `04-RESEARCH.md` § Validation Architecture for the authoritative test map.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Dart SDK) |
| **Config file** | `pubspec.yaml` (dev_dependencies: flutter_test) |
| **Quick run command** | `flutter test --no-pub` |
| **Full suite command** | `flutter test --no-pub --coverage` |
| **Estimated runtime** | ~30 seconds (quick) / ~90 seconds (full + coverage) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test --no-pub test/unit/` (unit subset)
- **After every plan wave:** Run `flutter test --no-pub`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

> Filled out during planning. Each planner task must either include an `<automated>` verify command or declare a Wave 0 dependency. See RESEARCH.md § Validation Architecture for the candidate test file layout.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD — populated by gsd-planner | | | | | | | | | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/grammar/feature_system_test.dart` — POS dimension CRUD + level validation (GRAM-01)
- [ ] `test/unit/grammar/paradigm_engine_test.dart` — rule stacking, most-specific-wins, ambiguity detection (GRAM-02, GRAM-03)
- [ ] `test/unit/grammar/paradigm_cell_override_test.dart` — per-cell exception persistence (GRAM-03)
- [ ] `test/unit/grammar/typology_test.dart` — alignment/word-order/modality persistence (GRAM-05)
- [ ] `test/unit/lexicon/derivation_repository_test.dart` — derivational rule CRUD, romanization application (GRAM-07)
- [ ] `test/integration/migration_v7_to_v8_test.dart` — existing morphology rules migrate cleanly to derivational; no data loss (GRAM-06, GRAM-07)
- [ ] `test/integration/paradigm_generation_test.dart` — end-to-end: lexeme + POS + rules → full paradigm chart (GRAM-04)
- [ ] `test/widget/grammar_shell_test.dart` — Grammar tab hosts inflectional rule editor + paradigm view (GRAM-06)
- [ ] `test/widget/lexicon_derivations_tab_test.dart` — Derivations tab renders with romanization column (GRAM-07)
- [ ] `test/fixtures/grammar/` — sample POS dimensions + rules for deterministic tests

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual paradigm chart readability (long dimension headers, cell wrapping, scroll behavior) | GRAM-04 | Visual/UX judgement — no automated oracle for "chart is readable" | Load a noun with 3 dimensions (gender × number × case: 2×2×4 = 16 cells). Verify headers don't truncate, cells expand for long forms, table scrolls horizontally without losing row labels. |
| Drag/keyboard reorder of dimension application order in inflectional rule editor | GRAM-02 | Widget interaction with visual feedback | Open inflectional rule editor for a POS with 2+ dims. Reorder dims via drag or keyboard. Verify preview updates and stored `applicationOrder` matches visible order. |
| POS dimension editor UX on resize / small windows | GRAM-01 | Responsive layout judgement | Shrink Grammar tab to minimum width. Verify dimension/level chips wrap gracefully without overlap. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (all 10 test files above)
- [ ] No watch-mode flags (no `flutter test --watch` in CI commands)
- [ ] Feedback latency < 90s (enforced: quick run is unit-only subset)
- [ ] Migration test covers data mutation AND rollback (file-level backup)
- [ ] `nyquist_compliant: true` set in frontmatter after gsd-planner fills the per-task map

**Approval:** pending
