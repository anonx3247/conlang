# Plan 04-17: Intrinsic Dimensions per POS + Standard-Form Patterns + Paradigm Viewer Improvements — Context

**Gathered:** 2026-04-11
**Status:** Ready for research + planning
**Parent phase:** 04-grammar-morphology-revised
**Wave:** 7 (with 04-15, 04-16, 04-18)
**Scope tag:** [GAP, Wave 7]

<domain>
## Phase Boundary

Plan 04-17 introduces **intrinsic dimensions**: a per-POS property on a `Dimension` row marking it as an inherent, non-inflecting feature of words of that POS. Classic example: grammatical gender on nouns (a noun IS masculine; it isn't "inflected into the feminine"). The plan also introduces **standard-form patterns** as a lightweight exception-highlighting mechanism tied to intrinsic levels (e.g. "masculine ends with V+o, feminine ends with V+a"), and extends the paradigm viewer to render every intrinsic-level combination as a stacked slice pooling lexemes across the POS.

### Scope

**Data model:**
- `Dimensions.intrinsic` boolean column (schema v10)
- `Lexemes.intrinsicLevelsJson` nullable JSON column (schema v10)
- New `StandardFormPatterns` side table (schema v10)

**Engine:**
- Cell enumeration in `paradigm_engine.dart` skips intrinsic dimensions
- Rule evaluation short-circuits when an intrinsic-dim binding mismatches a word's intrinsic level
- Coverage matrix becomes intrinsic-aware (collapses unreferenced intrinsic dims; expands referenced ones)

**UI:**
- Word creation dialog dynamically shows required intrinsic-level dropdowns under the POS picker
- POS change on existing word forces re-pick via blocking sub-form
- Dimension editor gains an "intrinsic" toggle per dimension and a "Standard form…" affordance per level
- Paradigm viewer always renders every intrinsic-level combination as a stacked slice, pooling lexemes across the POS
- Paradigm viewer default (no-selected-word) behavior: first matching lexeme, not the empty "template" placeholder
- Rule editor save-time validation blocks sole-intrinsic-binding rules

**Standard-form patterns:**
- Lightweight branch-based DSL (no ops, no conditions — just position-match predicates with class refs)
- Dedicated editor dialog accessed from the dimension editor
- Violations reuse `ValidationResult` / `Violation` / `ViolationText` → red-wavy highlights everywhere the form appears

**Out of scope (deferred):**
- Noun-adjective agreement propagation — explicit v2 deferral from the roadmap entry
- Intrinsic-to-intrinsic conditional rules that interact with *other* POSes (only within-POS intrinsic semantics for 04-17)
- Template patterns for adjectives derived from intrinsic patterns
- Any rule DSL changes to support new condition kinds — intrinsic conditions flow through the existing featureBindings structure via runtime reinterpretation
</domain>

<decisions>
## Implementation Decisions

### Schema (Cluster A — locked without discussion per user's call)

#### D-82 — `Dimensions.intrinsic` boolean column

- Schema v10 adds `BoolColumn get intrinsic => boolean().withDefault(const Constant(false))();` on `Dimensions` table.
- No junction table. `Dimensions` is already scoped per-POS via `posId`, so "gender-on-Noun" and "gender-on-Adjective" are already two separate rows that can independently set `intrinsic`.
- Toggle UI: checkbox in `dimension_editor_panel.dart` next to the dimension name, labeled "Intrinsic — words of this POS have a fixed level (not inflected)".
- Default false. Existing dimensions keep their current behavior after v9→v10 migration.

#### D-83 — `Lexemes.intrinsicLevelsJson` nullable TEXT column

- Schema v10 adds `TextColumn get intrinsicLevelsJson => text().nullable()();` on `Lexemes`.
- Content: JSON object `{"<dimensionId>": <levelId>, ...}`. Keys are stringified dimension ids, values are the level id within that dimension's `levelsJson`.
- `null` = no intrinsic levels set (e.g. root words of POSes with no intrinsic dims, or legacy words pre-v10).
- Mirrors the existing `skippedDimensionsJson` column pattern. No new DAO for now — reads/writes go through an extension method on `Lexemes` companion with a small `IntrinsicLevelsCodec`.

#### D-84 — Toggle-to-intrinsic backfill

- When a user flips `Dimensions.intrinsic` from false → true:
  - All existing `Lexemes` rows with `partOfSpeech` matching the dimension's POS are scanned.
  - For each matching lexeme, `intrinsicLevelsJson` gets `{dimensionId: firstLevelId}` added (or merged if the column already has entries for other intrinsic dims).
  - A one-time banner surfaces on the Inflections sub-tab listing the affected lexeme count with a "Review N words with auto-assigned default level" action that jumps to a filtered dictionary view.
- **Non-blocking.** The toggle completes immediately; the user can review affected words at their own pace. The banner dismisses when the user clicks "Review" or explicitly dismisses.

#### D-85 — Toggle-back to non-intrinsic

- Flipping `Dimensions.intrinsic` from true → false retains existing `intrinsicLevelsJson` entries for that dimension on lexemes (dead data, no harm).
- A cleanup affordance in the dimension editor ("Purge stale intrinsic levels for N words") lets the user explicitly scrub the entries.
- Rationale: if the user toggles back on, the data is preserved. If they never toggle back, the column is nullable and carries a few dead bytes per lexeme. Acceptable trade-off.

#### D-86 — Deleting an intrinsic level

- Deleting a `DimensionLevel` (via chip-delete in `dimension_editor_panel.dart:192`) when that level is referenced by any `Lexemes.intrinsicLevelsJson`:
  - Check runs in the `onDeleted` callback before the DAO write.
  - If `count > 0`, delete is blocked. A dialog shows the count and offers a "Reassign to level: [dropdown]" bulk action that updates every referring lexeme in one transaction, then deletes the level.
  - If `count == 0`, delete proceeds as today.
- Same check runs for non-intrinsic dimensions referenced in `featureBindings` of rules — already partial behavior; 04-17 unifies both into a single "dependency check before delete" helper.

### Rule DSL & engine (Cluster B — reframed after user feedback)

#### D-87 — RuleEditorDialog UI unchanged

- The bindings picker in `rule_editor_dialog.dart` continues to work exactly as today — users select dimension + level combinations from FilterChips regardless of whether the dimension is intrinsic.
- No "Conditions" section added, no locked chips, no special visual for intrinsic dims in the picker.
- Rationale (user-driven): "it being intrinsic doesn't change that a rule is e.g. only applied to a given level." The bindings picker already expresses "apply this rule when dim=level"; whether that's interpreted as an axis or a filter is an engine concern, not a UI concern.

#### D-88 — Read-time interpretation via `Dimensions.intrinsic`

- The paradigm engine reads each dimension referenced in a rule's `featureBindings` and consults its `intrinsic` flag at evaluation time:
  - **Non-intrinsic dim** → entry acts as an axis (the rule produces a cell in the paradigm where that dim has that level value).
  - **Intrinsic dim** → entry acts as a condition (the rule fires only when the word's `intrinsicLevelsJson` entry for that dim matches the binding value; no cell is produced on that axis).
- No storage change. Toggling `Dimensions.intrinsic` re-interprets existing rule bindings at next read. No migration of `featureBindings` needed.
- The engine will short-circuit early: before running ops, check every intrinsic-dim entry in `featureBindings` against the lexeme's `intrinsicLevelsJson`. On any mismatch, skip the rule entirely.

#### D-89 — Engine cell enumeration skips intrinsic dimensions

- `paradigm_engine.dart` cell-key generation currently enumerates the full Cartesian product of every dimension × level combination for the POS.
- 04-17 change: filter out any dimension with `intrinsic = true` from the enumeration base. The resulting cells are keyed only on non-intrinsic axes.
- Example: POS=Noun, dims=[gender(intrinsic, {M,F}), number({sg,pl})] → cell keys are just `{number=sg}`, `{number=pl}` (not four cells).
- `tiebreak_detector.dart` also consumes this enumeration — it auto-inherits the change.

#### D-90 — Rule save-time validation: block sole-intrinsic-binding rules

- In `rule_editor_dialog.dart` save path, after constructing `featureBindings` from the picker selections:
  - Compute `nonIntrinsicAxes = bindings.dimensionIds.where((id) => !dimension(id).intrinsic)`.
  - If `nonIntrinsicAxes.isEmpty` → block save. Error: "Rule has no non-intrinsic axes — it would produce no paradigm variation. Intrinsic-only behavior belongs in standard-form patterns at word creation, not inflection rules."
- Rationale: per user — "if it's intrinsic, you can't make a rule that applies all the time to them (might as well make this a format thing upon word creation)."

#### D-91 — Coverage matrix is intrinsic-aware

- The coverage computation in `coverage_matrix_panel.dart` / `paradigm_coverage_provider.dart` changes as follows:
  - **Axis construction:** take the set of all dimensions referenced by at least one rule's `featureBindings` for this POS. Include both intrinsic and non-intrinsic dims among referenced ones. Intrinsic dims not referenced by any rule are collapsed OUT of the axis list.
  - **Cell enumeration for coverage:** Cartesian product of the referenced-dimension axes.
  - **Coverage check per cell:** a cell is covered if any rule's `featureBindings` matches the cell (binding dim+level pair matches cell dim+level). A rule with no binding on a given dim covers *all* levels of that dim.
- **Worked example (user's own):**
  - POS=Noun, gender intrinsic with {M, F}, number non-intrinsic with {sg, pl}.
  - Rules: `{gender=M, number=pl}` and `{number=pl}`.
  - Coverage axes: `[gender, number]` (both referenced).
  - Cells: `(M,sg), (M,pl), (F,sg), (F,pl)`.
  - Cell `(M,pl)`: covered by both rules.
  - Cell `(F,pl)`: covered by `{number=pl}` only.
  - Cells `(M,sg)`, `(F,sg)`: UNCOVERED — flagged.
  - Drop the general `{number=pl}` rule: `(F,pl)` becomes uncovered, flagged.
  - Rules = only `{number=pl}` (no gender references): axes collapse to just `[number]`. Cells = `(sg), (pl)`. `(sg)` uncovered.
- **Intrinsic-blind, lexeme-blind.** Coverage never iterates `Lexemes.intrinsicLevelsJson`; it works purely from rule bindings.

#### D-91b — No migration of existing rules on toggle

- Toggling `Dimensions.intrinsic` does NOT touch existing rules' `featureBindings`. All existing rules continue to work under the new interpretation (with their entries now treated as conditions instead of axes if they reference the newly-intrinsic dim).
- If this produces an inconsistent or semantically-degenerate state (e.g. a rule with only intrinsic-dim entries after a toggle), it's surfaced via the D-90 save-time validator the next time the rule is edited. The engine tolerates the state in the meantime: the rule simply fires conditionally without producing any cell variation.
- Trade-off: predictability vs. cleanliness. User accepted this implicitly by choosing the simpler model in Cluster B discussion.

### Word creation / editing UI (Cluster C)

#### D-92 — Word creation dialog: dynamic sub-form under POS dropdown

- The existing word creation form (today asks for rom, ipa, meaning, POS) gains a dynamic "Intrinsic" section that renders beneath the POS dropdown.
- When the user picks a POS, the form queries `dimensionsForPosProvider(posId)` and filters to `d.intrinsic == true`. For each intrinsic dim, a required `DropdownButtonFormField` is rendered with that dim's levels.
- Save is blocked until every required intrinsic dropdown has a non-null value. Validation error inline per dropdown: "Required — every {dim.name} noun must have a fixed level."
- The section hides itself entirely if the selected POS has no intrinsic dims (current behavior preserved).
- Submitted values serialize into `intrinsicLevelsJson` on insert.

#### D-93 — POS change on existing word: force re-pick via blocking sub-form

- When the user changes an existing lexeme's `partOfSpeech` in `word_detail_panel.dart` edit form:
  - The same dynamic intrinsic section from D-92 renders inline.
  - **Overlap preservation:** for any dimension that exists (by `id`) on both the old POS and the new POS AND is intrinsic on the new POS, the existing level value from `intrinsicLevelsJson` is preserved and pre-filled.
  - Non-overlapping dims (intrinsic on new POS but not on old) have empty dropdowns — user must fill them.
  - Dims that were intrinsic on the old POS but aren't on the new POS are silently dropped from `intrinsicLevelsJson` on save.
- Save is blocked until all required new-POS intrinsic dropdowns are filled.

### Paradigm viewer (Cluster C continued)

#### D-94 — Always-show-every-intrinsic-slice: pooled lexemes

- `paradigm_table_widget.dart` currently renders one paradigm table for one selected lexeme.
- 04-17 change: when the POS has any intrinsic dimensions, the viewer renders the Cartesian product of intrinsic levels as stacked sections. Each section is labeled with the intrinsic combination (e.g. "Masculine", "Feminine Class I").
- **Lexeme pooling per section:**
  - Each section has a dropdown at the top that lists every `Lexemes` row whose `intrinsicLevelsJson` matches that intrinsic combination for this POS.
  - Default selection = first matching lexeme in id order.
  - If the user has an explicitly selected lexeme (from the Inflections sub-tab word picker), that lexeme's section is pre-selected to that lexeme; other sections default-pool.
  - Each section's dropdown is independently user-overridable without affecting the Inflections word picker selection.
- **Empty pools:** if no lexeme of that intrinsic combination exists, the section shows an empty-state hint: "No word with [Masculine Class I] intrinsic levels yet. Create one to view this paradigm."

#### D-95 — Default paradigm viewer word: first matching lexeme, not template

- General improvement separate from intrinsic logic: when the Inflections sub-tab word picker has no selection and the paradigm viewer is asked to render for a POS, the default should be the first matching `Lexemes` row with that POS (lowest id) — NOT the current empty-template placeholder behavior.
- If no lexeme of that POS exists at all, keep the existing empty state ("No words in this POS yet").
- This applies whether or not the POS has intrinsic dims. For a POS with intrinsic dims, the first-matching logic runs per intrinsic slice (D-94).

### Standard-form patterns (Cluster D)

#### D-96 — Pattern DSL: branches of position-match predicates with class refs

- A standard-form pattern for a single `(intrinsic dimensionId, levelId)` pair consists of one or more **branches**. A match against any branch satisfies the pattern (OR logic).
- **Branch structure:**
  - `kind`: one of `startsWith`, `endsWith`, `contains`.
  - `literal`: a sequence of tokens where each token is either a literal phoneme (phonemic per 04-15 D-70) or a natural class ref (`V`, `C`, `F`, `[classname]`). Class refs expand to a set of phonemes from the inventory at match time.
- **Examples:**
  - "Masculine ends with -o" → one branch `(endsWith, "o")`.
  - "Spanish verb classes" on intrinsic `class` dim:
    - Level `ar-class`: one branch `(endsWith, "ar")`.
    - Level `er-class`: one branch `(endsWith, "er")`.
    - Level `ir-class`: one branch `(endsWith, "ir")`.
  - "Feminine nouns end in -a or -ión": two branches `(endsWith, "a")` + `(endsWith, "ioŋ")`.
  - "Verbs end with vowel + r" (user's example): one branch `(endsWith, "Vr")` where `V` expands to the full vowel inventory, matching `-ar`, `-er`, `-ir`, `-or`, `-ur`.
- **Matcher:** reuse the pattern matching primitives from `morphology_dsl.dart` — the existing `PatternCond` logic already handles class ref expansion. Wrap it with a thin `StandardFormMatcher` that anchors the match at the correct position based on the branch `kind` (start, end, contain).
- **No conditions, no ops, no feature bindings.** Pattern rules are pure match-or-not predicates.

#### D-97 — Storage: new `StandardFormPatterns` side table

- Schema v10 adds:
  ```
  class StandardFormPatterns extends Table {
    IntColumn get id => integer().autoIncrement()();
    IntColumn get dimensionId => integer().references(Dimensions, #id, onDelete: KeyAction.cascade)();
    IntColumn get levelId => integer()();  // references id within Dimensions.levelsJson
    TextColumn get branchesJson => text()();  // List<PatternBranch> JSON
    @override
    Set<Column> get primaryKey => {dimensionId, levelId};
  }
  ```
- `UNIQUE(dimensionId, levelId)` — each (intrinsic dim, level) pair has at most one pattern row.
- Cascade delete when a Dimension is removed. Level-id removal is handled by D-86's dependency-check pattern extended to also check `StandardFormPatterns.levelId`.

#### D-98 — Standard-form pattern editor: dedicated dialog, not RuleEditorDialog

- A new `StandardFormPatternDialog` widget. Accessed from the dimension editor: each intrinsic level gets a "Standard form…" affordance (e.g. a small pencil icon appearing next to the level chip when the parent dimension is intrinsic).
- Dialog layout:
  - Dimension name + level name shown as read-only header.
  - Branches list with add / remove controls. Each branch row: `[dropdown kind] [text field literal]`.
  - Per-branch live preview showing what the branch matches (reuses `PhonemeInventory` to expand class refs and preview matches, e.g. "Vr matches: ar, er, ir, or, ur").
  - Save button writes to `StandardFormPatterns` via a new `StandardFormPatternDao`.
- Why not reuse `RuleEditorDialog`: semantics are too different (no ops, no feature bindings, no POS picker). Fork the branch-list UX element into a shared widget if needed, but the enclosing dialog is distinct.

#### D-99 — Violation rendering: red-wavy everywhere the form appears

- Standard-form violations reuse `ValidationResult` / `Violation` / `ViolationText`:
  - A new `standardFormValidationProvider(lexemeId)` computes violations for a lexeme against every applicable `(intrinsic dim, level)` pattern.
  - Violation instances include the pattern's natural-language description (e.g. "Masculine Class I nouns should end with Vr") in the `ruleDescription` field.
- **UI surfaces** (matches phonotactic violation scope today):
  - Dictionary list (`word_list_panel.dart`)
  - Word detail (`word_detail_panel.dart`)
  - Paradigm viewer cells (`paradigm_table_widget.dart`) — violation shown on the base form, not inflected output
  - Swadesh list (`swadesh_page.dart`)
  - Thesaurus / inspiration surfaces where a lexeme form is rendered
- **Soft warning only.** Violations never block word creation or editing. They're diagnostic highlights.
- **Combined with phonotactic violations:** when a word has both a phonotactic violation and a standard-form violation, both render through `ViolationText` simultaneously. Tooltips enumerate all violated rules.

### Claude's Discretion

- Exact widget tree for the stacked intrinsic-slice paradigm viewer (D-94) — stacked expansion tiles vs. side-by-side columns on wide screens.
- Banner copy / dismiss affordance for D-84 auto-backfill.
- Tooltip copy for standard-form violations.
- Whether `StandardFormPatternDao` lives under `grammar` or `lexicon` feature dir — depends on where readers expect it.
- Keyboard shortcuts for adding/removing branches in D-98 dialog.
- Whether the "Intrinsic" checkbox in the dimension editor warns before toggling on a dimension that has many existing words (the D-84 banner covers this already, but a pre-flight confirm may reduce surprise).
</decisions>

<specifics>
## Specific Ideas

- User's Spanish verb-class example was the anchor for intrinsic dims: `-ar`, `-ir`, `-er` classes as intrinsic values on nouns/verbs, with rules conditioned by class.
- User explicitly rejected a bindings-vs-conditions UI split: "keep it as is, being intrinsic doesn't change that a rule is e.g. only applied to a given level."
- User explicitly banned sole-intrinsic-binding rules: "this should be banned, insofar as if it's intrinsic, then you can't make a rule that applies all the time to them (might as well make this a format thing upon word creation)."
- User clarified class-ref support in standard-form patterns: "the literal should still accept classes as well, e.g. 'ends with Vr' (which would auto match -er, -ir, and -ar, but also -or, -ur)."
- User requested pooled-lexeme stacking: "it should always show the intrinsic dimensions, it should just pool from multiple lexemes."
- User requested paradigm viewer default improvement: "the default should be to choose the first word that corresponds to the matching criteria (i.e. default should not be the currently empty 'template's)."
- Coverage semantics are user-specified, not Claude-invented — see the worked example in D-91.
</specifics>

<canonical_refs>
## Canonical References

### Prior phase context (required reading)

- `.planning/phases/04-grammar-morphology-revised/04-CONTEXT.md` — Phase 04 master decisions (D-01..D-42), especially D-07/D-08 (dimension model), D-10/D-11 (feature consumption), D-22/D-28 (paradigm viewer / cell overrides)
- `.planning/phases/04-grammar-morphology-revised/04-CONTEXT-GAPS.md` — Wave 1-5 gap decisions (D-43..D-65), especially D-45/D-46/D-47 (unmarked / marker resolution — predecessor of 04-18's Markers UI), D-48/D-49/D-50 (Inflections sub-tab restructure), D-52 (ParadigmClickMode)
- `.planning/phases/04-grammar-morphology-revised/04-15-CONTEXT.md` — Wave 6 notation unification (D-70..D-77) — required for D-96 standard-form pattern literals (phonemic-stored)
- `.planning/phases/04-grammar-morphology-revised/04-16-CONTEXT.md` — Wave 7 sibling plan (D-78..D-81)
- `.planning/phases/04-grammar-morphology-revised/04-18-CONTEXT.md` — Wave 7 sibling plan (D-100..D-102, Markers UI via RuleEditorDialog checkbox)

### Source files touched by 04-17

#### Schema + migration
- `lib/db/app_database.dart:134-142` — `Dimensions` table, add `intrinsic` column
- `lib/db/app_database.dart:316-359` — `Lexemes` table, add `intrinsicLevelsJson` column
- `lib/db/app_database.dart:365+` — `@DriftDatabase` table list, add `StandardFormPatterns`
- `lib/db/` — new file `standard_form_patterns_table.dart` for the new table definition (or inline if the pattern is to keep tables in `app_database.dart`)
- Drift migration `onUpgrade` v9 → v10 — add columns, create table, set defaults

#### Engine
- `lib/features/grammar/domain/paradigm_engine.dart` — cell enumeration + rule eval intrinsic short-circuit (D-88, D-89)
- `lib/features/grammar/domain/tiebreak_detector.dart` — auto-inherits D-89 but may need explicit verification
- `lib/features/grammar/data/paradigm_coverage_provider.dart` — intrinsic-aware coverage (D-91)
- `lib/features/grammar/presentation/paradigm_viewer/coverage_matrix_panel.dart` — render new coverage semantics

#### Rule editor
- `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` — D-90 save-time validator
- `lib/features/morphology/presentation/rules/rules_page.dart` — no changes from 04-17 (04-16 and 04-18 touch this)

#### Dimension editor
- `lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart` — `intrinsic` toggle per dimension, "Standard form…" affordance per level, D-85 cleanup affordance, D-86 delete-with-reassign dialog

#### Word creation + edit
- `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart` — D-92 dynamic intrinsic sub-form, D-93 POS-change re-pick flow
- `lib/features/lexicon/presentation/dictionary/` — any word creation dialog files

#### Paradigm viewer
- `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` — D-94 stacked intrinsic slices with pooled lexemes, D-95 first-matching-lexeme default
- `lib/features/grammar/presentation/inflections/inflections_page.dart` — D-95 affects default word in the sub-tab

#### Standard-form patterns
- `lib/features/grammar/data/standard_form_pattern_dao.dart` — NEW. CRUD against `StandardFormPatterns`.
- `lib/features/grammar/domain/standard_form_matcher.dart` — NEW. Reuses `PatternCond` primitives from `morphology_dsl.dart`.
- `lib/features/grammar/presentation/pos_dimensions/standard_form_pattern_dialog.dart` — NEW. Dedicated dialog for pattern editing.
- `lib/features/grammar/data/standard_form_validation_provider.dart` — NEW. Wraps matcher + inventory lookup, emits `ValidationResult`.

#### Violation rendering surfaces (D-99)
- `lib/features/lexicon/presentation/dictionary/word_list_panel.dart`
- `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart`
- `lib/features/lexicon/presentation/swadesh/swadesh_page.dart`
- `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart`
- `lib/shared/widgets/violation_text.dart` — reused unchanged

### Roadmap

- `.planning/ROADMAP.md:160` — 04-17 plan line

### Requirements

- `.planning/REQUIREMENTS.md` — GRAM requirements; intrinsic dimensions are an extension of the existing grammar/paradigm model
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`Dimensions.posId`** — already scopes dimensions per-POS. No junction needed for intrinsic; the flag goes directly on the row (D-82).
- **`skippedDimensionsJson` on Lexemes** — the existing per-word dimension-scoped JSON column. `intrinsicLevelsJson` follows the same shape and codec pattern (D-83).
- **`PatternCond`** in `morphology_dsl.dart` — already handles class-ref expansion (`V`, `C`, `[name]`). Reused by `StandardFormMatcher` (D-96).
- **`ValidationResult` / `Violation` / `ViolationText`** — already used for phonotactic violations. Standard-form violations emit through the same types, rendered at the same widget (D-99).
- **`paradigm_coverage_provider`** — current coverage logic iterates all dim × level combinations. Minimal change to filter axes by "referenced by any rule" (D-91).
- **`markersForPosProvider`** — existing marker rendering consumer (built in 04-10). 04-18 adds the creation UI; 04-17 doesn't touch markers directly.
- **`_RenameDimensionDialog`** pattern — useful template for the `StandardFormPatternDialog` structure (D-98).
- **`computedInflectedParadigmProvider`** — the paradigm viewer's primary data source. D-94's stacked slices call this provider multiple times (once per intrinsic combination with different lexeme inputs).

### Established Patterns

- Drift schema version bumps with `onUpgrade` + `beforeOpen` safety net (pattern established in 04-01, 04-08). 04-17 adds v9 → v10.
- JSON-column-with-TypeConverter (e.g. `levelsJson`, `FeatureBindingsConverter`). `intrinsicLevelsJson` gets its own `IntrinsicLevelsCodec`.
- FilterChip bindings picker (`rule_editor_dialog.dart`). Unchanged.
- Stream-based provider reactivity (`markersForPosProvider`, `computedInflectedParadigmProvider`). `standardFormValidationProvider` follows the same shape.
- `isPhonologicalException` bool on Lexemes for phonotactic opt-out — potentially reusable for a future "standard-form exempt" flag if users complain.

### Integration Points

- `Dimensions.intrinsic` flag is read by: paradigm engine, coverage provider, rule editor save-time validator, word creation form, paradigm viewer, dimension editor itself. Provider-level caching (e.g. `intrinsicDimensionsForPosProvider`) avoids N+1 reads.
- `Lexemes.intrinsicLevelsJson` is read by: paradigm engine (rule eval short-circuit), paradigm viewer (slice assignment), word detail edit form. Writes happen in: word creation, word edit, D-84 backfill migration, D-86 reassignment.
- `StandardFormPatterns` is read by: `standardFormValidationProvider` → lexicon + paradigm surfaces. Written from: `StandardFormPatternDialog`.
- `PhonemeInventory` is consumed by: `StandardFormMatcher` (D-96), `PhonemeLiteralScanner` (04-16 D-81), existing phonotactic validator. Single provider, many consumers — no churn.

### Known non-issues / free infrastructure

- Engine change for D-88 / D-89 is localized — the cell-key generator and rule-eval entry point are each ~30 lines.
- Standard-form pattern matcher is a thin wrapper around existing DSL primitives — no new parser work.
- Violation rendering reuses existing widgets — no new UI components for violation highlighting.
- `markers` table already exists and is consumed by the engine (from 04-10) — 04-17 doesn't touch it; only 04-18 adds the creation UI.
</code_context>

<deferred>
## Deferred Ideas

- **Noun-adjective agreement propagation** — explicit v2 deferral from the roadmap entry. Not in 04-17. Would touch: rule DSL extension for cross-lexeme binding references, paradigm engine for agreement resolution, UI for declaring agreement targets.
- **Intrinsic dimensions conditioning OTHER POSes** — e.g. "adjective agrees with the noun's intrinsic gender". Depends on agreement propagation above.
- **Standard-form patterns with repetition / bounded quantification** — e.g. "ends with C+V+C". D-96 DSL is match-only with no quantifiers. If users ask, extend `StandardFormMatcher` with repeat counts.
- **Regex or full phonotactic DSL reuse for standard-form patterns** — considered and rejected in Cluster D discussion. User chose the restricted branch-based DSL with class refs.
- **Save-time block for standard-form violations** — chose soft-warning-only. Revisit if violation noise becomes a complaint.
- **Drag-to-reorder intrinsic level slices in the paradigm viewer.** Default order follows `levelsJson` order. Users can reorder levels themselves via 04-16 (when that affordance lands).
- **Per-lexeme standard-form exemption flag** — if a user has a legitimately-irregular word that shouldn't flag, they'll need a way to silence the violation. Analogous to `isPhonologicalException`. Backlog until a user asks.
- **Bulk standard-form violation report** — a "words violating standard-form patterns" filter in the dictionary list. Backlog.
</deferred>

---

*Plan: 04-17-intrinsic-dimensions-standard-forms-paradigm-viewer (parent phase: 04-grammar-morphology-revised)*
*Context gathered: 2026-04-11*
