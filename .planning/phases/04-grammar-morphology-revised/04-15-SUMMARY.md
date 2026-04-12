---
phase: 04-grammar-morphology-revised
plan: 15
subsystem: morphology
tags: [romanization, notation, dsl, drift-migration, phonology, bijection]

requires:
  - phase: 04-08
    provides: v9 Drift schema + v8→v9 migration pattern (customSelect + customStatement inside onUpgrade)
  - phase: 04-11
    provides: inflectional_rule_pos junction table (consulted by rule editor, not touched by 04-15)
provides:
  - D-70..D-78 notation unification contract across morphology + phonology surfaces
  - Pure Dart notation_helpers library (dotAwareDeromanize, smartRomanize, phonemicSegmentation, isDotAwareBijection) shared between runtime providers and the v10 migration
  - D-72 bijection validator + settings UI gate + rule-editor gate
  - D-73 rule editor rom/phonemic input contract for affix + ablaut literals
  - D-74 v9→v10 Drift migration with DSL-parse-aware classify pass over MorphologicalRules.source + migration_log in project_settings
  - D-75 per-surface render-path audit (VERIFICATION.md)
  - D-76 asymmetric sound rule editor labels (Pattern phonemic / Replacement phonetic)
  - D-77 static Morphology Preview pane deletion; live preview preserved
  - D-78 dot-separator disambiguator for ambiguous rom digraph mappings
  - Classify helper library (migration_notation_classify.dart) reusable by any future notation-aware data migration
affects: [04-16 (consumes bijection-enforced store for G-69 highlighting), 04-17 (appends to the SAME v10 onUpgrade block via TODO(04-17) marker)]

tech-stack:
  added:
    - Pure Dart notation helper library (no new package deps)
  patterns:
    - DSL-parse-aware data migration (parse → rewrite literals → serialize) vs naive string-level substitution
    - Shared pure helper imported by both Riverpod providers and Drift onUpgrade callbacks to guarantee behavioral parity
    - Cross-plan schema coordination marker (TODO(04-17) comment inside the v10 onUpgrade block)

key-files:
  created:
    - lib/features/phonology/domain/notation_helpers.dart (pure Dart — dotAwareDeromanize, smartRomanize, phonemicSegmentation, isDotAwareBijection, NotationMapping record)
    - lib/features/phonology/data/romanization_bijection.dart (BijectionViolation + BijectionViolationKind)
    - lib/db/migration_notation_classify.dart (DSL-parse-aware classify helper — classifyAndRewriteRuleSource, classifySingleLiteral, ClassifyOutcome)
    - test/unit/phonology/notation_helpers_test.dart (18 cases)
    - test/unit/phonology/romanization_bijection_test.dart (6 cases)
    - test/unit/morphology/rule_dsl_roundtrip_test.dart (21 cases including Fixture 4 ablaut flag regression lock)
    - test/widget/morphology/rule_editor_rom_roundtrip_test.dart (10 cases)
    - test/integration/migration_v9_to_v10_test.dart (11 cases)
    - .planning/phases/04-grammar-morphology-revised/04-15-VERIFICATION.md (D-75 audit table)
  modified:
    - lib/features/phonology/data/romanization_providers.dart (romanizeProvider + deromanizeProvider rewritten as thin wrappers over notation_helpers, bijectionStatusProvider added)
    - lib/features/phonology/data/romanization_dao.dart (validateRomanizationBijection method)
    - lib/features/phonology/presentation/inventory/romanization_section.dart (save-time gate + non-dismissible banner on violations)
    - lib/features/morphology/presentation/rules/rule_editor_dialog.dart (D-73 rom/phonemic contract on affix + ablaut fields + D-78 dot boundary helper text)
    - lib/features/morphology/domain/morphology_dsl.dart (class-ref invariant doc comment + D-78 dot note)
    - lib/features/phonology/presentation/sound_rules/rewrite_rule_editor.dart (D-76 asymmetric labels)
    - lib/db/app_database.dart (schemaVersion 10 + v10 onUpgrade block calling classifyAndRewriteRuleSource + TODO(04-17) marker + migration_log write)
    - lib/db/app_database.g.dart (regenerated)
    - lib/features/morphology/presentation/rules/rules_page.dart (D-77 static preview panel removed, rules list is full-width)
    - test/integration/migration_v8_to_v9_test.dart (schemaVersion assertions 9 → 10, chain path works)

