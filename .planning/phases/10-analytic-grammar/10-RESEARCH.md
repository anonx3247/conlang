# Phase 10: Analytic Grammar - Research

**Researched:** 2026-04-13
**Domain:** Flutter/Drift — closed-class inventory, phrase constructions, word order typology
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Closed-class words are edited in a new **"Particles"** sub-tab in the Grammar sidebar, separate from the main Lexicon dictionary

**D-02:** Closed-class words are stored in the **same Lexemes table** with a boolean/category flag distinguishing them from content words — unified search, Anki export, and phonotactic validation work automatically

**D-03:** Each closed-class word carries **one gloss tag** (e.g. DEF, NEG, PROG, FUT). If a particle serves multiple functions, create separate entries

**D-04:** Gloss tags use a **predefined catalog of common Leipzig glossing abbreviations** as suggestions, but user can also enter custom tags

**D-05:** Closed-class words **still carry a POS** (e.g. auxiliary verbs are POS=Verb, determiners have their own POS). The closed-class flag is orthogonal to POS assignment

**D-06:** Phrase construction rules are authored via a **visual slot editor** — each slot is a labeled box, slots are added/ordered in sequence

**D-07:** A slot can reference either a **closed-class gloss tag** (NEG, DEF, FUT) or an **open-class POS category** (V, N, ADJ)

**D-08:** Rules are organized as a **flat list with user-chosen names** (e.g. "Negation", "Future tense", "Genitive") — no category grouping layer

**D-09:** Rules show a **live preview** using actual closed-class words and sample lexicon entries to demonstrate the pattern with real words

**D-10:** New word order settings **extend the existing Typology page** with additional sections below the current Alignment / Word Order / Modality dropdowns — same auto-save pattern via project_settings

**D-11:** **Core settings only**: head-directionality (head-initial / head-final / mixed), adposition type (preposition / postposition / circumposition), and adjective/genitive placement relative to noun

**D-12:** Settings are stored as **structured data** (not free text) so Phase 12's scratchpad can use them as parsing hints — descriptive now, parseable later

**D-13:** Grammar sidebar grows from 3 to 5 items: POS & Dimensions, Inflections, **Particles** (new), **Constructions** (new), Typology

**D-14:** Particles page shows closed-class words **grouped by POS** (e.g. Auxiliaries section, Determiners section, Conjunctions section)

### Claude's Discretion
- Icon choices for new sidebar items (Particles, Constructions)
- Exact Leipzig glossing catalog contents (standard abbreviations)
- Particles page layout details (list vs cards, detail panel style)
- Construction slot editor widget design details

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AGRAM-01 | User can define closed-class words (particles, aux verbs, prepositions, determiners, conjunctions) with grammatical gloss tags (DEF, NEG, PROG, etc.) in a dedicated inventory separate from content words | D-02: Lexemes table + boolean flag + glossTag column (schema v15); D-14: Particles page grouped by POS; D-01: Grammar sidebar sub-tab |
| AGRAM-02 | User can define named phrase construction rules with ordered slots (e.g. "negation = NEG + V", "future = AUX:FUT + V", "genitive = N + PREP:GEN + N") | D-06/D-07/D-08: visual slot editor in new Constructions table; D-09: live preview; new DB table for constructions |
| AGRAM-03 | User can define structured word order patterns (basic order SVO/SOV/etc., head-directionality, adposition placement, NP/VP/PP ordering rules) | D-10/D-11/D-12: Typology page extension; project_settings keys; structured data for Phase 12 consumption |
</phase_requirements>

---

## Summary

Phase 10 adds analytic grammar capability to the conlang workbench. It has three distinct deliverables: (1) the Particles sub-tab with closed-class word inventory, (2) the Constructions sub-tab with a visual slot editor for phrase rules, and (3) extended word order settings on the Typology page.

