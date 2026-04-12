---
phase: 5
slug: culture-wiki
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | pubspec.yaml (dev_dependencies) |
| **Quick run command** | `flutter test test/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | CULT-01 | — | N/A | unit | `flutter test test/` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 2 | CULT-02 | — | N/A | widget | `flutter test test/` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Test stubs for CULT-01, CULT-02
- [ ] Existing infrastructure covers framework installation

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Markdown rendering preview | CULT-01 | Visual rendering quality | Create page with headers, lists, code blocks — verify rendered output |
| Wiki link navigation | CULT-02 | User interaction flow | Create [[link]], click it, verify navigation |
| Broken link visual distinction | CULT-02 | Visual styling | Create [[nonexistent]] link, verify red/distinct styling |
| Drag-and-drop reorder | CULT-01 | Gesture interaction | Drag page in tree, verify new position persists |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