key-decisions:
  - "D-70: Phonemic IPA is the single canonical stored form; romanize() is NOT retired (stays as derive-at-display)"
  - "D-71: Three-layer notation model (input rom-when-enabled, storage phonemic, display derived)"
  - "D-72: Bijection validator enforced at save-time and project-open; rule editor gates on bijection status"
  - "D-73: Rule editor wraps ONLY single-token literal fields (affix, ablaut from/to, remove-suffix); template/condition partial-string wrapping is deferred per WARN-1 and locked by Test 6 of rule_editor_rom_roundtrip_test.dart"
  - "D-74: v9→v10 migration uses a DSL-parse-aware classify helper, NOT raw string-level substitution. This was rediscovered the hard way: a naive earlier attempt corrupted ablaut flag segments (`e1` → `ε1`, silently flipping direction fromEnd → fromStart). The fix parses each rule via parseMorphDsl, walks the op tree, rewrites only phonological literals, serializes back via serializeMorphRule, and tracks literals_changed explicitly to avoid false-positive rewrites from parse/serialize normalization."
  - "D-74 schema coordination: 04-15 owns the v10 bump; plan 04-17 appends its intrinsic-dimension schema additions into the SAME v10 block via a TODO(04-17) insertion marker. 04-17 must NOT bump to v11."
  - "D-75: Per-surface render-path audit confirmed 16 sites already operate on stored phonemic; 0 patches needed; 1 site deleted per D-77. The isIpaManuallyOverridden helper is the documented exception for lexicon input/storage"
  - "D-76: Sound rule editor uses asymmetric labels — Pattern (phonemic) / Replacement (phonetic). The replacement side accepts surface IPA and is NEVER subject to rom↔phonemic conversion regardless of the romanization toggle"
  - "D-77: Static MorphologyPreviewPanel deleted from Inflections + Derivations pages. Live preview (preview_panel.dart inside rule_editor_dialog.dart) is preserved — the only preview surface the user wants"
  - "D-78: `.` is a first-class rom-side glyph separator. dotAwareDeromanize consumes it; smartRomanize inserts it at ambiguous boundaries; isDotAwareBijection relaxes the D-72 round-trip check to accept any set recoverable via dot insertion. The canonical case `{t→t, h→h, θ→th}` passes under D-78 but would have been rejected under strict bijection."
  - "Task 3 architectural lesson: string-level approaches to DSL-aware data migrations are silently unsafe. Always parse, transform the AST, and serialize. Locked by Fixture 4 in rule_dsl_roundtrip_test.dart and the ablaut regression tests in migration_v9_to_v10_test.dart."

patterns-established:
  - "Pure Dart domain helper reused across runtime + migration: notation_helpers.dart is imported by both romanization_providers.dart (runtime Riverpod) and app_database.dart (Drift onUpgrade). This pattern should be followed by any future migration that needs to call runtime conversion logic."
  - "DSL-parse-aware classify for data migrations: when a migration must rewrite fields inside a serialized DSL string, parse via the DSL's own parser, walk the AST, rewrite only the specific fields, and serialize back. Track whether any field actually changed so parse/serialize normalization doesn't falsely report a rewrite."
  - "Cross-plan schema coordination via TODO markers: the v10 onUpgrade block contains an explicit `TODO(04-17)` insertion point so the next plan can append schema additions without bumping to v11. This avoids a v10→v11 churn for data-only vs schema-only changes."
  - "Regression lock test-first: the ablaut flag preservation test (Fixture 4) is the test that WOULD HAVE caught the dropped first attempt. Writing the failure mode into a permanent test makes recurrence structurally impossible."

requirements-completed: [G-66, G-67, G-68, GRAM-06, GRAM-07, MORPH-01, PHON-07]

duration: ~2.5h (including the Task 3 redesign after the human-verify dry-run caught the ablaut regression)
completed: 2026-04-11
---

# Plan 04-15: Notation-Layer Unification Summary

**Phonemic IPA is now the single canonical storage format for every morphological rule literal; romanization is a derive-at-display function with bijection enforcement and a `.` glyph separator escape hatch; the v10 Drift migration performs a DSL-parse-aware round-trip classify that preserves ablaut flag segments even when they collide with romanization mappings.**

## Performance

- **Tasks:** 7 (including a Task 3 redesign after the dogfood dry-run caught a regression)
- **Commits:** 8 feat/docs commits on the Wave 6 worktree branch
- **Tests added:** 68 (18 notation_helpers + 6 bijection + 21 classify + 10 widget + 11 integration + 2 v8→v9 schemaVersion updates)
- **Full test-suite result:** 563 pass / 1 pre-existing unrelated failure (phonotactic_dsl_smoke_test — verified via `git stash` before this wave started)
- **Cross-checks:** 21/21 green

