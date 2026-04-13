# Coding Conventions

**Analysis Date:** 2026-04-12

## Language & Tooling

**Language:** Dart 3.10.4+
**Framework:** Flutter
**Linting:** flutter_lints 6.0.0 with custom rule overrides
**Formatting:** Configured via `analysis_options.yaml`

## Naming Patterns

**Files:**
- snake_case for all `.dart` files
- Examples: `paradigm_engine.dart`, `feature_bindings.dart`, `grammar_providers.dart`
- Test files: `{feature}_test.dart` (e.g., `paradigm_engine_test.dart`, `marker_dao_test.dart`)

**Classes:**
- PascalCase for all classes, including page widgets, DAOs, domain models
- Examples: `InflectionalRule`, `MarkerDao`, `FeatureBindings`, `ParadigmEngine`, `ProjectSelectorDialog`
- Private classes: prefix with underscore, still PascalCase (e.g., `_ProjectTile`, `_SidebarItem`)
- Suffix patterns:
  - `*Dao` for Drift data access objects (`GrammarDao`, `MarkerDao`)
  - `*Dialog` for dialog widgets (`ProjectSelectorDialog`, `RuleEditorDialog`)
  - `*Page` for page-level widgets (`InflectionalRulesPage`, `ParadigmViewerPage`)
  - `*Provider` for Riverpod providers (`grammarDaoProvider`, `dimensionTemplatesProvider`)
  - `*Shell` for navigation shells (`GrammarShell`, `LexiconShell`)

**Functions & Methods:**
- camelCase for all function and method names
- Start with action verbs for methods that perform operations: `insertMarker`, `updateMarker`, `deleteMarker`, `watchMarkersForPos`
- Getter methods: use `get` keyword or descriptive property names (e.g., `specificity`, `isInflectional`, `isDerivational`)
- Private functions: prefix with underscore (e.g., `_rule()`, `_dim()`, `_loadProjects()`, `_formatDate()`)
- Async functions: use `Future<T>` return type clearly in signature (e.g., `Future<int> insertMarker(...)`, `Future<void> updateMarker(...)`)

**Variables & Constants:**
- camelCase for local variables and parameters
- SCREAMING_SNAKE_CASE for constants that are truly immutable (rare in this codebase)
- Suffix patterns:
  - `*Id` for integer identifiers (e.g., `posNounId`, `dimGender`, `lvlM`)
  - `*Map` / `*List` / `*Set` for collection variables (e.g., `ruleChain`, `nounMarkers`)
- Private variables: prefix with underscore in StatefulWidget state (e.g., `_projects`, `_loading`, `_error`)

**Types & Generics:**
- Use explicit type annotations where clarity matters
- Example from `FeatureBindings`: `Map<int, int> dims` clearly indicates dimension ID → level ID mapping
- Stream/Future parameters: fully qualify (e.g., `Stream<List<MarkerDecl>>`, `Future<void>`)

## Import Organization

**Order (enforced by linting):**
1. `dart:` imports (core libraries)
2. `package:` imports (external packages)
3. Relative imports using `../` (internal files)

**Grouping:**
- Each group separated by blank line
- No blank line within a group — alphabetize imports within groups

**Example from `grammar_dao.dart`:**
```dart
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../domain/dimension_level.dart';
import '../domain/level_deletion_report.dart';
import 'intrinsic_levels_codec.dart';
```

**Path Aliases:**
- No path aliases configured; all relative imports use `../` traversal
- Imports always specify full relative path from current file

## Code Style

**Formatting Rules:**
- `prefer_single_quotes: true` — Use single quotes for strings (not double quotes)
- `avoid_print: true` — Never use `print()` for debugging in production code
- `prefer_const_constructors: true` — Mark constructors const where possible
- `prefer_const_literals_to_create_immutables: true` — Use const literals for collections

**Class Structure:**
- Constructor at top of class
- Final fields declared with type annotation
- Getter methods (`get` keyword) for computed properties
- Factory constructors for construction patterns (e.g., `InflectionalRule.fromDbRow()`)
- `copyWith()` method for immutable value objects (e.g., `FeatureBindings.copyWith()`)
- Operator overrides (`==`, `hashCode`) for value-semantic classes

**Method & Function Sizing:**
- Keep functions focused on single responsibility
- Long procedures broken into helper functions with clear names
- Builder functions or setUp helpers extracted from test methods

**Async/Await:**
- Always use `async`/`await` syntax over `.then()` chains
- Mark methods with `Future<T>` return type when asynchronous
- Use `Stream<T>` explicitly for streaming operations (Drift `.watch()`)

## Comments

**Documentation Comments:**
- Use `///` for public API documentation (classes, methods, properties)
- Required for:
  - All public classes and their purpose
  - Complex factory methods
  - Non-obvious getter semantics
  - Any method with subtle behavior or gotchas