The Lexemes table already exists and the decision to store closed-class words there (D-02) makes AGRAM-01 mostly a schema migration (add two columns) plus a new UI tab. The Constructions feature (AGRAM-02) requires a new DB table since there is no analogous data structure in the existing schema — the MorphologicalRules table is close but couples a DSL string to the rule, which is the wrong shape for ordered slot lists. The Typology extension (AGRAM-03) is the simplest: pure project_settings keys with the same auto-save pattern already used three times.

The GrammarShell's `_sidebarItems` list is a plain Dart const array — adding two entries is trivial, but each new sidebar entry also needs a new GoRouter StatefulShellBranch (following the exact three-branch pattern already in place). This is the structural surgery that locks all other tasks: navigation must be in place before pages can be developed in parallel.

**Primary recommendation:** Split work into 4 waves — (1) schema migration + navigation skeleton, (2) Particles page, (3) Constructions page, (4) Typology extension. Wave 1 is the prerequisite for everything else.

---

## Standard Stack

### Core (all verified in pubspec.yaml)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| drift | ^2.30.0 | SQLite ORM with reactive streams | Project-wide ORM — all DB access via Drift DAOs |
| flutter_riverpod | ^3.0.3 | State management | Project-wide state layer |
| riverpod_annotation | ^3.0.3 | Code-gen providers | Established for parameterized providers |
| go_router | ^17.2.0 | Navigation | Project-wide routing with StatefulShellRoute |
| build_runner | ^2.4.15 | Code generation | Required for Drift + Riverpod generators |

[VERIFIED: pubspec.yaml]

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test (sdk) | — | Unit + widget tests | All test files in test/ |
| drift/native.dart | — | In-memory DB for tests | All DAO/migration tests use NativeDatabase.memory() |

[VERIFIED: test/unit/grammar/typology_providers_test.dart, test/integration/migration_v8_to_v9_test.dart]

**No new dependencies are required for this phase.** All building blocks (Drift, Riverpod, GoRouter, flutter_riverpod) are already in the project.

---

## Architecture Patterns

### Existing Grammar Feature Structure
```
lib/features/grammar/
├── data/
│   ├── grammar_dao.dart           # Drift DAO for POS, Dimensions
│   ├── typology_providers.dart    # TypologySettings + project_settings helpers
│   ├── grammar_providers.dart     # Riverpod stream providers
│   └── ...
├── domain/
│   ├── dimension_level.dart       # Value types
│   └── ...
└── presentation/
    ├── grammar_shell.dart         # Sidebar shell (3 items, needs → 5)
    ├── pos_dimensions/            # POS & Dimensions page
    ├── inflections/               # Inflections page
    └── typology/
        └── typology_page.dart     # Typology dropdowns (needs extension)
```

New directories to create:
```
lib/features/grammar/presentation/
├── particles/
│   └── particles_page.dart
└── constructions/
    └── constructions_page.dart
```

### Pattern 1: Grammar Sidebar Extension
**What:** `_sidebarItems` in `GrammarShell` is a const list; `GrammarShell` has a nested `StatefulShellRoute.indexedStack`. Adding Particles (index 3) and Constructions (index 4) requires:
1. Two new `_SidebarItem` entries in `_sidebarItems`
2. Two new `StatefulShellBranch` entries in `app_router.dart`'s Grammar branch
3. Two new `GoRoute` entries: `/grammar/particles` and `/grammar/constructions`

**Critical:** The `navigationShell.goBranch(index)` call in `_onSidebarTap` uses list index. The new items must be appended at positions 3 and 4 (after existing Typology at 2), and the Typology item stays at index 2. Order in `_sidebarItems` must exactly match order in `StatefulShellRoute.indexedStack` branches.

[VERIFIED: lib/features/grammar/presentation/grammar_shell.dart, lib/router/app_router.dart]

**Example — new sidebar items:**
```dart
// Source: lib/features/grammar/presentation/grammar_shell.dart
static const _sidebarItems = [
  _SidebarItem(label: 'POS & Dimensions', icon: Icons.category_outlined, path: '/grammar/pos'),
  _SidebarItem(label: 'Inflections', icon: Icons.auto_fix_high_outlined, path: '/grammar/inflections'),
  _SidebarItem(label: 'Typology', icon: Icons.language_outlined, path: '/grammar/typology'),
  // Phase 10 additions:
  _SidebarItem(label: 'Particles', icon: Icons.local_offer_outlined, path: '/grammar/particles'),
  _SidebarItem(label: 'Constructions', icon: Icons.format_list_bulleted, path: '/grammar/constructions'),
];
```

