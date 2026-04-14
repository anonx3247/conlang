---
phase: 11
slug: lexicon-etymology-chain
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-14
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (bundled with Flutter SDK) |
| **Config file** | none — standard `flutter test` discovery |
| **Quick run command** | `flutter test test/lexicon/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/lexicon/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 0 | LEX-09 | — | N/A | unit | `flutter test test/lexicon/etymology_chain_test.dart` | ❌ Wave 0 | ⬜ pending |
| 11-01-02 | 01 | 1 | LEX-09 | — | N/A | unit | `flutter test test/lexicon/etymology_chain_test.dart` | ❌ Wave 0 | ⬜ pending |
| 11-01-03 | 01 | 1 | LEX-09 | — | N/A | unit | `flutter test test/lexicon/etymology_chain_test.dart` | ❌ Wave 0 | ⬜ pending |
| 11-02-01 | 02 | 1 | LEX-09 | — | N/A | unit | `flutter test test/lexicon/lexeme_providers_test.dart` | ❌ Wave 0 | ⬜ pending |
| 11-03-01 | 03 | 2 | LEX-09 | — | N/A | manual | See manual verifications below | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lexicon/etymology_chain_test.dart` — unit tests for ancestry traversal: single parent chain, cycle detection, multi-parent DAG, 10-level truncation, node display form correctness (LEX-09)
- [ ] `test/lexicon/lexeme_providers_test.dart` — unit tests for Bug 1 fix: `promotedDerivedFormProvider` computes C correctly when B is also promoted (in-memory DB + ProviderContainer)

*Follow existing `test/lexicon/lexeme_dao_test.dart` pattern for `AppDatabase(NativeDatabase.memory())` setup.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Etymology chain renders visually as indented tree with connector lines | LEX-09 | Flutter widget rendering requires visual inspection | Open any derived word → verify indented tree with up-arrow chips, connector lines visible, current word highlighted |
| Clicking a node navigates to that word's detail panel | LEX-09 | Navigation interaction requires UI | Tap any ancestor node → verify word_detail_panel updates to show tapped word |
| Searchable dropdown filters words as user types | LEX-09 | Autocomplete UX requires interaction | In etymology section, click "Add parent" → type letters → verify filtered results appear |
| Parent pill removal works | LEX-09 | Tap interaction | Select a parent → verify pill appears → tap × → verify parent link removed |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
