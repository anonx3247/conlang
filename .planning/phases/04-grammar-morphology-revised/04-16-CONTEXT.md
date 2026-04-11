# Plan 04-16: Rules List UX + Dimension Editor Extensions + Phoneme Validation — Context

**Gathered:** 2026-04-11
**Status:** Ready for research + planning
**Parent phase:** 04-grammar-morphology-revised
**Wave:** 7 (with 04-15, 04-17, 04-18)
**Scope tag:** [GAP, Wave 7]

<domain>
## Phase Boundary

Plan 04-16 bundles four small UX / correctness fixes against rules and dimensions that emerged from the 04-10 → 04-14 UAT pass:

- **(a)** When no POS is selected in the Inflections sub-tab, show ALL inflectional rules instead of an empty-state placeholder.
- **(b)** Per-DimensionLevel rename affordance inside `dimension_editor_panel.dart`, extending the G-11 dimension rename shipped in 04-09.
- **(c)** "Add new level" affordance for an existing dimension.
- **(d)** G-69: non-existent-phoneme highlighting in the rule editor and rules list — catch notation mismatches like `+ci` referencing a `c` that's not in the inventory.

**In scope:** `inflections_page.dart` empty-state branch, `dimension_editor_panel.dart` level chip affordances, a new literal-phoneme scanner against `PhonemeInventory`, reuse of `ViolationText` for G-69 highlighting, rule editor + rules list wiring for G-69 indicators.

**Out of scope (belongs elsewhere):**
- Anything touching rule DSL storage format or `deromanize()` contract → 04-15
- Intrinsic dimensions, standard-form patterns, paradigm viewer stacking → 04-17
- Markers / "Leave as unmarked" UI → 04-18
- Dimension template picker work beyond rename / add-level → backlog
</domain>

<decisions>
## Implementation Decisions

### D-78 — 04-16 (a): Empty-POS rules pane renders full rule list

- In `inflections_page.dart:155-167`, when `_selectedPosId == null`, replace the empty-state with `RulesPage(kind: RuleKind.inflectional)` and no `posScopeFilter`. The rules list renders full-width.
- Paradigm table + word-picker header panes keep their current empty-states ("Select a POS to view its paradigm." / hidden). They genuinely require a POS.
- Inflections sub-tab stays **kind-locked to inflectional** — no derivational toggle, no tab-level kind switcher. Derivational rules stay in Lexicon → Derivations (per 04-07 / 04-13 restructure).
- `RulesPage`'s internal POS dropdown (`_selectedPosId` at `rules_page.dart:186-229`) is already the "show all when null" path — nothing new to implement there, only the empty-state branch in `InflectionsPage` flips from placeholder to passthrough.

### D-79 — 04-16 (b): Per-level rename

- In `dimension_editor_panel.dart:189-200`, each level `InputChip` gains an edit affordance. Interaction: small edit icon inside the chip label area (hover-reveal on desktop, always-visible on mobile/touch).
- Tapping the edit icon opens a dialog structurally identical to `_RenameDimensionDialog` (`dimension_editor_panel.dart:211`), adapted to edit a `DimensionLevel` instead of a `Dimension`.
- Dialog edits **both `name` and `abbr`** in one form with validation: both fields required, non-empty, abbr auto-uppercase on save.
- Save path: decode `levelsJson`, find the level by id, replace its name+abbr, re-encode, call `GrammarDao.updateDimensionLevels(dim.id, updated)`.
- Level id is preserved — rename does not reassign ids. This is critical because existing rules and lexemes reference level ids in their featureBindings and `skippedDimensionsJson`.

### D-80 — 04-16 (c): Add new level

- A trailing "+" chip at the end of the level `Wrap` in `dimension_editor_panel.dart`. Rendered as an `InputChip` with a `+` icon, no label, distinct hover tooltip "Add level".
- Tap opens the same level editor dialog from D-79 with empty `name` / `abbr` fields.
- On save, append a new `DimensionLevel` to the decoded levels list with:
  - `id` = `max(existing ids) + 1` (or `0` if empty).
  - `name` = user input.
  - `abbr` = user input.
- Call `GrammarDao.updateDimensionLevels(dim.id, updated)`.
- No re-ordering UI in 04-16 — new levels append at the end. Re-ordering can be a future ask if users complain.