## Accomplishments

### D-70..D-78 decisions shipped

1. **D-70 — Phonemic IPA canonical storage.** `romanize()` is kept as the derive-at-display function; the `retire romanize()` roadmap language is superseded and documented.
2. **D-71 — Three-layer notation model.** Input = rom-when-enabled, storage = phonemic always, display = derived. Documented in rule editor and DSL parser.
3. **D-72 — Bijection validator.** `validateRomanizationBijection()` on `RomanizationDao` returns structured violations (`duplicatePhonemeTarget`, `duplicateRomTarget`, `nonRoundTrip`). Save-time inline block; project-open non-dismissible banner. Rule editor reads `bijectionStatusProvider` and shows a gate message when violations are present.
4. **D-73 — Rule editor rom/phonemic input contract.** `rule_editor_dialog.dart` reads `romanizationEnabledProvider` and wraps every single-token literal field (affix, ablaut from/to, remove-suffix) via `deromanize` on save and `romanize` on load. Class refs (V, C, F, `[name]`) flow through untouched. WARN-1 partial-scope deferral for template + condition literals is locked by a test.
5. **D-74 — v9→v10 migration with DSL-parse-aware classify.** The v10 onUpgrade block calls `classifyAndRewriteRuleSource(source, mappings)` which parses the rule, walks the op tree, rewrites only phonological literals, and serializes back. The schema coordination marker `TODO(04-17)` is embedded inside the `if (from < 10)` block so 04-17 can append its schema additions there without bumping to v11.
6. **D-75 — Render-path audit.** All 16 romanize call sites across paradigm_table_widget, preview_panel, inspiration_panel, word_generator_panel, inventory_page, word_list_panel, word_detail_panel, and derivation_tree_widget are confirmed to operate on stored phonemic values. No patches needed. One deletion (morphology_preview_panel.dart, D-77).
7. **D-76 — Sound rule editor asymmetric labels.** `rewrite_rule_editor.dart` now shows `Pattern (phonemic)` and `Replacement (phonetic)`. Inline helper text surfaces the asymmetry. Context-side fields (Before/After) are annotated with D-76 comments as phonemic.
8. **D-77 — Static Morphology Preview deleted.** `morphology_preview_panel.dart` removed; `rules_page.dart` no longer imports it, no longer renders the `VerticalDivider`, no longer renders the right pane. Rules list is now full-width. `preview_panel.dart` (the live preview inside the rule editor dialog) is intact.
9. **D-78 — Dot-separator disambiguator (new decision 2026-04-11).** `.` is a first-class rom-side glyph separator. `dotAwareDeromanize` consumes it and resets the longest-match scan; `smartRomanize` inserts it at ambiguous boundaries; `isDotAwareBijection` relaxes D-72 to accept mapping sets like `{t→t, h→h, θ→th}` that would be rejected under strict bijection. Rule editor helper text surfaces the escape hatch inline.

### Task 3 redesign — the ablaut flag regression

An earlier attempt at Task 3 ran `dotAwareDeromanize` directly on the raw serialized DSL source string. The dogfood dry-run against the user's actual 7-rule database caught a **critical silent regression**: ablaut flag segments like `e1` (fromEnd, count=1) contain ASCII `e`, which under the mapping `e → ε` got rewritten to `ε1`. The ablaut flag parser's `flags.startsWith('e')` check then returned false for non-ASCII `ε`, silently flipping direction from fromEnd to fromStart. Two of the user's seven rules (Masculine `/V/o/e1` and Feminine `/V/a/e1`) would have had their meaning inverted post-migration.

The fix is the new `lib/db/migration_notation_classify.dart` helper library: parses every rule via `parseMorphDsl`, walks the op tree, calls `classifySingleLiteral` on **only** the phonological literal fields (AblautOp.from/to, SuffixOp.affix, PrefixOp.affix, RemoveSuffixOp.suffix), leaves all structural tokens untouched, and serializes back via `serializeMorphRule`. Classify outcome tracking was also fixed to use `identical()` op comparison instead of string comparison, so parse→serialize normalizations (e.g. bare `-s` → quoted `-"s"`) don't falsely report a rewrite.

**Regression lock test (Fixture 4 in rule_dsl_roundtrip_test.dart):** asserts that `/V/o/e1` under a mapping containing `e → ε` is rewritten to `/V/ø/e1` (ASCII `e1` preserved) and NOT `/V/ø/ε1`. The test file header explicitly documents the failure mode so a future contributor cannot accidentally regress.

