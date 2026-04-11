# Phase 04: Grammar & Morphology Revised — Gaps Context

**Gathered:** 2026-04-11
**Status:** Ready for gap planning
**Supplements:** `04-CONTEXT.md` (original phase scope, decisions D-01 through D-42)
**Source:** `04-HUMAN-UAT.md` — 19 gaps recorded during UAT (all 8 structural tests passed)

<domain>
## Phase Boundary (gap scope)

Refinements to what was shipped in Phase 04. All 19 gaps are current-phase work per the standing memory `UAT feedback is current-phase work`. No new phase is being opened — these decisions extend the Phase 04 implementation and will be planned via `/gsd-plan-phase 04 --gaps`.

The gaps cluster into:
1. **Semantic/schema additions** — unmarked cells (G-03), multi-POS rules (G-05), derivation overhaul (G-13–G-19)
2. **UX restructure** — merged Inflections sub-tab (G-06, G-07, G-10)
3. **Pure bugs** — G-02, G-04, G-08, G-11, G-12, G-13 (no design decisions needed)
4. **Trivial additions** — G-01, G-09, G-15 (clear, mechanical)

A v9 schema migration is implied by the decisions below. All migrations must follow the Phase 1 pattern (onUpgrade guard + beforeOpen ALTER TABLE safety net) established in plan 01-13.
</domain>

<decisions>
## Implementation Decisions

### Unmarked Cells (G-03)

- **D-43: Unmarked declarations cascade by binding-set, not per-cell.** A user declares "this feature-binding set produces no form change" at whatever specificity they want — e.g. `{gender=M, number=SG}` → unmarked covers the whole masculine-singular slice of a paradigm. Per-cell-only declarations are rejected as too tedious for typologically common zero-marker patterns (masculine-nominative-singular zero-morpheme, etc.). The engine evaluates unmarked declarations with the same specificity + feature-consumption algorithm as D-10.

- **D-44: New `Markers` table stores unmarked declarations.** Schema: `Markers(id INTEGER PK, pos_id INTEGER FK → PartsOfSpeech, feature_bindings TEXT JSON)`. Parallel to `MorphologicalRules` in shape but with no form output, no DSL, and no `kind` column (all markers are inflectional-scoped). Migration: new table in v9 `onUpgrade`, empty on upgrade. D-19's `feature_bindings` JSON format is reused for consistency with inflectional rules.

- **D-45: Cell resolution order — override → rule → marker → uncovered.** For each paradigm cell, the engine resolves in this order:
  1. Per-word override from `MorphologicalRuleExceptions` (D-22) or the forthcoming word-detail override mechanism (D-54)
  2. Inflectional rule with the most specific matching binding-set (D-10 / D-12 specificity)
  3. Marker with the most specific matching binding-set (same algorithm)
  4. Uncovered (em-dash with warning icon, D-14)

- **D-46: Marker vs rule specificity contest uses the D-10 algorithm.** A `{SG,NOM}` marker beats a `{SG}` rule. On exact ties (same binding-set size, same keys), **rules win over markers** because rules carry an explicit form while markers assert absence — tiebreaker documented in the engine. This sits above D-12's ambiguous-tie error logic: marker-vs-rule ties are auto-resolved (rules win), rule-vs-rule ties are still red warnings.

- **D-47: Unmarked cells render as the bare root in muted gray.** Cell shows the root form (after any upstream derivational stages) in subdued text with a trailing `∅` or `(unmarked)` badge. Distinct from uncovered em-dash cells (D-14) and distinct from normal derived cells (D-29). Communicates "the root IS the form here" — standard zero-morpheme linguistic convention. Respects the romanization toggle (D-29) and the phonotactic violation highlighter (D-30).

### Inflections Tab Restructure (G-06, G-07, G-10)

- **D-48: Grammar tab collapses from 4 sub-tabs to 3.** New sidebar: **POS & Dimensions** / **Inflections** / **Typology**. The old standalone Paradigm Viewer sub-tab (D-31, D-34) and the old Inflectional Rules sub-tab (D-33) are merged into the new Inflections sub-tab. The global morphology preview is deleted (it was redundant — popup previews elsewhere suffice).

