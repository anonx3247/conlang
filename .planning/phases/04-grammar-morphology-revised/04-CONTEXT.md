# Phase 4: Grammar & Morphology (revised) - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can define custom parts of speech with N grammatical dimensions × K levels, attach inflectional morphology rules that bind to feature values and stack via a feature-consumption model, generate paradigm tables per word with per-cell manual overrides, and record language-level typology choices (alignment, word order, modality strategy).

The standalone **Morphology tab is removed**. Its rule editor UI is reused in two new locations:
1. **Grammar tab** (new) — owns POS & dimensions, inflectional rules, paradigm viewer, typology
2. **Lexicon tab > Derivations sub-tab** (new 4th sub-tab) — owns derivational rules

Existing Phase 2 `MorphologicalRules` are silently reclassified as derivational on v7→v8 migration. The `PartsOfSpeech` table and POS editor move from Morphology tab to Grammar > POS & Dimensions. Per-word exceptions from Phase 3 (`MorphologicalRuleExceptions`) are preserved.

Out of scope for Phase 4: SPE-style rule computation for allophones (still descriptive per Phase 3.2); AI-assisted rule generation; cross-project dimension sharing; agreement between words (e.g., adjective-noun concord); writing scratchpad / interlinear gloss (v2).

</domain>

<decisions>
## Implementation Decisions

### POS dimension data model

- **D-01:** **Hybrid storage** — new `Dimensions` table with columns `(id, posId FK, name, ordering, levels_json, templateId nullable)`. Dimension rows exist per POS; the levels are stored as a JSON array inside the row (e.g., `[{"name":"Singular","abbr":"SG","ordering":0}, {"name":"Plural","abbr":"PL","ordering":1}]`). This is the middle ground between fully normalized DimensionLevels tables and an embedded JSON blob on the POS row.
- **D-02:** **Dimensions are per-POS only.** No cross-POS sharing. If both Noun and Adjective have a "gender" dimension, they exist as two separate rows. Keeps schema simple and matches the `Dimensions(posId, ...)` shape in D-01.
- **D-03:** **Ship a rich template catalog** of common dimension variants, hardcoded in Dart as const data (not seeded into the DB). Template variants include:
  - **Gender**: M/F, M/F/N, Animate/Inanimate, Common/Neuter
  - **Number**: SG/PL, SG/DU/PL, SG/PL/COLL
  - **Case**: NOM/ACC/GEN/DAT, ABS/ERG/GEN/DAT, NOM/ACC/GEN/DAT/ABL/LOC/INSTR (Latin-ish)
  - **Tense**: PRS/PST/FUT, PRS/PST, Non-future/Future
  - **Aspect**: PFV/IPFV, Progressive/Habitual/Perfect
  - **Person**: 1/2/3, 1INCL/1EXCL/2/3
  - **Mood**: IND/SUBJ/IMP, IND/OPT/IMP
  - **Voice**: ACT/PASS, ACT/MID/PASS
  - **Definiteness**: DEF/INDEF
  - (Planner may add more during research — these are the starting set.)
- **D-04:** Each template entry carries a **short description string** (bundled in the Dart catalog) shown as a tooltip on hover in the template picker. Descriptions should explain the concept briefly (e.g., "Ergative — the case marking the agent of a transitive verb; contrasts with absolutive for intransitive subjects and direct objects."). Phase 6 glossary can later deep-link to fuller articles, but Phase 4 ships self-contained tooltips.
- **D-05:** **Template picker is a two-step dialog.** Click "Add dimension" → searchable modal grouped by type (Gender / Number / Case / Tense / Person / Aspect / Mood / Voice / Definiteness). Each template card shows its levels and description tooltip. Clicking a template inserts it into the current POS as an editable instance — the user can then remove levels or add new ones.
- **D-06:** **No hard limit** on N dimensions × K levels per POS. Planner may add a soft warning above 4 dimensions or >100 total cells, but no enforcement.
- **D-07:** **Per-word dimension opt-out.** Each word can mark specific dimensions as "not applicable" (e.g., mass nouns skip number; impersonal verbs skip person). Requires a per-word skip list — implementation candidate: a `Lexeme.skippedDimensionIds` JSON/CSV column, or a join table. Planner to decide the exact shape. Paradigm viewer only renders axes that apply to the selected word.
- **D-08:** **Lemma = first level of every dimension.** The "citation form" shown in the dictionary word list is the root with all dimensions resolved to their first (ordering=0) level — typically NOM/SG/M/PRS. Dimension `ordering` on levels determines which is canonical. This is global behavior; no per-word lemma override in v1.

### Rule binding & stacking — feature consumption model

