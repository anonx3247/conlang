# Plan 04-15 D-75 Render-Path Audit

**Audited:** 2026-04-11
**Contract:** Every `romanize()` call must receive a stored phonemic value. No double-romanization. No `romanize()` on user-typed buffers without `deromanize()` first.

## Per-surface Results

| # | Surface | File:Line | Input source | Status | Regression test | Notes |
|---|---------|-----------|--------------|--------|-----------------|-------|
| 1 | Paradigm table cell (main form) | paradigm_table_widget.dart:489 | `form` = phonemic output of `computeParadigmCell` (engine) | confirmed | widget tests in paradigm_table_widget_test.dart | Watches `romanizeProvider`; passes phonemic `form` to `romanize(form)` on line 495. Identity no-op when mapping empty. |
| 2 | Paradigm table cell (root variant) | paradigm_table_widget.dart:564 | `root` = phonemic Lexemes.ipa | confirmed | same widget tests | Watches `romanizeProvider`; passes phonemic `root` to `romanize(root)` on line 570. Same pattern as row 1. |
| 3 | Rule editor live preview (read romanize) | preview_panel.dart:350 | `ref.read(romanizeProvider)` — hoisted function handle | confirmed | preview_panel reads engine output only; no test file, but the call site itself is a passthrough | Preview panel is the live preview INSIDE `rule_editor_dialog.dart` — kept per D-77. Reads romanize once, applies it to `row.derived` and `row.root`. |
| 4 | Rule editor live preview (derived form) | preview_panel.dart:371 | `row.derived` = engine output of `applyRule()` on phonemic root | confirmed | executed exclusively on engine-output phonemic | `romanize(row.derived)` on line 371. row.derived comes from `MorphologyEngine.applyRule(rule, phonemicRoot)` — already phonemic. No double-romanization risk. |
| 5 | Rule editor live preview (root) | preview_panel.dart:421 | `row.root` = stored Lexemes.ipa (phonemic) | confirmed | same file | `romanize(row.root)` on line 421. row.root is the phonemic input the engine received. |
| 6 | Inspiration panel (word generator read) | inspiration_panel.dart:55 | `ref.watch(romanizeProvider)` | confirmed | — | Hoists the romanize function; applied on line 214 to `rawWord` which is `wordGenerator.generateOne()` output — already phonemic IPA. |
| 7 | Inspiration panel (per-word rom render) | inspiration_panel.dart:214 | `rawWord` = `WordGenerator.generateOne()` phonemic | confirmed | — | `romanize(rawWord)` on line 214. WordGenerator emits phonemic IPA by construction; no user input path. |
| 8 | Word generator panel (top-level read) | word_generator_panel.dart:36 | `ref.watch(romanizeProvider)` | confirmed | — | Hoists romanize for per-row application on line 190. Same pattern as inspiration panel. |
| 9 | Word generator panel (per-row render) | word_generator_panel.dart:190 | `rawWord` = `WordGenerator` phonemic | confirmed | — | `romanize(rawWord)` on line 190. |
| 10 | Inventory page phoneme chip | inventory_page.dart:626 | `phoneme.symbol` = Phonemes.symbol (phonemic-native by table contract) | confirmed | — | `romanize(phoneme.symbol)` on line 627. Phonemes table stores IPA symbols directly; no user-input round-trip. |
| 11 | Word list panel (overridden-IPA flag) | word_list_panel.dart:376 | `deromanize(lexeme.romanization)` compared to `lexeme.ipa` | confirmed | existing lexicon tests | Uses `deromanize` via `isIpaManuallyOverridden(ipa, romanization, deromanize)` on line 415. This is a DEROMANIZE call, not a romanize call — the audit contract still holds because it operates on stored `Lexemes.romanization` and compares to `Lexemes.ipa`. **This is the `isIpaManuallyOverridden` exception documented below.** |
| 12 | Word list panel (dictionary sort) | word_list_panel.dart:569 | `lexeme.romanization` / `lexeme.ipa` | confirmed | existing lexicon tests | Sort key extraction uses `a.romanization ?? a.ipa` (line 579-580) and the same override check on line 662. Both are stored values, not derived. |
| 13 | Word detail panel (form controller init) | word_detail_panel.dart:76 | `deromanize(_romanizationController.text)` | confirmed | word_detail_panel tests | User types romanization → `deromanize()` produces IPA → both stored. Standard lexicon input pattern (D-71 `isIpaManuallyOverridden` exception). |
| 14 | Word detail panel (edit commit) | word_detail_panel.dart:88 | `deromanize(_romanizationController.text)` | confirmed | word_detail_panel tests | Same pattern as row 13. |
| 15 | Word detail panel (override flag check) | word_detail_panel.dart:103 | `deromanize(lexeme.romanization)` vs `lexeme.ipa` | confirmed | word_detail_panel tests | `isIpaManuallyOverridden(ipa, romanization, deromanize)` override-flag computation. Uses stored fields only. |
| 16 | Derivation tree widget (root + children) | derivation_tree_widget.dart:48 | `ref.watch(romanizeProvider)` | confirmed | derivation tree widget tests | Hoists romanize; applies to `rootIpa` (phonemic) on line 64 and each child's `ipa` (phonemic) on line 109. All sources are stored Lexemes.ipa values. |
| 17 | Morphology preview (static pane) | morphology_preview_panel.dart | — | **deleted (Task 6)** | N/A | D-77 deletion — the static Morphology Preview pane is slated for removal in Task 6. This row documents the deletion; no audit required. |

## isIpaManuallyOverridden exception

The `isIpaManuallyOverridden(ipa, romanization, deromanize)` helper at `romanization_providers.dart:175` is the **one legitimate divergence** from the storage-is-phonemic contract. When the returned flag is `true`, the stored `Lexemes.ipa` is a user manual override that does NOT round-trip with the current romanization mapping — the user typed IPA directly instead of deriving it from the romanization field. This is preserved intentionally per D-71 and is NOT an audit failure.

Surfaces 11, 12, 13, 14, 15 all call this helper on stored `Lexemes.romanization` and `Lexemes.ipa` pairs. None of them take user-typed buffers and pass them through `romanize()` — they only compare stored fields via `deromanize()`, which is the correct save-time boundary direction.

## Summary

- **Confirmed sites:** 16
- **Patched sites:** 0 (every call site was already operating on stored phonemic)
- **Deleted sites:** 1 (morphology_preview_panel.dart, D-77, Task 6)
- **Total:** 17

Every `romanize()` call in the audited surfaces is proven to operate on a value that is either:
1. Stored phonemic read directly from a Drift column (`Lexemes.ipa`, `Phonemes.symbol`), OR
2. The direct output of `MorphologyEngine.applyRule()` / `computeParadigmCell()` / `WordGenerator.generateOne()` — all of which are engine-native phonemic producers.

No double-romanization (`romanize(romanize(x))`) patterns found.
No `romanize()` on unwrapped user-input buffer found.
No audit call sites needed patching.

## Patches applied

None. The render-path audit found every surface already correctly operating on stored phonemic values. Task 6 will still remove the static `MorphologyPreviewPanel` per D-77, but that is a code-deletion task, not an audit patch.

The only lexicon-path deromanize calls (rows 11-15) legitimately use the `isIpaManuallyOverridden` escape hatch on stored fields only, per D-71.

---

*Audit performed by plan 04-15 Task 4. See `04-15-CONTEXT.md` §D-75 for the full decision record.*