- **D-49: Inflections sub-tab uses a stacked paradigm-top / rules-bottom layout.** Top half: POS dropdown + word picker + paradigm table (current `paradigm_viewer_page.dart` layout). Bottom half: rules list filtered to the selected POS. Editing a rule in the bottom updates the paradigm above live (stream-driven via Riverpod). No draggable divider in v1; reasonable fixed ratio (~55/45) with internal scroll in each pane.

- **D-50: The rules pane is scoped to the current POS plus any multi-POS rules that include it.** When "Noun" is selected, the pane shows: rules attached only to Noun, plus rules attached to `{Noun, Adjective}`, `{Noun, Verb}`, etc. Grouped per D-53.

- **D-51: Clicking any paradigm cell opens the `RuleEditorDialog` pre-filled with feature bindings from the cell's axis position.** Both empty (uncovered) cells and cells with existing rules open the same dialog — for cells with a rule, the dialog opens that rule for edit; for uncovered cells, the dialog opens blank with bindings pre-filled for rule creation. The existing `CellOverrideDialog` (D-28) is **deleted from the Grammar/Inflections context**. Per-word rom/IPA exceptions move to the Lexicon word detail context (D-54).

- **D-52: `ParadigmTableWidget` has two click modes depending on host context.**
  - In the Grammar > Inflections sub-tab: click → `RuleEditorDialog` (D-51).
  - In the Lexicon word detail panel (the embedded paradigm from D-27b): click → per-word override dialog (the old D-28 behavior, keyed to `MorphologicalRuleExceptions` for the current word).
  The widget takes a `clickMode: ParadigmClickMode { ruleEditor, wordOverride }` constructor parameter. Same widget, two hosts, two behaviors.

- **D-53: Old routes `/grammar/paradigm` and `/grammar/inflectional` return 404.** No redirect, no migration banner. `app_router.dart` drops both branches; the Grammar branch now has only three sub-routes: `/grammar/pos`, `/grammar/inflections`, `/grammar/typology`. Bookmarks or cached sessions that hit the old routes see a hard 404 screen. User preference: clean break over smooth migration for internal routing.

- **D-54: Per-word rom/IPA overrides live in the Lexicon word detail ParadigmTableWidget only.** No separate "Exceptions" list section — discoverability comes from clicking cells in the embedded paradigm, same as the old D-28 behavior but scoped to one word and hosted inside Lexicon. Backed by the existing `MorphologicalRuleExceptions` table (D-22) — no schema change for this decision. The `(from paradigm viewer)` code path from D-28 is deleted.

### Multi-POS Inflectional Rules (G-05, G-09)

- **D-55: New `InflectionalRulePOS` junction table.** Schema: `InflectionalRulePOS(rule_id INTEGER FK → MorphologicalRules, pos_id INTEGER FK → PartsOfSpeech, PRIMARY KEY (rule_id, pos_id))`. v9 migration: create table, backfill one row per existing inflectional rule using its current `input_pos_id`. After backfill, `MorphologicalRules.input_pos_id` becomes unused for `kind='inflectional'` rows — planner decides whether to null it or keep it as a convenience cache.

- **D-56: Rules list (bottom pane of Inflections, D-49) groups by POS set.** Grouping rules:
  - Single-POS rules group under `Noun`, `Verb`, etc. (alphabetic).
  - Multi-POS rules each form their own group named after the set: `Noun + Adjective`, `Noun + Verb + Adjective`, etc. (alphabetized within group, groups ordered after single-POS groups).
  - A multi-POS rule appears **once**, in its own POS-set group — not duplicated under every constituent POS.
  - An empty POS set (edge case) sinks to a "Unattached" group.

### Derivation Overhaul (G-13–G-19)