Wait — D-13 specifies the order as: POS & Dimensions, Inflections, **Particles** (new), **Constructions** (new), Typology. That puts Particles at index 2, Constructions at index 3, and Typology moves to index 4. This means Typology's index changes from 2 to 4, which affects any stored navigation state. The planner must decide whether to insert in the middle (D-13 order) or append (simpler). D-13 is locked, so Typology moves to index 4.

[VERIFIED: lib/features/grammar/presentation/grammar_shell.dart, 10-CONTEXT.md D-13]

### Pattern 2: Project_settings Auto-Save (for Typology Extension)
**What:** `writeTypologyKey(db, key, value)` uses update-then-insert upsert. `typologySettingsProvider` streams all project_settings and filters by key prefix. New word order keys follow the same `typology.*` namespace.

**Example:**
```dart
// Source: lib/features/grammar/data/typology_providers.dart
await writeTypologyKey(db, 'typology.head_direction', value);
await writeTypologyKey(db, 'typology.adposition_type', value);
await writeTypologyKey(db, 'typology.adj_placement', value);
await writeTypologyKey(db, 'typology.gen_placement', value);
```

`TypologySettings` value object needs new nullable String fields for the 3-4 new keys. Provider needs to read them from the stream.

[VERIFIED: lib/features/grammar/data/typology_providers.dart]

### Pattern 3: Drift DAO for New Tables
**What:** Each new table gets a `@DriftAccessor`-annotated DAO class registered in `AppDatabase`'s `daos:` list.

```dart
// Source: lib/features/lexicon/data/lexeme_dao.dart (pattern)
@DriftAccessor(tables: [MyTable])
class MyDao extends DatabaseAccessor<AppDatabase> with _$MyDaoMixin {
  MyDao(super.db);
  Stream<List<MyDataRow>> watchAll() => select(myTable).watch();
}
```

After any schema or DAO change, run: `dart run build_runner build --delete-conflicting-outputs`

[VERIFIED: lib/features/lexicon/data/lexeme_dao.dart, lib/db/app_database.dart]

### Pattern 4: Schema Migration Versioning
**What:** Current schema version is **14** (confirmed). Phase 10 adds:
- `lexemes.is_closed_class` (BoolColumn, default false)
- `lexemes.gloss_tag` (TextColumn, nullable)
- New `phrase_constructions` table
- New `construction_slots` table (or JSON-in-constructions column)

Version bumps to **15**. Migration block pattern:
```dart
// Source: lib/db/app_database.dart onUpgrade
if (from < 15) {
  await m.addColumn(lexemes, lexemes.isClosedClass);
  await m.addColumn(lexemes, lexemes.glossTag);
  await m.createTable(phraseConstructions);
  await m.createTable(constructionSlots);
}
```

[VERIFIED: lib/db/app_database.dart — schemaVersion = 14]

### Pattern 5: Drift StreamProvider for Reactive Data
**What:** All list providers follow this shape:
```dart
// Source: lib/features/lexicon/data/lexeme_providers.dart
final closedClassLexemeListProvider = StreamProvider<List<Lexeme>>((ref) {
  final dao = ref.watch(lexemeDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchClosedClassWords();
});
```

[VERIFIED: lib/features/lexicon/data/lexeme_providers.dart]

### Pattern 6: Live Preview Pattern (from RulesPage)
**What:** The rules page uses a separate panel to show live morphology preview. Construction rules need a similar preview. The preview for constructions substitutes: slot of type `glossTag` → first closed-class word with that tag; slot of type `POS abbreviation` → first lexeme with that POS.

[VERIFIED: lib/features/morphology/presentation/rules/rules_page.dart — pattern observed]

