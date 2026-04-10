# Phase 4: Grammar & Morphology (revised) - Research

**Researched:** 2026-04-10
**Domain:** Flutter/Dart — N-dimensional inflectional morphology, paradigm generation, schema migration, UI refactor
**Confidence:** HIGH (codebase is fully investigated; external libraries are unchanged from prior phases)

## Summary

Phase 4 is a **codebase-internal refactor + feature layering** phase. No new external dependencies are introduced — the entire plan reuses the existing Flutter/Material 3 + Drift + Riverpod + petitparser stack already proven in Phases 1–3. The complexity is concentrated in four areas: (1) a clean v7→v8 Drift migration that adds a `Dimensions` table, extends `MorphologicalRules` with a `kind` + `feature_bindings` JSON column, drops `posIds`, and preserves every existing rule as a derivational rule; (2) a **feature-consumption paradigm engine** wrapper around the existing `MorphologyEngine` that implements most-specific-wins rule selection with explicit tiebreak errors (D-10/D-11/D-12); (3) a **router and shell reshape** that removes the Morphology tab, creates a Grammar tab with 4 sub-tabs, and adds a Derivations sub-tab to Lexicon; (4) a **shared, kind-aware `RuleEditorDialog`** that renders feature-binding chips for inflectional mode and input→output POS pickers for derivational mode.

All free infrastructure — romanization (`romanizeProvider`), phonotactic violation highlighting (`ViolationText` + `WordGenerator.validateWord`), the Drift stream reactivity, the existing 8 DSL operation types, the exception table, and the hybrid rule editor body — is reused unchanged. The biggest risk areas are the atomic migration (schema v8) and the correctness of the feature-consumption algorithm for portmanteau rules.

**Primary recommendation:** Plan the migration first (04-01), then the engine + data layer (04-02/04-03) with TDD against a dedicated test file, then the router/shell surgery (part of 04-04) before the new UI widgets on top. Wave 0 must add at least one new test file per plan: `test/grammar/paradigm_engine_test.dart`, `test/grammar/v8_migration_test.dart`, and `test/grammar/rule_binding_parser_test.dart`.

## User Constraints (from CONTEXT.md)

### Locked Decisions

**POS dimension data model**
- **D-01:** Hybrid storage — new `Dimensions` table `(id, posId FK, name, ordering, levels_json, templateId nullable)`. Levels are a JSON array on the row.
- **D-02:** Dimensions are per-POS only. No cross-POS sharing.
- **D-03:** Ship a rich template catalog (Gender M/F, M/F/N, Animate/Inanimate, Common/Neuter; Number SG/PL, SG/DU/PL, SG/PL/COLL; Case NOM/ACC/GEN/DAT, ABS/ERG/GEN/DAT, Latin-ish; Tense PRS/PST/FUT, PRS/PST, Non-future/Future; Aspect PFV/IPFV, Progressive/Habitual/Perfect; Person 1/2/3, 1INCL/1EXCL/2/3; Mood IND/SUBJ/IMP, IND/OPT/IMP; Voice ACT/PASS, ACT/MID/PASS; Definiteness DEF/INDEF). Hardcoded in Dart as const data (not seeded).
- **D-04:** Each template has a short description string shown as a tooltip (plain text, 500ms waitDuration).
- **D-05:** Two-step "Add Dimension" picker: searchable modal grouped by type, template cards with tooltips; clicking inserts an editable instance. Custom-from-scratch entry included in each group.
- **D-06:** No hard limit on N × K; soft warning > 4 dims or > 100 cells.
- **D-07:** Per-word dimension opt-out. Planner to decide column vs join table.
- **D-08:** Lemma = first level (ordering=0) of every dimension. No per-word lemma override in v1.

**Rule binding & stacking — feature consumption**
- **D-09:** Inflectional rules carry feature-value bindings — a set of `{dimensionId, levelId}` pairs. Unbound = not inflectional.
- **D-10:** Feature consumption algorithm: (1) for target cell feature set F, (2) find all rules whose bindings ⊆ F, (3) pick largest binding set (most specific), (4) apply and mark bound dimensions consumed, (5) remove consumed from F and repeat, (6) stop when all consumed or no more matches.
- **D-11:** Portmanteau example — rules `-s`{PL}, `-o`{M}, `-is`{M,PL}. For M.PL: `-is` wins. For M.SG: `-o`. For F.PL: `-s`. Multi-pass example — `-ar`{M,PL}, `-e`{DAT} on M.PL.DAT → `root-ar-e`.
- **D-12:** Ambiguous ties = **explicit error** (red inline banner in rule editor + conflict marker in paradigm cell tooltip). Never silent ordering tiebreaker.
- **D-13:** Unbound rules never fire on inflectional paths.
- **D-14:** Uncovered cells show em-dash `—` + warning icon; clicking opens override dialog with optional "Create rule for this cell" shortcut.
- **D-15:** Coverage visibility — dual surfacing: per-word (in paradigm viewer) and per-POS (standalone coverage matrix panel on Grammar > Paradigm Viewer).

**Migration v7 → v8**
- **D-16:** Schema version → 8. Migration in `onUpgrade` + `beforeOpen` safety-net.
- **D-17:** Add `kind` text column to `MorphologicalRules` ('inflectional' | 'derivational').
- **D-18:** Silent reclassification — all existing rows get `kind='derivational'`. No prompt, no data loss.
- **D-19:** Drop `posIds` CSV column in favor of a unified `feature_bindings` JSON column. Derivational rules store `{pos:[...ids]}`; inflectional rules store `{pos:[...ids], dimId: levelId, ...}`.
- **D-20:** Add `input_pos_id` and `output_pos_id` columns for derivational rules. `input_pos_id` derived from the single migrated posId if present; `output_pos_id` defaults to `input_pos_id`.
- **D-21:** Create new `Dimensions` table empty on upgrade.
- **D-22:** `MorphologicalRuleExceptions` preserved as-is. Per-cell paradigm overrides reuse this table keyed to the topmost inflectional rule's ID. Planner may introduce `ParadigmCellOverrides` if single-ruleId proves insufficient.
- **D-23:** POS page moves from Morphology tab to Grammar > POS & Dimensions. POS schema unchanged.
- **D-24:** Delete Morphology tab, `morphology_shell.dart`, and router branch 1. Relocate sub-pages (`pos_page.dart` → Grammar, `rules_page.dart` → reused filtered by kind, `rule_editor_dialog.dart` → shared, `preview_panel.dart` → reused).

**Paradigm table rendering**
- **D-25:** 2-axis layout; 3+ dim POS uses TabBar (≤6 slices) or DropdownButton (>6) for the third+ dimensions.
- **D-26:** Axis configuration user-configurable, persisted per-POS in `project_settings` as `typology.paradigm_axes.{posId}` JSON. **Grammar tab is the only place to set it**; Lexicon reflects.
- **D-27:** Paradigm viewer lives in Grammar > Paradigm Viewer (configurable) and Lexicon > word detail panel (read-only reflection). Both views share the same widget. Grammar panel supports synthetic-root template mode when no word is selected.
- **D-28:** Per-cell override — inline click → dialog. Fields: romanization (primary), IPA (auto-derived via deromanize), notes. Saves to `MorphologicalRuleExceptions` keyed by `(lexemeId, ruleId=topmost-filling-rule)`. Overridden cells in amber. Clear-override reverts.
- **D-29:** Cell display = rom (top) + `[IPA]` (bottom). Respects project romanization toggle and Alt-held modifier.
- **D-30:** Phonotactic violation highlighting per cell via `ViolationText` + `WordGenerator.validateWord`. Phase 3 exception toggle carries over.

**Grammar tab IA**
- **D-31:** 4 sub-tabs in Grammar sidebar: POS & Dimensions, Inflectional Rules, Paradigm Viewer, Typology.
- **D-32:** POS & Dimensions = POS-as-primary master-detail (mirrors Lexicon Dictionary layout). Left POS list; right dimension editor.
- **D-33:** Inflectional Rules = `rules_page.dart` reused with `kind='inflectional'` filter + feature-value filter. Reorder arrows disabled (D-12 rejects ordering tiebreaker) but visible at 20% opacity.
- **D-34:** Paradigm Viewer layout: POS dropdown + word picker top bar, axis config below, paradigm table + side coverage matrix panel.
- **D-35:** Typology = simple form (Alignment, Basic Word Order, Modality Strategy). Descriptive only — no engine behavior in Phase 4.

**Lexicon Derivations sub-tab**
- **D-36:** 4th sub-tab in Lexicon sidebar, positioned after Thesaurus. Route `/lexicon/derivations`.
- **D-37:** Reuses `rules_page.dart` filtered to `kind='derivational'`.
- **D-38:** Derivational rules show input POS → output POS; default output POS = input POS.
- **D-39:** Auto-refresh via existing `computedDerivedFormsProvider` stream plumbing.

**Rule editor reuse**
- **D-40:** Single `RuleEditorDialog({existingRule, kind})`. Inflectional → "Applies to" chip rows; derivational → input/output POS dropdowns; shared = DSL field, structured op editor, branching/conditions, preview, name, active toggle.
- **D-41:** Single `MorphologyDao` extended with kind-aware queries. No new DAO class.
- **D-42:** Feature binding UI — multi-chip tag picker (FilterChip per level, one row per dimension of currently-selected POS). Unbound = validation error.

