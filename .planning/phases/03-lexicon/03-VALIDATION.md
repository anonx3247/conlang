---
phase: 3
slug: lexicon
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Flutter SDK) |
| **Config file** | `pubspec.yaml` (dev_dependencies) |
| **Quick run command** | `flutter test --plain-name` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test --plain-name`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | LEX-01 | — | N/A | unit | `flutter test` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | LEX-02 | — | N/A | unit | `flutter test` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 2 | LEX-03 | — | N/A | widget | `flutter test` | ❌ W0 | ⬜ pending |
| 03-03-01 | 03 | 2 | LEX-04, LEX-05 | — | N/A | unit | `flutter test` | ❌ W0 | ⬜ pending |
| 03-04-01 | 04 | 3 | LEX-06 | — | N/A | unit | `flutter test` | ❌ W0 | ⬜ pending |
| 03-05-01 | 05 | 1 | PHON-05 | — | N/A | unit | `flutter test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lexicon/lexeme_dao_test.dart` — stubs for LEX-01, LEX-02
- [ ] `test/lexicon/lexicon_screen_test.dart` — widget stubs for LEX-03
- [ ] `test/lexicon/semantic_refs_test.dart` — stubs for LEX-04, LEX-05
- [ ] `test/lexicon/anki_export_test.dart` — stubs for LEX-06
- [ ] `test/phonology/phonotactic_validation_test.dart` — stubs for PHON-05

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Swadesh list coverage UI indicators | LEX-04 | Visual correctness | Open Swadesh view, verify coverage % matches actual lexicon entries |
| Anki .apkg import | LEX-06 | Requires Anki desktop | Import exported .apkg into Anki, verify cards render correctly |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
