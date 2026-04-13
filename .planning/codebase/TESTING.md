# Testing Patterns

**Analysis Date:** 2026-04-12

## Test Framework

**Runner:**
- `flutter_test` (Dart's testing framework, bundled with Flutter SDK)
- Config: No separate `flutter_test.yaml`; uses default Flutter test runner

**Assertion Library:**
- Dart's built-in `expect()` function from `flutter_test`
- Matchers: `equals()`, `isA()`, `isEmpty`, `isNotEmpty`, `greaterThan()`, `hasLength()`, `isFalse`, `isTrue`, etc.

**Run Commands:**
```bash
flutter test                    # Run all tests in test/ directory
flutter test test/unit/grammar  # Run tests in specific directory
flutter test --watch           # Watch mode — re-run on file changes
flutter test --coverage        # Generate coverage report
```

## Test File Organization

**Location:**
- Co-located in `test/` directory parallel to `lib/`
- Mirrors feature structure: `test/unit/{feature}/{entity}_test.dart`

**Naming:**
- Test files: `{entity_name}_test.dart`
- Examples: `marker_dao_test.dart`, `paradigm_engine_test.dart`, `notation_helpers_test.dart`, `typology_providers_test.dart`

**Structure:**
```
test/
├── unit/
│   ├── grammar/
│   │   ├── marker_dao_test.dart
│   │   ├── paradigm_engine_test.dart
│   │   ├── paradigm_engine_rewrite_test.dart
│   │   └── ...
│   ├── morphology/
│   ├── lexicon/
│   ├── phonology/
│   └── project/
```

## Test Structure

**Imports:**
```dart
import 'package:conlang_workbench/features/grammar/data/marker_dao.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
```

**Top-Level Organization:**
```dart
void main() {
  // Late-binding setUp variables
  late AppDatabase db;
  late MarkerDao dao;
  late int posNounId;

  setUp(() async {
    // Initialize test database and fixtures
    db = AppDatabase(NativeDatabase.memory());
    dao = db.markerDao;
    posNounId = await db.into(db.partsOfSpeech).insert(...);
  });

  tearDown(() async {
    // Clean up resources
    await db.close();
  });

  group('MarkerDao', () {
    test('description of what should happen', () async {
      // Arrange: prepare test data
      // Act: call the function under test
      // Assert: check the result
    });
  });
}
```

**Suite Organization:**
- Single `void main()` function wrapping all tests
- Late-binding variables for shared test fixtures using `late` keyword
- `setUp()` / `tearDown()` lifecycle hooks for initialization/cleanup
- `group()` to logically organize related tests by feature or class
- Tests are defined inside groups with `test()` function

**Example from `marker_dao_test.dart`:**
```dart
void main() {
  late AppDatabase db;
  late MarkerDao dao;
  late int posNounId;
  late int posVerbId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.markerDao;
    posNounId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    posVerbId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('MarkerDao', () {
    test('insertMarker writes a row with the given bindings', () async {
      final id = await dao.insertMarker(
        posId: posNounId,
        bindings: const FeatureBindings(pos: [], dims: {5: 2}),
      );
      expect(id, greaterThan(0));

      final rows = await db.select(db.markers).get();
      expect(rows, hasLength(1));
      expect(rows.first.posId, equals(posNounId));
      expect(rows.first.featureBindings.dims, equals({5: 2}));
    });
  });
}
```

## Async Testing

**Pattern:**
- All async operations must complete before assertions
- Use `await` for `Future`-returning operations
- Use `.first` on `Stream` to get first emission and complete

**Examples:**

```dart
// DAO test with Future
test('insertMarker writes a row', () async {
  final id = await dao.insertMarker(
    posId: posNounId,
    bindings: const FeatureBindings(pos: [], dims: {5: 2}),
  );
  expect(id, greaterThan(0));
});

// Stream test — take first emission
test('watchMarkersForPos emits only markers for the requested POS', () async {
  await dao.insertMarker(...);
  
  final nounMarkers = await dao.watchMarkersForPos(posNounId).first;
  expect(nounMarkers, hasLength(1));
  expect(nounMarkers.first.bindings.dims, equals({5: 2}));
});
```

## Mocking

**Database Mocking:**
- Use `NativeDatabase.memory()` for in-memory SQLite testing
- No mocking framework; Drift DAOs are tested with real (in-memory) database
- Supports full schema validation without hitting disk

**Pattern:**
```dart
late AppDatabase db;

setUp(() async {
  db = AppDatabase(NativeDatabase.memory());
  // Database is fresh and empty for each test
});

tearDown(() async {
  await db.close();
});
```

**What to Mock:**
- External async dependencies (file I/O, network) — use mocking framework if needed
- Time/DateTime — inject dependencies or use test-friendly wrappers

**What NOT to Mock:**
- Database layer — use in-memory SQLite instead
- Pure domain logic — test against real implementations
- Riverpod providers — test by reading from ProviderContainer if needed

## Fixtures and Factories

**Test Data:**
- Inline constant construction for small fixtures
- Helper functions for complex object construction

**Example constant fixture from `paradigm_engine_test.dart`:**
```dart
final _inventory = PhonemeInventory(
  consonants: const ['k', 't', 'b', 'n', 's', 'r'],
  vowels: const ['a', 'e', 'i', 'o', 'u'],
  naturalClasses: const {
    'c': ['k', 't', 'b', 'n', 's', 'r'],
    'v': ['a', 'e', 'i', 'o', 'u'],
    'vowel': ['a', 'e', 'i', 'o', 'u'],
  },
);
```

**Helper Function Pattern from `paradigm_engine_test.dart`:**
```dart
InflectionalRule _rule(
  int id,
  String name,
  String source,
  Map<int, int> dims, {
  bool isActive = true,
}) {
  return InflectionalRule(
    id: id,
    name: name,
    source: source,
    isActive: isActive,
    bindings: FeatureBindings(pos: const [], dims: dims),
  );
}

// Usage in tests
final rules = [
  _rule(1, '-s', '+s', const {dimNumber: lvlPL}),
  _rule(2, '-o', '+o', const {dimGender: lvlM}),
  _rule(3, '-is', '+is', const {dimGender: lvlM, dimNumber: lvlPL}),
];
```

**Multi-Fixture Pattern from `notation_helpers_test.dart`:**
```dart
final List<NotationMapping> fixtureA = <NotationMapping>[
  (ipaSymbol: 'a', latinMapping: 'a'),
  (ipaSymbol: 't', latinMapping: 't'),
  (ipaSymbol: 'h', latinMapping: 'h'),
  (ipaSymbol: 'θ', latinMapping: 'th'),
];

// Each fixture used in separate group
group('Fixture A — canonical D-78 (t, h, th)', () {
  test('dotAwareDeromanize("atha") → "aθa"', () {
    expect(dotAwareDeromanize('atha', fixtureA), equals('aθa'));
  });
});
```

**Database Fixtures:**
- Insert test rows directly in setUp using Drift
- No factory builders; direct `.insert()` calls maintain clarity

**Example from `typology_providers_test.dart`:**
```dart
setUp(() async {
  db = AppDatabase(NativeDatabase.memory());
  posNounId = await db.into(db.partsOfSpeech).insert(
        PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
      );
});
```

## Test Categories

**Unit Tests:**
- Pure domain logic with no side effects (`paradigm_engine_test.dart`, `notation_helpers_test.dart`)
- DAO/provider tests with in-memory database
- Location: `test/unit/{feature}/{entity}_test.dart`
- No Flutter binding required for pure tests

**DAO & Database Tests:**
- Test data persistence using in-memory SQLite
- Cover CRUD operations explicitly
- Verify that streams emit correct data on state changes

**Example from `marker_dao_test.dart` — All CRUD operations:**
```dart
group('MarkerDao', () {
  test('insertMarker writes a row with the given bindings', () async {
    // CREATE
    final id = await dao.insertMarker(...);
    final rows = await db.select(db.markers).get();
    expect(rows.first.featureBindings.dims, equals({5: 2}));
  });

  test('watchMarkersForPos emits only markers for the requested POS', () async {
    // READ (streaming)
    await dao.insertMarker(posId: posNounId, bindings: ...);
    final markers = await dao.watchMarkersForPos(posNounId).first;
    expect(markers, hasLength(1));
  });

  test('updateMarker replaces the feature bindings', () async {
    // UPDATE
    final id = await dao.insertMarker(posId: posNounId, bindings: ...);
    await dao.updateMarker(id, const FeatureBindings(...));
    final list = await dao.watchMarkersForPos(posNounId).first;
    expect(list.first.bindings.dims, equals(...));
  });

  test('deleteMarker removes the row', () async {
    // DELETE
    final id = await dao.insertMarker(...);
    final removed = await dao.deleteMarker(id);
    expect(removed, equals(1));
  });
});
```

**Provider Tests:**
- Test Riverpod providers with real database backend
- Verify that providers respond to state changes

**Example from `typology_providers_test.dart`:**
```dart
test('readTypologySettings returns defaults when project_settings empty', () async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final settings = await readTypologySettings(db);
  expect(settings.alignment, isNull);
  expect(settings.wordOrder, isNull);
  expect(settings.modality, isNull);
});

test('writeTypologyKey then readTypologySettings round-trip', () async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await writeTypologyKey(db, 'typology.alignment', 'nom_acc');
  await writeTypologyKey(db, 'typology.alignment', 'nom_acc');  // upsert
  final settings = await readTypologySettings(db);
  expect(settings.alignment, equals('nom_acc'));
});
```

**Integration Tests:**
- Not currently present; all tests are unit/domain tests
- Future integration tests could test features end-to-end with ProviderContainer

## Error Testing

**Pattern:**
- Use `expect()` with `throws` matcher for exception testing (not yet seen in codebase)
- Prefer testing error conditions through result types or error states

**Expected Pattern (following Dart conventions):**
```dart
test('insertMarker with null posId throws AssertionError', () {
  expect(
    () async => await dao.insertMarker(posId: -1, bindings: ...),
    throwsAssertionError,
  );
});
```

## Test Execution

**Running Tests:**
```bash
# Run all tests
flutter test

# Run tests in one directory
flutter test test/unit/grammar

# Run tests matching a pattern
flutter test --name "MarkerDao"

# Run with coverage
flutter test --coverage

# View coverage report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

**Coverage:**
- No explicit coverage requirement configured
- Coverage reports can be generated but are not enforced in CI/pre-commit

## Common Test Patterns

**Testing Stream Emissions:**
```dart
// Take first emission from stream and verify
final markers = await dao.watchMarkersForPos(posId).first;
expect(markers, hasLength(2));

// Verify stream reflects deletions
await dao.deleteMarker(id);
final listAfter = await dao.watchMarkersForPos(posId).first;
expect(listAfter, isEmpty);
```

**Testing Round-Trip Serialization:**
```dart
test('toJson/fromJson round-trip', () {
  const a = ParadigmAxes(rows: 10, cols: 11, tabs: [12, 13]);
  final json = a.toJson();
  expect(json['rows'], equals(10));
  expect(ParadigmAxes.fromJson(json), equals(a));
});

test('JSON string round-trip', () {
  const a = ParadigmAxes(rows: 1, cols: 2, tabs: [3]);
  expect(
    ParadigmAxes.fromJsonString(a.toJsonString()),
    equals(a),
  );
});
```

**Testing with Multiple Fixtures:**
```dart
group('Fixture A — canonical case', () {
  test('case 1', () {
    expect(dotAwareDeromanize('atha', fixtureA), equals('aθa'));
  });
});

group('Fixture B — collisions', () {
  test('case 1', () {
    expect(smartRomanize('sh', fixtureB), equals('s.h'));
  });
});
```

**Testing Edge Cases & Defensive Behavior:**
```dart
group('Empty + edge cases', () {
  test('empty mapping list acts as identity', () {
    expect(
      dotAwareDeromanize('hello', const <NotationMapping>[]),
      equals('hello'),
    );
  });

  test('empty input strings round-trip', () {
    expect(smartRomanize('', fixtureA), equals(''));
    expect(dotAwareDeromanize('', fixtureA), equals(''));
  });

  test('malformed JSON parses to empty axes (defense against corruption)', () {
    expect(
      ParadigmAxes.fromJsonString('not a json'),
      equals(const ParadigmAxes()),
    );
  });
});
```

## Database Testing Best Practices

**Isolation:**
- Every test gets a fresh in-memory database via `setUp()`
- Tests cannot interfere with each other
- `tearDown()` ensures clean shutdown

**Assertions Over Mocks:**
- Assert actual database state via queries
- Example: `final rows = await db.select(db.markers).get();`
- More reliable than mocking because it validates actual persistence

**Stream Behavior:**
- Always use `.first` to await first emission before asserting
- Simplifies async logic in tests

---

*Testing analysis: 2026-04-12*