### Claude's Discretion
- Exact UI spacing/typography/colors for paradigm + coverage matrix (resolved in UI-SPEC)
- Coverage matrix = separate panel vs mode toggle → **separate always-visible panel** (UI-SPEC resolved)
- Per-word dimension opt-out shape (column vs join table) — **planner must decide**
- Uncovered cell "Create rule" shortcut → **in override dialog** (UI-SPEC resolved)
- Sentinel for uncovered-cell overrides — **planner must decide**: `ruleId=0` vs new `ParadigmCellOverrides` table
- Template picker "custom from scratch" option → **included** (UI-SPEC resolved)
- Tiebreaker UX → **inline banner only** (UI-SPEC resolved)
- Template tooltips markdown vs plain → **plain** (UI-SPEC resolved)
- Hidden reorder arrows on inflectional list → **20% opacity, disabled** (UI-SPEC resolved)
- POS editor redesign vs reuse → **inherit existing dialog, relocated** (UI-SPEC resolved)
- One-time explainer banner on first v8 open → **dismissible migration banner in both Inflectional Rules and Derivations sub-tabs** (UI-SPEC resolved)
- Exact template description strings — planner/researcher to draft against standard linguistic references

### Deferred Ideas (OUT OF SCOPE)
- Cross-POS dimension sharing (rejected D-02)
- Agreement / concord (no cross-word feature propagation)
- Ordering-based tiebreaker (rejected D-12)
- AI rule suggestions from typology
- Full SPE allophone rule computation on paradigm cells
- Writing scratchpad / interlinear gloss (v2)
- Paradigm export (CSV/HTML/LaTeX)
- Paradigm diffing between words
- Bulk paradigm-cell editing
- Rule debugging mode ("why did this rule not fire")
- Editable default dimension templates
- Per-POS typology overrides
- Dimension-level rule grouping / folders

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GRAM-01 | Custom POS with N dimensions × K levels | §Dimensions Schema Options, §Standard Stack (Drift JSON column pattern) |
| GRAM-02 | Inflectional rules bound to dimension levels with hierarchical stacking and combined output | §Feature Consumption Algorithm, §Paradigm Engine Implementation |
| GRAM-03 | Paradigm chart generation per word | §Paradigm Viewer Architecture, §Axis Config Storage |
| GRAM-04 | Language-level typology choices (alignment, word order, modality) | §Typology Storage (project_settings) |
| GRAM-05 | Per-cell manual override | §Per-Cell Override Storage, §Existing MorphologicalRuleExceptions Reuse |
| GRAM-06 | Morphology tab removed; rule editor reused in Grammar (inflectional) + Lexicon (derivational) | §Shell and Router Surgery, §Kind-Aware RuleEditorDialog |
| GRAM-07 | Existing morphology rules → Lexicon derivational rules with romanization | §v7→v8 Migration, §Silent Reclassification |

## Project Constraints (from CLAUDE.md)

No `./CLAUDE.md` file exists at the working directory. No `.claude/skills/` or `.agents/skills/` directory detected. Planner operates under the CONTEXT.md decisions + the patterns already established by prior phases (captured in STATE.md Accumulated Decisions).

**Effective conventions inherited from prior phases:**
- Drift `onUpgrade` + `beforeOpen` safety-net ALTER TABLE pattern (plans 01-13, 02-08, 03-01)
- Plain `Provider` / `StreamProvider` (not `@riverpod` codegen) for Drift-generated types — build_runner type-traversal issue (STATE 01-05)
- Drift tables plural-named (`MorphologicalRules`), generated data class drops `s` (`MorphologicalRule`) unless conflict forces suffix (`PartsOfSpeechData`, `NaturalClassesData`)
- Import aliasing: `import '../../../db/app_database.dart' as db;` to disambiguate generated data classes from domain DSL types of the same name
- Hardcoded const catalogs in Dart for default data (Phase 3.2 default natural classes; Phase 1 ipa_data.dart)
- `ConsumerStatefulWidget` for dialog state; `ref.read` inside event handlers; `ref.watch` for reactive builds
- Amber (`Colors.amber`) for irregular forms / overrides
- `ViolationText` + Phase 3.5 validation path for every text that renders a word form
- Master-detail layouts use fixed-width left panel (200–260px)

## Standard Stack

All packages listed below are **already in `pubspec.yaml`** (verified 2026-04-10). No new dependencies needed.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter | sdk ^3.10.4 | UI framework | Project baseline |
| drift | ^2.30.0 | ORM + SQLite | Already used for all schema work [VERIFIED: pubspec.yaml] |
| drift_flutter | ^0.2.8 | File-backed per-project DB | Already used (LazyDatabase pattern) [VERIFIED: pubspec.yaml] |
| flutter_riverpod | ^3.0.3 | State management | Project baseline; all providers use this [VERIFIED: pubspec.yaml] |
| riverpod_annotation | ^3.0.3 | @riverpod codegen | Used where Drift types are NOT referenced [VERIFIED: pubspec.yaml] |
| petitparser | ^7.0.2 | DSL parser | Used by morphology_dsl.dart — unchanged in Phase 4 [VERIFIED: pubspec.yaml] |
| go_router | ^17.2.0 | Routing | Two-level StatefulShellRoute already in use [VERIFIED: pubspec.yaml] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| drift_dev | ^2.30.1 (dev) | Drift code generation | Required for new `Dimensions` table and DAO extensions [VERIFIED: pubspec.yaml] |
| build_runner | ^2.4.15 (dev) | Code gen driver | Run after every Drift table or @riverpod change [VERIFIED: pubspec.yaml] |
| riverpod_generator | ^3.0.3 (dev) | @riverpod codegen | Only for providers that don't touch Drift types [VERIFIED: pubspec.yaml; STATE 01-05] |
| flutter_test | sdk | Test framework | All new tests |