### Recommended New Table Shape for Constructions

**Option A — Two tables (recommended for relational integrity):**
```dart
class PhraseConstructions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();           // e.g. "Negation"
  IntColumn get ordering => integer().withDefault(const Constant(0))();
}

class ConstructionSlots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get constructionId =>
      integer().references(PhraseConstructions, #id, onDelete: KeyAction.cascade)();
  TextColumn get slotType => text()(); // 'gloss_tag' | 'pos_abbr'
  TextColumn get slotValue => text()(); // e.g. 'NEG', 'V', 'DEF'
  TextColumn get label => text().nullable()(); // optional display label
  IntColumn get ordering => integer().withDefault(const Constant(0))();
}
```

**Option B — JSON slots column (simpler, less relational):**
```dart
class PhraseConstructions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get slotsJson => text()(); // JSON array of slot objects
  IntColumn get ordering => integer().withDefault(const Constant(0))();
}
```

**Recommendation:** Use Option A (two tables). The slot editor adds/reorders/removes individual slots — having each slot as a separate row with an `ordering` column makes those CRUD operations cleaner and avoids JSON-parsing in DAO queries. Cascade delete on construction deletion handles cleanup automatically.

[ASSUMED — schema design choice. Option A follows established pattern from Dimensions table which stores levels JSON inline but the levels themselves are simple value types. Slots have identity (needed for reorder) so separate rows are better.]

### Anti-Patterns to Avoid
- **JSON slots in a single column:** Harder to reorder, query, and validate. Use separate ConstructionSlots table.
- **Separate lexeme table for particles:** D-02 is locked — particles MUST be in Lexemes table with a flag.
- **Custom route indexes:** GoRouter `indexedStack` branch order must exactly match `_sidebarItems` list order — any mismatch causes wrong page to render when sidebar item is tapped.
- **Forgetting build_runner:** Any Drift table change requires re-running code generation. Tasks that modify `app_database.dart` must include the build_runner step.
- **Inserting sidebar items in wrong position:** D-13 specifies Particles at position 3 (index 2) and Constructions at position 4 (index 3), pushing Typology to index 4. This order must be consistent between `_sidebarItems` and the router branches.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Auto-save on dropdown change | Manual save button + state management | `writeTypologyKey` upsert pattern | Already handles the update-then-insert race; used 3 times in existing Typology page |
| Reactive list updates | Polling / manual refresh | Drift `watch()` streams + StreamProvider | Drift streams auto-notify on DB writes; entire project uses this pattern |
| Slot reorder UI | Custom drag-and-drop from scratch | Flutter's `ReorderableListView` widget | Built into Flutter Material; handles drag handles, animations, index callbacks |
| POS lookup for grouping | Re-fetching POS from DB in render | `posListProvider` (already streams POS list) | Existing provider; closed-class words need POS name for section headers |
| DB code gen | Manual Drift companion classes | `dart run build_runner build --delete-conflicting-outputs` | Drift generates companion classes, DAO mixins, and table accessors automatically |

**Key insight:** The upsert pattern in `writeTypologyKey` is non-obvious (update-first, then insert if zero rows updated). Never write a new variant — always call the existing helper or copy its pattern exactly.

---

## Common Pitfalls

### Pitfall 1: Sidebar Index Mismatch
**What goes wrong:** `_sidebarItems` list position ≠ router branch order. Tapping "Particles" navigates to "Constructions" page (or vice versa) because `goBranch(index)` is position-based.
**Why it happens:** `_sidebarItems` is a const list in `grammar_shell.dart`; branches are defined in `app_router.dart`. They are coupled by position but maintained in two separate files.
**How to avoid:** Add sidebar items and router branches in the same plan task. Add a comment in both files cross-referencing the other.
**Warning signs:** Sidebar item tap navigates to the wrong content.

[VERIFIED: lib/features/grammar/presentation/grammar_shell.dart, lib/router/app_router.dart]

