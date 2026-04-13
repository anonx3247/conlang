# Architecture

**Analysis Date:** 2026-04-12

## Pattern Overview

**Overall:** Feature-driven clean architecture with cross-cutting shell navigation and reactive state management.

**Key Characteristics:**
- Feature-first organization (Phonology, Grammar, Lexicon, Morphology, Project, Glossary)
- Layered within each feature (data/presentation/domain, or data/application/domain for morphology)
- Riverpod for state management and dependency injection
- Go Router for navigation with StatefulShellRoute for tab-based layouts
- Drift ORM for SQLite database persistence with typed DAOs
- Reactive StreamProviders for real-time data binding across features

## Layers

**Presentation:**
- Purpose: UI widgets, pages, shells, and dialogs
- Location: `lib/features/*/presentation/`
- Contains: Feature pages, sub-shells (sidebar layouts), dialogs, shared widgets
- Depends on: Domain (for types), Riverpod providers, go_router
- Used by: Go Router for page routing

**Data (Repositories & DAOs):**
- Purpose: Database access, caching, and data transformation
- Location: `lib/features/*/data/`
- Contains: Drift DAOs (e.g., `GrammarDao`, `PhonemeDao`), Riverpod providers, codecs for JSON serialization
- Depends on: Database (`lib/db/app_database.dart`), Domain (for types)
- Used by: Presentation layer via Riverpod providers

**Domain (Business Logic):**
- Purpose: Core business rules, algorithms, and type definitions
- Location: `lib/features/*/domain/`
- Contains: Paradigm engine, DSL parsing, type definitions (e.g., `ParadigmCell`, `InflectionalRule`), result types
- Depends on: Nothing (pure Dart)
- Used by: Data layer for computations, Presentation for display logic

**Application (Orchestration):**
- Purpose: Multi-layer coordination (specific to morphology feature)
- Location: `lib/features/morphology/application/`
- Contains: Service orchestrators that coordinate data and domain layers
- Depends on: Data and Domain layers
- Used by: Presentation layer

**Shared/Router:**
- Purpose: Cross-cutting concerns (navigation, UI utilities)
- Location: `lib/shared/`, `lib/router/`
- Contains: Global app shell, tab bar, glossary drawer, router configuration
- Depends on: All features (for imports)
- Used by: main.dart and all features

## Data Flow

**Project Initialization:**

1. User opens app → `main.dart` initializes `ProviderScope` with `ConlangApp`
2. `AppShell` watches `currentProjectIdProvider` (null initially)
3. User clicks File > Open/Create → `ProjectMenu` via `ProjectRegistry` opens project
4. `currentProjectIdProvider` state is set to project ID
5. `projectDatabaseProvider(projectId)` creates `AppDatabase` connection
6. All feature DAOs activate via `currentDatabaseProvider` watch chain

**Grammar Paradigm Computation:**

1. User views lexeme in Dictionary → `DictionaryPage` watches `currentLexemeProvider`
2. Presentation triggers `computedInflectedParadigmProvider(lexemeId, posId)` watch
3. Provider chain resolves:
   - `dimensionsForPosProvider(posId)` → stream of dimensions
   - `inflectionalRulesForPosProvider(posId)` → stream of rules
   - `markersForPosProvider(posId)` → stream of markers
   - `phonemeInventoryProvider` → phoneme/natural class inventory
4. `paradigmEngineProvider` computes each cell via `computeParadigmCell()`
5. Result is a `ParadigmCell` per feature set (shows form or failure reason)
6. Presentation renders paradigm table with cell data

**Rule Matching Algorithm (Feature Consumption):**

1. Input: target feature set (e.g., {dim1: level2, dim2: level3})
2. Filter: keep only active inflectional rules with non-empty bindings
3. Loop until no remaining features:
   - Find rules whose binding dims are subset of remaining
   - Select highest-specificity group (compare |binding.dims| size)
   - On conflict (2+ rules with identical binding at same specificity) → return Ambiguous
   - Try candidates in order: parse DSL → apply via `MorphologyEngine`
   - First success updates working form and removes consumed dims
   - No success → return Uncovered (partial if chain non-empty)
4. On completion → return Filled with working form and rule chain

**Morphology DSL Application:**

1. Input: working form (IPA string), parsed rule (e.g., "p->f / V_V")
2. Tokenize form into phoneme segments
3. Match pattern against all positions
4. On match: apply transformation, phonology rules, check syllable constraints
5. Return `MorphSuccess(newForm)` or `MorphNoMatch(reason)`

**Reactive Updates:**

- StreamProviders (e.g., `phonemesForInventoryProvider`) emit new data on database changes
- Presentation layers listen via `.watch()` and rebuild on change
- Cascading invalidation: changing a dimension invalidates all dependent paradigm computations

## Key Abstractions

**FeatureSet:**
- Purpose: Identifies a paradigm cell as a map of dimension ID → level ID
- Examples: `{1: 2, 3: 5}` = "Dim 1 Level 2, Dim 3 Level 5"
- Pattern: Lightweight value type, used as paradigm table key

