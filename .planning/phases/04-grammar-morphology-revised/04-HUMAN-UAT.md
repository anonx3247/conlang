---
status: partial
phase: 04-grammar-morphology-revised
source: [04-VERIFICATION.md]
started: 2026-04-10T00:00:00Z
updated: 2026-04-11T00:00:00Z
---

## Current Test

[awaiting human testing of 10 re-verification items + 3 wave 3a-bis hot-fix items]

## Tests

### Original structural tests (2026-04-10) — 8 passed

1. POS and dimension creation flow — **passed**
2. Live tiebreak banner on identical inflectional bindings — **passed**
3. Paradigm viewer for 3+ dimension POS — **passed**
4. Cell override dialog — auto-derive + reactive render — **passed**
5. Typology auto-save + reload across app restart — **passed**
6. Lexicon Derivations sub-tab — **passed**
7. Word detail paradigm embed — **passed**
8. v7→v8 migration on a real legacy project.db — **passed**

### Re-verification items (2026-04-11, from v2 VERIFICATION.md — 14-plan scope)

### 9. Inflections sub-tab stacked layout + cell-to-rule edit flow
expected: Top pane (~55%) shows ParadigmTableWidget with clickMode.ruleEditor; bottom pane (~45%) shows RulesPage filtered to the selected POS. Clicking any cell opens RuleEditorDialog with feature bindings pre-filled from the cell's axis position; clicking a filled cell edits the existing rule.
result: [pending]

### 10. Multi-POS inflectional rule create + POS-set grouping
expected: RuleEditorDialog shows a multi-POS FilterChip picker (not a single Target POS dropdown). After saving, the rule appears EXACTLY ONCE in the POS-set grouped rules list under its {Noun, Adjective} group — not duplicated under each constituent POS. v9 junction table backfill survives a migrating v8 project.
result: [pending]

### 11. Hard 404 on retired routes + "Back to Grammar" button
expected: Both `/grammar/paradigm` and `/grammar/inflectional` render a hard 404 (no redirect). Page shows "Page not found" + the URL + a "Back to Grammar" button routing to `/grammar/pos`.
result: [pending]

### 12. Derivation suggestion chips in word detail
expected: For a word whose POS has ≥1 derivational rule with autoApply=false, word detail shows a Suggestions section with clickable chips. Clicking a chip creates a promoted Lexeme row; the chip disappears on the next rebuild.
result: [pending]

### 13. Per-derivation meaning field + promote/demote + implicit-detach warning
expected: Typing into a computed derivation row's meaning field confirms a promotion. Clearing the meaning demotes. Editing rom/ipa on a promoted row triggers a warning dialog before detaching. Editing meaning/notes does NOT trigger the warning.
result: [pending]

### 14. Auto-apply derivational rule + reconcile
expected: When autoApply=true, every matching-POS parent gets a promoted Lexeme row automatically with gloss `"{parentMeaning} ({rule.name})"`. Parents with no meaning defer promotion. Editing the rule's source updates all dependent lexemes reactively.
result: [pending]

### 15. rootOnlyViaDerivations checkbox + Parents picker + muted Dictionary render
expected: Checkbox persists `rootOnlyViaDerivations`. Parents multi-select writes LexemeParents rows. Dictionary sidebar renders muted/italic. Lexeme remains findable, clickable, editable.
result: [pending]

### 16. ParadigmUnmarked render (bare root + ∅ badge)
expected: Cell whose feature set matches a Marker row renders as bare root in muted gray with trailing ∅ badge — distinct from uncovered em-dash and from normal derived cells. Resolution order override → rule → marker → uncovered respected.
result: [pending]

### 17. v8→v9 migration on a real v8 project
expected: No user-visible errors. InflectionalRulePOS junction backfilled from inflectional rules' input_pos_id (derivational rows skipped). Markers and LexemeParents tables exist and empty. MorphologicalRules.autoApply defaults to 0. New Lexemes columns default to NULL/false.
result: [pending]

### 18. v7→v8→v9 migration chain on a real v7 project
expected: `project.db.v7.bak` snapshot next to project.db. v8 migration reclassifies existing rules to kind='derivational'. v9 migration runs with empty InflectionalRulePOS. Migrated rules appear under Lexicon → Derivations; migration banner visible on first open.
result: [pending]

### Wave 3a-bis hot-fix validation (2026-04-11, user-reported during execution)

### 19. G-66 — ablaut class resolution fires on actual words
expected: A rule with `AblautOp(from='V', to='o', direction=fromEnd, count=1)` applied to a vowel-final word replaces only the last vowel (e.g. `sana → sano`, NOT `sana → sana`). Same fix applies to inflectional + derivational rules. Regression test in `morphology_engine_test.dart`.
result: [pending]