### Pitfall 2: Forgetting Build Runner After Schema Change
**What goes wrong:** Dart analyzer errors on `lexemes.isClosedClass` or Drift companion classes missing new fields.
**Why it happens:** Drift generates `_$AppDatabaseMixin` and companion classes via `app_database.g.dart`. Until regenerated, the new columns don't exist in code.
**How to avoid:** Every plan task that modifies `app_database.dart` must end with `dart run build_runner build --delete-conflicting-outputs`.
**Warning signs:** `The getter 'isClosedClass' isn't defined for the class 'Lexemes'` errors.

[VERIFIED: lib/db/app_database.dart — uses `part 'app_database.g.dart'`]

### Pitfall 3: Typology Index Shift Breaking Existing Navigation
**What goes wrong:** D-13 moves Typology from sidebar index 2 to index 4. Any test or cached navigation state that hard-codes `/grammar/typology` as branch index 2 will break.
**Why it happens:** GoRouter `StatefulShellRoute.indexedStack` maps branch index to position. The index is implicit in list order.
**How to avoid:** Update router tests that check branch ordering. The `grammar_router_test.dart` and `grammar_router_404_test.dart` files likely need updating.
**Warning signs:** Tests in `test/widget/grammar/grammar_router_test.dart` fail with wrong page displayed.

[VERIFIED: test/widget/grammar/grammar_router_test.dart — file exists]

### Pitfall 4: Closed-Class Words Appearing Twice in Unified Search
**What goes wrong:** If the search provider filters by `rootId IS NULL` (roots only), and closed-class words also have `rootId IS NULL`, they'll appear in both the Particles page and the main Dictionary.
**Why it happens:** D-02 stores particles in Lexemes with the existing CRUD path. `rootLexemeListProvider` watches `rootId IS NULL` without filtering closed-class.
**How to avoid:** After adding `isClosedClass` column, update `rootLexemeListProvider` (or `watchRoots()` in LexemeDao) to filter `WHERE is_closed_class = 0 OR is_closed_class IS NULL`. Particles page uses a separate query: `WHERE is_closed_class = 1`.
**Warning signs:** Particles appear in the main Dictionary word list.

[VERIFIED: lib/features/lexicon/data/lexeme_dao.dart — `watchRoots()` currently has no closed-class filter]

### Pitfall 5: Construction Slot Ordering with ReorderableListView
**What goes wrong:** After reordering slots via drag, the `ordering` column in `ConstructionSlots` is not updated, so on next load the original order is restored.
**Why it happens:** `ReorderableListView.onReorder` callback provides new indices but the caller must persist the new ordering to the database.
**How to avoid:** In `onReorder` callback, update all affected slot rows' `ordering` values. Since slot count is small (< 10 typically), a batch update of all slots is fine.

[ASSUMED — standard ReorderableListView pattern]

### Pitfall 6: Leipzig Gloss Tag Catalog Size
**What goes wrong:** Autocomplete dropdown becomes unwieldy if the catalog is exhaustive (Leipzig has 200+ abbreviations).
**Why it happens:** Full Leipzig standard is large.
**How to avoid:** Include the ~40-50 most commonly used abbreviations. D-04 allows custom tags, so completeness is not required. See Assumptions Log.

---

## Code Examples

### Adding a New Lexeme Column (Lexemes Table)
```dart
// Source: lib/db/app_database.dart — Lexemes class
// Add after existing columns:
BoolColumn get isClosedClass =>
    boolean().withDefault(const Constant(false))();
TextColumn get glossTag => text().nullable()();  // e.g. 'NEG', 'DEF', 'PROG'
```

### Watching Closed-Class Words in LexemeDao
```dart
// Source: pattern from lib/features/lexicon/data/lexeme_dao.dart
Stream<List<Lexeme>> watchClosedClassWords() =>
    (select(lexemes)
          ..where((t) => t.isClosedClass.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.partOfSpeech),
                     (t) => OrderingTerm.asc(t.ipa)]))
        .watch();
```