**Example from `InflectionalRule`:**
```dart
/// View-model wrapping a Drift [db.MorphologicalRule] row with its
/// [FeatureBindings] already parsed, suitable for paradigm engine use.
///
/// This type is non-Drift-dependent at call sites — the paradigm engine
/// consumes `List<InflectionalRule>` without touching SQL.
///
/// Only construct via [InflectionalRule.fromDbRow] after verifying the
/// source row has `kind == 'inflectional'`. Passing a derivational row is
/// an assertion failure in debug builds.
class InflectionalRule { ... }
```

**Implementation Comments:**
- Use `//` for inline explanations of why, not what
- Section separators: `// ---------------------------------------------------------------------------` (80 chars)
- Used to group related methods in DAOs and providers (reads section, writes section)
- Context comments: Reference planning documents (e.g., `// D-10 step 3`, `// Plan 04-15 D-78`)

**Example section separator from `marker_dao.dart`:**
```dart
  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Streams every marker bound to [posId]...
  Stream<List<MarkerDecl>> watchMarkersForPos(int posId) { ... }
```

**What NOT to Comment:**
- Obvious code (e.g., `i++` in a loop)
- Getters that directly return a field
- Names that are self-documenting

## Error Handling

**Strategy:**
- Explicit error handling in async contexts using try/catch
- Silent catches (`catch (_)`) only when error is truly non-fatal and documented in comment
- Mounted checks in StatefulWidget state updates to prevent memory leaks

**Pattern from `ProjectSelectorDialog`:**
```dart
Future<void> _loadProjects() async {
  try {
    final registry = await widget.ref.read(projectRegistryProvider.future);
    final projects = await registry.listProjects();
    if (mounted) {
      setState(() {
        _projects = projects;
        _loading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _error = 'Failed to load projects: $e';
        _loading = false;
      });
    }
  }
}
```

**Assertions:**
- Use `assert()` for invariant checking in debug builds only
- Only in situations where failure indicates a programming error, not runtime data issue

**Example from `InflectionalRule.fromDbRow`:**
```dart
assert(
  row.kind == 'inflectional',
  'InflectionalRule.fromDbRow called on non-inflectional row '
  '(id=${row.id}, kind=${row.kind})',
);
```

## Validation & Null Safety

**Null Coalescing:**
- Use `??` for default values when null is possible
- Use `?.` for safe navigation on nullable types
- Non-nullable fields must be initialized in constructor with `required`

**Required Parameters:**
- All constructor parameters that are essential marked `required`
- Optional parameters with defaults come after required ones

**Defensive Returns:**
- Null-coalescing in provider pattern: return `Stream.value(const [])` when dependent resource is null
- Prevents null pointer exceptions in dependent providers

**Example from `grammar_providers.dart`:**
```dart
final dimensionsForPosProvider =
    StreamProvider.family<List<Dimension>, int>((ref, posId) {
  final dao = ref.watch(grammarDaoProvider);
  if (dao == null) return Stream.value(const []);  // Return empty stream, not null
  return dao.watchDimensionsForPos(posId);
});
```

## Module Design

**Exports:**
- No barrel files (index.dart) currently used
- Direct imports from feature modules required

**Package Structure:**
- Features organized under `lib/features/{feature}` with clear sub-directories:
  - `domain/` — Pure business logic, value objects, interfaces
  - `data/` — DAOs, providers, external service adapters
  - `presentation/` — UI widgets, dialogs, pages

**Example Feature Structure (`grammar`):**
```
lib/features/grammar/
├── domain/
│   ├── inflectional_rule.dart
│   ├── feature_bindings.dart
│   └── paradigm_engine.dart
├── data/
│   ├── grammar_dao.dart
│   ├── grammar_providers.dart
│   └── marker_dao.dart
└── presentation/
    ├── grammar_shell.dart
    ├── inflectional_rules/
    └── paradigm_viewer/
```

## Riverpod State Management

**Provider Naming:**
- DAO providers: `{entity}DaoProvider` (e.g., `grammarDaoProvider`)
- Stream providers: `{entity}ForXxxProvider` (e.g., `dimensionsForPosProvider`, `markersForPosProvider`)
- Computed providers: Clear verb phrases (e.g., `computedInflectedParadigmProvider`)

**Provider Declaration:**
- Hand-written `Provider` and `StreamProvider` for Drift-generated types (due to codegen limitations)
- Can use `@riverpod` annotation for pure Dart functions (no Drift types involved)
- All Drift DAOs wrapped in provider for dependency injection and lazy initialization

**Provider Pattern:**
```dart
final grammarDaoProvider = Provider<GrammarDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db?.grammarDao;
});
```

## Testing-Specific Conventions

See `TESTING.md` for full testing guidance. Key conventions:
- Test function naming: `test('description of expected behavior', () { ... })`
- Fixture data: Defined at module scope with descriptive underscore prefixes (e.g., `_inventory`, `fixtureA`)
- Helper functions for test data construction: Private functions with clear names (e.g., `_rule()`, `_dim()`)

---

*Convention analysis: 2026-04-12*