- **D-09:** **Inflectional rules carry feature-value bindings.** A rule's binding is a set of `{dimensionId, levelId}` pairs — 1 to N of them. A rule with `{gender=M, number=PL}` is a 2-dimension portmanteau. A rule with `{number=PL}` is single-dimension. A rule with no bindings at all is effectively unbound and not inflectional (this is derivational territory — see D-28).
- **D-10:** **Feature consumption algorithm for paradigm cell generation:**
  1. For a target cell with feature set `F = {dim1=v1, dim2=v2, ..., dimN=vN}`
  2. Among all inflectional rules for the word's POS, find those whose bindings are a **subset of `F`**
  3. Pick the one with the **largest** binding set (most specific)
  4. Apply that rule to the working form and mark its bound dimensions as **"consumed"**
  5. Remove consumed dimensions from `F`; if any remain, repeat from step 2 with the reduced feature set
  6. Stop when all dimensions are consumed or no more matching rules exist
- **D-11:** **Examples of D-10 in action:**
  - Rules: `-s` for `{PL}`, `-o` for `{M}`, `-is` for `{M, PL}`. For cell M.PL: `-is` wins (most specific, covers both). For M.SG: `-o` fires. For F.PL: `-s` fires.
  - Rules: `-ar` for `{M, PL}` (gender+number portmanteau), `-e` for `{DAT}`. For cell M.PL.DAT: `-ar` fires first (most specific, covers gender+number), consuming those two dims. Remaining feature set is `{DAT}`; `-e` fires next. Final stacked output: `root-ar-e`.