### Updating watchRoots to Exclude Closed-Class
```dart
// Source: lib/features/lexicon/data/lexeme_dao.dart
Stream<List<Lexeme>> watchRoots() =>
    (select(lexemes)
          ..where((t) => t.rootId.isNull() & t.isClosedClass.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.ipa)]))
        .watch();
```

### New TypologySettings with Word Order Fields
```dart
// Source: pattern from lib/features/grammar/data/typology_providers.dart
class TypologySettings {
  const TypologySettings({
    this.alignment,
    this.wordOrder,
    this.modality,
    // Phase 10 additions (D-11):
    this.headDirection,    // 'head_initial' | 'head_final' | 'mixed'
    this.adpositionType,   // 'preposition' | 'postposition' | 'circumposition'
    this.adjPlacement,     // 'prenominal' | 'postnominal'
    this.genPlacement,     // 'prenominal' | 'postnominal'
  });
  // ...existing fields...
  final String? headDirection;
  final String? adpositionType;
  final String? adjPlacement;
  final String? genPlacement;
}
```

### New project_settings keys (D-12 — structured data for Phase 12)
```
'typology.head_direction'   → 'head_initial' | 'head_final' | 'mixed'
'typology.adposition_type'  → 'preposition' | 'postposition' | 'circumposition'
'typology.adj_placement'    → 'prenominal' | 'postnominal'
'typology.gen_placement'    → 'prenominal' | 'postnominal'
```

### New GoRouter Branches (Grammar sub-shell)
```dart
// Source: lib/router/app_router.dart — Grammar branch (Phase 10 additions)
// Branch order must match _sidebarItems order in grammar_shell.dart (D-13):
// 0=POS, 1=Inflections, 2=Particles (NEW), 3=Constructions (NEW), 4=Typology

StatefulShellBranch(routes: [GoRoute(path: '/grammar/particles',
    builder: (_, _) => const ParticlesPage())]),
StatefulShellBranch(routes: [GoRoute(path: '/grammar/constructions',
    builder: (_, _) => const ConstructionsPage())]),
// Typology branch moves to index 4 (was 2):
StatefulShellBranch(routes: [GoRoute(path: '/grammar/typology',
    builder: (_, _) => const TypologyPage())]),
```

---

## Leipzig Glossing Catalog (for D-04)

Recommended catalog (~45 common abbreviations): [ASSUMED — standard Leipzig glossing standards]

| Abbreviation | Meaning | Category |
|---|---|---|
| DEF | Definite | Determination |
| INDF | Indefinite | Determination |
| NEG | Negation | Polarity |
| PROG | Progressive | Aspect |
| PERF | Perfective | Aspect |
| IPFV | Imperfective | Aspect |
| PRFV | Perfect | Aspect |
| PST | Past | Tense |
| PRS | Present | Tense |
| FUT | Future | Tense |
| AUX | Auxiliary | Modality/TAM |
| MOD | Modal | Modality |
| CAUS | Causative | Voice/Valence |
| PASS | Passive | Voice |
| REFL | Reflexive | Voice |
| RECIP | Reciprocal | Voice |
| TOP | Topic | Information |
| FOC | Focus | Information |
| EMPH | Emphatic | Pragmatics |
| Q | Question | Pragmatics |
| CONJ | Conjunction | Coordination |
| DISJ | Disjunction | Coordination |
| PREP | Preposition | Adposition |
| POST | Postposition | Adposition |
| GEN | Genitive | Case function |
| ACC | Accusative | Case function |
| DAT | Dative | Case function |
| LOC | Locative | Case function |
| COMP | Complementizer | Subordination |
| REL | Relativizer | Subordination |
| SUB | Subordinator | Subordination |
| PTCL | Particle | Generic |
| DET | Determiner | Determination |
| QUANT | Quantifier | Determination |
| INTJ | Interjection | Other |
| COP | Copula | TAM |
| EXIST | Existential | TAM |
| CERT | Certitude | Evidentiality |
| EV | Evidential | Evidentiality |
| QUOT | Quotative | Evidentiality |

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Separate morphology tab | Grammar tab reuses rule editor | Phase 4 | RulesPage widget is reusable pattern |
| Hard-coded sidebar items | Const list in GrammarShell | Phase 4 | Trivial to extend; just add to list |
| DropdownButtonFormField value: | initialValue: (deprecated `value:`) | Flutter 3.38 | Already uses `initialValue:` in TypologyPage — copy this |

