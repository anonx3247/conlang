# Plan 04-15: Notation-Layer Unification — Context

**Gathered:** 2026-04-11
**Status:** Ready for research + planning
**Parent phase:** 04-grammar-morphology-revised
**Scope tag:** [GAP, Wave 6]

<domain>
## Phase Boundary

Plan 04-15 establishes a single, consistent notation contract across every morphology / phonology surface so that user-facing DSL input is always rom-when-enabled (phonemic-when-disabled), while the single source of truth in storage is always the phonemic form. The immediate motivating bug is G-68 (user wrote `+ci` expecting rom interpretation, engine read it as IPA literal and silently failed — same root cause as the G-66 `AblautOp from='V'` class), but the plan is an architectural cleanup, not a one-line fix.

**In scope:** Inflectional + derivational rule DSL input/storage/eval contract, romanization-mapping bijection enforcement, migration of existing `MorphologicalRules.source` values, full render-path audit of morphology + paradigm + inspiration + word-generator + sound-rule surfaces to confirm `rom → phonemic storage → rom display` flow, removal of the static Morphology Preview pane from both Inflections and Derivations pages.

**Out of scope (deferred to other plans):**
- Rules list UX changes (→ 04-16 (a))
- Dimension editor per-level rename (→ 04-16 (b))
- Add-new-level affordance (→ 04-16 (c))
- Non-existent-phoneme highlighting in rule editor / rules list — G-69 (→ 04-16 (d))
- Intrinsic-per-POS dimensions (→ 04-17)
- Schema-level removal of `Lexemes.romanization` column and `isIpaManuallyOverridden` flag — see Deferred Ideas below
</domain>

<decisions>
## Implementation Decisions

### D-70: Single storage format — phonemic IPA (overrides roadmap "retire romanize()")

- **Phonemic IPA is the only canonical stored form** for every representation in the project:
  - `Lexemes.ipa` (already)
  - `MorphologicalRules.source` literal strings (affixes, conditions, ablaut from/to, remove-suffix, infix, reduplication templates) — NEW
  - Future phonology / sound-rule pattern sources — already phonemic
- Rom is always **derived at render time** via `romanizeProvider` (`lib/features/phonology/data/romanization_providers.dart:90`).
- Phonetic (surface) is always derived at render time via the existing sound-change / rewrite pipeline applied to the phonemic form.
- **`romanize()` is NOT retired.** The roadmap entry for 04-15 called for retiring it; the user's clarification supersedes that — `romanize()` stays as the derive-at-display function because rom can change and phonemic must remain stable.
- **`deromanize()` is the single rom→phonemic conversion boundary**, called at input/save time (editor → DAO) for any surface where the user types literal phonological characters.

### D-71: Three-layer notation model

- **Input layer (rom when enabled, phonemic when disabled):** What the user types. For rule DSL literals, affixes, and lexeme forms. `deromanize()` runs at save time to produce the stored phonemic form.
- **Storage layer (phonemic IPA, always):** The single source of truth. Rules, lexemes, class members, phonotactic patterns.
- **Display layer (derived on demand):**
  - Rom via `romanize(phonemic)` for all rom-enabled contexts.
  - Phonetic via the sound-change rewrite pipeline applied to the phonemic form. Phonetic output is surface IPA (allophones, diacritics) — NOT romanized, never passed through `romanize()`.

### D-72: Romanization-mapping bijection enforcement (Validator + save-time block)

- `RomanizationMapping` rows must define a **bijection** between the active phoneme inventory and the Latin alphabet subset used for rom input.
- A new validator runs at mapping save time and at project open. Violations:
  - Two phonemes mapping to the same rom string.
  - Two rom strings deromanizing to the same phoneme (first-mapping-wins ambiguity).
  - A rom string that doesn't round-trip: `romanize(deromanize(x)) != x` for any `x` in the active mapping domain.
- Save-time: block the offending row with an inline error; do not persist.
- Open-time (legacy project with pre-existing non-bijective mappings): show a one-time banner on the romanization settings page listing the conflicting rows, block editing of rule DSL until resolved.
- Bijection is a **precondition** for D-70, D-71, D-73, and D-75 — without it, rule DSL round-trip is silently broken.

### D-73: Rule DSL input/storage contract

- `rule_editor_dialog.dart`:
  - Every literal-text input (affix fields, ablaut from/to, remove-suffix, condition patterns) reads `romanizationEnabledProvider`.
  - When rom is enabled: field accepts rom characters, field label hint shows "rom"; on save, `deromanize(input)` runs and stores the phonemic form in `MorphologicalRules.source`.
  - When rom is disabled: field accepts phonemic IPA directly; saved as-is.
  - When opening an existing rule for edit: load phonemic source, apply `romanize()` for display if rom enabled, else show raw phonemic.
