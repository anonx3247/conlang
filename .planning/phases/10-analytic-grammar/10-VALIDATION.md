---
phase: 10
slug: analytic-grammar
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-13
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (flutter_test + integration_test) |
| **Config file** | `pubspec.yaml` (dev_dependencies section) |
| **Quick run command** | `flutter test --tags phase10` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test --tags phase10`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | AGRAM-01 | — | N/A | unit | `flutter test test/features/grammar/data/` | ❌ W0 | ⬜ pending |
| 10-01-02 | 01 | 1 | AGRAM-01 | — | N/A | unit | `flutter test test/db/` | ❌ W0 | ⬜ pending |
| 10-02-01 | 02 | 1 | AGRAM-02 | — | N/A | unit | `flutter test test/features/grammar/data/` | ❌ W0 | ⬜ pending |
| 10-03-01 | 03 | 2 | AGRAM-03 | — | N/A | unit | `flutter test test/features/grammar/data/` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Test stubs for closed-class CRUD (AGRAM-01)
- [ ] Test stubs for construction rule CRUD (AGRAM-02)
- [ ] Test stubs for typology settings extension (AGRAM-03)

*Existing flutter_test infrastructure covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Particles sub-tab renders in Grammar sidebar | AGRAM-01 | Visual layout verification | Open Grammar tab, verify "Particles" appears at index 2 in sidebar |
| Construction slot editor drag/reorder | AGRAM-02 | Interactive widget behavior | Create a construction rule, reorder slots, verify persistence |
| Particles appear in unified lexicon search | AGRAM-01 | Cross-feature integration | Add a particle, switch to Lexicon, search for it |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