[VERIFIED: lib/features/grammar/presentation/typology/typology_page.dart — comment on line 136 confirms Flutter 3.38 deprecation note]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Option A (two-table constructions) is preferred over JSON-in-column | Architecture Patterns — Schema Design | Low risk: either approach works. Two-table is cleaner for ordered CRUD. Could switch to JSON if planner prefers simpler schema. |
| A2 | Leipzig catalog of ~40-50 abbreviations is sufficient; no need for all 200+ | Leipzig Glossing Catalog | Low risk: D-04 explicitly allows custom tags, so an incomplete catalog is fine |
| A3 | `ReorderableListView` is the right widget for slot reordering | Don't Hand-Roll | Very low risk: it is the standard Flutter widget for this purpose |
| A4 | watchRoots() needs to exclude closed-class words | Common Pitfalls #4 | Medium risk: if the main Dictionary already excludes particles via another mechanism this is redundant, but the current code shows no such filter exists |

---

## Open Questions

1. **Construction Slots — Two Tables vs JSON Column**
   - What we know: two-table approach (Option A) follows the `Dimensions`/`Dimensions.levelsJson` precedent in spirit but uses proper relational rows; JSON approach is simpler.
   - What's unclear: the planner should confirm which approach to use in Plan 1 (schema migration task). Both work; choice affects the DAO complexity.
   - Recommendation: Use two-table (Option A). Reordering rows is cleaner than parsing + reserializing JSON.

2. **Anki Export for Closed-Class Words**
   - What we know: D-02 says "Anki export ... work[s] automatically." The export UI lives in `DictionaryPage` and currently exports selected root lexemes.
   - What's unclear: Does the user select particles for export from the Particles page? From the unified Anki selection in DictionaryPage? Or does the export automatically include all closed-class words?
   - Recommendation: The planner should ensure the Anki export selection is accessible for closed-class words too — either by making the Particles page have its own export button, or by making the DictionaryPage's export mode include all lexemes (including closed-class). D-02 says "automatic" which implies no extra work needed, but the UX should be verified.

3. **Grammar Router Tests Need Update**
   - What we know: `test/widget/grammar/grammar_router_test.dart` exists and likely tests the 3-branch Grammar navigation.
   - What's unclear: Exact test assertions (haven't read the test content).
   - Recommendation: The plan task that adds navigation must include updating/extending grammar router tests.

---

## Environment Availability

Step 2.6: SKIPPED — phase is code/config-only changes. No external services or CLI tools beyond the existing Flutter toolchain are required.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | pubspec.yaml (flutter_test dev dependency) |
| Quick run command | `flutter test test/unit/grammar/ --no-pub` |
| Full suite command | `flutter test --no-pub` |

