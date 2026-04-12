# Plan 04-18: Markers UI — "Leave as Unmarked" Rule Editor Mode — Context

**Gathered:** 2026-04-11
**Status:** Ready for research + planning
**Parent phase:** 04-grammar-morphology-revised
**Wave:** 7 (with 04-15, 04-16, 04-17)
**Scope tag:** [GAP, Wave 7]

<domain>
## Phase Boundary

Plan 04-18 fills a UAT-discovered gap from plan 04-10: the Markers (unmarked cells) data layer and engine support exist, but there is no user-facing way to CREATE a marker. The paradigm engine consumes `markersForPosProvider` (`lib/features/grammar/data/grammar_providers.dart:68`) and the marker-resolution pipeline is implemented (D-45/D-46/D-47 in 04-CONTEXT-GAPS.md), but `MarkerDao.insertMarker` (`lib/features/grammar/data/marker_dao.dart:55`) is never called from UI code. Verified by grep in `lib/` — the only reference is the DAO definition itself.

04-18 adds a "Leave as unmarked" checkbox to `RuleEditorDialog`. When checked, the dialog's operations section collapses, the bindings picker still works, and saving writes to the `markers` table via `MarkerDao.insertMarker` instead of `MorphologyDao.insertRule`. Markers then appear inline in the rules list alongside rules, tagged with a distinct `∅` badge, so they're editable and deletable from one place.

**In scope:** `RuleEditorDialog` checkbox + conditional operations section, `MarkerDao` call site, rules list display for markers, cell-click flow to edit existing markers (reuses `ParadigmClickMode.ruleEditor`).

**Out of scope:**
- Marker schema changes (the table already exists from 04-08)
- Engine changes to marker resolution (already implemented in 04-10)
- Changing the `∅` badge rendering in paradigm cells (already implemented in 04-10)
- Everything in 04-15, 04-16, 04-17
</domain>

<decisions>
## Implementation Decisions

### D-100 — "Leave as unmarked" checkbox in RuleEditorDialog

- `RuleEditorDialog` gains a new boolean field `_leaveAsUnmarked` and a corresponding checkbox rendered near the rule-name field at the top of the dialog body. Label: "Leave as unmarked (no rule, just a ∅ cell)".
- When checked:
  - The operations section (`branchesListBuilder` / ops editor area) is hidden from the dialog body.
  - The live `PreviewPanel` (`rule_editor_dialog.dart:1098`) is hidden — there's nothing to preview.
  - The rule name field remains visible and defaults to "Unmarked" if the user leaves it blank on save.
  - The kind selector (inflectional / derivational) remains visible; markers are typically inflectional but the `markers` table is kind-agnostic and the engine consumes them for inflectional-only paradigm generation. For 04-18, the checkbox is only rendered when `kind == RuleKind.inflectional` — hidden in derivational mode.
- When unchecked:
  - Dialog behaves exactly as today — ops section visible, preview visible, save writes to `MorphologicalRules`.
- The bindings (FilterChip) picker stays visible in both modes — markers need bindings to know which cells they resolve.

### D-101 — Save path: MarkerDao branch

- On save with `_leaveAsUnmarked == true`:
  - Skip `MorphologyDao.insertRule` / `updateRule` entirely.
  - Construct a `MarkerDecl` from the current bindings + rule name.
  - Call `MarkerDao.insertMarker(posId, featureBindings)` (new lifecycle) or `MarkerDao.updateMarker(id, featureBindings)` if editing an existing marker.
  - Close dialog; `markersForPosProvider` reactively updates the rules list and paradigm engine.
- Validation: at least one binding must be set (markers on the empty bindings set are a no-op and should be rejected with an inline error: "Select at least one dimension + level to mark as unmarked.").

### D-102 — Markers inline in rules list

- In `rules_page.dart` `_buildInflectionalGroupedList` (`rules_page.dart:451`), the current renderer pulls from `MorphologyDao`. Extend it to ALSO pull from `markersForPosProvider` and merge the two streams into a single list.
- Each merged list item is a tagged union: either a `MorphologicalRule` or a `MarkerDecl`.
- Visual distinction:
  - Rule rows render as today.
  - Marker rows render with the rule name prefix `∅` badge (e.g. "∅ Unmarked: 2sg present"), muted text color, and no ops preview.
- Both row types use the same tap-to-edit behavior — tapping opens `RuleEditorDialog` in the appropriate mode:
  - Tapping a rule row → dialog with `_leaveAsUnmarked = false` and rule pre-loaded.
  - Tapping a marker row → dialog with `_leaveAsUnmarked = true` and marker bindings pre-loaded.
- Both row types have the trailing delete action — rule delete calls `MorphologyDao.deleteRule`, marker delete calls `MarkerDao.deleteMarker`.
- POS-set grouping (D-56 from 04-11) extends to markers as well — markers with the same bindings set group with rules of that set.

### D-103 — Cell click → edit existing marker

- When the user clicks a paradigm cell that currently resolves to a `ParadigmUnmarked` variant (the `∅` cells from D-47), and the `ParadigmClickMode == ruleEditor`:
  - Determine if the cell is backed by a specific marker (`MarkerDecl` that matched the cell) vs. the "uncovered by any rule or marker" default.
  - If backed by a marker → open `RuleEditorDialog` in unmarked mode, pre-loaded with that marker's bindings, for editing.
  - If uncovered → open `RuleEditorDialog` in rule-creation mode (current behavior) with `preFilledBindings` from the cell (current 04-13 behavior).
- The distinction requires the paradigm engine to surface *which* marker produced the `ParadigmUnmarked` (or null if it was the default uncovered). Small change to `ParadigmUnmarked` variant to carry an optional `markerId`.

### Claude's Discretion