### D-81 — 04-16 (d): G-69 non-existent phoneme highlighting

- **Dependency:** Must execute strictly after 04-15 within Wave 7. Before 04-15, `MorphologicalRules.source` literal strings could be rom-intended-but-IPA-interpreted, making "is this a known phoneme?" an unanswerable question. After 04-15, sources are guaranteed phonemic and class refs are explicit, so inventory membership is a clean check.
- **Scanner:** A new `PhonemeLiteralScanner` service in `lib/features/morphology/domain/` that takes:
  - A parsed rule (`ParsedMorphRule` from `morphology_dsl.dart:139`)
  - A `PhonemeInventory` snapshot (`lib/features/phonology/domain/word_generator.dart:16`)
  - Returns a list of `PhonemeViolation(opIndex, literalOffset, length, char)` tuples.
- **Scan scope:** All literal-string fields in every MorphOperation kind — `SuffixOp.affix`, `PrefixOp.affix`, `InfixOp.affix`, `AblautOp.from`, `AblautOp.to`, `RemoveSuffixOp.suffix`, `TemplateOp` literals, `RedupOp` literals, `SuppleteOp` surface forms, and `PatternCond` literal phoneme references (NOT class refs `V`/`C`/`F`/`[name]`).
- **Class-ref handling:** The parser already distinguishes class refs from literal phonemes. Scanner skips any token that is a class ref. Only plain phonemic characters get checked.
- **Longest-match phoneme recognition:** Scanner uses the inventory's consonants + vowels, sorted longest-first (digraphs like `tʃ`, `aː` beat `t` + `ʃ`). Characters that match no phoneme of any length are flagged.
- **Visual treatment in rule editor:** Reuse `ViolationText` widget (`lib/shared/widgets/violation_text.dart`) in the rule editor's branch display — offending character renders with red wavy underline. Tooltip: "'{char}' is not in the phoneme inventory (did you mean to define it first?)".
- **Visual treatment in rules list:** A subtle warning icon (`Icons.warning_amber_outlined`) next to the rule row in `rules_page.dart` when any op in that rule has a phoneme violation. Tooltip: "Contains unknown phoneme: '{char}'".
- **Save-time behavior:** **Soft warning only.** The rule editor displays the red-wavy highlight inline but does NOT block save. The user may intentionally be prototyping a rule for a phoneme they're about to add. Users can ignore warnings without being nagged.
- **Reactivity:** Scanner results derived from `phonemeInventoryProvider` — when the user adds the missing phoneme to the inventory, warnings clear automatically.

### Claude's Discretion

- Exact icon choice (`edit` vs `edit_outlined`) and placement pixels in level chips.
- Tooltip copy in the G-69 warning (as long as the affected char is named).
- Whether the `+` chip uses an outlined style vs filled, and whether it's keyboard-focusable via Tab.
- How the rules list warning icon interacts with the existing POS-set grouping badge from D-56.
</decisions>

<specifics>
## Specific Ideas

- The user explicitly flagged (a)(b)(c)(d) as "clear enough" in the discussion (2026-04-11) — no deep spec needed, reasonable defaults locked directly.
- G-69 was deferred from the G-68 ablaut fix pass specifically so the notation-unification (04-15) could land first.
- The merge of 04-16 + 04-17 (and the new 04-18) into a single wave was a user-driven scope decision: "merge into a single 'wave' since all of this is part of phase 4".
</specifics>

<canonical_refs>
## Canonical References

### Prior phase context (required reading)

- `.planning/phases/04-grammar-morphology-revised/04-CONTEXT.md` — Phase 04 master decisions (D-01..D-42)
- `.planning/phases/04-grammar-morphology-revised/04-CONTEXT-GAPS.md` — Wave 1-5 gap decisions (D-43..D-65)
- `.planning/phases/04-grammar-morphology-revised/04-15-CONTEXT.md` — Wave 6 notation unification (D-70..D-77) — required for D-81 (G-69 depends on phonemic DSL storage)
- `.planning/phases/04-grammar-morphology-revised/04-HUMAN-UAT.md` — UAT items and "Deferred to future plans" table at row 135

### Source files touched by 04-16

#### Sub-item (a) — Rules list empty-POS
- `lib/features/grammar/presentation/inflections/inflections_page.dart:155-167` — empty-state branch replacement
- `lib/features/morphology/presentation/rules/rules_page.dart:186-229` — existing "no POS" internal branch (unchanged, reused)

