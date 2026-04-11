# Phase 04: Grammar & Morphology Revised — Gap Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `04-CONTEXT-GAPS.md` — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 04-grammar-morphology-revised (gaps)
**Areas discussed:** Unmarked cells (G-03), Inflections tab restructure (G-06/G-07/G-10), Derivation overhaul (G-13–G-19), Multi-POS inflectional rules (G-05)
**Gaps in source:** 19 total (see `04-HUMAN-UAT.md`)

---

## Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Unmarked cells (G-03) | Semantic design for "no form change" declarations | ✓ |
| Inflections tab restructure (G-06, G-07, G-10) | 4→3 sub-tabs, merged viewer+rules, cell-click flow change | ✓ |
| Derivation overhaul (G-13–G-19) | Seven coupled derivation changes | ✓ |
| Multi-POS inflectional rules (G-05) | Schema for multi-POS rule attachment | ✓ |

**User's choice:** All four areas selected for discussion.

---

## Unmarked Cells (G-03)

### Q1: Declaration granularity

| Option | Description | Selected |
|--------|-------------|----------|
| Per cell only | Click one cell, toggle unmarked | |
| **Per binding-set (recommended)** | Declare `{feature_set}` → unmarked, cascades | ✓ |
| Both levels | Binding-set + per-cell overrides | |

**User's choice:** Per binding-set (recommended).
**Notes:** Matches typological patterns (masculine-singular zero-marker slices). Engine evaluates markers with the D-10 feature consumption algorithm.

### Q2: Storage

| Option | Description | Selected |
|--------|-------------|----------|
| **New `Markers` table (recommended)** | Parallel to MorphologicalRules, no form output | ✓ |
| Sentinel rule in MorphologicalRules | Identity DSL rule | |
| Tri-state on ParadigmCellOverrides | State enum on override table | |

**User's choice:** New `Markers` table (recommended).
**Notes:** Clean separation from MorphologicalRules; reuses `feature_bindings` JSON format.

### Q3: Marker vs rule conflict

| Option | Description | Selected |
|--------|-------------|----------|
| Rule wins silently | Rule always overrides marker | |
| **Specificity ranking (recommended)** | D-10 specificity; rules win on exact ties | ✓ |
| Ambiguous-tie error | Red warning on any marker+rule overlap | |

**User's choice:** Specificity ranking (recommended).
**Notes:** Rules carry explicit forms, markers assert absence — tiebreaker documented as "rules win on exact ties."

### Q4: Render

| Option | Description | Selected |
|--------|-------------|----------|
| **Root form in muted gray (recommended)** | Bare root + `∅` badge | ✓ |
| `—` em-dash with distinct tooltip | Same as uncovered, different tooltip | |
| `∅` glyph only | No root shown | |

**User's choice:** Root form in muted gray (recommended).
**Notes:** Shows the actual form at the unmarked slice; distinct from both derived cells (D-29) and uncovered em-dash cells (D-14).

---

## Inflections Tab Restructure (G-06, G-07, G-10)

### Q1: Internal layout

| Option | Description | Selected |
|--------|-------------|----------|
| **Stacked: paradigm top, rules bottom (recommended)** | Top paradigm, bottom rules list filtered to POS | ✓ |
| Split view: paradigm left, rules right | Side-by-side with divider | |
| Single view with toggle | One pane, tab between views | |

**User's choice:** Stacked (recommended).
**Notes:** Live paradigm-updates-as-you-edit-rules is the main value of merging.

### Q2: Cell click behavior

| Option | Description | Selected |
|--------|-------------|----------|
| **Always opens new-rule dialog (recommended)** | Feature bindings pre-filled from axis position | ✓ |
| Context menu on click | Action menu: rule / mark / override / open | |
| Different on empty vs filled | Empty=new rule, filled=edit rule | |

**User's choice:** Always opens new-rule dialog (recommended).
**Notes:** CellOverrideDialog (D-28) deleted from Grammar/Inflections context. Per-word overrides move to Lexicon word detail.

### Q3: Per-word override location

| Option | Description | Selected |
|--------|-------------|----------|
| **Embedded in ParadigmTableWidget (recommended)** | Same widget, dual click-mode based on host | ✓ |
| Separate "Exceptions" section | Collapsible list in word detail | |
| Right-click only in Lexicon embed | Hidden affordance | |

**User's choice:** Embedded in ParadigmTableWidget (recommended).
**Notes:** `ParadigmTableWidget` gains `clickMode` constructor param — same widget, two host behaviors.

### Q4: Rules scope in bottom pane

| Option | Description | Selected |
|--------|-------------|----------|
| **Scoped to current POS + multi-POS rules (recommended)** | Only relevant rules, grouped | ✓ |
| All inflectional rules, filterable | Filter chips | |
| Just rules that render in current paradigm | Tightest scope | |

**User's choice:** Scoped to current POS + multi-POS rules (recommended).

### Q5: Old routes

| Option | Description | Selected |
|--------|-------------|----------|
| Redirect both to `/grammar/inflections` (recommended) | Seamless migration | |
| Redirect + one-time banner | Explainer on first v9 open | |
| **Hard 404** | Clean break | ✓ |

**User's choice:** Hard 404 (non-recommended — user override).
**Notes:** Clean break preferred over smooth migration for internal routing. Worth noting as a project preference.

---

## Derivation Overhaul (G-13–G-19)

### Q1: Derived form storage model

| Option | Description | Selected |
|--------|-------------|----------|
| Full Lexeme rows (recommended) | Every derivation → real row | |
| **Computed strings + optional promotion** | Hybrid, promote when meaning assigned | ✓ |
| Computed strings + side table | `DerivedWordMeanings` for meanings only | |