- Exact copy for the checkbox label and the ∅ badge styling.
- Whether the checkbox is a `Checkbox`, a `Switch`, or a `SegmentedButton` — any visual cue that clearly signals "rule mode" vs "marker mode".
- How the merged rules+markers list animates reordering when a rule becomes a marker or vice versa (probably it doesn't — converting requires deleting and recreating, no animation).
- Whether to add a soft hint "Markers are cells that should have no form change" somewhere visible on the dialog when in unmarked mode.
</decisions>

<specifics>
## Specific Ideas

- User's exact spec for the Markers UI: "can be marked through a 'new rule' by checking a checkbox of 'leave as unmarked' for all the selected POS / dimensions / levels defined in the rule dialog."
- Markers were shipped at the data + engine level in 04-10 (D-45..D-47) but the UI was omitted, which made the feature invisible. 04-18 closes the loop.
- Users can already SEE ∅ cells in the paradigm viewer (from 04-10's paradigm cell rendering), but could not create them until 04-18.
</specifics>

<canonical_refs>
## Canonical References

### Prior phase context (required reading)

- `.planning/phases/04-grammar-morphology-revised/04-CONTEXT.md` — Phase 04 master decisions
- `.planning/phases/04-grammar-morphology-revised/04-CONTEXT-GAPS.md` — specifically D-45 (override-rule-marker-uncovered order), D-46 (rules-win-on-tie), D-47 (∅ badge rendering)
- `.planning/phases/04-grammar-morphology-revised/04-RESEARCH.md` — 04-10 marker research + engine integration notes
- `.planning/phases/04-grammar-morphology-revised/04-17-CONTEXT.md` — Wave 7 sibling plan, especially D-87 (RuleEditorDialog UI unchanged for intrinsic); 04-18 is the ONLY wave-7 plan that changes RuleEditorDialog structure, so there's no conflict

### Source files touched by 04-18

- `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` — checkbox + conditional UI (D-100), save path branch (D-101)
- `lib/features/morphology/presentation/rules/rules_page.dart` — merged list rendering (D-102)
- `lib/features/grammar/data/marker_dao.dart` — already has insertMarker/updateMarker/deleteMarker; 04-18 adds the first real callers
- `lib/features/grammar/data/grammar_providers.dart:68` — `markersForPosProvider` (existing, reused)
- `lib/features/grammar/domain/paradigm_cell.dart` — `ParadigmUnmarked` variant, add optional `markerId` field (D-103)
- `lib/features/grammar/domain/paradigm_engine.dart:77` — marker matching logic, surface which marker produced the resolution
- `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` — cell-click handler for markers (D-103)

### Roadmap

- `.planning/ROADMAP.md:141` — Phase 04 plan list (04-18 is a NEW plan added during the 2026-04-11 discuss pass; roadmap will need an update)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`MarkerDao`** (`marker_dao.dart`) — full CRUD already exists. `insertMarker`, `updateMarker`, `deleteMarker` are all defined, just unused.
- **`markersForPosProvider`** (`grammar_providers.dart:68`) — already streams markers for a POS. Rules list merge (D-102) subscribes directly.
- **`MarkerDecl`** (`lib/features/grammar/domain/marker.dart`) — marker domain type. Has featureBindings like a rule. Ready for UI consumption.
- **Paradigm engine marker resolution** (`paradigm_engine.dart:52-78`) — already consumes markers and emits `ParadigmUnmarked` variants when matched.
- **`ParadigmClickMode.ruleEditor`** — the enum variant 04-13 added to route cell clicks to `RuleEditorDialog`. 04-18 reuses this without adding a new mode.
- **`FilterChip` bindings picker** in `RuleEditorDialog` — unchanged; both rule and marker modes use the same picker.

### Established Patterns

- Dialog modes via a boolean state field (already used for "editing existing vs creating new" in `rule_editor_dialog.dart`). `_leaveAsUnmarked` follows the same pattern.
- Pre-filled bindings via `RuleEditorDialog.preFilledBindings` constructor param (04-13 D-51) — reused for marker-editing via cell click.
- Reactive list provider merging — not currently done in the rules list, but `StreamProvider.value` composition is idiomatic Riverpod.

### Integration Points

- `RuleEditorDialog` is opened from: floating action button in `rules_page.dart:430`, cell click in `paradigm_table_widget.dart`, and (after 04-18) merged list row tap. All three entry points need to know whether to open in rule mode or marker mode.
- `markers` table is already in the Drift schema (from 04-08). No schema changes in 04-18.
- `ParadigmUnmarked` sealed variant change (adding `markerId`) cascades to any switch statement over `ParadigmCell` — verify callers in `paradigm_table_widget.dart`, `coverage_matrix_panel.dart`, and any tests.

### Known non-issues / free infrastructure

- All the data plumbing exists. 04-18 is almost entirely UI glue.
- Engine marker semantics are already correct and tested (from 04-10). 04-18 doesn't change them.
- Paradigm cell ∅ rendering exists (from 04-10 D-47). No change.
</code_context>

<deferred>
## Deferred Ideas

- **Bulk "mark as unmarked" across a range of cells.** User might want to declare a whole row as unmarked at once. Deferred until a user asks.
- **Per-cell overrides that mimic markers but on a specific lexeme.** The `ParadigmCellOverrides` table from 04-06 already handles this. Don't confuse the two: cell overrides are per-lexeme; markers are per-POS.
- **Marker / rule priority editor UI.** D-46 locked "rules win on tie" — no UI needed. If users want to override, backlog.
- **Importing markers from linguistic templates.** No bulk import in 04-18; users create one marker at a time.
</deferred>

---

*Plan: 04-18-markers-ui-unmarked-checkbox (parent phase: 04-grammar-morphology-revised)*
*Context gathered: 2026-04-11*
