---
status: complete
phase: 04-grammar-morphology-revised
source: [04-VERIFICATION.md, 04-15-SUMMARY.md, 04-16-SUMMARY.md, 04-17-SUMMARY.md]
started: 2026-04-10T00:00:00Z
updated: 2026-04-12T11:15:00Z
---

## Current Test

[testing complete]

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
result: pass

### 10. Multi-POS inflectional rule create + POS-set grouping
expected: RuleEditorDialog shows a multi-POS FilterChip picker (not a single Target POS dropdown). After saving, the rule appears EXACTLY ONCE in the POS-set grouped rules list under its {Noun, Adjective} group — not duplicated under each constituent POS. v9 junction table backfill survives a migrating v8 project.
result: pass

### 11. Hard 404 on retired routes + "Back to Grammar" button
expected: Both `/grammar/paradigm` and `/grammar/inflectional` render a hard 404 (no redirect). Page shows "Page not found" + the URL + a "Back to Grammar" button routing to `/grammar/pos`.
result: skipped
reason: macOS desktop app — no URL bar to trigger route navigation

### 12. Derivation suggestion chips in word detail
expected: For a word whose POS has ≥1 derivational rule with autoApply=false, word detail shows a Suggestions section with clickable chips. Clicking a chip creates a promoted Lexeme row; the chip disappears on the next rebuild.
result: pass

### 13. Per-derivation meaning field + promote/demote + implicit-detach warning
expected: Typing into a computed derivation row's meaning field confirms a promotion. Clearing the meaning demotes. Editing rom/ipa on a promoted row triggers a warning dialog before detaching. Editing meaning/notes does NOT trigger the warning.
result: issue
reported: "when i go to edit it in its own pane, i see the original root word appear in the IPA section and nothing in the romanisation"
severity: major

### 14. Auto-apply derivational rule + reconcile
expected: When autoApply=true, every matching-POS parent gets a promoted Lexeme row automatically with gloss `"{parentMeaning} ({rule.name})"`. Parents with no meaning defer promotion. Editing the rule's source updates all dependent lexemes reactively.
result: pass

### 15. rootOnlyViaDerivations checkbox + Parents picker + muted Dictionary render
expected: Checkbox persists `rootOnlyViaDerivations`. Parents multi-select writes LexemeParents rows. Dictionary sidebar renders muted/italic. Lexeme remains findable, clickable, editable.
result: pass

### 16. ParadigmUnmarked render (bare root + ∅ badge)
expected: Cell whose feature set matches a Marker row renders as bare root in muted gray with trailing ∅ badge — distinct from uncovered em-dash and from normal derived cells. Resolution order override → rule → marker → uncovered respected.
result: skipped
reason: Marker UI not built yet — planned for 04-18

### 17. v8→v9 migration on a real v8 project
expected: No user-visible errors. InflectionalRulePOS junction backfilled from inflectional rules' input_pos_id (derivational rows skipped). Markers and LexemeParents tables exist and empty. MorphologicalRules.autoApply defaults to 0. New Lexemes columns default to NULL/false.
result: skipped
reason: no v8 project database available

### 18. v7→v8→v9 migration chain on a real v7 project
expected: `project.db.v7.bak` snapshot next to project.db. v8 migration reclassifies existing rules to kind='derivational'. v9 migration runs with empty InflectionalRulePOS. Migrated rules appear under Lexicon → Derivations; migration banner visible on first open.
result: skipped
reason: no v7 project database available

### Wave 3a-bis hot-fix validation (2026-04-11, user-reported during execution)

### 19. G-66 — ablaut class resolution fires on actual words
expected: A rule with `AblautOp(from='V', to='o', direction=fromEnd, count=1)` applied to a vowel-final word replaces only the last vowel (e.g. `sana → sano`, NOT `sana → sana`). Same fix applies to inflectional + derivational rules. Regression test in `morphology_engine_test.dart`.
result: pass

### 20. G-67 — multi-POS inflectional rule fires on every attached POS
expected: A single inflectional rule attached to both Noun and Descriptor produces inflected cells for BOTH paradigm viewers, not just the first-sorted POS. Class/level name matching translates bindings at read time (no user-visible change in the editor — just "it now works"). Regression test in `binding_translator_test.dart`.
result: pass

### 21. G-68 — promoted derivation displays the derived form everywhere
expected: A promoted derivation (via Suggestions chip or meaning entry) shows the DERIVED form in: dictionary list view, dictionary data-table view, word detail header, word detail IPA sub-label, paradigm viewer cells (inflected FROM the derived form, not the root). The phonotactic-violation highlight should apply to the derived form, not the root. The "IPA manual override" flag should NEVER fire on a promoted row.
result: pass

### Plan 04-15: Notation Unification (2026-04-11)

### 22. Bijection validator on romanization save
expected: After adding a duplicate romanization mapping (e.g. two phonemes → same rom string), clicking Save shows an inline error blocking the save. Opening a project with violations shows a non-dismissible banner at the top of the romanization section.
result: pass