#### Sub-items (b)(c) — Dimension editor
- `lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart:140-208` — level chip rendering + new affordances
- `lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart:211-275` — `_RenameDimensionDialog` pattern to generalize for levels
- `lib/features/grammar/domain/dimension_level.dart` — `DimensionLevel` data class + `encodeLevelsJson` / `decodeLevelsJson`
- `lib/features/grammar/data/grammar_dao.dart` — `updateDimensionLevels` (already exists, reused)

#### Sub-item (d) — G-69 scanner + UI
- `lib/features/morphology/domain/morphology_dsl.dart` — parsed rule structure (`ParsedMorphRule`, `MorphOperation` hierarchy at lines 11-67)
- `lib/features/phonology/domain/word_generator.dart:16` — `PhonemeInventory` class
- `lib/features/phonology/data/phonotactic_providers.dart:162` — `phonemeInventoryProvider`
- `lib/shared/widgets/violation_text.dart` — `ViolationText` widget (reused unchanged)
- `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` — inline violation rendering in branch display
- `lib/features/morphology/presentation/rules/rules_page.dart` — rule row warning icon

### New files in 04-16
- `lib/features/morphology/domain/phoneme_literal_scanner.dart` — scanner service + `PhonemeViolation` struct
- Tests: `test/unit/morphology/phoneme_literal_scanner_test.dart`

### Roadmap

- `.planning/ROADMAP.md:159` — 04-16 plan line; the four sub-items and their descriptions
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`_RenameDimensionDialog`** (`dimension_editor_panel.dart:211`) — stateful dialog with controller lifecycle bound to dialog state. Generalize into a base dialog that accepts name+abbr fields and returns a validated `(name, abbr)` pair.
- **`GrammarDao.updateDimensionLevels`** — already takes a full levels list, handles JSON encode, does a single update. Supports D-79 and D-80 without new DAO methods.
- **`PhonemeInventory`** — pre-built snapshot of consonants + vowels + natural classes. Longest-match search against its members is the standard pattern (`word_generator.dart:172` uses it for parsing generated words).
- **`ViolationText`** — already used in `paradigm_table_widget.dart`, `word_list_panel.dart`, `word_detail_panel.dart`, `word_generator_panel.dart` — consistent red-wavy highlight for phonotactic violations. G-69 piggybacks on the same widget.
- **`ParadigmClickMode`** — not used by 04-16 but established the pattern of "enum parameter on widget controls behavior" which D-81's rules list warning icon follows.

### Established Patterns

- Level chip `onDeleted` with optimistic DAO write — D-79's edit icon follows the same pattern (fire-and-forget async DAO call, UI reacts via stream).
- Hover-reveal on desktop vs always-visible on mobile — existing pattern in `paradigm_table_widget.dart` hover state handling; reuse the same approach for level-chip edit icons.
- `phonotactic_validation_provider` derives violations from inventory + form — G-69's scanner follows the same dependency shape (inventory + rule source → violations).

### Integration Points

- `InflectionsPage` → `RulesPage` via `posScopeFilter` (plan 04-13). D-78 simply passes `null` for that parameter in the no-POS branch.
- `RuleEditorDialog` → `PreviewPanel` live preview already renders per-branch ops; D-81 adds violation highlighting to the same branch display.
- `rules_page.dart` rule row rendering (`_buildInflectionalGroupedList` at line 451) already has a trailing actions area — add warning icon there.
</code_context>

<deferred>
## Deferred Ideas

- **Dimension level re-ordering / drag-to-reorder.** D-80 appends new levels at the end. If users need to reorder, add a backlog item for drag handles.
- **Phoneme violation auto-fix suggestion.** When G-69 flags a character, could offer "Did you mean …" using a Levenshtein distance against the inventory. Not in 04-16.
- **Save-time block option for G-69.** The user chose soft-warning-only; revisit if violation noise becomes a complaint.
- **Dimension template picker rename / edit.** Template catalog is hard-coded in `ipa_data.dart` — not user-editable. Out of scope.
</deferred>

---

*Plan: 04-16-rules-ux-dimension-extensions-phoneme-validation (parent phase: 04-grammar-morphology-revised)*
*Context gathered: 2026-04-11*