**ParadigmCell:**
- Purpose: Result of computing a single cell in a word's inflectional paradigm
- Examples: `ParadigmFilled(working: "fɛ", chain: [rule1, rule2])`, `ParadigmUncovered(reason: "no rule matches")`
- Pattern: Sealed class (Dart 3.0) for exhaustive pattern matching

**InflectionalRule:**
- Purpose: Grammar rule that transforms a word form based on grammatical features
- Examples: "Plural -s", "Past tense -ed"
- Pattern: Contains name, DSL source, feature bindings (`FeatureBindings`), ordering
- Stored in: `MorphologicalRules` table (filtered by `kind == 'inflectional'`)

**FeatureBindings:**
- Purpose: Maps grammar dimensions to specific levels a rule targets
- Examples: `{dims: {1: 2}, pos: [3]}` = "when Dim 1 has Level 2 (and POS is 3)"
- Pattern: Serialized as JSON in `MorphologicalRules.featureBindings`
- Related: `FeatureBindingsConverter` for JSON codecs

**Dimension:**
- Purpose: One grammatical axis (e.g., Number, Gender) for a POS
- Examples: "Singular", "Plural" (levels within Number dimension)
- Pattern: Levels stored as JSON array in `levelsJson` (hybrid storage D-A6)
- Intrinsic flag: When true, dimension is inherent to the word (not inflected)

**ParadigmChart:**
- Purpose: A multi-dimensional inflectional table for a lexeme
- Pattern: Keys are feature set JSON strings, values are paradigm cells
- Used by: TypologyPage to display inflection matrices

## Entry Points

**main.dart:**
- Location: `lib/main.dart`
- Triggers: Application startup
- Responsibilities: Initialize Flutter bindings, audio kit, window manager, run ProviderScope

**app.dart (ConlangApp):**
- Location: `lib/app.dart`
- Triggers: Entry point widget for ProviderScope
- Responsibilities: Configure MaterialApp.router, apply dark theme, provide appRouterProvider

**AppShell:**
- Location: `lib/shared/widgets/app_shell.dart`
- Triggers: Root StatefulShellRoute builder
- Responsibilities: Render top-level tab bar (Phonology/Grammar/Lexicon), project menu, empty state when no project

**Feature Shells (PhonologyShell, GrammarShell, LexiconShell):**
- Location: `lib/features/{feature}/presentation/{feature}_shell.dart`
- Triggers: Branch builders for each major feature
- Responsibilities: Left sidebar with sub-tabs, Glossary integration, route all sub-pages

**Feature Pages (InventoryPage, TypologyPage, DictionaryPage, etc.):**
- Location: `lib/features/{feature}/presentation/{section}/{section}_page.dart`
- Triggers: GoRoute builders
- Responsibilities: Render feature-specific content, dispatch to sub-widgets

## Error Handling

**Strategy:** Try-catch for JSON parsing, null-coalescing for provider chain breaks.

**Patterns:**

1. **JSON Deserialization:**
   ```dart
   // In intrinsic_levels_codec.dart
   try {
     return raw.map((k, v) => MapEntry(int.parse(k as String), v as int));
   } catch (_) {
     return {}; // Malformed JSON → empty map (safe fallback)
   }
   ```

2. **Provider Nullability:**
   ```dart
   // In phoneme_providers.dart
   final dao = ref.watch(phonemeDaoProvider);
   if (dao == null) return Stream.value([]); // No project open → empty stream
   return dao.watchConsonants();
   ```

3. **Database Async Operations:**
   ```dart
   // In project_providers.dart
   Future<void> open(String id) async {
     final docsDir = await ref.read(appDocsDirProvider.future);
     final dbPath = p.join(docsDir, id, 'project.db');
     await prepareProjectDb(dbPath); // Backup pre-v8 schemas
     state = id;
   }
   ```

4. **DSL Parse Failures:**
   - Morphology DSL parse errors → return `MorphNoMatch(reason: "...")`
   - Paradigm cell computation treats parse failure as "rule doesn't match"
   - No exception thrown; failure is a first-class result type

5. **Hard 404 on Retired Routes:**
   ```dart
   // In app_router.dart
   errorBuilder: (context, state) => _show404Scaffold(state.uri.toString())
   // Old routes like /grammar/paradigm land here with "Back to Grammar" button
   ```

## Cross-Cutting Concerns

**Logging:** Console via `print()` (no external framework; debug annotations in code)

**Validation:** DSL parsers use result types (not exceptions); phone number/IPA validation via regex in domain layer

**Authentication:** Not applicable (single-user desktop app)

**Glossary Integration:** Lazy-drawn side panel via `glossaryOpenProvider` and `glossaryCategoryFilterProvider`; rendered by all feature shells

**Audio Playback:** Just Audio with media_kit for Windows/Linux; initialized in main.dart before app startup (Pitfall 4)

**Romanization:** Optional post-processing of IPA; stored in `RomanizationMappings` table; watch via `romanizationProvider`

**Project Isolation:** Each project gets a unique SQLite database in `{appDocsDir}/{projectId}/project.db`; database connection scoped via Riverpod family provider per project ID

---

*Architecture analysis: 2026-04-12*