- **D-57: Derived forms stay computed by default; promotion to a full Lexeme row happens when the user assigns a meaning.** Current behavior (computed string in the derivation tree widget) is preserved as the default. When a user types a meaning into the empty meaning field of a computed derivation and confirms, a new Lexeme row is created with:
  - `derived_from_lexeme_id` = parent lexeme
  - `derived_via_rule_id` = the derivational rule
  - `gloss` = the user's input
  - `rom` / `ipa` = NULL (computed at render time from rule + parent)
  Clearing the meaning on a promoted row deletes the Lexeme row and reverts to computed-only.

- **D-58: Promoted derived Lexemes keep their form *computed* by default; manual editing of `rom` or `ipa` detaches the row from the rule.** This is the critical constraint: editing the `-in` rule to `-il` must automatically update all promoted derived Lexemes that use it (e.g., 100 `kamain` → `kamail` with no manual edits). Implementation:
  - While `rom` and `ipa` are NULL on a promoted derived Lexeme, the display form is computed via `rule.applyTo(parent)` at render time (cached in-memory per session; invalidated on rule or parent change via existing Riverpod streams).
  - When the user edits `rom` or `ipa` in the word detail, that write populates the column AND nulls `derived_via_rule_id` (the row becomes standalone). This is the "detach" gesture — implicit, triggered by the edit.
  - UI must communicate the detachment clearly: a "linked to rule X" badge on promoted-and-computed rows; editing the rom/ipa field shows an inline warning "Editing this form will unlink it from rule X" with confirm. Planner to refine the exact copy.
  - Meaning/notes edits do NOT detach — only `rom`/`ipa` edits do.

- **D-59: Derivational rules gain an `auto_apply` column (boolean, default false).** Migration: add column to `MorphologicalRules`, default false for all existing rows (zero disruption to existing projects). Semantics:
  - **`auto_apply=false` (dormant):** The rule does NOT automatically compute derived forms for every matching word. It appears as a clickable **suggestion chip** in each matching word's derivation tree panel (G-19). Clicking creates that one word's derived form (initially computed, promotable per D-57).
  - **`auto_apply=true` (auto-promote):** The rule automatically promotes every matching word's derived form to a full Lexeme row with a **template-generated meaning**: `"{parentLexeme.meaning} ({rule.name})"`. Example: `kama` "to run" + rule "Actor" with suffix `-in` → creates `kamain` with `gloss = "to run (Actor)"`. The templated meaning is editable afterwards (meaning edits don't detach form per D-58). If the parent lexeme has no meaning yet, the promotion waits until it does (no "undefined (Actor)" rows).

- **D-60: Suggestion chips for `auto_apply=false` rules live in the word detail derivation tree panel.** Each word detail shows:
  1. Its parents (etymology, per D-62) — if any
  2. Its direct computed derivations — the existing derivation tree widget
  3. A new "Suggestions" section: clickable chips for every `auto_apply=false` rule whose input POS matches this word. Clicking a chip creates the derived form (same flow as a manual derivation action). Applied suggestions disappear from the chip list for that word (tracked via the derived Lexeme row or a `suggestion_dismissed_rule_ids` column on Lexemes — planner decides).

- **D-61: `computedDerivedFormsProvider` filters strictly by `rule.input_pos_id == word.pos_id`.** Fixes G-13. No "any POS" sentinel — if a user genuinely needs a universal rule, they can attach it to every POS via the multi-POS mechanism (D-55, but multi-input for derivational rules is deferred as TBD — see below). Strict match matches linguistic intuition: nominalizers target verbs, diminutives target nouns, etc.