- Class refs (`V`, `C`, `F`, `[natural-class-name]`) pass through both `romanize()` and `deromanize()` untouched — they're literal tokens matched structurally, not phonological characters. Document this invariant in the DSL parser (`morphology_dsl.dart`).
- The engine (`morphology_engine.dart`) requires NO changes — it already operates on phonemic strings; D-73 just guarantees that the stored DSL source is phonemic so the engine's existing contract is finally consistent with the editor's.

### D-74: Migration strategy — round-trip classify per rule

- One-shot migration on 04-15 rollout, gated by the bijection validator passing (D-72).
- For each existing `MorphologicalRules.source` value `S`:
  1. Compute `phonemic = deromanize(S)`.
  2. Compute `roundTrip = romanize(phonemic)`.
  3. **If `roundTrip == S`:** treat `S` as rom input, rewrite the source field to `phonemic`.
  4. **If `roundTrip != S`:** assume `S` was already phonemic IPA literal, leave unchanged.
- Migration runs inside a Drift `onUpgrade` step (schema bump from v9 → v10). The `onUpgrade` acquires the active romanization mappings and performs the rewrite per row.
- Migration log is written to a new `migration_log` key in `project_settings` listing per-rule outcome (rewritten vs left alone) for post-hoc debugging.
- **Wave 3a hot-fix rules (G-66, G-67, G-68) were authored with IPA awareness** — most of them will round-trip classify as "leave alone". The user's G-68 `+ci` case will classify as "rewrite". This is the intended asymmetry.

### D-75: Render-path audit — storage-is-phonemic contract

Every render path that currently calls `romanize()` must be verified to call it on a **stored phonemic value**, never on a value that was itself the output of an earlier `romanize()` call (no double-romanization), and never on a value that came from user input without going through `deromanize()` first.

Surfaces audited in 04-15:
- `paradigm_table_widget.dart:489,564` — cells already render `romanize(form)` where `form` is the phonemic output of the morphology engine. Verify, add regression test.
- `preview_panel.dart:350,371,421` — live rule preview in the editor dialog. Must render `romanize(engine.applyRule(...))`. Verify.
- `morphology_preview_panel.dart` — **SLATED FOR DELETION** (see D-77). Audit N/A.
- `inspiration_panel.dart:55,214` — already generates phonemic words via `WordGenerator` and romanizes for display. Verify no IPA→rom→IPA round-trip.
- `word_generator_panel.dart:36,190` — same pattern. Verify.
- `inventory_page.dart:626` — phonemes are phonemic-native; rom display is pure derivation. Confirm.
- `word_list_panel.dart:376,569` and `word_detail_panel.dart:76,88,103` — lexicon input uses `deromanize(romanization)` correctly today. Document the `isIpaManuallyOverridden` flag as the one legitimate exception (user manually typed IPA that diverges from the rom→phonemic derivation).
- `derivation_tree_widget.dart:48` — already phonemic-stored, romanize on display.

Audit deliverable: a per-surface table in `04-15-VERIFICATION.md` marking each site as `confirmed` / `patched` / `deleted`.

### D-76: Sound-change / rewrite rules — phonemic input, phonetic output (asymmetry)

- Sound-change rules (the rules in the Sound Rules page under phonology, `sound_rules_page.dart`) map **phoneme → allophones**.
  - **Input side** of the rule (the match pattern, e.g. `s -> z / V_V` left-hand context and target) is phonemic. Rom input contract from D-73 applies to this side: when rom is enabled, editor accepts rom and stores phonemic.
  - **Output side** (the replacement, e.g. the `z` in `s -> z`) is **phonetic** — a surface allophone with potentially diacritics or characters not in the phoneme inventory. This side is **never** subject to rom↔phonemic conversion. The editor accepts and stores phonetic IPA literal on the output side, independent of the rom toggle.
- Document this asymmetry in the rewrite rule editor UI with distinct field labels ("Pattern (phonemic)" vs "Replacement (phonetic)").
- The rewrite pipeline in `paradigm_engine.dart:161` applies sound-change rules to the final phonemic morphology output, producing a phonetic form for display; this flow is unchanged.

### D-77: Delete static "Morphology Preview" pane from Inflections + Derivations pages

- Remove `MorphologyPreviewPanel` widget + the vertical divider from `rules_page.dart:417-427`. The inner rules list becomes full-width in the `InflectionsPage` bottom pane and the `DerivationsPage` body.
- Delete `lib/features/morphology/presentation/rules/morphology_preview_panel.dart` (unused elsewhere after this plan).
- **Keep** `lib/features/morphology/presentation/rules/preview_panel.dart` — this is the live preview panel inside `rule_editor_dialog.dart:1098`, which is the only preview surface the user wants retained.
- Any tests referencing `MorphologyPreviewPanel` are updated or deleted.
- User context: "I said earlier and it wasn't done: remove the 'Morphology Preview' from both the inflectional rules and derivational rules. Only the live preview during the popup is necessary."