### 23. Rule editor rom input + phonemic storage
expected: With romanization enabled, affix and ablaut fields in the rule editor show romanized values (e.g. `ca` instead of `kæ`). Saving converts to phonemic. Reopening shows rom again. Class refs (V, C, [name]) pass through unchanged.
result: pass

### 24. Dot-separator in rule editor
expected: For an ambiguous romanization mapping (e.g. t→t, h→h, θ→th), typing `t.h` in an affix field stores `th` (two separate phonemes), not `θ`. Helper text near the field mentions the dot separator.
result: pass

### 25. Sound rule editor asymmetric labels
expected: In the sound change rule editor, the Pattern field is labeled "Pattern (phonemic)" and the Replacement field is labeled "Replacement (phonetic)". The replacement side is never subject to rom↔phonemic conversion.
result: pass

### 26. Static preview panel removed
expected: The Inflections and Derivations pages show the rules list at full width. There is no static morphology preview side panel. The live preview inside the rule editor dialog is still present.
result: pass

### Plan 04-16: Rules UX + Dimension Editor + Phoneme Validation (2026-04-12)

### 27. Rules shown when no POS selected
expected: On the Inflections tab, when no POS is selected, the bottom rules pane shows all inflectional rules (not a "Select a POS" placeholder). The paradigm pane above still shows a placeholder since paradigms require a POS.
result: pass

### 28. Per-level rename via edit icon
expected: Each dimension level chip has a small edit icon. Tapping it opens a dialog pre-filled with name and abbreviation. Saving updates the level without changing its ID or ordering. Rules referencing this level still work.
result: issue
reported: "the edit icon is unclickable on the chips"
severity: major

### 29. Add new level via + chip
expected: A trailing + chip appears at the end of each dimension's level list (even if empty). Tapping opens a dialog for name and abbreviation. The new level appears in the chip list and is available in paradigm axes.
result: pass

### 30. Phoneme violation warnings in rule editor (G-69)
expected: When a rule contains a phoneme not in the inventory, inline warning text appears below the offending field naming the unknown phoneme. Warnings are soft — saving still works. Adding the missing phoneme to the inventory reactively clears the warning without reopening the dialog.
result: pass

### 31. Phoneme violation icon in rules list
expected: In the rules list, any rule containing unknown phonemes shows a warning icon next to the rule name. Tooltip says "Contains unknown phoneme: '{char}'". Rules with valid phonemes show no icon.
result: pass

### Plan 04-17: Intrinsic Dimensions + Standard Forms + User Feedback (2026-04-12)

### 32. Word selector dropdowns show rom (D-110)
expected: In the inflections page and paradigm viewer, word selector dropdowns show romanized form when romanization is enabled — not raw IPA.
result: pass

### 33. Rule editor preview parity (D-111)
expected: The live preview inside the rule editor dialog matches what paradigm cells show — same romanization and phonetic rendering. Preview refreshes live when rom mappings change.
result: pass

### 34. Romanization excludes rewrite artifacts (D-112)
expected: Paradigm cells and other romanized surfaces show romanization of the pre-rewrite (phonemic) form, not the post-rewrite (phonetic) form. E.g. if a rewrite rule changes s→z between vowels, the rom column still shows the original spelling (e.g. `casana` not `cazana`). The phonetic [bracket] display shows the post-rewrite form.
result: pass

### 35. Surface phonetic preview in word creation (D-113)
expected: In the word creation/edit dialog, when rewrite rules produce a different surface form, a `[phonetic]` preview line appears below the IPA field. Hidden when no rewrite rules are configured or none fire.
result: issue
reported: "phonetic preview shouldn't appear BELOW the IPA section, it should directly update the IPA section. Also the [phonetic] description under the word in the word list and word card is actually phonemic when it should be phonetic (i.e. follow the rewrite rules)."
severity: major

### 36. Mark dimension as intrinsic + backfill banner
expected: A dimension can be marked as intrinsic (per-word, not paradigm axis). After toggling, a backfill banner appears prompting to assign intrinsic values to existing words. The dimension disappears from paradigm axes.
result: pass

### 37. Stacked-slice paradigm viewer for intrinsic POS
expected: For a POS with intrinsic dimensions, the paradigm viewer shows a dropdown to select intrinsic level combinations. Each selection shows a filtered paradigm slice. All non-intrinsic dimensions remain as normal axes.
result: issue
reported: "1) Paradigm should render with 1 non-intrinsic dimension — single row, not require 2 minimum. 2) Word detail paradigm should source multiple words (one per intrinsic level) to show each inflection, not use a dropdown. 3) Grammar tab paradigm viewer should allow selecting MULTIPLE words of different intrinsic levels to display all levels side by side."
severity: major