- **D-12:** **Ambiguous ties = error.** When two rules have the same specificity (same binding-set size) and both match a cell's remaining feature set, the engine surfaces a **red warning** in the rule editor / paradigm viewer pointing to both rules. The user must differentiate them (add another tag, or disable one) — no silent tiebreaker. Rationale: conlangers should not be confused by invisible ordering-based resolution; surface the conflict.
- **D-13:** **Unbound rules never fire on inflectional paths.** A rule with zero bindings cannot apply to a paradigm cell (it's derivational by definition). This prevents accidental stacking from legacy Phase 2 rules after migration (see D-22).
- **D-14:** **Uncovered cells display an em-dash `—` with a subtle warning icon.** The cell is clickable: clicking opens the paradigm-cell override dialog (D-18) pre-seeded with nothing, or offers a "Create rule for this cell" shortcut. Coverage is intentionally visible at a glance.
- **D-15:** **Coverage visibility — dual surfacing:**
  - **Per-word** — in the paradigm viewer (both Grammar tab and Lexicon word detail), each cell is color-coded or annotated with which rule(s) filled it. Hovering a cell shows the rule chain (e.g., "`-ar` (gender+number) → `-e` (case)").
  - **Per-POS** — the Grammar tab has a standalone coverage matrix for each POS showing which `{dimension, level}` combinations have at least one matching rule, independent of any specific word. Uncovered combinations stand out visually.

### Migration of Phase 2 rules and schema evolution (v7 → v8)

- **D-16:** **Schema version bumped to 8.** New migration in `lib/db/app_database.dart` under `onUpgrade` with `if (from < 8)` guard. Safety-net `beforeOpen` ALTER TABLE added for backward compatibility (matches Phase 1 pattern from plan 01-13).
- **D-17:** **Add `kind` enum column to `MorphologicalRules`.** Text column with values `'inflectional' | 'derivational'`. Default on new inserts: determined by which tab the user opened the editor from. Default on migration: `'derivational'` for every existing row.
- **D-18:** **Silent reclassification on migration.** All existing Phase 2 `MorphologicalRules` rows get `kind='derivational'` when a v7 project is opened in v8. No one-time migration UI, no user prompt. Rationale: zero friction, zero data loss; users who want an inflectional rule can toggle the kind manually afterward. The rules simply appear in the new Lexicon > Derivations sub-tab.
- **D-19:** **Drop `posIds` CSV column in favor of unified `feature_bindings` JSON.** The existing Phase 2 `posIds` comma-separated column is migrated into the new feature-binding model:
  - For derivational rules (every migrated row), the posIds become `{ pos: [id1, id2, ...] }` entries in the new `feature_bindings` JSON. The "pos" binding is a first-class feature at the POS-selection layer, not a grammatical dimension.
  - For inflectional rules (newly created post-migration), `feature_bindings` holds `{ pos: [...], dim1: level, dim2: level, ... }`.
  - This unifies Phase 2's posIds filtering with Phase 4's new feature tags under one JSON schema. Simpler reasoning and one query path in the engine.
- **D-20:** **Add `input_pos_id` and `output_pos_id` columns for derivational rules.** Both required for `kind='derivational'`. `input_pos_id` = POS the rule applies to (derived from migrated posIds — if the migrated row had a single posId, it becomes the input; if multiple, the rule still applies to any of them via `feature_bindings.pos[]`). `output_pos_id` defaults to `input_pos_id` on migration so existing derivations preserve their POS (e.g., fire+man → fireman stays a Noun). User can change output POS in the rule editor.
- **D-21:** **New `Dimensions` table** created in v8 migration: `(id INTEGER PK, pos_id INTEGER FK → PartsOfSpeech, name TEXT, ordering INTEGER, levels_json TEXT, template_id TEXT nullable)`. Empty on upgrade — no seeding.
- **D-22:** **`MorphologicalRuleExceptions` preserved as-is.** Phase 3's per-word exception table is untouched. Exceptions continue to work on derivational rules; for inflectional rules, per-cell overrides use the same table via the rule ID (each paradigm cell maps to at most one inflectional rule chain; the override is keyed to the topmost rule in that chain). Planner may introduce a separate `ParadigmCellOverrides` table if the single-ruleId approach proves insufficient.
- **D-23:** **POS page moves to Grammar > POS & Dimensions sub-tab.** The existing `morphology_shell.dart` POS page is absorbed into the new Grammar sub-tab. The dimension editor is added to it. The `PartsOfSpeech` schema is unchanged.
- **D-24:** **Morphology tab and its router branch are deleted.** `lib/shared/widgets/app_shell.dart:25` removes the Morphology `_TabItem`. `lib/router/app_router.dart:104-133` removes Branch 1 (Morphology). Downstream branch indices (Lexicon, Grammar/new, Culture) renumber accordingly. `lib/features/morphology/presentation/morphology_shell.dart` is deleted; the sub-pages (`pos_page.dart`, `rules_page.dart`, `rule_editor_dialog.dart`, `preview_panel.dart`) are relocated — `pos_page.dart` into Grammar, `rules_page.dart` reused by both Grammar (filtered to inflectional) and Lexicon > Derivations (filtered to derivational), `rule_editor_dialog.dart` becomes the shared editor.

### Paradigm table rendering

- **D-25:** **Two-axis layout with third-dimension tab/dropdown.** For POS with 2 dimensions: flat rows × columns. For 3+ dimensions: two dimensions become the table axes (rows and columns), the rest become a tab bar or dropdown above the table that switches between "slices". Most readable for 3+ dim POS; standard Wiktionary/grammar-book style.
- **D-26:** **Axis configuration is user-configurable and persisted per-POS.** A small control above the paradigm table lets the user assign which dimension goes on the row axis, which on the column axis, and the rest on tabs/dropdown. Configuration is stored as a `typology.paradigm_axes.{posId}` key in `project_settings` (JSON blob per POS). **Configuration is set in the Grammar tab Paradigm Viewer sub-tab only**; the Lexicon word detail panel renders the paradigm using the current Grammar-tab setting (read-only reflection).
- **D-27:** **Paradigm viewer lives in both Grammar and Lexicon.**
  - **Grammar tab > Paradigm Viewer sub-tab** — standalone page. Top bar: POS dropdown + word picker (scoped to selected POS). Empty-word state shows a template paradigm using a synthetic root (e.g., `XYZ-`) so users can design/debug rules without a real word.
  - **Lexicon tab > Dictionary > word detail panel** — shows the paradigm for the currently-selected word using the axis config set in Grammar. No axis reconfiguration here.
  - Both views share the same widget.
- **D-28:** **Per-cell override UX — inline click opens a dialog.**
  - Click any paradigm cell to open an "Edit cell form" dialog.
  - Dialog fields: romanization (primary input), IPA (auto-derived from romanization on first input using the existing Phase 1 reverse-romanization mapping; editable after), optional notes.
  - Saving stores the override in `MorphologicalRuleExceptions` keyed by `(lexemeId, ruleId)` where ruleId = the topmost inflectional rule that filled the cell. If the cell was uncovered, the override is stored with a sentinel ruleId (planner to spec; candidate: `ruleId = 0` or a separate `ParadigmCellOverrides` table).
  - Overridden cells display in **amber/orange** (matching Phase 2/3 convention for irregular forms). Clearing the override restores the computed form.
- **D-29:** **Cell display: romanization + IPA stacked.** Each cell shows `rom` on the top line and `[IPA]` on the second line. Respects the project-wide romanization toggle (Phase 1) — if romanization is off, only IPA is shown. Alt-held modifier from Phase 3.1 still flips to IPA-first display app-wide; this view obeys the same contract.
- **D-30:** **Phonotactic violation highlighting on every cell.** Each cell's computed form runs through `WordGenerator.validateWord(form, inventory, constraints)` and the result is rendered via the existing `ViolationText` widget (wavy red underline + tooltip from Phase 3 plan 03-05). Per-word phonological exception toggle from Phase 3 still suppresses highlighting for loanwords. This is free infrastructure — no new validation code.

### Grammar tab information architecture

- **D-31:** **Grammar tab ships with 4 sub-tabs** in the Grammar sidebar (parallel structure to Lexicon's Dictionary/Swadesh/Thesaurus/Derivations):
  1. **POS & Dimensions** — manage parts of speech and their dimensions
  2. **Inflectional Rules** — create/edit inflectional rules with feature-value bindings
  3. **Paradigm Viewer** — browse paradigms by POS + word picker, configure axis layout
  4. **Typology** — project-level typology fields (alignment, word order, modality)
- **D-32:** **POS & Dimensions sub-tab is POS-as-primary master-detail.** Left panel: list of POS (Noun, Verb, Adjective, …) with add/delete buttons. Right panel: selected POS shows its dimensions (with add/remove/reorder), each dimension's levels (editable), and a "View paradigm template" link that jumps to Paradigm Viewer with this POS pre-selected. Layout mirrors the Lexicon dictionary master-detail pattern from Phase 3.
- **D-33:** **Inflectional Rules sub-tab reuses `rules_page.dart` with filters.** Top bar: POS filter dropdown (same as current Phase 2 rules_page) PLUS a feature-value filter ("show rules that apply when number=PL"). Bottom: rules list with up/down reorder arrows (unused for inflectional rules — see D-12 which rejects silent ordering tiebreakers — but kept for UI consistency with the derivational rules list; may be hidden or made non-functional for inflectional). Rule list filtered to `kind='inflectional'`.
- **D-34:** **Paradigm Viewer sub-tab layout.** Top: POS dropdown + word picker (searchable, scoped to selected POS). Empty word → synthetic root template mode. Below: axis config controls (row dim / col dim / tabs dim) + the paradigm table itself. Side panel: coverage matrix for the current POS (which `{dim, level}` combos have rules).
- **D-35:** **Typology sub-tab is a form.** Simple labeled-dropdown form with three fields: **Alignment** (NOM-ACC / ERG-ABS / Split), **Basic Word Order** (SVO / SOV / VSO / VOS / OVS / OSV / Free/Topic-prominent), **Modality Strategy** (Synthetic / Analytic / Mixed). Each field has an info tooltip explaining the concept (matching the Dimension template tooltip pattern from D-04). Typology is descriptive metadata only — no downstream filtering or engine behavior in Phase 4.

### Lexicon Derivations sub-tab

- **D-36:** **4th sub-tab in Lexicon sidebar, positioned after Thesaurus.** Route `/lexicon/derivations`. Added to `lexicon_shell.dart` `_SidebarItem` list. No reordering of existing Dictionary / Swadesh / Thesaurus entries.
- **D-37:** **Primary view: rules list.** Port of the current Phase 2 `rules_page.dart` into the Derivations sub-tab, filtered to `kind='derivational'`. Zero-surface new UI; reuses the existing editor dialog (via D-39's shared approach) and filter chips.
- **D-38:** **Derivational rules show input POS → output POS columns in the list.** Each rule row displays: name, DSL preview, input POS, output POS. Creation/edit dialog has selectors for both. **Default: output POS = input POS** on rule creation (preserves category; e.g., fire+man → fireman stays a Noun). User can change it to create cross-category derivations (verbalizer, nominalizer, etc.).
- **D-39:** **Auto-refresh via existing Riverpod stream plumbing.** `computedDerivedFormsProvider` already watches the rules table via Drift streams. Any insert/update/delete of a derivational rule automatically recomputes derived forms for all visible words in the Lexicon derivation tree widget. No manual refresh needed.

### Rule editor reuse approach

- **D-40:** **Single `RuleEditorDialog` with a `kind` parameter.** Constructor takes `(db.MorphologicalRule? existingRule, RuleKind kind)`. Based on kind:
  - **Inflectional** → shows a new "Applies to" section at the top with a multi-chip tag picker for feature bindings (D-42). Input/output POS selectors are hidden.
  - **Derivational** → shows "Input POS → Output POS" selectors at the top. Feature-binding tag picker is hidden.
  - **Shared between both** — DSL field, structured operations editor, branching/condition editor, live preview panel, name + active toggle.
- **D-41:** **Single `MorphologyDao` extended with kind-aware queries.** Add methods like `watchRulesByKind(RuleKind)`, `watchInflectionalRulesForPos(posId)`, `insertRuleWithKind(companion, kind)`. No separate DAO class. Both the Grammar and Lexicon rules list pages use this DAO with a `kind` filter.
- **D-42:** **Feature binding UI — multi-chip tag picker.** The inflectional rule editor's "Applies to" section renders one row per dimension of the currently-selected POS(es). Each row shows chips for each level (e.g., `Gender: [M] [F]` / `Number: [SG] [PL]` / `Case: [NOM] [ACC] [GEN] [DAT]`). Click a chip to toggle it into the binding set for this rule. Rules with no chips selected across any dimension are effectively unbound and get flagged as a validation error (inflectional rules must bind at least one feature). Similar chip-picker pattern to the existing Phase 2 `rules_page.dart` POS filter chips.

### Claude's Discretion

- Exact UI spacing, typography, and colors for the paradigm table and coverage matrix
- Whether the coverage matrix on the POS coverage sub-view is a separate panel or a mode toggle on the paradigm viewer
- Exact shape of the per-word dimension opt-out storage (`Lexemes.skippedDimensionIds` column vs a join table) — D-07 leaves this to the planner
- Whether uncovered paradigm cells get a "Create rule for this cell" shortcut button (D-14) or just an em-dash
- Exact sentinel for per-cell overrides on uncovered cells (D-28) — ruleId=0 vs a new `ParadigmCellOverrides` table
- Whether the dimension template picker (D-05) supports a "custom from scratch" option alongside templates, or requires always starting from a template
- Tiebreaker-error UX (D-12) — red toast? inline warning banner in rule editor? both?
- Whether the template catalog tooltips (D-04) support markdown or are plain-text
- How hidden reorder arrows on the Inflectional Rules list (D-33) are visually handled — hidden entirely, or disabled-gray
- Whether the Grammar tab POS editor (D-32) inherits the existing POS dialog from `morphology/presentation/pos/pos_page.dart` or gets a redesigned version
- Whether dropping the Morphology tab (D-24) requires a one-time explainer banner on first v8 open ("Morphology moved to Grammar and Lexicon → Derivations")
- Exact copy of each template's short description string (D-03/D-04) — researcher/planner should verify against standard linguistic references

### Folded Todos

No todos matched Phase 4 (`todo match-phase 4` returned empty).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Database schema (current state and migration target)
- `lib/db/app_database.dart` §PartsOfSpeech (lines 103–107) — current POS table (id, name, abbreviation); unchanged in v8 but gains the new Dimensions FK relationship (D-01, D-21)
- `lib/db/app_database.dart` §MorphologicalRules (lines 115–126) — current schema; Phase 4 v8 migration adds `kind`, `feature_bindings` (JSON), `input_pos_id`, `output_pos_id`; drops `posIds` (D-17, D-19, D-20)
- `lib/db/app_database.dart` §MorphologicalRuleExceptions (lines 134–140) — preserved as-is (D-22)
- `lib/db/app_database.dart` §Lexemes — needs per-word dimension opt-out column or join table (D-07, Claude's discretion for exact shape)
- `lib/db/app_database.dart` §onUpgrade (lines 202–235) — v7 → v8 migration goes here with `if (from < 8)` guard; beforeOpen safety-net follows the Phase 1 pattern from plan 01-13
- `lib/db/app_database.dart` §ProjectSettings — stores `typology.alignment`, `typology.word_order`, `typology.modality`, `typology.paradigm_axes.{posId}` (D-26, D-35)

### Existing morphology UI to reuse, relocate, or delete
- `lib/features/morphology/presentation/morphology_shell.dart` — **deleted** in Phase 4 (D-24)
- `lib/features/morphology/presentation/pos/pos_page.dart` — **relocated** to Grammar > POS & Dimensions sub-tab (D-23, D-32)
- `lib/features/morphology/presentation/rules/rules_page.dart` — **reused** by both Grammar > Inflectional Rules (filtered to `kind='inflectional'`) and Lexicon > Derivations (filtered to `kind='derivational'`) (D-33, D-37)
- `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` — **shared editor** for both contexts, extended with kind-aware affordances (D-40, D-42). Currently hard-wired to `morphologyDaoProvider` at line ~329; extend that DAO rather than injecting a new one (D-41).
- `lib/features/morphology/presentation/rules/preview_panel.dart` — reused as-is inside the shared editor
- `lib/features/morphology/data/morphology_dao.dart` — extended with `watchRulesByKind`, `watchInflectionalRulesForPos`, `insertRuleWithKind`, and queries against the new Dimensions table (D-41)
- `lib/features/morphology/domain/morphology_dsl.dart` — DSL parser/serializer unchanged; Phase 4 uses the existing DSL for both inflectional and derivational rules

### Router and shell surgery
- `lib/shared/widgets/app_shell.dart:25` — remove the Morphology `_TabItem`; add Grammar `_TabItem` (D-24)
- `lib/router/app_router.dart:104–133` — remove Branch 1 (Morphology); add Grammar branch with 4 sub-routes (`/grammar/pos`, `/grammar/inflectional`, `/grammar/paradigm`, `/grammar/typology`); renumber downstream branch indices (Lexicon, Culture) (D-24, D-31)
- `lib/features/lexicon/presentation/lexicon_shell.dart:17–32` — add 4th `_SidebarItem` for Derivations; add `/lexicon/derivations` route in app_router.dart (D-36)

### Existing lexicon and derivation infrastructure (reuse as-is)
- `lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart` — existing root → derived forms tree; auto-updates via `computedDerivedFormsProvider` (D-39); used by word detail panel to show derivations alongside the paradigm table
- `lib/features/lexicon/` (providers) — `computedDerivedFormsProvider` already watches rules via Drift streams; no new reactivity code needed
- `lib/features/phonology/data/romanization_providers.dart:90–105` — `romanizeProvider` is the global romanization helper; paradigm cell widget calls this to render romanized forms on top line (D-29) and to derive IPA in the override dialog (D-28). GRAM-07 "romanization for all derived forms" is satisfied automatically.

### Phonotactic validation and violation highlighting (reuse as-is)
- `lib/features/phonology/domain/word_generator.dart:42–66` — `Violation` and `ValidationResult` classes
- `lib/features/phonology/domain/word_generator.dart:275–303` — `WordGenerator.validateWord(form, inventory, constraints)` — call once per paradigm cell (D-30)
- `lib/shared/widgets/violation_text.dart:20–101` — `ViolationText(text, violations)` widget — drop-in for paradigm cell rendering (D-30)
- `lib/features/lexicon/` (Phase 3 per-word exception toggle) — already suppresses violations for `Lexemes.isPhonologicalException=true` (plan 03-06); paradigm cells inherit this automatically via the shared ValidationResult path

### Morphology engine integration
- `lib/features/morphology/domain/morphology_engine.dart` — evaluates rules against roots; Phase 4 extends the engine's rule selection path to implement the feature-consumption algorithm (D-10, D-11). The engine receives a "target cell feature set" and an ordered-by-specificity list of candidate rules; it applies them iteratively, marking consumed dimensions. The existing 8 operation types (Prefix, Suffix, Infix, Template, Ablaut, Reduplication, Suppletive, RemoveSuffix) and branching-with-conditions support are unchanged — only the rule-selection wrapper is new.
- `lib/features/morphology/domain/morphology_engine.dart` §resolvePhonemeClass (lines ~64–87) — unchanged; Phase 4 rules still reference natural classes via the Phase 3.2 resolver

### Prior phase context (read in this order)
- `.planning/phases/02-morphology-engine/02-CONTEXT.md` — hybrid rule authoring, exception handling philosophy, preview behavior, amber-for-irregular convention
- `.planning/phases/03-lexicon/03-CONTEXT.md` — lexicon master-detail layout, derivation tree, word detail panel structure, romanization-primary input pattern, Derivations tab placement hint (deferred from Phase 3)
- `.planning/phases/03.1-display-ux-fixes-inserted/03.1-CONTEXT.md` — Alt-held IPA reveal (FIX-05); paradigm cells should honor the same modifier contract
- `.planning/phases/03.2-phonology-enhancements-inserted/03.2-CONTEXT.md` — hardcoded-catalog pattern for default data (reference for D-03 template catalog approach); phonology violation highlighting is cross-cutting

### Requirements and roadmap
- `.planning/REQUIREMENTS.md` §Grammar (GRAM-01 through GRAM-07) — phase requirements
- `.planning/ROADMAP.md` §Phase 4 — phase goal, success criteria, plan skeleton (5 plans)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`rule_editor_dialog.dart`** — nearly self-contained; the main refactor is (a) adding a `kind` parameter to the constructor, (b) rendering conditional sections for feature bindings (inflectional) vs input/output POS (derivational), (c) threading `kind` into save companions. Internal state classes (`_OpState`, `_BranchState`, `_CondState`) and the DSL round-trip logic are unchanged.
- **`rules_page.dart`** — the POS filter chip pattern, the live rules list with Drift streams, and the reorder arrows are all reusable. Both the Grammar > Inflectional Rules sub-tab and the Lexicon > Derivations sub-tab instantiate this page with a `kind` filter.
- **`derivation_tree_widget.dart`** in lexicon — renders root → derived forms via `computedDerivedFormsProvider`. Phase 4 adds no new reactivity to it; it auto-refreshes when derivational rules change.
- **`romanizeProvider`** — already watched by every romanization-aware widget; paradigm cells subscribe via `ref.watch(romanizeProvider)` and get automatic updates when mappings change.
- **`ViolationText` + `WordGenerator.validateWord`** — drop-in phonotactic highlighting. Paradigm cells call `validateWord` per cell form and pass the violations to `ViolationText`.
- **`PartsOfSpeech` table + POS editor** — unchanged schema; existing CRUD moves from Morphology tab into Grammar > POS & Dimensions sub-tab (D-23).
- **`MorphologicalRuleExceptions` table + DAO** — unchanged; per-cell overrides in paradigm viewer reuse this table keyed to the topmost inflectional rule that filled the cell.
- **`project_settings` table** — reused for typology storage (D-35) and paradigm axis configuration per POS (D-26). No schema change, just new keys.
- **`computedDerivedFormsProvider`** — already computes derivations lazily from rules; Phase 4 repurposes it for `kind='derivational'` rules only. A new parallel provider `computedInflectedParadigmProvider(lexemeId)` is added for paradigm generation with the feature-consumption algorithm.

### Established Patterns
- **Drift migrations**: `onUpgrade` with `if (from < N)` guards + `beforeOpen` safety net (Phase 1 plan 01-13, Phase 2 plan 02-08, Phase 3 plan 03-01)
- **Hardcoded const catalogs in Dart**: `ipa_data.dart` (Phase 1) and Phase 3.2's default natural classes are the precedent for D-03's dimension template catalog
- **Master-detail layouts**: Lexicon Dictionary (Phase 3) is the pattern for Grammar > POS & Dimensions (D-32)
- **Hybrid rule authoring**: structured form + live DSL + preview panel (Phase 2) — the single shared `RuleEditorDialog` keeps this pattern for both inflectional and derivational rules (D-40)
- **Amber/orange for irregular forms**: Phase 2/3 convention for per-word exceptions; paradigm cell overrides inherit this color (D-28)
- **Alt-held modifier for alternate display**: Phase 3.1 FIX-05; Phase 4 paradigm cells honor it
- **POS filter chips**: Phase 2 rules_page.dart pattern, extended in Phase 4 for the feature-binding chip picker (D-42)
- **4-sub-tab sidebar pattern**: Lexicon already ships Dictionary/Swadesh/Thesaurus — Grammar parallels this structure (D-31), Lexicon grows a 4th entry (D-36)
- **Riverpod + Drift streams for reactive UI**: unchanged; paradigm viewer and coverage matrix are derived providers over existing rule and POS streams

### Integration Points
- **Router surgery** (`app_shell.dart:25`, `app_router.dart:104–178`) — remove Morphology branch, add Grammar branch with 4 sub-routes, add `/lexicon/derivations` sub-route. Non-trivial but mechanical.
- **Schema migration** (`app_database.dart:199, 202–235`) — bump to v8; add `kind`, `feature_bindings`, `input_pos_id`, `output_pos_id` columns; drop `posIds`; create `Dimensions` table; add per-word dimension opt-out (shape TBD). Migration is the highest-risk plan — must be atomic, reversible via beforeOpen safety net.
- **Morphology engine** (`morphology_engine.dart`) — new `computeParadigmCell(root, features, rules)` wrapper implementing the feature-consumption algorithm (D-10). Existing rule-evaluation code is reused unchanged for individual rule application.
- **New providers** — `dimensionsForPosProvider(posId)`, `computedInflectedParadigmProvider(lexemeId)`, `paradigmCoverageMatrixProvider(posId)`, `typologySettingsProvider`.
- **Shared rule editor dialog** — needs to accept `kind` at construction time and render conditional sections; DAO call sites pass `kind` into companions.
- **Paradigm viewer widget** (new) — composes axis-config UI + table + cell override dialog + ViolationText per cell. Used in both Grammar > Paradigm Viewer and Lexicon > word detail panel.

### Known non-issues / free infrastructure
- Romanization for derived forms (GRAM-07 part) — `romanizeProvider` handles this automatically.
- Phonotactic highlighting on paradigm cells — `ViolationText` + existing exception toggle handle this automatically.
- Drift stream reactivity for Lexicon derivation tree — existing plumbing.
- Phase 2 rule DSL parser, serializer, and 8 operation types — unchanged.
- POS table schema — unchanged; only the UI moves.
- Phase 3 exception table — unchanged; paradigm overrides reuse it.

</code_context>

<specifics>
## Specific Ideas

- **"I want quite a few common paradigms shipped"** — the user explicitly wants a rich default catalog of dimension templates (gender M/F, M/F/N, Animate/Inanimate; number SG/PL or SG/PL/DU; case NOM/ACC or ABS/ERG sets; tense; etc.) with per-template tooltip descriptions explaining the concept. Templates are pickable starting points; users then edit levels on the instance. This is a template-catalog pattern parallel to the Phase 3.2 default natural classes: hardcoded in Dart, read-only defaults, rich metadata.
- **"If I have a rule `-is` for masculine plural and single-dim rules `-s` for plural and `-o` for masculine, only `-is` is applied"** — the user's mental model of rule stacking is strict most-specific-wins with feature consumption, not additive stacking. This is the core engine decision (D-10, D-11) and has to be right for Phase 4 to feel natural for fusional languages.
- **"If the gender-number portmanteau already exists then we apply that and then case"** — multi-pass feature consumption: a 2-dim portmanteau covers its two dims, then remaining dims continue to match against single-dim rules in the same rule set. This enables hybrid fusional+agglutinative morphology without special-casing.
- **"A table showing that this case is filled"** — the user wants an exhaustiveness helper so they don't forget to define ACC.PL.NEUTER after defining ACC.SG.NEUTER. Coverage visibility has to be prominent — both per-word (in the paradigm viewer) and per-POS (in the Grammar tab), because the user needs both "is this word's paradigm complete" and "is my rule set complete".
- **"fire + man gives fireman which is still a noun"** — derivational rules default output POS = input POS, preserving category. This is the intuitive default; cross-category derivations (verbalizer, nominalizer) require explicit output POS change.
- **"IPA should again be autogenerated on first romanised input"** — consistent with the Phase 3 lexicon pattern: user types romanization first, IPA is reverse-derived from the romanization mapping, then user can override IPA manually. Applies to paradigm cell override dialogs (D-28).
- **"Axis config is only in the grammar tab, the lexicon tab reflects"** — axis configuration is a Grammar-tab concern; the Lexicon word detail panel is a consumer. One configuration source, two views.
- **"Forget I said that, don't merge them"** — confirmation that the Grammar tab keeps 4 distinct sub-tabs (POS & Dimensions / Inflectional Rules / Paradigm Viewer / Typology). No merging of rules and paradigm viewer.

</specifics>

<deferred>
## Deferred Ideas

- **Cross-POS dimension sharing** — explicitly rejected (D-02) in favor of per-POS scoping. Could revisit in a future "grammatical features library" phase if users build many POS with identical dimensions.
- **Agreement between words (adjective-noun concord, verb-subject agreement)** — not discussed; out of scope for Phase 4. Would require a cross-word feature-propagation mechanism. Candidate for a future "syntax" phase.
- **Tiebreaker-as-ordering** — rejected in favor of explicit error (D-12). Users who want ordering-based resolution can add more tags to differentiate rules. Could be added as an opt-in project setting later if Phase 4 UAT shows this is too strict.
- **AI-assisted rule suggestions from typology** — typology is descriptive-only in Phase 4 (D-35). A future AI-agent phase could read typology fields to suggest rule templates (e.g., "your language is ergative — suggest ABS/ERG case inflections").
- **Full SPE rule computation for allophones** — still descriptive per Phase 3.2 D-10 through D-13. Paradigm cells show the surface form the morphology engine produces, without applying phonological rewrite rules downstream. Integrating SPE is a future phonology-engine phase.
- **Writing scratchpad / interlinear gloss** — v2 per REQUIREMENTS.md (WRIT-01…WRIT-04). Phase 4 does not add gloss output.
- **Paradigm export (CSV, HTML, LaTeX tables)** — not discussed. Users might want to export paradigms for grammar documentation; add to backlog.
- **Paradigm diffing between words** — not discussed. "Show me which cells differ between `run` and `swim`" — candidate for later.
- **Bulk paradigm-cell editing** — not discussed. "Paste a column of 24 forms from a spreadsheet". Candidate for later.
- **Rule debugging / "why did this rule not fire"** — not discussed. A debug mode showing the feature-consumption algorithm's match decisions per cell would help users diagnose unexpected outputs. Candidate for UAT-driven gap closure if needed.
- **Template: "custom from scratch"** — Claude's discretion whether to include a "blank template" entry in the template picker (D-05). Currently, D-05 implies template-first; a blank-start option is a UX decision.
- **One-time explainer banner on first v8 open** — Claude's discretion; could help users understand that "Morphology" moved to Grammar and Lexicon > Derivations (D-24 consequence).
- **Editable default dimension templates** — rejected in D-03 in favor of read-only template catalog with editable instances. Parallels the Phase 3.2 D-04 natural classes decision.
- **Per-POS typology overrides** — typology is global per project (D-35). Users with mixed-alignment languages would need workarounds.
- **Dimension-level rule grouping / folders** — not discussed. In large paradigms (Navajo-scale verbs), rules could benefit from folder-style organization. Candidate for later if the flat rule list gets unwieldy.

</deferred>

---

*Phase: 04-grammar-morphology-revised*
*Context gathered: 2026-04-10*
