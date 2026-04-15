---
phase: 12
slug: writing-scratchpad
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-15
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (flutter_test) |
| **Config file** | none (standard flutter test runner) |
| **Quick run command** | `flutter test test/scratchpad/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/scratchpad/`
- **After every wave merge:** Run `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

---

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WRIT-01 | Whitespace tokenization + multi-step lookup (exact → inflected → derived → unknown) | unit | `flutter test test/scratchpad/gloss_index_test.dart` | Wave 0 |
| WRIT-01 | Leipzig gloss label construction from FeatureSet | unit | `flutter test test/scratchpad/gloss_label_test.dart` | Wave 0 |
| WRIT-02 | Unknown tokens produce "?" gloss + amber highlight state | unit | `flutter test test/scratchpad/phrase_tokenizer_test.dart` | Wave 0 |
| WRIT-02 | Phonotactic violation tokens trigger red underline | widget | `flutter test test/scratchpad/scratchpad_widget_test.dart` | Wave 0 |
| WRIT-03 | IPA toggle applies rewrite pipeline per token | unit | `flutter test test/scratchpad/ipa_toggle_test.dart` | Wave 0 |
| WRIT-04 | Free translation persists via Drift DAO | unit | `flutter test test/scratchpad/scratchpad_dao_test.dart` | Wave 0 |

---

## Wave 0 Gaps

Test files that must be created before Wave 1 execution begins:

- [ ] `test/scratchpad/gloss_index_test.dart` — covers WRIT-01 lookup pipeline
- [ ] `test/scratchpad/gloss_label_test.dart` — covers WRIT-01 Leipzig labels
- [ ] `test/scratchpad/phrase_tokenizer_test.dart` — covers WRIT-01/WRIT-02 tokenizer
- [ ] `test/scratchpad/ipa_toggle_test.dart` — covers WRIT-03
- [ ] `test/scratchpad/scratchpad_dao_test.dart` — covers WRIT-04 persistence