### Claude's Discretion

- Exact copy and label text for the bijection validator's error messages.
- Exact per-field hint text in the rule editor ("rom" vs "IPA" vs "phonemic").
- Whether the bijection banner on project open is dismissible, and whether it blocks navigation or just rule editing.
- Structure of the `migration_log` JSON payload stored in `project_settings`.
- Whether to fold an integration test for the round-trip classify migration into the existing migration test suite or create a new test file.
- UI placement of the asymmetric "Pattern (phonemic) / Replacement (phonetic)" labels in the sound rule editor — can defer to the phonology UI's existing conventions.
</decisions>

<specifics>
## Specific Ideas

- "The single source of truth is the phonemic representation… because if romanization is the input format, then the phonemic is what's stored."
- "There needs to be a one-to-one mapping with romanization" — the user explicitly elevated the bijection from implicit assumption to enforced precondition.
- User previously chose A+C for G-68 in the HUMAN-UAT log (workaround in the running app, defer architectural fix to 04-15). 04-15 delivers the fix and obsoletes the workaround.
- "Phonotactic rules aren't the same here — they map from a phoneme to its allophones" → the user conflated "phonotactic" with sound-change/rewrite rules. D-76 captures the asymmetry the user actually meant: input phonemic, output phonetic.
- "Only the live preview during the popup is necessary" — the static Morphology Preview was dead weight in the 3-pane Inflections layout.
</specifics>

<canonical_refs>
## Canonical References

### Prior phase context (required reading)

- `.planning/phases/04-grammar-morphology-revised/04-CONTEXT.md` — Phase 04 master context, D-01..D-42 decisions, especially D-28/D-29 on paradigm cell rom+IPA stacked display
- `.planning/phases/04-grammar-morphology-revised/04-CONTEXT-GAPS.md` — Wave 1-5 gap-closure context, D-43..D-65 decisions
- `.planning/phases/04-grammar-morphology-revised/04-HUMAN-UAT.md` items 19-21 (G-66, G-67, G-68) — bug reports that motivate 04-15
- `.planning/phases/04-grammar-morphology-revised/04-RESEARCH.md` — Phase 04 research, especially sections on romanization + rewrite pipeline
- `.planning/phases/04-grammar-morphology-revised/04-VERIFICATION.md` v2 — prior state of the codebase before 04-15

### Source files touched by 04-15

#### Storage + conversion (single rom↔phonemic boundary)
- `lib/features/phonology/data/romanization_providers.dart:90` — `romanizeProvider` (kept)
- `lib/features/phonology/data/romanization_providers.dart:131` — `deromanizeProvider` (kept, becomes the save-time conversion point)
- `lib/features/phonology/data/romanization_providers.dart:175` — `isIpaManuallyOverridden` (kept; document as the legitimate exception)
- `lib/features/phonology/data/romanization_dao.dart` — may need a new bijection validator method

#### Rule DSL input + storage + migration
- `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` — input fields, save-path deromanize
- `lib/features/morphology/domain/morphology_dsl.dart` — parser unchanged; add a class-ref invariant doc comment
- `lib/features/morphology/data/morphology_dao.dart` — save path; no schema change, but optional source-column doc
- `lib/db/app_database.dart` / drift schema — v9 → v10 migration for the round-trip classify pass
- `lib/features/morphology/domain/morphology_engine.dart` — verify no changes needed (engine is already phonemic-native)

#### Render-path audit surfaces
- `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart:489,564`
- `lib/features/grammar/domain/paradigm_engine.dart:129,161` (rewrite pipeline application)
- `lib/features/morphology/presentation/rules/preview_panel.dart:350,371,421`
- `lib/features/lexicon/presentation/dictionary/inspiration_panel.dart:55,214`
- `lib/features/phonology/presentation/sound_rules/word_generator_panel.dart:36,190`
- `lib/features/phonology/presentation/inventory/inventory_page.dart:626`
- `lib/features/lexicon/presentation/dictionary/word_list_panel.dart:376,569`
- `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart:76,88,103`
- `lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart:48`

#### Deletion candidates (D-77)
- `lib/features/morphology/presentation/rules/morphology_preview_panel.dart` — delete file
- `lib/features/morphology/presentation/rules/rules_page.dart:417-427` — remove right pane + divider

#### Sound rule editor (D-76 asymmetry)
- `lib/features/phonology/presentation/sound_rules/sound_rules_page.dart` — label + field hint updates

### Roadmap