**User's choice:** Computed strings + optional promotion (with critical rule-link constraint).
**Notes:** User's full answer: *"basically lets say 2. in the sense that i only want the full lexeme once a meaning is assigned to it, if its derived without a meaning then theres no point. Once important thing however is it might be useful to still keep it as a computed string once as a lexeme, since lets say i have a suffix -in for an agent of a verb so kama = to run, and kamain = runner, and i do this for say 100 verbs, but later i decide actually i would prefer -in to be -il instead, i don't want to have to change 100 entries."* This establishes the rule-link invariant: promoted derived Lexemes keep their form computed from rule+parent so rule edits propagate automatically.

### Q2: Link model after promotion

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — form stays computed forever (recommended) | No detach; rule edits always propagate | |
| Yes, but user can 'detach' to lock the form | Explicit detach action | |
| **Computed by default, stored if edited** | Implicit detach on rom/ipa edit | ✓ |

**User's choice:** Computed by default, stored if edited.
**Notes:** User preferred the implicit magic over explicit detach UI. Requires clear UI warning on rom/ipa edit ("this will unlink").

### Q3: Promotion trigger

| Option | Description | Selected |
|--------|-------------|----------|
| **Assigning a meaning promotes automatically (recommended)** | Typing meaning = create Lexeme row | ✓ |
| Explicit 'Promote' button | Button opens dialog | |

**User's choice:** Assigning a meaning promotes automatically (recommended).

### Q4: Root-only dictionary hide (G-16)

| Option | Description | Selected |
|--------|-------------|----------|
| Hidden from dictionary list only (recommended) | Still searchable, still in Swadesh | |
| Hidden everywhere except derivation trees | Fully hidden | |
| Hidden + greyed in search results | Middle ground | |

**User's choice:** "not hidden, just grayed out in the lexeme list" (free-text override).
**Notes:** User preferred visual demotion over hiding. Lexeme is fully present everywhere but rendered muted in the Dictionary sidebar list. Stored via `Lexemes.root_only_via_derivations` boolean (D-63).

### Q5: Auto-apply toggle semantics (G-18)

| Option | Description | Selected |
|--------|-------------|----------|
| **Rule is dormant — only fires on click (recommended)** | Suggestion chips for false | ✓ |
| Rule fires but forms are 'dim' until confirmed | Greyed in tree | |
| Rule fires into a separate 'suggestions' section | Two sections per word | |

**User's choice:** Dormant + suggestion chips, **plus an addition**: *"but if autoApply is enabled, then we'll give these new derived lexemes the automatic meaning of: root meaning (Rule Name) e.g. for my previous example kama -> kamain becomes 'to run (Actor)'"*
**Notes:** This added a significant feature: `auto_apply=true` auto-promotes derived forms to full Lexemes with a template-generated meaning `"{parent.meaning} ({rule.name})"`. Captured in D-59.

### Q6: Manual parent storage (G-17)

| Option | Description | Selected |
|--------|-------------|----------|
| **`LexemeParents` junction table (recommended)** | Multi-parent, relationship labels | ✓ |
| `parentLexemeIds` JSON column | Single column, harder queries | |
| Reuse derivation-rule link | Rule-only etymologies | |

**User's choice:** `LexemeParents` junction table (recommended).

### Q7: POS filter on computedDerivedFormsProvider (G-13)

| Option | Description | Selected |
|--------|-------------|----------|
| **Strict: input POS must match exactly (recommended)** | No cross-POS leakage | ✓ |
| Strict + 'any POS' sentinel | Escape hatch for universal rules | |

**User's choice:** Strict: input POS must match exactly (recommended).

---

## Multi-POS Inflectional Rules (G-05, G-09)

### Q1: Storage

| Option | Description | Selected |
|--------|-------------|----------|
| **Junction table `InflectionalRulePOS` (recommended)** | Normalized, simple joins | ✓ |
| Extend `feature_bindings` JSON | Single source, JSON scans | |
| Revive `posIds` CSV column | Uncomfortable, duplicates intent | |

**User's choice:** Junction table (recommended).
**Notes:** v9 migration: create table, backfill from existing `input_pos_id`.

### Q2: List grouping (G-09)

| Option | Description | Selected |
|--------|-------------|----------|
| **Own 'Noun + Adjective' group (recommended)** | Each POS-set forms a group | ✓ |
| Appears in every group it belongs to | Duplicated visual entries | |
| Separate 'Multi-POS' section | Flat section after single-POS groups | |

**User's choice:** Own POS-set group (recommended).

---

## Claude's Discretion

The following were explicitly left to planner/implementer judgment:
- Badge design and warning copy for the "linked to rule" UX on promoted derived Lexemes (D-58)
- Whether Markers have their own editor pane or are edited via the paradigm viewer
- Suggestion-dismissed tracking mechanism for D-60 (new column vs derived-state inference)
- Exact copy and layout for the root-only-via-derivations toggle (D-63, D-65)
- Rules-list POS-set group header format (e.g., `Noun + Adjective` vs `N+Adj`)
- Whether `MorphologicalRules.input_pos_id` is nulled post-backfill or kept as a legacy convenience

## Deferred Ideas

- Derivational rules with multiple input POS (only inflectional rules get multi-POS in this gap scope)
- Full etymology tree visualization UI (storage only in D-62, visual UI deferred)
- Controlled vocabulary for `LexemeParents.relationship` (free-text in v1)
- Cross-project derivational rule template catalog
- Thesaurus / Swadesh UX for promoted derived Lexemes