**Dogfood dry-run result (user's actual 7 rules):**

| id | name | before | after | outcome |
|---|---|---|---|---|
| 7 | Simple Past | `+moc` | `+møk` | `rewritten` (G-68 fix) |
| 8 | Imperfect | `"V"$ +k \| "C"$ +ik` | *unchanged* | `left_alone_phonemic` (IPA-aware) |
| 9 | Habitual | `ca+` | `kæ+` | `rewritten` |
| 11 | Masculine | `"V"$ /V/o/e1 \| "C"$ +o` | `"V"$ /V/ø/e1 \| "C"$ +ø` | `rewritten` (flag preserved) |
| 12 | Plural | `+s` | *unchanged* | `left_alone_phonemic` |
| 13 | Feminine | `"C"$ +a \| "V"$ /V/a/e1` | `"C"$ +æ \| "V"$ /V/æ/e1` | `rewritten` (flag preserved) |
| 14 | Agent | `"k"$ +i \| +ki` | *unchanged* | `left_alone_phonemic` (IPA-aware) |

4 rewrites, 3 left alone, 0 garbled. User explicitly approved the dry-run before the final Tasks 4-7 commits.

### Test coverage

- **notation_helpers_test.dart (18 tests):** `dotAwareDeromanize`, `smartRomanize`, `phonemicSegmentation`, `isDotAwareBijection` — including D-78 canonical `(t, h, θ→th)` fixture.
- **romanization_bijection_test.dart (6 tests):** duplicate targets, dot-disambiguatable acceptance, dot-un-recoverable rejection, clean bijection baseline.
- **rule_dsl_roundtrip_test.dart (21 tests):** pure affix rewrite, already-phonemic left alone, condition + suffix, Fixture 4 ablaut flag preservation regression lock, ablaut fromEnd count=2, ablaut fromStart default, condition with literal phoneme, unparseable fallback, D-78 dot in affix (both directions), RedupOp/InfixOp structural passthroughs, class-ref affix passthrough, empty source, prefix op.
- **rule_editor_rom_roundtrip_test.dart (10 tests):** load path, save path, rom disabled bypass, class ref passthrough, bijection gate, WARN-1 deferral lock, D-78 save round-trip, D-78 load round-trip, D-78 helper text discoverability.
- **migration_v9_to_v10_test.dart (11 tests):** schemaVersion reports 10, pure rom rewrite, already-phonemic left alone, prefix rewrite, both ablaut regression locks, literal-phoneme condition left alone, unparseable left alone, D-78 dot rewrite (both directions), migration_log contents.
- **migration_v8_to_v9_test.dart:** schemaVersion assertions updated 9 → 10 (chained v8→v9→v10 path still passes all 17 cases).

### Cross-plan integration ready

- Plan 04-16 can now implement G-69 (non-existent phoneme highlighting) trivially: every `MorphologicalRules.source` is phonemic, so a phoneme-in-inventory check is a simple set membership.
- Plan 04-17 will append its schema additions (Dimensions.intrinsic, Lexemes.intrinsicLevelsJson, StandardFormPatterns table) to the same `if (from < 10)` onUpgrade block via the TODO(04-17) marker. 04-17 must NOT bump to v11.

## Issues encountered

1. **Dropped first attempt at Task 3.** A naive string-level classify corrupted ablaut flag segments. Caught during the dogfood dry-run checkpoint. Dropped the bad commit, redesigned as DSL-parse-aware, shipped with a regression-lock test.

2. **Parse→serialize normalization false rewrites.** The initial DSL-parse-aware classify compared the serialized output to the original source string, which incorrectly flagged normalization-only changes as rewrites (e.g. bare `-s` → quoted `-"s"`). Fixed by tracking `literals_changed` explicitly via `identical()` op comparison inside `_rewriteOp`. Verified by re-running `migration_v7_to_v8_test.dart` which had regressed on this.

3. **Pre-existing test failure.** `test/phonotactic_dsl_smoke_test.dart` was already failing on `main` before this wave started (verified via `git stash`). Not touched by 04-15 and not in scope for this plan.

## Links

- Plan: [04-15-PLAN.md](./04-15-PLAN.md)
- Context: [04-15-CONTEXT.md](./04-15-CONTEXT.md) (§D-70..D-78)
- D-75 audit: [04-15-VERIFICATION.md](./04-15-VERIFICATION.md)
- Human-verify sign-off on Task 3: dogfood dry-run preview approved 2026-04-11 after the ablaut regression was caught and fixed