[VERIFIED: pubspec.yaml, test/ directory structure]

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AGRAM-01 | LexemeDao correctly filters closed-class vs content words | unit | `flutter test test/unit/grammar/closed_class_dao_test.dart -x` | ❌ Wave 0 |
| AGRAM-01 | Schema v14→v15 migration adds isClosedClass + glossTag columns | integration | `flutter test test/integration/migration_v14_to_v15_test.dart -x` | ❌ Wave 0 |
| AGRAM-01 | Particles page renders words grouped by POS | widget | `flutter test test/widget/grammar/particles_page_test.dart -x` | ❌ Wave 0 |
| AGRAM-02 | PhraseConstruction CRUD creates/reads/deletes constructions and slots | unit | `flutter test test/unit/grammar/phrase_construction_dao_test.dart -x` | ❌ Wave 0 |
| AGRAM-02 | Construction slot ordering persists correctly | unit | `flutter test test/unit/grammar/construction_slot_order_test.dart -x` | ❌ Wave 0 |
| AGRAM-03 | New typology keys round-trip via writeTypologyKey/readTypologySettings | unit | `flutter test test/unit/grammar/typology_providers_test.dart -x` | ✅ (extend existing) |
| AGRAM-03 | Typology page renders new word order dropdowns | widget | `flutter test test/widget/grammar/typology_page_test.dart -x` | ✅ (extend existing) |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/grammar/ --no-pub`
- **Per wave merge:** `flutter test --no-pub`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/unit/grammar/closed_class_dao_test.dart` — covers AGRAM-01 (DAO filter)
- [ ] `test/integration/migration_v14_to_v15_test.dart` — covers AGRAM-01 schema migration
- [ ] `test/widget/grammar/particles_page_test.dart` — covers AGRAM-01 UI
- [ ] `test/unit/grammar/phrase_construction_dao_test.dart` — covers AGRAM-02 CRUD
- [ ] `test/unit/grammar/construction_slot_order_test.dart` — covers AGRAM-02 ordering
- Existing tests `typology_providers_test.dart` and `typology_page_test.dart` need new assertions for Phase 10 keys (extend in-place, do not create new files)

---

## Security Domain

`security_enforcement` key is absent from `.planning/config.json` — treated as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | Gloss tag + slot value field length validation; POS name inputs |
| V6 Cryptography | no | — |

### Known Threat Patterns for Flutter/Drift Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| SQL injection via gloss tag text | Tampering | Drift parameterized queries — all values bound as parameters, never string-concatenated into SQL |
| Malformed JSON in slotsJson (if Option B used) | Tampering | Wrap `jsonDecode` in try/catch; return empty list on FormatException. Same pattern as `decodeSkippedDimensionIds` in typology_providers.dart |
| Unbounded gloss tag length | Denial of Service | Add client-side maxLength constraint on text field (e.g. 20 chars for a gloss tag) |

---

## Sources

### Primary (HIGH confidence)
- `lib/features/grammar/presentation/grammar_shell.dart` — sidebar structure, confirmed 3 items
- `lib/router/app_router.dart` — GoRouter grammar branch, confirmed 3 StatefulShellBranch entries
- `lib/features/grammar/data/typology_providers.dart` — TypologySettings, writeTypologyKey, project_settings pattern
- `lib/features/grammar/presentation/typology/typology_page.dart` — DropdownButtonFormField auto-save pattern
- `lib/db/app_database.dart` — schemaVersion=14, Lexemes table definition, migration pattern
- `lib/features/lexicon/data/lexeme_dao.dart` — LexemeDao CRUD, watchRoots filter
- `lib/features/lexicon/data/lexeme_providers.dart` — StreamProvider pattern for lexemes
- `lib/features/lexicon/data/anki_exporter.dart` — AnkiExportEntry shape
- `pubspec.yaml` — dependency versions
- `test/unit/grammar/typology_providers_test.dart` — test pattern (NativeDatabase.memory())
- `test/integration/migration_v8_to_v9_test.dart` — migration integration test pattern

### Secondary (MEDIUM confidence)
- `lib/features/morphology/presentation/rules/rules_page.dart` — RulesPage pattern for live preview inspiration
- `test/widget/grammar/grammar_router_test.dart` — confirms router tests exist (content not fully read)

### Tertiary (LOW confidence / Assumed)
- Leipzig glossing abbreviation catalog — based on training knowledge of standard Leipzig glossing conventions
- Two-table vs JSON choice for ConstructionSlots — reasoning from established patterns

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all versions verified from pubspec.yaml
- Architecture: HIGH — all pattern files read directly from codebase
- Schema design: HIGH (existing patterns) / MEDIUM (new Constructions table design)
- Pitfalls: HIGH — verified against actual code (sidebar index coupling, watchRoots filter, build_runner requirement)
- Leipzig catalog: LOW — training knowledge, not verified against authoritative source

**Research date:** 2026-04-13
**Valid until:** 2026-05-13 (stable Flutter/Drift stack, low churn)