### Alternatives Considered
| Instead of | Could Use | Why NOT |
|------------|-----------|---------|
| Drift JSON TEXT column for `feature_bindings` | Drift `jsonb()` / typed converter | drift supports `TypeConverter<T, String>` — **recommended** for feature_bindings to get compile-time typed decoding. Plain TEXT is simpler but requires manual jsonEncode/Decode. See [CITED: https://drift.simonbinder.eu/type_converters/]. **Planner should use a TypeConverter** to avoid scattered `jsonDecode` calls. |
| New `Dimensions` table | JSON blob on `PartsOfSpeech` row | Rejected by D-01 — hybrid is middle ground (table rows for dims, JSON for levels). This lets dimensions be queried/filtered without parsing JSON per-row. |
| New `DimensionLevels` table (fully normalized) | Same | Rejected by D-01 — unnecessary fragmentation for data that's always loaded alongside its parent dimension. |
| Separate `InflectionalRules` and `DerivationalRules` tables | Same row, `kind` column | Rejected by D-17/D-40/D-41 — one table, one DAO, one editor. Simpler query path, simpler migration. |
| New `ParadigmCellOverrides` table | Reuse `MorphologicalRuleExceptions` | D-22 defaults to reuse; planner may introduce the new table if the ruleId sentinel approach becomes unclear for uncovered cells. **Research recommendation below.** |

**Version verification (performed 2026-04-10):**
- All packages already pinned in `pubspec.yaml` — no `npm view` / `pub outdated` needed. Planner should NOT bump versions during Phase 4 (past decisions locked drift 2.30.x + riverpod_generator 3.0.x for analyzer-version reasons — see STATE 01-01). [VERIFIED: STATE.md]

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── db/
│   └── app_database.dart          # + Dimensions table, + columns on MorphologicalRules,
│                                   # + v8 migration, + beforeOpen safety-nets
├── features/
│   ├── morphology/                # DOMAIN KEPT — only presentation/shell deleted
│   │   ├── data/
│   │   │   ├── morphology_dao.dart    # + watchRulesByKind, watchInflectionalRulesForPos,
│   │   │   │                          # insertRuleWithKind, watchDimensionsForPos, etc.
│   │   │   └── morphology_providers.dart  # + dimensionsForPosProvider
│   │   ├── domain/
│   │   │   ├── morphology_dsl.dart    # unchanged
│   │   │   └── morphology_engine.dart # unchanged (rule application kept)
│   │   └── presentation/
│   │       ├── morphology_shell.dart  # DELETED
│   │       ├── pos/                    # DELETED (moves to grammar/)
│   │       └── rules/                  # MOVED to shared/grammar (planner TBD)
│   ├── grammar/                   # NEW FEATURE MODULE
│   │   ├── data/
│   │   │   ├── grammar_dao.dart           # OR extend morphology_dao (D-41 says extend)
│   │   │   ├── grammar_providers.dart     # dimensionsForPosProvider,
│   │   │   │                              # computedInflectedParadigmProvider,
│   │   │   │                              # paradigmCoverageMatrixProvider,
│   │   │   │                              # typologySettingsProvider
│   │   │   └── dimension_templates.dart   # const catalog (D-03, D-04)
│   │   ├── domain/
│   │   │   ├── paradigm_engine.dart       # feature-consumption algorithm (D-10/D-11)
│   │   │   ├── feature_binding.dart       # {dimId, levelId} value type + (de)serializer
│   │   │   ├── rule_kind.dart             # enum RuleKind { inflectional, derivational }
│   │   │   └── tiebreak_detector.dart     # specificity tie detection (D-12)
│   │   └── presentation/
│   │       ├── grammar_shell.dart          # mirrors lexicon_shell.dart
│   │       ├── pos_dimensions/
│   │       │   ├── pos_dimensions_page.dart
│   │       │   ├── pos_list_panel.dart     # (inherits pos_page.dart widgets)
│   │       │   ├── dimension_editor_panel.dart
│   │       │   └── dimension_template_picker.dart
│   │       ├── inflectional_rules/
│   │       │   └── inflectional_rules_page.dart  # uses shared rules_page
│   │       ├── paradigm_viewer/
│   │       │   ├── paradigm_viewer_page.dart
│   │       │   ├── paradigm_table_widget.dart    # shared with Lexicon word detail
│   │       │   ├── cell_override_dialog.dart
│   │       │   ├── axis_config_bar.dart
│   │       │   └── coverage_matrix_panel.dart
│   │       └── typology/
│   │           └── typology_page.dart
│   └── lexicon/
│       └── presentation/
│           ├── lexicon_shell.dart  # + 4th sidebar entry for Derivations
│           ├── dictionary/
│           │   └── word_detail_panel.dart  # + paradigm table embed
│           └── derivations/         # NEW
│               └── derivations_page.dart   # uses shared rules_page with kind filter
└── shared/
    └── widgets/
        ├── app_shell.dart  # Morphology tab removed; Grammar tab enabled
        └── rule_editor/    # RELOCATED from morphology/presentation/rules
            ├── rule_editor_dialog.dart     # now kind-aware
            ├── preview_panel.dart           # reused as-is
            └── rules_list_page.dart         # parameterized by kind (was rules_page.dart)
```

**Note:** Planner is free to keep `rules_page.dart` + `rule_editor_dialog.dart` inside `features/morphology/presentation/rules/` and simply parameterize them — relocation is a structural nice-to-have, not a requirement. The canonical rule is that both Grammar and Lexicon import from the same file, not that the file physically lives in `shared/`.

### Pattern 1: Drift Table Addition + Column Extensions (from Phase 1, 2)
```dart
// Source: lib/db/app_database.dart (existing Phase 1-3 pattern)
class Dimensions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get posId => integer().references(PartsOfSpeech, #id)();
  TextColumn get name => text()();
  IntColumn get ordering => integer().withDefault(const Constant(0))();
  TextColumn get levelsJson => text()();  // JSON array of {name, abbr, ordering}
  TextColumn get templateId => text().nullable()();  // catalog key, null = custom
}

// In existing MorphologicalRules:
TextColumn get kind => text().withDefault(const Constant('derivational'))();
TextColumn get featureBindings => text().withDefault(const Constant('{}'))(); // JSON
IntColumn get inputPosId => integer().nullable().references(PartsOfSpeech, #id)();
IntColumn get outputPosId => integer().nullable().references(PartsOfSpeech, #id)();
// posIds dropped — data migrated into featureBindings.pos[]
```

### Pattern 2: Drift Migration with beforeOpen Safety Net (from plan 01-13 / 02-08)
```dart
// Source: lib/db/app_database.dart:204-305
if (from < 8) {
  await m.createTable(dimensions);
  await m.addColumn(morphologicalRules, morphologicalRules.kind);
  await m.addColumn(morphologicalRules, morphologicalRules.featureBindings);
  await m.addColumn(morphologicalRules, morphologicalRules.inputPosId);
  await m.addColumn(morphologicalRules, morphologicalRules.outputPosId);
  // Data migration — every existing row: kind='derivational',
  // featureBindings={'pos':[...parsed posIds...]},
  // inputPosId=first posId if any, outputPosId=inputPosId.
  final existing = await select(morphologicalRules).get();
  for (final row in existing) {
    final posIds = row.posIds.isEmpty
        ? <int>[]
        : row.posIds.split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toList();
    final bindings = jsonEncode({'pos': posIds});
    final input = posIds.isNotEmpty ? posIds.first : null;
    await (update(morphologicalRules)..where((t) => t.id.equals(row.id)))
        .write(MorphologicalRulesCompanion(
          kind: const Value('derivational'),
          featureBindings: Value(bindings),
          inputPosId: Value(input),
          outputPosId: Value(input),
        ));
  }
  // NOTE: dropping posIds column requires Drift's .dropColumn() in 2.15+ OR
  // a table rebuild. See §Migration Details below.
}

// beforeOpen safety-net (PATTERN from 01-13): wrap every CREATE/ALTER in try/catch
try {
  await customStatement(
    'CREATE TABLE IF NOT EXISTS dimensions ('
    '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
    '"pos_id" INTEGER NOT NULL REFERENCES parts_of_speech(id), '
    '"name" TEXT NOT NULL, '
    '"ordering" INTEGER NOT NULL DEFAULT 0, '
    '"levels_json" TEXT NOT NULL, '
    '"template_id" TEXT'
    ')',
  );
} catch (_) {}
try {
  await customStatement('ALTER TABLE morphological_rules ADD COLUMN "kind" TEXT NOT NULL DEFAULT \'derivational\'');
} catch (_) {}
// ... similar for feature_bindings, input_pos_id, output_pos_id
```

### Pattern 3: Hardcoded const Catalog (from Phase 3.2 default_natural_classes.dart, Phase 1 ipa_data.dart)
```dart
// Source: dimension_templates.dart (NEW)
class DimensionTemplate {
  const DimensionTemplate({
    required this.id,
    required this.group,
    required this.name,
    required this.levels,
    required this.description,
  });
  final String id;       // 'gender.mfn'
  final String group;    // 'Gender'
  final String name;     // 'Masculine/Feminine/Neuter'
  final List<DimensionLevel> levels;
  final String description;  // tooltip text
}

class DimensionLevel {
  const DimensionLevel({required this.name, required this.abbr});
  final String name;   // 'Masculine'
  final String abbr;   // 'M'
}

const dimensionTemplates = <DimensionTemplate>[
  DimensionTemplate(
    id: 'gender.mf',
    group: 'Gender',
    name: 'Masculine/Feminine',
    levels: [
      DimensionLevel(name: 'Masculine', abbr: 'M'),
      DimensionLevel(name: 'Feminine', abbr: 'F'),
    ],
    description: 'Two-gender system distinguishing masculine and feminine. '
        'Common in Romance languages (Spanish, French, Italian).',
  ),
  // … 20+ more
];
```

### Pattern 4: Feature Consumption Engine (NEW)
```dart
// Source: lib/features/grammar/domain/paradigm_engine.dart (NEW)
/// The feature set for a paradigm cell — e.g. {1: 3, 2: 7, 3: 12} meaning
/// dim1=level3 AND dim2=level7 AND dim3=level12.
typedef FeatureSet = Map<int, int>;

/// Result of paradigm cell computation.
sealed class ParadigmCell {
  const ParadigmCell();
}
class ParadigmFilled extends ParadigmCell {
  const ParadigmFilled({
    required this.form,
    required this.ruleChain,   // in application order
  });
  final String form;
  final List<InflectionalRule> ruleChain;
}
class ParadigmUncovered extends ParadigmCell {
  const ParadigmUncovered();
}
class ParadigmAmbiguous extends ParadigmCell {
  const ParadigmAmbiguous(this.tiedRules);
  final List<InflectionalRule> tiedRules;
}

ParadigmCell computeParadigmCell({
  required String root,
  required FeatureSet target,
  required List<InflectionalRule> rules,  // pre-filtered to the word's POS
  required PhonemeInventory inventory,
  required MorphologyEngine engine,
}) {
  var working = root;
  var remaining = Map<int, int>.from(target);
  final chain = <InflectionalRule>[];

  while (remaining.isNotEmpty) {
    // Subset match: a rule whose bindings are a subset of `remaining`
    final candidates = rules
        .where((r) => _isSubset(r.bindings, remaining))
        .toList();
    if (candidates.isEmpty) {
      return chain.isEmpty ? const ParadigmUncovered() : ParadigmFilled(form: working, ruleChain: chain);
    }
    // Most specific = largest binding set
    candidates.sort((a, b) => b.bindings.length.compareTo(a.bindings.length));
    final maxSize = candidates.first.bindings.length;
    final tied = candidates.where((r) => r.bindings.length == maxSize).toList();
    if (tied.length > 1) {
      return ParadigmAmbiguous(tied);
    }
    final winner = tied.single;
    // Apply the winner's underlying DSL rule to the working form
    final result = engine.applyRule(winner.toDomainRule(), working, inventory);
    if (result case MorphSuccess(:final form)) {
      working = form;
      chain.add(winner);
      // Consume bound dimensions
      for (final dimId in winner.bindings.keys) {
        remaining.remove(dimId);
      }
    } else {
      // MorphNoMatch on an inflectional rule is a failure condition —
      // skip the rule and try the next candidate. Or surface as warning.
      // Decision for planner: either retry with next candidate, or treat as
      // uncovered. Recommend retry with next candidate.
      break;
    }
  }
  return ParadigmFilled(form: working, ruleChain: chain);
}
```

### Pattern 5: Kind-Aware RuleEditorDialog (extension of existing)
```dart
enum RuleKind { inflectional, derivational }

class RuleEditorDialog extends ConsumerStatefulWidget {
  const RuleEditorDialog({
    super.key,
    required this.kind,
    this.existing,
  });
  final RuleKind kind;
  final db.MorphologicalRule? existing;
  // …existing state extended with:
  //   - FeatureSet _featureBindings (inflectional mode)
  //   - int? _inputPosId, _outputPosId (derivational mode)
  //   - String? _tiebreakError (live-computed against existing rules)
}
```

### Pattern 6: Router Branch Replacement (from existing two-level StatefulShellRoute)
```dart
// Source: lib/router/app_router.dart:67-202 (existing architecture)
// Remove branch 1 (Morphology) completely; add Grammar as branch 1 (which was
// Lexicon) and renumber. Or: keep branch indices by replacing branch 1 in place
// with Grammar. Planner decision — replacing in place is simpler and minimizes
// StatefulShellBranch reindexing in app_shell.dart.

StatefulShellBranch(
  routes: [
    GoRoute(path: '/grammar', redirect: (_, _) => '/grammar/pos'),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => GrammarShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/grammar/pos', builder: ...)]),
        StatefulShellBranch(routes: [GoRoute(path: '/grammar/inflectional', builder: ...)]),
        StatefulShellBranch(routes: [GoRoute(path: '/grammar/paradigm', builder: ...)]),
        StatefulShellBranch(routes: [GoRoute(path: '/grammar/typology', builder: ...)]),
      ],
    ),
  ],
),
```

### Anti-Patterns to Avoid
- **Storing levels as separate rows in a `DimensionLevels` table.** Rejected by D-01; creates a 3-way join (POS ← Dim ← Level) for no benefit since levels are always loaded alongside their dimension.
- **Exploding the paradigm into rows in a table.** Storing every cell's computed form statically defeats the "rules produce forms" architecture. Compute on demand via the engine + Riverpod caching (same pattern as `computedDerivedFormsProvider`).
- **Hand-rolling JSON parsing in DAO methods.** Use Drift `TypeConverter<FeatureBindings, String>` so feature_bindings round-trips are typed.
- **Branch index juggling in `app_router.dart`.** Minimize renumbering — replace Morphology's branch 1 in place with Grammar.
- **A new DAO class for Grammar.** Rejected by D-41 — extend `MorphologyDao` with kind-aware methods. One DAO touching `MorphologicalRules` + `Dimensions`. (Note: Drift allows multiple `@DriftAccessor` classes to hit the same tables, so if the planner wants a thin `GrammarDao` wrapper for organization, that's fine — but don't duplicate CRUD methods.)
- **Silent tiebreaker.** D-12 is explicit: ambiguous specificity = error, not a coin flip.
- **Deleting rows in migration.** Every existing `MorphologicalRule` row survives v7→v8. Only the `posIds` column is dropped; its data is migrated first into `feature_bindings.pos[]`.
- **Dropping `MorphologicalRuleExceptions` during migration.** Phase 3 data is preserved as-is (D-22).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Rule application (affix, ablaut, infix, template, redup, suppletive, remove-suffix) | Re-implementing MorphOperation dispatch | Existing `MorphologyEngine.applyRule` | 8 op types already tested in Phase 2 |
| DSL parsing | Re-parsing rule source strings | Existing `parseMorphDsl` + `serializeMorphRule` | Round-trip tested |
| Romanization / deromanization | Manual IPA ↔ Latin mapping | `romanizeProvider` / `deromanizeProvider` | Live-reactive from Phase 1/3 |
| Phonotactic validation on paradigm cells | Re-implementing constraint matching | `WordGenerator.validateWord` + `ViolationText` widget | Phase 3 `ValidationResult` path inherits the per-word exception toggle (Lexemes.isPhonologicalException) for free |
| Drift stream reactivity | Custom listeners on rule changes | Watch existing streams via Riverpod StreamProvider | Already plumbed for Phase 2-3 |
| Dialog layout / structured rule form | Rebuilding editor from scratch | Extend existing `RuleEditorDialog` + `_OpState`/`_BranchState`/`_CondState` | Over 950 LoC of proven form handling |
| POS CRUD | New POS editor | Relocate `pos_page.dart` as-is | Schema unchanged per D-23 |
| Migration safety net | Raw SQLite table re-creation | Copy the `try { customStatement(ALTER TABLE…) } catch(_){}` pattern from `app_database.dart:282-305` | Proven across 4 prior migrations |
| Feature binding serialization | String-format keys like "1:3,2:7" | JSON via Drift TypeConverter | Typed, indexable, extensible (pos[] alongside dim→level) |
| Tooltip rendering | Custom Overlay | Flutter `Tooltip` widget with `waitDuration: 500ms` | Matches `TooltipThemeData` in app.dart — UI-SPEC verified |
| Chip UI for feature picker | Custom chip widget | `FilterChip` from Material | Matches Phase 2 POS filter chips pattern |

**Key insight:** Phase 4 is >80% reuse of existing infrastructure. The net-new code is: (1) `Dimensions` table + migration, (2) `RuleKind` + feature-bindings TypeConverter, (3) paradigm engine wrapper, (4) 4 new pages (POS+Dim, Inflectional, Paradigm Viewer, Typology), (5) dimension template catalog, (6) cell override dialog. Everything else is relocation, reparameterization, and wiring.

## Runtime State Inventory

Phase 4 includes data migration (v7→v8) AND UI relocation. Check every category.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| **Stored data** | SQLite `morphological_rules` table rows (project-local DBs, one per project) with `posIds` CSV column that must be migrated to `feature_bindings` JSON. Pre-existing `morphological_rule_exceptions` rows key to ruleIds — these MUST continue pointing to the same rule rows after v8 migration (ruleId is preserved; only column structure changes). | **Data migration in onUpgrade `if (from < 8)` block**: parse `posIds`, write `feature_bindings` JSON with `{pos:[…]}` and set `input_pos_id` to first parsed posId. Preserve ruleId primary keys. Do NOT delete rows. |
| **Stored data — project_settings** | Project settings store romanization_enabled + (new) typology + paradigm axis config. No existing rows conflict. | Add new keys on first write; no migration needed. |
| **Stored data — Lexemes** | `Lexemes.partOfSpeech` is currently a free-text string (see app_database.dart:164); Phase 2 has the `parts_of_speech` table but Lexemes never migrated to reference it. Phase 4 CONTEXT does not require this migration either, but the paradigm viewer needs to resolve a word's POS → its dimensions. **Planner must decide** whether to (a) keep the free-text field and resolve by name/abbreviation match to `parts_of_speech`, or (b) add a nullable `posId` FK on `Lexemes` in v8. Option (a) is minimal and Phase 3's existing behavior; option (b) is cleaner but adds scope. Recommend (a). | **No forced migration**; add a resolver helper `posForLexeme(Lexeme l) → PartsOfSpeechData?` that matches on name or abbreviation. |
| **Live service config** | None — Flutter desktop app, no external services. | N/A |
| **OS-registered state** | None — no OS-level registrations. | N/A |
| **Secrets/env vars** | None. | N/A |
| **Build artifacts / installed packages** | `lib/db/app_database.g.dart`, `lib/features/morphology/data/morphology_dao.g.dart`, any new `*.g.dart` — must be regenerated after adding `Dimensions` table and new columns. | **Run `dart run build_runner build --delete-conflicting-outputs`** after each schema change. Add to the plan's task checklist. |
| **Router state / go_router state** | `go_router` branch indices are persisted in `StatefulNavigationShell.currentIndex`. Removing Branch 1 (Morphology) without replacing it would shift all downstream branches and corrupt any persisted-to-disk state (there is none in this project — go_router state is in-memory only). | Replace Morphology branch in place with Grammar to minimize index churn; verify `app_shell.dart` `_tabs` list and any tooltip index math aligns. |
| **Existing code references to `morphologyDaoProvider` / `morphologicalRuleListProvider`** | `rule_editor_dialog.dart:329`, `lexeme_providers.dart:152,276`, `rules_page.dart:69`, `word_detail_panel.dart:7` (via morphology_providers import), and any other consumer. Removing the Morphology tab does NOT delete these providers — they live in `features/morphology/data/`. Keep the DAO alive; only the presentation folder is pruned. | Ensure provider file stays; migrate any stale `rules_page.dart` imports to the relocated path. |

**After every file in the repo is updated, what runtime systems still have the old string cached, stored, or registered?**

- **SQLite project DBs at `{appDocsDir}/conlang/{projectId}/project.db`**: these exist on the user's machine and will be migrated on first open after v8 deploy. **The migration is irreversible without a backup** — the beforeOpen safety-net does NOT roll back. **Recommend the planner add a one-time backup step** (`project.db` → `project.db.v7.bak`) in the v8 onUpgrade path before the ALTER statements run, to give users a safety net. See "Open Questions" below.
- **Generated `.g.dart` files** in the working tree: must be regenerated; `build_runner` will complain if stale.
- **UI deep-links / router paths stored in code**: any string literal `/morphology/...` in tests, navigation calls, or widget keys breaks after D-24 deletion. Grep required.

## Environment Availability

This phase is purely code/schema — no new external dependencies. Skip.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK-bundled, Flutter 3.10.4) |
| Config file | none — flutter_test uses `test/` directory convention |
| Quick run command | `flutter test test/grammar/paradigm_engine_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GRAM-01 | POS with N dims × K levels round-trips through Dimensions table + JSON levels | integration | `flutter test test/grammar/dimensions_dao_test.dart` | ❌ Wave 0 |
| GRAM-02 | Most-specific-wins; portmanteau beats single-dim (`-is` > `-s`/`-o` on M.PL) | unit | `flutter test test/grammar/paradigm_engine_test.dart` | ❌ Wave 0 |
| GRAM-02 | Multi-pass feature consumption (`-ar`{M,PL} then `-e`{DAT} on M.PL.DAT → `root-ar-e`) | unit | `flutter test test/grammar/paradigm_engine_test.dart` | ❌ Wave 0 |
| GRAM-02 | Tiebreak: two rules with same binding size → `ParadigmAmbiguous` | unit | `flutter test test/grammar/paradigm_engine_test.dart` | ❌ Wave 0 |
| GRAM-02 | Unbound rule never fires on inflectional path (D-13) | unit | `flutter test test/grammar/paradigm_engine_test.dart` | ❌ Wave 0 |
| GRAM-02 | Rule with MorphNoMatch result falls through to next candidate | unit | `flutter test test/grammar/paradigm_engine_test.dart` | ❌ Wave 0 |
| GRAM-03 | Full paradigm over synthetic root with 2 dims × 4 levels generates all cells | unit | `flutter test test/grammar/paradigm_generator_test.dart` | ❌ Wave 0 |
| GRAM-03 | 3-dim POS generates slices (2 axes + tab dim) correctly | unit | same | ❌ Wave 0 |
| GRAM-03 | Per-word dimension opt-out collapses axis correctly | unit | same | ❌ Wave 0 |
| GRAM-04 | Typology settings round-trip via project_settings | integration | `flutter test test/grammar/typology_providers_test.dart` | ❌ Wave 0 |
| GRAM-05 | Cell override stores to exceptions table; clearing restores computed form | integration | `flutter test test/grammar/cell_override_test.dart` | ❌ Wave 0 |
| GRAM-05 | Override on uncovered cell works (sentinel ruleId path) | integration | same | ❌ Wave 0 |
| GRAM-06 | Router has no `/morphology/*` routes after migration; `/grammar/*` 4-tab routing works | widget | `flutter test test/grammar/grammar_router_test.dart` | ❌ Wave 0 |
| GRAM-06 | `RuleEditorDialog(kind: inflectional)` renders chip picker; `kind: derivational` renders POS dropdowns | widget | `flutter test test/grammar/rule_editor_dialog_kind_test.dart` | ❌ Wave 0 |
| GRAM-07 | v7→v8 migration: existing rows get `kind='derivational'`, `feature_bindings={pos:[...]}`, preserved IDs, preserved exceptions | integration | `flutter test test/grammar/v8_migration_test.dart` | ❌ Wave 0 |
| GRAM-07 | Derivations sub-tab appears in Lexicon; rules filter by kind; romanization shown on derived forms (reuse of existing romanize) | widget | `flutter test test/grammar/lexicon_derivations_test.dart` | ❌ Wave 0 |
| GRAM-07 | `computedDerivedFormsProvider` only surfaces `kind='derivational'` rules (not inflectional) | unit | `flutter test test/grammar/computed_derived_forms_kind_filter_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/grammar/` (Phase 4 specific)
- **Per wave merge:** `flutter test` (full suite — prior phase tests must still pass)
- **Phase gate:** `flutter test` green + `flutter analyze` clean

### Wave 0 Gaps
- [ ] `test/grammar/` directory — create
- [ ] `test/grammar/paradigm_engine_test.dart` — covers GRAM-02 feature consumption, tiebreak, portmanteau, multi-pass
- [ ] `test/grammar/paradigm_generator_test.dart` — covers GRAM-03 full chart generation
- [ ] `test/grammar/dimensions_dao_test.dart` — covers GRAM-01 Dimensions table CRUD + JSON round-trip
- [ ] `test/grammar/rule_binding_serializer_test.dart` — covers FeatureBindings TypeConverter
- [ ] `test/grammar/v8_migration_test.dart` — covers GRAM-07 migration (use Drift's `NativeDatabase.memory()` + seed v7 schema + run migration to v8 + assert)
- [ ] `test/grammar/cell_override_test.dart` — covers GRAM-05
- [ ] `test/grammar/typology_providers_test.dart` — covers GRAM-04
- [ ] `test/grammar/rule_editor_dialog_kind_test.dart` — widget test for kind-aware editor
- [ ] `test/grammar/grammar_router_test.dart` — widget test for router (verify no morphology routes, verify 4 grammar sub-routes)
- [ ] `test/grammar/lexicon_derivations_test.dart` — widget test for Derivations sub-tab
- [ ] `test/grammar/computed_derived_forms_kind_filter_test.dart` — unit test that inflectional rules don't pollute lexicon derivations
- [ ] **Rewire existing `test/morphology_engine_test.dart`** — this suite uses `simpleRule` helper with `branches` — unchanged by Phase 4 since engine API is preserved.
- [ ] **Rewire `test/morphology_preview_raw_pipeline_test.dart`** — likely unchanged; verify imports don't break if files relocate.

Framework install: not needed — `flutter_test` is in dev_dependencies.

## Dimensions Schema Options (Deep Dive)

D-01 locks the hybrid approach. Research the concrete shape:

**Chosen shape:**
```dart
class Dimensions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get posId => integer().references(PartsOfSpeech, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get ordering => integer().withDefault(const Constant(0))();
  TextColumn get levelsJson => text()();  // JSON: [{"id":1,"name":"Singular","abbr":"SG","ordering":0}, ...]
  TextColumn get templateId => text().nullable()();
}
```

**Level storage inside `levelsJson`:**
```json
[
  {"id": 1, "name": "Singular", "abbr": "SG", "ordering": 0},
  {"id": 2, "name": "Plural", "abbr": "PL", "ordering": 1}
]
```

**Critical decision for the planner: level IDs.** Since levels live inside JSON, they need stable IDs for rule bindings to reference them. Options:
1. **String IDs** like `"sg"`, `"pl"` — human-readable, easy to debug, but collide across dimensions (`"sg"` in number vs `"sg"` anywhere else).
2. **Integer IDs unique within a dimension** (1, 2, 3 within the dimension row) — rule bindings reference `{dimId: 5, levelId: 2}`. Stable even if level names change.
3. **Globally unique integer IDs** — requires an auto-increment source. Complicates JSON round-trips.

**Recommendation (MEDIUM confidence):** Option 2. Rules bind `{dimId: int, levelId: int}` where levelId is unique within that dim row. Store next-level-id counter in the levelsJson top-level (or compute as max+1 on write). This matches D-09's `{dimensionId, levelId}` tuple shape literally.

**Feature bindings JSON shape:**
```json
{"pos": [1, 3], "5": 2, "7": 4}
```
Top-level `"pos"` is a reserved key (array of POS IDs). Other keys are stringified dimension IDs mapping to level IDs. Using string keys for dim IDs matches JSON's insistence on string keys.

**TypeConverter:**
```dart
class FeatureBindings {
  const FeatureBindings({required this.pos, required this.dims});
  final List<int> pos;        // POS IDs this rule applies to
  final Map<int, int> dims;   // dimId → levelId
  int get specificity => dims.length;  // for D-10
  bool get isInflectional => dims.isNotEmpty;
  bool get isDerivational => dims.isEmpty;
}

class FeatureBindingsConverter extends TypeConverter<FeatureBindings, String> {
  const FeatureBindingsConverter();
  @override FeatureBindings fromSql(String fromDb) { /* jsonDecode */ }
  @override String toSql(FeatureBindings value) { /* jsonEncode */ }
}
```

Wire in the Drift table:
```dart
TextColumn get featureBindings => text()
    .map(const FeatureBindingsConverter())
    .withDefault(const Constant('{}'))();
```

[CITED: https://drift.simonbinder.eu/type_converters/ — Drift TypeConverter pattern]

## Per-Cell Override Storage (Recommendation)

D-22 defaults to reusing `MorphologicalRuleExceptions`. D-28 asks how to handle **uncovered cells** (no rule matched — no ruleId to key by).

**Option A: Sentinel `ruleId=0`** — treats 0 as "no rule; pure cell override." Simple but the foreign-key relationship is semantically broken (0 doesn't exist in `morphological_rules`).

**Option B: New `ParadigmCellOverrides` table.**
```dart
class ParadigmCellOverrides extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lexemeId => integer().references(Lexemes, #id, onDelete: KeyAction.cascade)();
  TextColumn get featureSetJson => text()();  // e.g. {"5":2,"7":4} — which cell
  TextColumn get overrideIpa => text()();
  TextColumn get overrideRomanization => text().nullable()();
  TextColumn get notes => text().nullable()();
}
```
Keyed by `(lexemeId, featureSetJson)`. Cleaner semantics: an override is tied to a specific cell, not to a rule.

**Recommendation (HIGH confidence):** **Option B.** Reasons:
1. Overrides on covered cells and uncovered cells behave identically — the storage always keys by cell coordinates, not by rule ID. The "topmost rule" heuristic in D-22 creates a fragility: if rules change and a different rule becomes topmost, the exception's ruleId is stale.
2. `MorphologicalRuleExceptions` remains for derivational exceptions (Phase 3's original use case) — clean separation.
3. The feature-set-JSON key is idempotent with the `FeatureBindings` JSON format already used for rule bindings (minus the `pos` array).
4. No FK integrity violation via sentinel ruleIds.

The planner should confirm with the user during plan-check (in the past CONTEXT.md marked this as Claude's discretion). If the user prefers Option A, implementation is simpler but more fragile.

## Migration Details — Dropping `posIds` Column

**Problem:** SQLite does NOT support `ALTER TABLE DROP COLUMN` before SQLite 3.35 (March 2021). sqlite3_flutter_libs bundles a recent version (2.4.6 via pubspec), and the bundled sqlite3 should be ≥ 3.35. [VERIFIED: pubspec.yaml shows `sqlite3: ^2.4.6`, which bundles SQLite 3.45+.]

[CITED: https://sqlite.org/lang_altertable.html — "ALTER TABLE ... DROP COLUMN ... added in SQLite 3.35.0"]

**Drift support:** Drift 2.x added `m.alterTable` with `dropColumns` helper for table-rebuild patterns. For single-column drops, plain `customStatement('ALTER TABLE morphological_rules DROP COLUMN pos_ids')` should work on the bundled SQLite 3.45+.

**Safer alternative:** **Don't actually drop `posIds`.** Keep the column in the schema, stop writing it in v8+, and ignore it on read. This avoids any ALTER DROP risk and preserves the ability to read v7 data via safety-net if the migration fails mid-way. Database size impact is trivial (strings are typically empty post-migration). D-19 says "drop" but the intent is "stop using" — planner should discuss this tradeoff with user.

**Recommendation (MEDIUM confidence):** **Do not physically drop the column.** Remove from the Drift Table class in code, let Drift's `beforeOpen` safety-net handle the schema-vs-code mismatch gracefully (Drift will log a warning about an unexpected column but continue). If the user specifically wants the column gone, add a v9 that drops it after v8 has been in production and battle-tested.

⚠️ **Planner should call this out in 04-01 plan-check.** Dropping a column is irreversible and the migration is run in place on user data. A keep-and-ignore approach gives a safety net; a drop approach is cleaner but risky.

## Migration Backup Safety Net (RECOMMENDATION)

Prior migrations (v1→v7) were additive. v8 is the **first migration to mutate existing data rows** (parsing `posIds` and writing `feature_bindings`). If the migration corrupts data, users lose their rules.

**Recommended safety net (add to 04-01 plan):**

```dart
// Before running v8 ALTER + data migration:
if (from < 8) {
  // Backup the entire database file before mutating.
  final dbPath = /* …get from drift_flutter context, e.g. via ProjectRegistry… */;
  final backup = File('$dbPath.v7.bak');
  if (!backup.existsSync()) {
    await File(dbPath).copy(backup.path);
  }
  // … run v8 migration
}
```

Drift's `onUpgrade` migrator does not expose the underlying file path directly. The planner would need to inject the path via `AppDatabase.fromPath` — which already captures it (see `app_database.dart:318-327`). Store the path on the `AppDatabase` instance and read it during migration.

Alternative: Do the backup at the `currentDatabaseProvider` level (project load layer), *before* opening the Drift DB, checking `user_version` via `sqlite3` package directly. This is the cleaner pattern — backup outside Drift, then let Drift run its migrations on the live file.

**Planner decision required.** This is outside CONTEXT.md scope but is a research-flagged safety concern.

## Paradigm Engine — Deeper Mechanics

**Rule lookup data structure.** For a POS with R inflectional rules and a paradigm with C cells, naive lookup is O(R × C × avg_specificity). For realistic sizes (R ≤ 50, C ≤ 100), naive is fine — no indexing needed. Riverpod caches the full paradigm per-word via a family provider.

**Pre-filter by POS.** Before running the algorithm per cell, filter rules by `featureBindings.pos.contains(wordPosId) || featureBindings.pos.isEmpty`. This dramatically shrinks the candidate set.

**Rule application order within a cell.** Multiple rules may apply sequentially (D-11 multi-pass). The application order is: most-specific first, then by whatever comes next in the remaining feature set. The engine chain is deterministic because at each step we pick the most-specific rule and there's no valid "tiebreak." If a tie occurs, the cell is `ParadigmAmbiguous`.

**What counts as "consumed"?** The bound dimensions of the winning rule. Example: rule `-ar{M,PL}` applied to cell `{M,PL,DAT}` consumes M and PL, leaving `{DAT}`. Next iteration matches `-e{DAT}`.

**Interaction with existing `MorphologyEngine.applyRule`.** The engine returns `MorphSuccess(form)` or `MorphNoMatch(reason)`. A MorphNoMatch inside a paradigm step means the rule's DSL conditions (e.g., `endsWith [nasal]`) didn't match the working form — this is expected and normal (the DSL condition narrows the rule further than just feature bindings). The paradigm engine should treat MorphNoMatch as "skip this candidate, try the next one with the same specificity" — **NOT** fall through to a less-specific rule (which would violate most-specific-wins semantics). If no candidate at the current specificity level succeeds, the cell is uncovered.

⚠️ **Edge case for planner:** What if a more-specific rule's DSL condition fails but a less-specific one would have applied? Two interpretations:
1. **Strict most-specific:** skip the more-specific rule's failure and the cell is uncovered (even though a less-specific rule could have filled it). Consistent with feature-consumption semantics but surprising to users.
2. **Fall-through:** on MorphSuccess match failure, try progressively less-specific rules. More forgiving but muddies the "most-specific wins" contract.

Neither is specified in CONTEXT.md. **Recommend interpretation 1** (strict) with a visible "rule condition didn't match" warning in the cell tooltip. Planner should surface this during plan-check for user confirmation.

## Typology Storage

D-26, D-35 → `project_settings` key-value table (already exists since Phase 1 v3 migration).

**Keys:**
- `typology.alignment` = `'nom_acc' | 'erg_abs' | 'split'`
- `typology.word_order` = `'SVO' | 'SOV' | 'VSO' | 'VOS' | 'OVS' | 'OSV' | 'free'`
- `typology.modality` = `'synthetic' | 'analytic' | 'mixed'`
- `typology.paradigm_axes.{posId}` = JSON `{"rows": dimId, "cols": dimId, "tabs": [dimIds]}`
- `ui.migration_v8_banner_dismissed.{tabKey}` = `'true'` — banner dismissal per sub-tab (UI-SPEC D-24)

No schema change; only new key usage. Riverpod provider pattern reuses the existing `romanizationEnabledProvider` pattern (STATE 01-12): watch the full project_settings stream, filter by key client-side.

## Phase Requirements → Research Findings Map

| Requirement | Research Section | Key Points |
|-------------|------------------|------------|
| GRAM-01 POS + N dims × K levels | §Dimensions Schema Options | Hybrid table + JSON levels; TypeConverter for levels_json; level IDs unique per dim row |
| GRAM-02 Inflectional rules + hierarchical stacking | §Paradigm Engine Implementation, §Pattern 4 | Feature-consumption algorithm; strict most-specific-wins; explicit tiebreak errors |
| GRAM-03 Paradigm chart generation | §Paradigm Engine Implementation, §Pattern 4 | Riverpod family provider per lexeme, re-use existing `MorphologyEngine.applyRule` |
| GRAM-04 Typology choices | §Typology Storage | `project_settings` keys; new provider; no schema change |
| GRAM-05 Per-cell override | §Per-Cell Override Storage | Recommend new `ParadigmCellOverrides` table (cleaner than sentinel ruleId) |
| GRAM-06 Morphology tab removed; rule editor reused | §Pattern 5, §Pattern 6, §Shell and Router Surgery | Router branch replacement; `RuleEditorDialog(kind:)`; `rules_page.dart` parameterized by kind |
| GRAM-07 Migration + derivations sub-tab | §Migration Details, §Runtime State Inventory | Silent `kind='derivational'` reclassification; `feature_bindings` JSON write from `posIds`; IDs preserved |

## Common Pitfalls

### Pitfall 1: Forgetting to regenerate `.g.dart` after Drift changes
**What goes wrong:** Compiler errors about missing `dimensionsCompanion`, missing methods on generated database.
**Root cause:** Drift is a code-generator; new tables/columns require re-running build_runner.
**How to avoid:** Include `dart run build_runner build --delete-conflicting-outputs` in every plan task that touches Drift tables. Plan 04-01 should have this as a mandatory step.
**Warning signs:** Analyzer errors on `MorphologicalRulesCompanion`, missing accessor on `AppDatabase`.

### Pitfall 2: Migration writes only onUpgrade, forgetting beforeOpen safety net
**What goes wrong:** Hot-restart during development or an aborted migration leaves the SQLite `user_version` bumped but tables incomplete.
**Root cause:** onUpgrade runs once; beforeOpen runs every open.
**How to avoid:** For every CREATE TABLE and ALTER TABLE in onUpgrade, add an idempotent equivalent in beforeOpen wrapped in `try { ... } catch (_) {}`. Precedent: `app_database.dart:237-305`.
**Warning signs:** `no such column` or `no such table` errors only on second app run after a migration.

### Pitfall 3: Drift-generated class name collision with domain class name
**What goes wrong:** `MorphologicalRule` is defined BOTH as a Drift row data class (from the `MorphologicalRules` table) AND as a domain class in `morphology_dsl.dart`. Naive imports → ambiguous symbol.
**Root cause:** Drift drops `s` from plural table names; domain modelers often pick the same noun.
**How to avoid:** Already handled in codebase via `import '../../db/app_database.dart' as db;` (see `rule_editor_dialog.dart:5`, `lexeme_providers.dart:8`). Phase 4 new files must follow the same pattern.
**Warning signs:** "The name 'MorphologicalRule' is defined in multiple imports" analyzer errors.

### Pitfall 4: StatefulShellRoute branch index drift
**What goes wrong:** Removing a branch shifts every downstream branch; any tab-count math in `app_shell.dart` breaks silently.
**Root cause:** `navigationShell.currentIndex` and `_tabs[index]` are loosely coupled by position.
**How to avoid:** **Replace Morphology branch in place with Grammar.** The list `_tabs` in `app_shell.dart:23-29` then changes: remove Morphology, enable Grammar. Branch indices: 0=Phonology, 1=Grammar (was Morphology), 2=Lexicon, 3=(new) Grammar or Culture. Audit every `currentIndex ==` comparison.
**Warning signs:** Tapping one tab selects a different sub-shell; tests selecting by index point to wrong pages.

### Pitfall 5: Tiebreak detection happens too late
**What goes wrong:** User creates two rules with the same binding set; no warning until they view a paradigm cell, by which time they've forgotten which rule they created.
**Root cause:** D-12 banner lives in the Rule Editor dialog but only fires on the current rule's bindings vs rules already saved.
**How to avoid:** Live-compute tiebreak on every FilterChip toggle. Query sibling rules filtered to the same POS and same specificity size and compare binding-set equality. Surface the matched rule name in the banner copy: "Conflict: This rule has the same specificity as '[other rule name]' …"
**Warning signs:** Silent tie → `ParadigmAmbiguous` only visible when viewing a paradigm cell, not when editing the rule.

### Pitfall 6: Paradigm viewer re-computing the entire chart on every provider rebuild
**What goes wrong:** Performance drops for POS with 100+ cells.
**Root cause:** No memoization per cell; each rebuild calls `engine.applyRule` per cell.
**How to avoid:** Wrap paradigm generation in a `Provider.family<Map<FeatureSet, ParadigmCell>, int lexemeId>` that Riverpod auto-caches. Only recomputes when upstream providers (rules, inventory, constraints, exceptions) change. Same pattern as `computedDerivedFormsProvider` in `lexeme_providers.dart:274`.
**Warning signs:** UI jank when typing in the word picker filter.

### Pitfall 7: Per-word dimension opt-out storage not covered by research
**What goes wrong:** D-07 explicitly leaves the shape to the planner; choosing the wrong shape later requires data migration.
**Root cause:** Options are (a) `Lexemes.skippedDimensionIdsJson` column, (b) `LexemeDimensionSkips` join table, (c) ignore and treat all dims as always-applicable.
**How to avoid:** **Recommendation (MEDIUM confidence):** Option (a) — a nullable JSON column on `Lexemes`. Reason: dimension skip lists are almost always small (0–3 entries), accessed atomically with the lexeme, and never queried standalone. A join table adds a query for a trivial payload. Precedent: `Lexemes.ruleIds` is already a JSON-string column.
**Warning signs:** Planner forgets this and the paradigm viewer always renders full axes even for mass nouns / impersonal verbs.

### Pitfall 8: Drift migration test harness
**What goes wrong:** Testing migrations in flutter_test against a persistent file is slow and non-hermetic.
**Root cause:** Default `AppDatabase.fromPath` wants a real file.
**How to avoid:** Use `AppDatabase(NativeDatabase.memory())` (in-memory) OR Drift's `schema_versioning` package — but the project does NOT currently use schema_versioning. Easiest path for v8 migration tests: open an in-memory DB, manually execute `CREATE TABLE` statements matching v7 schema, insert test rows, bump `user_version` to 7 via `PRAGMA`, then open `AppDatabase` wrapping the same executor and let `onUpgrade` run. Verify rows post-migration.
**Warning signs:** Migration tests that mutate the developer's real project.db.

### Pitfall 9: `computedDerivedFormsProvider` polluted by inflectional rules post-migration
**What goes wrong:** After v8, if the provider doesn't filter by kind, every inflectional rule fires when computing derived forms for a word in the lexicon derivation tree — producing bogus "derivations."
**Root cause:** `lexeme_providers.dart:274-301` watches `morphologicalRuleListProvider` which returns ALL rules.
**How to avoid:** Add a `kind='derivational'` filter inside the provider. Alternatively create `derivationalRulesProvider` and switch the consumer. Plan 04-05 must include this.
**Warning signs:** Lexicon word detail suddenly shows 20 "derivations" that are actually inflections.

### Pitfall 10: Drift FK cascade behavior when deleting a POS
**What goes wrong:** Deleting a POS orphans its Dimensions (with `posId` FK) and leaves rules bound to non-existent features.
**Root cause:** Drift doesn't auto-add `ON DELETE CASCADE` unless declared.
**How to avoid:** Explicitly set `.references(PartsOfSpeech, #id, onDelete: KeyAction.cascade)` on `Dimensions.posId`, and handle rule-binding cleanup at the DAO level (rebuild rule's feature_bindings with the deleted dim removed). Phase 4 should enforce this in the confirm-delete dialog copy ("This will also delete all its dimensions and remove dimension bindings from inflectional rules.") — UI-SPEC already spec'd this.
**Warning signs:** Post-delete query returns rules with stale `feature_bindings` referencing dead dimension IDs.

## Code Examples

### Reading feature bindings with Riverpod
```dart
// Source: NEW — derived from lexeme_providers.dart:274 pattern
final inflectionalRulesForPosProvider =
    Provider.family<List<InflectionalRule>, int>((ref, posId) {
  final rulesAsync = ref.watch(morphologicalRuleListProvider);
  final dbRules = rulesAsync.asData?.value ?? [];
  return dbRules
      .where((r) => r.kind == 'inflectional')
      .where((r) => r.featureBindings.pos.isEmpty || r.featureBindings.pos.contains(posId))
      .map(InflectionalRule.fromDbRow)
      .toList();
});

final computedInflectedParadigmProvider =
    Provider.family<Map<FeatureSet, ParadigmCell>, int>((ref, lexemeId) {
  final lexemeAsync = ref.watch(lexemeByIdProvider(lexemeId));
  final lexeme = lexemeAsync.asData?.value;
  if (lexeme == null || lexeme.partOfSpeech == null) return {};

  final pos = ref.watch(posByNameOrAbbrProvider(lexeme.partOfSpeech!));
  if (pos == null) return {};

  final dims = ref.watch(dimensionsForPosProvider(pos.id));
  final rules = ref.watch(inflectionalRulesForPosProvider(pos.id));
  final inventory = ref.watch(phonemeInventoryProvider);
  final skippedDims = lexeme.skippedDimensionsJson ?? <int>[];

  final activeDims = dims.where((d) => !skippedDims.contains(d.id)).toList();
  final cells = <FeatureSet, ParadigmCell>{};

  // Cartesian product of all dim levels
  for (final featureSet in cartesianOfDimensionLevels(activeDims)) {
    cells[featureSet] = computeParadigmCell(
      root: lexeme.ipa,
      target: featureSet,
      rules: rules,
      inventory: inventory,
      engine: const MorphologyEngine(),
    );
  }
  return cells;
});
```

### Dimension editor save
```dart
// Source: NEW — derived from existing pos_page.dart CRUD pattern
await dao.insertDimension(DimensionsCompanion(
  posId: Value(selectedPosId),
  name: Value('Gender'),
  ordering: Value(await dao.nextDimensionOrdering(selectedPosId)),
  levelsJson: Value(jsonEncode([
    {'id': 1, 'name': 'Masculine', 'abbr': 'M', 'ordering': 0},
    {'id': 2, 'name': 'Feminine', 'abbr': 'F', 'ordering': 1},
  ])),
  templateId: const Value('gender.mf'),
));
```

### Opening shared RuleEditorDialog from two places
```dart
// Grammar > Inflectional Rules sub-tab
showDialog(
  context: context,
  builder: (_) => const RuleEditorDialog(kind: RuleKind.inflectional),
);

// Lexicon > Derivations sub-tab
showDialog(
  context: context,
  builder: (_) => const RuleEditorDialog(kind: RuleKind.derivational),
);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phase 2 `posIds` CSV column for POS filtering | `feature_bindings.pos[]` JSON | Phase 4 D-19 | Typed access, room for additional bindings in same JSON |
| Single-kind `MorphologicalRules` (all treated as derivational) | `kind` column splits inflectional/derivational | Phase 4 D-17 | Engine can branch behavior; UI can filter lists |
| Separate rule editors for inflectional vs derivational | Single kind-aware dialog | Phase 4 D-40 | One code path for DSL editing; less duplication |
| Phase 2 "Morphology" as standalone tab | Merged into Grammar (inflectional) + Lexicon (derivational) | Phase 4 D-24 | Information architecture aligned with linguistic convention |

**Deprecated/outdated in Phase 4:**
- `morphology_shell.dart` — deleted
- Morphology tab entry in `app_shell.dart:25` — removed
- Router Branch 1 `/morphology/*` routes — removed/replaced
- `posIds` CSV column on `MorphologicalRules` — no longer written (physical drop deferred; see §Migration Details)

## Assumptions Log

Every claim below has been verified against the codebase, CONTEXT.md, UI-SPEC.md, REQUIREMENTS.md, ROADMAP.md, STATE.md, or pubspec.yaml. The following items are `[ASSUMED]` and warrant user confirmation during plan-check:

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Bundled SQLite 3.45+ (via `sqlite3` package ^2.4.6) supports `ALTER TABLE DROP COLUMN` | §Migration Details | If false, the `posIds` physical drop must use table-rebuild pattern. **Mitigation: research recommends NOT physically dropping anyway.** |
| A2 | `computedDerivedFormsProvider` currently returns all rules unfiltered (verified at line 274-301). Adding a `kind='derivational'` filter in plan 04-05 is the right fix | §Pitfall 9 | If the provider is restructured before Phase 4 plan runs, the pitfall description needs updating. |
| A3 | Strict most-specific-wins (Interpretation 1) is the user's mental model — when a more-specific rule's DSL condition fails, the cell is uncovered, not fallen through | §Paradigm Engine — Deeper Mechanics | User may have expected fall-through. Surface in plan-check. |
| A4 | A new `ParadigmCellOverrides` table is cleaner than sentinel ruleId for uncovered-cell overrides | §Per-Cell Override Storage | User may prefer sentinel (simpler migration) — planner must confirm. |
| A5 | Per-word dimension opt-out → JSON column on `Lexemes` is the right shape | §Pitfall 7 | Join table is an alternative; migration cost is different. Low-risk choice, but make it explicit. |
| A6 | Dimension level IDs should be unique within a dimension row (integer, auto-assigned in levelsJson) rather than globally unique | §Dimensions Schema Options | Global uniqueness would require a separate DimensionLevels table or a counter in project_settings. Per-dim is simpler. |
| A7 | `Lexemes.partOfSpeech` (free text) should stay free-text; paradigm viewer resolves by name/abbreviation match to `PartsOfSpeech` table rather than adding a `posId` FK column | §Runtime State Inventory | An FK would be cleaner but adds scope + migration for existing lexemes. |
| A8 | Drift migration backup (copy project.db → project.db.v7.bak) should be added as a safety net before v8 data mutation | §Migration Backup Safety Net | Adds scope. If skipped and migration fails, users lose rules. |
| A9 | Dropping physical `posIds` column should be deferred to a post-v8 migration after battle-testing | §Migration Details | Planner/user may want a clean schema now. |
| A10 | Exact template description strings are planner's to draft. The dimension template catalog should ship ~20 templates covering all 9 groups listed in D-03 | §Pattern 3 | Description accuracy against linguistic references is a quality concern, not correctness. |

**None of these assumptions affect correctness of the locked CONTEXT.md decisions** — they are engineering choices within Claude's discretion and research-surfaced safety concerns.

## Open Questions

1. **Drop `posIds` physically, or keep-and-ignore?**
   - What we know: SQLite 3.35+ supports ALTER DROP COLUMN; bundled SQLite is recent enough. But the drop is irreversible.
   - What's unclear: whether the user wants a clean schema immediately or a safer gradual migration.
   - Recommendation: keep-and-ignore in v8, add a v9 drop after UAT. Surface in plan-check.

2. **Per-cell override storage: `ParadigmCellOverrides` table vs reuse `MorphologicalRuleExceptions` with sentinel ruleId=0?**
   - What we know: D-22 defaults to reuse; D-28 and Claude's discretion leave the sentinel shape open.
   - What's unclear: user preference for schema cleanliness vs migration simplicity.
   - Recommendation: new table. Surface in plan-check.

3. **MorphNoMatch fall-through semantics.**
   - What we know: D-10/D-11 specify most-specific-wins but don't address what happens when the most-specific rule's DSL condition fails.
   - What's unclear: user's expectation — strict cell-uncovered vs try-less-specific.
   - Recommendation: strict. Surface in plan-check.

4. **Migration backup step.**
   - What we know: v8 is the first mutating migration; no current backup mechanism exists.
   - What's unclear: whether to add backup (scope cost) or rely on user's own file management.
   - Recommendation: add backup. Surface in plan-check.

5. **Per-word dim opt-out: column vs join table.**
   - What we know: D-07 leaves this open.
   - What's unclear: user preference.
   - Recommendation: JSON column (matches `Lexemes.ruleIds` pattern).

6. **`Lexemes.partOfSpeech` free-text vs FK.**
   - What we know: Lexemes currently uses free-text POS; Phase 2 added the PartsOfSpeech table but never FK'd Lexemes. Phase 4 needs POS→dimensions resolution per word.
   - What's unclear: whether to add the FK now or resolve by name match.
   - Recommendation: stay free-text + resolver helper. Defer FK to a future cleanup phase.

7. **Dimension level ID scheme** — per-dim unique integer (recommended) vs string keys vs globally unique. Surface during 04-01 plan-check so the TypeConverter spec is locked before implementation.

## Security Domain

Not applicable. This is a single-user offline desktop tool with no authentication, network boundary, or PII. `security_enforcement` is not configured in `.planning/config.json`. V5 Input Validation applies only insofar as the DSL parser (petitparser) already validates rule source syntax — no new attack surface added in Phase 4.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Single-user local tool |
| V3 Session Management | no | No sessions |
| V4 Access Control | no | Local file access only |
| V5 Input Validation | yes (minor) | petitparser DSL grammar (existing Phase 2); feature_bindings JSON validated by TypeConverter |
| V6 Cryptography | no | No crypto |

No known threat patterns for this phase.

## Sources

### Primary (HIGH confidence)
- `.planning/phases/04-grammar-morphology-revised/04-CONTEXT.md` — phase-defining decisions D-01 through D-42
- `.planning/phases/04-grammar-morphology-revised/04-UI-SPEC.md` — UI contract, resolves Claude's discretion items
- `.planning/REQUIREMENTS.md` §Grammar (GRAM-01 through GRAM-07)
- `.planning/ROADMAP.md` §Phase 4
- `.planning/STATE.md` §Accumulated Decisions (all 01-, 02-, 03- decisions relevant to patterns)
- `lib/db/app_database.dart` — full schema, all prior migrations, beforeOpen safety-net pattern (verified lines 104-328)
- `lib/features/morphology/data/morphology_dao.dart` — existing DAO, will be extended (verified 171 lines)
- `lib/features/morphology/data/morphology_providers.dart` — existing providers (verified 65 lines)
- `lib/features/morphology/domain/morphology_dsl.dart` — DSL parser/serializer, MorphologicalRule/MorphBranch classes (verified lines 110-131, 419, 466)
- `lib/features/morphology/domain/morphology_engine.dart` — `applyRule`, helpers (verified 531 lines)
- `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` — hybrid editor form state, _OpState/_BranchState/_CondState, posIds save path (verified lines 1-429)
- `lib/features/morphology/presentation/rules/rules_page.dart` — POS filter chips, streams (verified lines 1-150)
- `lib/features/morphology/presentation/pos/pos_page.dart` — POS CRUD UI (verified lines 1-120)
- `lib/features/morphology/presentation/morphology_shell.dart` — the shell that will be deleted (verified 152 lines)
- `lib/features/lexicon/presentation/lexicon_shell.dart` — pattern for 4-item sidebar (verified 161 lines)
- `lib/features/lexicon/data/lexeme_providers.dart` — `computedDerivedFormsProvider` at lines 274-301 (verified 323 lines)
- `lib/features/lexicon/data/lexeme_dao.dart` — LexemeDao + MorphologicalRuleExceptions access (verified 73 lines)
- `lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart` — uses computedDerivedFormsProvider (verified lines 1-80)
- `lib/router/app_router.dart` — current 4-branch router with Morphology at branch 1 (verified 203 lines)
- `lib/shared/widgets/app_shell.dart` — top tab bar with `_tabs` list (verified lines 1-80)
- `pubspec.yaml` — full dependency list (verified 71 lines)
- `test/morphology_engine_test.dart` — existing test patterns for new paradigm_engine tests (verified lines 1-60)
- `.planning/config.json` — mode=yolo, research=true, plan_check=true (verified)

### Secondary (MEDIUM confidence)
- [CITED: https://drift.simonbinder.eu/type_converters/] — Drift TypeConverter pattern for feature_bindings JSON
- [CITED: https://sqlite.org/lang_altertable.html] — SQLite ALTER TABLE DROP COLUMN support since 3.35
- STATE.md decision 01-13: `onUpgrade` + `beforeOpen` safety-net precedent

### Tertiary (LOW confidence)
- None — all findings grounded in codebase or CONTEXT.md.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages verified in pubspec.yaml; no new deps
- Architecture (migration, schema): HIGH — fully investigated codebase, CONTEXT.md decisions locked
- Architecture (paradigm engine): HIGH for algorithm shape, MEDIUM for MorphNoMatch fall-through semantics (A3 open question)
- Rule editor reuse: HIGH — existing file structure read end-to-end
- Router / shell surgery: HIGH — router source read in full
- Per-cell override storage: MEDIUM — research recommends new table vs CONTEXT.md default; needs user sign-off (A4)
- Migration safety: MEDIUM — research recommends keep-and-ignore + file backup vs CONTEXT.md literal "drop"; needs user sign-off (A8, A9)
- Test architecture: HIGH — test directory structure and existing suite patterns verified

**Research date:** 2026-04-10
**Valid until:** 2026-05-10 (30 days — the research concerns Phase 4 internal work; external dependencies do not move in this window for locked versions)