- **D-62: New `LexemeParents` junction table for manual parent/etymology links.** Schema: `LexemeParents(child_lexeme_id FK, parent_lexeme_id FK, relationship TEXT nullable, notes TEXT nullable, PRIMARY KEY (child_lexeme_id, parent_lexeme_id))`. Supports:
  - Multiple parents per child (compounds: `sun + flower → sunflower`)
  - Optional relationship label (e.g., `"from"`, `"via"`, `"cognate with"`, free-text)
  - Optional notes per link
  - Rule-linked derivations (D-57's `derived_from_lexeme_id` + `derived_via_rule_id`) are distinct from this table — `LexemeParents` is for the *manual/rule-less* case. A single Lexeme can have both: an auto-derived parent-via-rule AND additional manual parents in `LexemeParents` (for mixed etymologies).
  - Tree queries walk the union of rule-derived links and manual-parent links.

- **D-63: G-16 root-only-via-derivations toggle is a UI filter, not deletion.** New `Lexemes.root_only_via_derivations BOOLEAN` column (default false). Behavior: roots with this flag set are **grayed out** in the main Dictionary sidebar list (not hidden) — rendered in muted text with an icon. Still fully findable via search, still present in Swadesh / Thesaurus if linked, still openable for editing, still appear in derivation trees as the root. Only the default Dictionary browse view demotes them visually.

- **D-64: G-15 POS abbreviation badge next to derived forms in the word detail derivation tree.** Each derived form row shows the rule's **output POS abbreviation** as a compact badge (e.g., `[N]`, `[V]`, `[Adj]`). For rule-linked derivations, output POS comes from the rule (D-38). For manual parent-linked derivations (D-62), the child's own POS is used. Trivial UI addition, no schema change.

- **D-65: G-16 lexicon toolbar rename: `+New root` → `+New word`.** Plus the new `root_only_via_derivations` toggle is a checkbox inside the new-word dialog (not a separate button). Minor UI-only change.

### Claude's Discretion

- Exact visual treatment of the "linked to rule" badge on promoted derived Lexemes (D-58) — badge design, tooltip copy, confirm-dialog copy for the detach warning
- Whether `Markers` gets its own editor pane inside the Inflections sub-tab or is edited inline from the paradigm viewer (cell click on an unmarked cell — what happens?). Suggestion: cell click on a cell that currently resolves to a marker opens a "Marker" tab in `RuleEditorDialog` showing the marker's binding set, with options to edit or delete it. Planner to refine.
- Whether the `suggestion_dismissed_rule_ids` tracker for D-60 is needed at all, or applied suggestions are identified by "a Lexeme with `derived_via_rule_id == rule.id` exists for this parent" (simpler, no new column)
- UI treatment of the root-only-via-derivations toggle (D-63) in the word detail — checkbox location, label copy
- Empty-state copy changes for the new `auto_apply` toggle on the derivational rule editor
- Exact shape of the POS-set group header in D-56 (e.g., `Noun + Adjective` vs `N+Adj` vs separator glyphs) — use whatever fits the existing rules-list design
- Whether `MorphologicalRules.input_pos_id` is nulled post-backfill (D-55) or kept as a legacy convenience — planner call

### Pure Bugs (No Discussion, Flag for Planner)

These gaps are clear root-cause fixes with no design decision. The planner should bucket them as direct bug-fix tasks:

- **G-02: Dimension templates render as `-` literally.** Rendering bug in `dimension_template_picker.dart` — template payload not unpacked. Fix the renderer or the data pipeline depending on root cause.
- **G-04: Paradigm viewer shows IPA, should show romanization primary.** Fix in `paradigm_table_widget.dart` cell renderer — D-29 is the contract (romanization on top line, IPA on second). Currently swapped or rom is missing. Respect the project-wide romanization toggle (D-29).
- **G-08: Phonetic rewrite rules not applied to inflected forms.** Pipeline ordering bug — the phonology rewrite pass is not running after inflectional rule application. Separate from G-13 (which is a filter bug, also listed in decisions above as D-61). Planner to trace the pipeline stages in the paradigm cell generator and insert/re-run the rewrite stage.
- **G-11: Dimensions can't be renamed.** `DimensionEditorPanel` is missing the rename affordance. `GrammarDao` already supports the update operation — just add the edit UI.
- **G-12: Multiple "Custom" buttons in template picker.** Should render exactly one "Custom" entry (or one per group if that's the design — the template picker code needs audit to confirm intent). Planner to verify against D-05 and either fix to one or document the one-per-group intent.
- **G-13: `computedDerivedFormsProvider` POS filter.** Captured as **D-61** in decisions above. Listed here for cross-reference.

### Trivial Features (No Discussion, Flag for Planner)

- **G-01: Persist per-POS "last selected word" in the paradigm viewer.** Add `paradigm_last_selected_word.{posId}` keys under `project_settings` (existing store from D-26). Read on mount, write on selection change. No new schema.
- **G-09: Group inflectional rules by POS in the list.** Captured as **D-56** above.
- **G-15: POS abbreviation badge.** Captured as **D-64** above.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior phase context (required reading)
- `.planning/phases/04-grammar-morphology-revised/04-CONTEXT.md` — Full Phase 04 context (D-01 through D-42). Gap decisions D-43+ supplement but do not override these unless explicitly stated. Notably relevant: D-10 (feature consumption algorithm), D-12 (ambiguous-tie error), D-14 (uncovered cell em-dash rendering), D-22 (`MorphologicalRuleExceptions` preserved), D-27 (paradigm viewer dual-hosting in Grammar + Lexicon), D-28 (old per-cell override UX — being replaced by D-54), D-29 (romanization + IPA stacked), D-30 (phonotactic violation highlighting), D-31 (4-sub-tab Grammar layout — being replaced by D-48), D-33 (Inflectional Rules sub-tab — being merged), D-38 (input/output POS on derivational rules), D-40 (`RuleEditorDialog` shared editor — extended by D-51).
- `.planning/phases/04-grammar-morphology-revised/04-HUMAN-UAT.md` — Source of all 19 gaps with user-written reproduction notes and rationale. Planner should cross-check every gap is addressed.
- `.planning/phases/04-grammar-morphology-revised/04-VERIFICATION.md` — Phase 04 verification report; confirms structural completeness of what's being refined.
- `.planning/phases/04-grammar-morphology-revised/04-REVIEW.md` — Phase 04 code review notes; flag any gap-adjacent issues the reviewer raised.
- `.planning/phases/04-grammar-morphology-revised/04-RESEARCH.md` §A9 — Legacy `posIds` CSV column research, relevant to D-55's junction-table choice.
- `.planning/phases/03-lexicon/03-CONTEXT.md` — Lexicon master-detail layout, derivation tree widget, word detail panel structure. Relevant to D-52, D-54, D-60, D-63.

### Project-level references
- `.planning/PROJECT.md` — Project vision and non-negotiables. Check the non-negotiables section for any constraints that affect gap scope.
- `.planning/REQUIREMENTS.md` §GRAM — Grammar module requirements. Original Phase 04 acceptance criteria.
- `.planning/ROADMAP.md` — Phase 04 canonical refs section for any additional linked ADRs/specs.
- `/Users/neosapien/.claude/projects/-Users-neosapien-dev-conlang/memory/feedback_uat_items_are_requirements.md` — Standing memory: UAT feedback is current-phase work. This is why the gaps are being planned under Phase 04 instead of spun into a new phase.

### Source files touched by these decisions
These are the integration points the planner will need to understand. Paths are advisory — the planner should verify against current state.

**Schema / DB**
- `lib/db/app_database.dart` §MorphologicalRules — gains `auto_apply` column (D-59); `input_pos_id` deprecated for `kind='inflectional'` rows after D-55 backfill
- `lib/db/app_database.dart` §Lexemes — gains `derived_from_lexeme_id`, `derived_via_rule_id`, `root_only_via_derivations` columns (D-57, D-58, D-63)
- `lib/db/app_database.dart` — new tables: `Markers` (D-44), `InflectionalRulePOS` (D-55), `LexemeParents` (D-62). New v9 `onUpgrade` block with `if (from < 9)` guard, safety-net `beforeOpen` ALTER TABLE (pattern from plan 01-13).

**Router / shells**
- `lib/router/app_router.dart` — Grammar branch collapses to 3 sub-routes (D-48, D-53); old `/grammar/paradigm` and `/grammar/inflectional` removed (hard 404)
- `lib/features/grammar/presentation/grammar_shell.dart` — sidebar collapses from 4 to 3 entries (D-48)

**Inflections sub-tab (new)**
- `lib/features/grammar/presentation/inflections_page.dart` — NEW. Hosts the stacked paradigm-top / rules-bottom layout (D-49)
- `lib/features/morphology/presentation/paradigm_viewer_page.dart` — gutted or deleted; core paradigm table rendering moves into `ParadigmTableWidget` which is embedded by the new Inflections page
- `lib/features/morphology/presentation/rules/rules_page.dart` — kept for Lexicon > Derivations host; the Inflections bottom pane uses the same widget scoped to current POS (D-50)
- `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` — extended to support opening from a paradigm cell click with feature-binding pre-fill (D-51). Cell-click handler replaces the deleted `CellOverrideDialog` path.

**Paradigm widget (dual-hosted)**
- `lib/features/morphology/presentation/paradigm/paradigm_table_widget.dart` — gains `clickMode: ParadigmClickMode` constructor parameter (D-52). Implementation branches on the enum: `ruleEditor` → `RuleEditorDialog`, `wordOverride` → per-word override dialog (former `CellOverrideDialog` behavior, keyed to current word via `MorphologicalRuleExceptions`).

**Derivation engine**
- `lib/features/morphology/application/computed_derived_forms_provider.dart` — add strict POS filter (D-61); add the promoted-lexeme form computation path (D-58); handle auto-apply rule auto-promotion (D-59)
- `lib/features/morphology/data/morphology_dao.dart` — new queries for `Markers`, `InflectionalRulePOS`, `LexemeParents`, and promoted-derived-Lexeme form computation
- `lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart` — renders rule-linked derivations + manual parent links (D-62), applies POS abbreviation badges (D-64), shows suggestion chips for `auto_apply=false` rules (D-60)
- `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart` — hosts the new Suggestions section (D-60), the parents/etymology display (D-62), and the `root_only_via_derivations` toggle UI (D-63, D-65)

**Lexicon toolbar / dictionary**
- `lib/features/lexicon/presentation/dictionary/lexicon_toolbar.dart` — `+New root` → `+New word` (D-65)
- `lib/features/lexicon/presentation/dictionary/new_word_dialog.dart` — add the root-only-via-derivations checkbox (D-65)
- `lib/features/lexicon/presentation/dictionary/dictionary_page.dart` — render root-only-via-derivations lexemes in muted gray (D-63)

**Dimension template bugs**
- `lib/features/grammar/presentation/dimension_template_picker.dart` — G-02 renderer bug, G-12 duplicate Custom button
- `lib/features/grammar/presentation/dimension_editor_panel.dart` — G-11 rename affordance missing

**Pipeline bug**
- Wherever the phonology rewrite pipeline runs — G-08 requires rewrite stage to run AFTER inflectional rule application, not just after derivational/root stage. Planner traces the call sites.

**Persistence**
- `lib/db/project_settings.dart` (or equivalent) — G-01 per-POS last-selected-word key (`paradigm_last_selected_word.{posId}`)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`RuleEditorDialog`** (`lib/features/morphology/presentation/rules/rule_editor_dialog.dart`) — already a shared editor with a `kind` parameter (D-40). The D-51 extension layers a new "open with bindings pre-filled from paradigm cell" entry point, not a new dialog.
- **`ParadigmTableWidget`** — already embedded in both Grammar paradigm viewer and Lexicon word detail (D-27, D-27b). D-52's dual click-mode is a natural extension; the widget already knows how to render cells, just needs a click-handler switch.
- **`MorphologicalRuleExceptions`** (D-22, preserved) — already the storage for per-word exceptions. D-54 reuses this for the relocated word-detail override flow; no schema change for D-54 itself.
- **D-10 specificity algorithm** — reusable for resolving marker-vs-rule contests (D-46), preserving consistency with how inflectional rules already resolve.
- **`computedDerivedFormsProvider` Riverpod stream** — already watches the rules table and reactively recomputes derived forms. D-58's rule-edit-propagates-to-100-lexemes constraint is satisfied automatically by this stream.
- **`romanizeProvider`** (`lib/features/phonology/data/romanization_providers.dart:90–105`) — global romanization helper. Promoted derived Lexemes computing rom at render time route through this provider.

### Established Patterns
- **v8 migration pattern** (plan 01-13, echoed in Phase 4) — `onUpgrade` guard + `beforeOpen` safety-net ALTER TABLE. v9 migration follows this pattern identically.
- **JSON feature_bindings** (D-19) — already the format for storing dimension-level bindings on rules. Markers (D-44) reuse this format directly, making the marker-vs-rule resolution logic share a code path.
- **Template catalog as Dart const data** (D-03) — no DB seeding. If D-44 Markers ever need template presets, follow the same pattern.
- **Project settings as flat key-value** (D-26 — `typology.*`, `paradigm_axes.{posId}`) — extend with `paradigm_last_selected_word.{posId}` for G-01.
- **Lexicon master-detail** (Phase 3 pattern) — how the root-only-via-derivations toggle and the new-word dialog should feel.

### Integration Points
- Grammar sidebar (4→3 sub-tabs) in `grammar_shell.dart`
- `app_router.dart` branch structure for Grammar (three routes)
- `ParadigmTableWidget` constructor signature (gains `clickMode` enum)
- Derivation tree widget's rendering loop in `word_detail_panel.dart`

</code_context>

<specifics>
## Specific Ideas

- **Auto-apply template meaning format (D-59):** Exactly `"{parentLexeme.meaning} ({rule.name})"`. Example verbatim: `kama` "to run" + rule named "Actor" (with suffix `-in`) → lexeme `kamain` with gloss `"to run (Actor)"`. This is the user's explicit example; planner should match it exactly and surface the template in the rule editor so users see what meaning will be generated.
- **100-lexeme rule-edit constraint (D-58):** The user's motivating scenario is "I have 100 `-in` agents and want to change to `-il` without editing 100 rows." This is the primary correctness check for the promoted-derivation model. Any implementation that requires manual re-save on the 100 lexemes fails the requirement.
- **Hard 404 preference (D-53):** User explicitly rejected redirect + banner options for the retired Grammar sub-routes. Clean break preferred over smooth migration for internal routing.
- **"Computed by default, stored if edited" (D-58):** User preferred the most implicit detachment model over an explicit "Detach" button. The UI has to compensate for the magic with clear warnings on the rom/ipa edit action.

</specifics>

<deferred>
## Deferred Ideas

- **Derivational rules with multiple input POS.** D-55 adds multi-POS for *inflectional* rules. Derivational rules remain single-input-POS per D-38. If a user genuinely needs a universal derivational rule (rare — diminutive on any nominal?), they'd create two rules today. This is not in the gap scope; note for a future phase if it surfaces again.
- **Etymology tree visualization UI.** D-62 adds the `LexemeParents` storage layer and the word detail link display, but a full etymology tree view (with visual tree rendering, hover navigation, ancestor/descendant browse) is deferred. The junction table is designed to support it without schema changes when that feature is planned.
- **Relationship-label vocabulary for `LexemeParents.relationship`.** Currently free-text. A future phase could add a controlled vocabulary (`from`, `via`, `cognate with`, `borrowed from`, etc.) with dropdown selection, but v1 is free-text to avoid premature standardization.
- **Cross-project derivational rule sharing / template catalog.** If users repeatedly build the same `-in` agent rule across projects, a future phase could ship a derivational rule template catalog similar to D-03's dimension catalog. Not in gap scope.
- **Thesaurus / Swadesh treatment of promoted derived Lexemes.** The schema changes make this possible (derived Lexemes are full rows, so they can be added to Swadesh lists etc.), but the UX of "how should Swadesh lists handle derivations" is deferred — current behavior is unchanged.
- **Reviewed Todos (not folded):** None — no pending todos cross-referenced for this gap discussion.

</deferred>

---

*Phase: 04-grammar-morphology-revised*
*Gap context gathered: 2026-04-11*
*Supplements: 04-CONTEXT.md*
*Source of truth for gap scope: 04-HUMAN-UAT.md (19 gaps, status: failed)*
*Next step: `/gsd-plan-phase 04 --gaps` — planner reads this file plus the original 04-CONTEXT.md to generate gap plans.*