- `.planning/ROADMAP.md` — phase 4 plan list, 04-15 line at row 158 (note: the "retire romanize()" language there is superseded by D-70)

### Requirements

- `.planning/REQUIREMENTS.md` — GRAM requirements that cover inflectional morphology + romanization contract (referenced from 04-CONTEXT.md canonical refs)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`deromanizeProvider`** (`romanization_providers.dart:131`) — already implements longest-match left-to-right rom→phonemic conversion. Becomes the single save-time conversion function for rule DSL input. No algorithmic change needed.
- **`romanizeProvider`** (`romanization_providers.dart:90`) — already implements longest-IPA-first phonemic→rom conversion. Becomes the single render-time derivation function. No algorithmic change needed.
- **`parseMorphDsl`** (`morphology_dsl.dart:419`) — already parses DSL into ops that are string-opaque (it doesn't care if the strings are rom or phonemic). After D-73, DSL sources fed to the parser will always be phonemic, so the parser's existing behavior is finally consistent with the engine's.
- **`MorphologyEngine`** (`morphology_engine.dart`) — already phonemic-native. No changes needed beyond possibly tightening asserts or doc comments.
- **Class-ref resolution in the binding translator** (`binding_translator.dart`) — already notation-agnostic; tokens like `V`, `C`, `[nasal]` are resolved structurally against the inventory. Unaffected by D-70..D-75.

### Established Patterns

- **Lexeme input/storage pattern** (`word_detail_panel.dart:76-107`) — user types rom, `deromanize(rom)` produces IPA, both are stored but IPA is canonical; on display, `romanize(ipa)` is used unless `isIpaManuallyOverridden` is true. 04-15 extends this pattern to `MorphologicalRules.source`, minus the manual override escape hatch (rules don't need it — if bijection holds, deromanize is deterministic).
- **Drift `onUpgrade` migration pattern** (established by plan 04-08 v8→v9 migration) — 04-15's v9→v10 migration follows the same structure with a beforeOpen safety net.
- **`project_settings` key-value store** — used today for `romanization_enabled` and migration banner flags; 04-15's `migration_log` entry piggybacks on the same table.

### Integration Points

- Rule editor dialog is the primary user-visible change surface; everything else is internal plumbing + one pane deletion.
- The bijection validator plugs into the romanization settings UI (phonology → romanization subpage), which today allows unrestricted mapping edits.
- The v10 migration is coordinated with existing v8/v9 migrations in `app_database.dart` `onUpgrade`.

### Known non-issues / free infrastructure

- Engine layer is unchanged — it's already phonemic-native, so all morphology tests keep working.
- Class refs and natural classes need no changes — they're already structurally resolved.
- Lexemes.ipa + Lexemes.romanization dual-column model is untouched in 04-15 (see Deferred Ideas for the potential simplification).
</code_context>

<deferred>
## Deferred Ideas

- **Schema simplification: drop `Lexemes.romanization` column and `isIpaManuallyOverridden` flag.** With D-72 bijection enforcement, the rom form of any lexeme is determinable from its phonemic form, so the stored `romanization` column is redundant except as a cache. The `isIpaManuallyOverridden` flag is only meaningful if the user can type divergent rom+IPA — under D-70..D-72 they cannot. Deferring because (a) schema change + backfill is a separate migration, (b) the existing column is harmless as a cache, (c) user hasn't requested this simplification. Capture as a backlog idea to revisit after 04-15 stabilizes.

- **"Cached rom" on paradigm cells.** The roadmap entry mused about forward-projecting rom to avoid the round-trip. D-70's decision to keep `romanize()` as the derive-at-display function makes this unnecessary — cells render `romanize(phonemic)` cheaply on demand. Capture as a perf optimization backlog item only if profiling later shows it matters.

- **Non-existent phoneme highlighting (G-69).** Covered by 04-16 (d); the infrastructure 04-15 ships (bijection validator + stored-phonemic DSL source) makes G-69's detection logic trivial, but the UX work is explicitly 04-16.

- **Retire `romanize()` entirely.** Explicitly rejected by user during discussion (2026-04-11). Captured for posterity.

- **Auto-migrate sound-change rules with rom input on pattern side.** D-76 notes the asymmetry, but the current sound rules schema may not distinguish pattern vs replacement with enough granularity to safely auto-migrate. If the existing sound rules in the user's dogfood project are phonemic-native already, no migration is needed; otherwise a mini migration follows the same round-trip classify pattern. Flag for research in 04-15 — if research finds existing sound rule sources are all phonemic, drop this; if not, add a second migration step.
</deferred>

---

*Plan: 04-15-notation-layer-unification (parent phase: 04-grammar-morphology-revised)*
*Context gathered: 2026-04-11*