### 20. G-67 — multi-POS inflectional rule fires on every attached POS
expected: A single inflectional rule attached to both Noun and Descriptor produces inflected cells for BOTH paradigm viewers, not just the first-sorted POS. Class/level name matching translates bindings at read time (no user-visible change in the editor — just "it now works"). Regression test in `binding_translator_test.dart`.
result: [pending]

### 21. G-68 — promoted derivation displays the derived form everywhere
expected: A promoted derivation (via Suggestions chip or meaning entry) shows the DERIVED form in: dictionary list view, dictionary data-table view, word detail header, word detail IPA sub-label, paradigm viewer cells (inflected FROM the derived form, not the root). The phonotactic-violation highlight should apply to the derived form, not the root. The "IPA manual override" flag should NEVER fire on a promoted row.
result: [pending]

## Summary

total: 21
passed: 8
issues: 0
pending: 13
skipped: 0
blocked: 0

## Gaps

### Original 19 gaps from 2026-04-10 UAT — ALL CLOSED by wave 1 execution (plans 04-08..04-14)

All G-01 through G-19 were planned and executed during the 2026-04-10 → 2026-04-11 gap-closure waves. Each maps to a plan and a committed SUMMARY.md. Resolved status confirmed by 04-VERIFICATION.md v2 goal-backward analysis.

| Gap | Plan | Status |
|---|---|---|
| G-01 — last-selected word persistence | 04-09 | resolved |
| G-02 — dimension templates render as "-" | 04-09 | resolved |
| G-03 — unmarked cells | 04-10 | resolved |
| G-04 — paradigm viewer rom primary | 04-09 | resolved |
| G-05 — multi-POS inflectional rules | 04-11 | resolved |
| G-06 — paradigm viewer rename | 04-13 (subsumed into Inflections tab) | resolved |
| G-07 — cell click → new rule dialog | 04-13 (ParadigmClickMode.ruleEditor + preFilledBindings) | resolved |
| G-08 — phonology rewrite on inflected forms | 04-09 | resolved |
| G-09 — group rules by POS set | 04-11 | resolved |
| G-10 — Grammar 4→3 tabs (Inflections merge) | 04-13 | resolved |
| G-11 — dimension rename | 04-09 | resolved |
| G-12 — single Custom entry in template picker | 04-09 | resolved |
| G-13 — derivation POS filter | 04-12 | resolved |
| G-14 — per-derivation meaning | 04-12 + 04-14 | resolved |
| G-15 — POS abbreviation badge | 04-14 | resolved |
| G-16 — "New word" rename + rootOnlyViaDerivations | 04-09 + 04-14 | resolved |
| G-17 — manual parent selection (etymology) | 04-12 + 04-14 | resolved |
| G-18 — autoApply flag on rules | 04-08 + 04-12 + 04-14 | resolved |
| G-19 — non-auto derivations as suggestion chips | 04-14 | resolved |

### New wave 3a-bis hot-fix gaps (2026-04-11) — all FIXED inline during re-verification

| Gap | Symptom | Fix commit | Validation test |
|---|---|---|---|
| G-66 — ablaut class resolution no-op | `applyAblaut from='V'` silently failed | `36ea4d8` | item #19 above |
| G-67 — multi-POS rule only fired on first POS | Rule attached to Noun+Descriptor only worked on one | `85de247` | item #20 above |
| G-68 — promoted row displayed root phonemes | Derived words showed root in dictionary + paradigm | `d129b78` + `408bdc4` | item #21 above |

### Deferred to future plans (out of scope for this phase)

| Issue | Target plan |
|---|---|
| Notation-layer unification (rom vs phonemic vs surface; retire `romanize()`) | 04-15 |
| Rules list UX — show all rules when no POS selected | 04-16 (a) |
| Per-level rename in dimension editor | 04-16 (b) |
| Add-new-level affordance in dimension editor | 04-16 (c) |
| Non-existent-phoneme highlighting in rule editor (G-69) | 04-16 (d) |
| Intrinsic-per-POS dimensions with standard-form patterns | 04-17 |

## Notes

- Re-verification pass (2026-04-11, v2) expanded scope from 7 plans (04-01..04-07) to 14 plans (04-01..04-14), adding the gap-closure wave.
- All automated invariants in 04-VERIFICATION.md v2 PASS: 14/14 plans shipped, 7/7 roadmap truths verified, 497/499 tests green (2 pre-existing unrelated failures documented in deferred-items.md).
- The user chose option A+C for G-68: workaround by updating their IPA inventory and rule replacement targets in the running app; defer the architectural fix to plan 04-15.
- Items 19-21 are lightweight sanity-checks — their regression tests already lock the fix in CI, so "pending" here mostly means "confirm the running app behaves as described once the user finishes their inventory workaround".
