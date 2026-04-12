---
phase: 6
slug: reference-glossary
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | pubspec.yaml (dev_dependencies) |
| **Quick run command** | `flutter test test/unit/glossary/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/glossary/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | REF-01 | — | N/A | unit | `flutter test test/unit/glossary/glossary_entry_test.dart` | ❌ W0 | ⬜ pending |
| 06-01-02 | 01 | 1 | REF-01 | — | N/A | unit | `flutter test test/unit/glossary/glossary_providers_test.dart` | ❌ W0 | ⬜ pending |
| 06-02-01 | 02 | 2 | REF-01 | — | N/A | widget | `flutter analyze lib/features/glossary/` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Test stubs for REF-01 (glossary entry parsing, provider filtering)
- [ ] Existing infrastructure covers framework installation

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Glossary drawer opens from ? icon | REF-01 | Visual interaction | Click ? in app bar, verify 320px drawer appears |
| Search filters terms in real time | REF-01 | Visual rendering | Type in search box, verify results update live |
| Contextual ? pre-filters by domain | REF-01 | Cross-tab interaction | Click ? on Phonology tab, verify filter is set |
| Accordion tiles expand on tap | REF-01 | Animation/gesture | Tap a term, verify definition expands |
| See Also chips navigate to term | REF-01 | Navigation behavior | Tap a See Also chip, verify target term scrolls into view |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