### 38. Standard-form pattern + violation rendering
expected: For an intrinsic dimension, standard-form patterns can be created (endsWith, startsWith, contains, regex). Words that violate the pattern are visually flagged across dictionary list, data table, word detail, paradigm cells, and creation dialog.
result: issue
reported: "standard-form icon on level chips is unclickable — same hit-test issue as level edit icon (test 28)"
severity: major

### 39. Word creation intrinsic sub-form
expected: When creating/editing a word for a POS with intrinsic dimensions, a sub-form appears for selecting intrinsic level values. The selection is saved with the lexeme and used for paradigm filtering.
result: issue
reported: "1) Intrinsic level must display next to POS pill e.g. 'Noun (Masculine)' in word detail header. 2) Word-detail paradigm viewer should NOT show dropdowns — use THAT word only. 3) Word-detail paradigm should only show the slice for that word's intrinsic level, not all levels."
severity: major

## Summary

total: 39
passed: 27
issues: 6
pending: 0
skipped: 4
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

### New issues from 2026-04-12 UAT (plans 04-15..04-17)

- truth: "Editing a promoted derivation in its own pane shows the derived form's IPA and rom"
  status: failed
  reason: "User reported: when editing in own pane, sees original root word IPA and nothing in romanisation"
  severity: major
  test: 13
  artifacts: []
  missing: []

- truth: "Level chip edit icon is clickable and opens rename dialog"
  status: failed
  reason: "User reported: the edit icon is unclickable on the chips"
  severity: major
  test: 28
  artifacts: []
  missing: []

- truth: "Surface phonetic preview updates IPA section directly; [bracket] display shows post-rewrite phonetic form"
  status: failed
  reason: "User reported: preview appears below IPA instead of updating it; [phonetic] in word list/card shows phonemic not phonetic"
  severity: major
  test: 35
  artifacts: []
  missing: []

- truth: "Paradigm viewer works with 1 non-intrinsic dimension; word detail shows only that word; grammar tab allows multi-word intrinsic selection"
  status: failed
  reason: "User reported: requires 2 non-intrinsic dims minimum; word detail shows dropdowns for all words instead of just that word; no multi-word selection in grammar tab"
  severity: major
  test: 37
  artifacts: []
  missing: []

- truth: "Standard-form pattern icon on level chips is clickable"
  status: failed
  reason: "User reported: icon unclickable — same hit-test issue as level edit icon"
  severity: major
  test: 38
  artifacts: []
  missing: []

- truth: "Word detail shows intrinsic level next to POS pill; paradigm uses only that word's intrinsic level"
  status: failed
  reason: "User reported: intrinsic level not shown next to POS pill; paradigm shows all levels with dropdowns instead of filtering to that word"
  severity: major
  test: 39
  artifacts: []
  missing: []

### Deferred to future plans (out of scope for this phase)

| Issue | Target plan |
|---|---|
| Notation-layer unification (rom vs phonemic vs surface; retire `romanize()`) | 04-15 (resolved) |
| Rules list UX — show all rules when no POS selected | 04-16 (resolved) |
| Per-level rename in dimension editor | 04-16 (resolved — but hit-test bug remains) |
| Add-new-level affordance in dimension editor | 04-16 (resolved) |
| Non-existent-phoneme highlighting in rule editor (G-69) | 04-16 (resolved) |
| Intrinsic-per-POS dimensions with standard-form patterns | 04-17 (partially resolved — UI issues remain) |

## Notes

- Re-verification pass (2026-04-11, v2) expanded scope from 7 plans (04-01..04-07) to 14 plans (04-01..04-14), adding the gap-closure wave.
- All automated invariants in 04-VERIFICATION.md v2 PASS: 14/14 plans shipped, 7/7 roadmap truths verified, 497/499 tests green (2 pre-existing unrelated failures documented in deferred-items.md).
- The user chose option A+C for G-68: workaround by updating their IPA inventory and rule replacement targets in the running app; defer the architectural fix to plan 04-15.
- Items 19-21 are lightweight sanity-checks — their regression tests already lock the fix in CI, so "pending" here mostly means "confirm the running app behaves as described once the user finishes their inventory workaround".

### User feedback / enhancement requests (2026-04-12)

- **Validation rules (test 15):** Words MUST have a POS, and if that POS has an intrinsic dim it MUST be assigned to a level. Exception: rootOnlyViaDerivations words can have no POS since they represent fluid concepts (e.g. "chron(os)" in Greek).
- **Auto-derive intrinsic levels (test 14):** When auto-deriving into a POS with intrinsic dimensions, need UI to determine the intrinsic level — "preserve" option if source POS shares the same intrinsic dimension, otherwise specify.
- **Confirmation dialogs (test 29):** Add confirmation dialog when deleting a level chip or a dimension.
- **Missing-assignment warning (test 36):** Show a warning icon next to words that haven't been assigned an intrinsic level after a dimension is marked intrinsic.
- **Parent pills in word card:** Derived words should show clickable parent pills in the word detail card that navigate to the parent's card.
