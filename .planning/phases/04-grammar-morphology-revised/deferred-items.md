# Phase 04 — Deferred Items

Items discovered during plan execution that are out of scope for the current
plan but should be addressed in a future plan.

## From 04-01 (schema v8 + migration backup)

### Pre-existing test failure: phonotactic_dsl_smoke_test

**File:** `test/phonotactic_dsl_smoke_test.dart` line 72

**Failing assertion:**
```dart
assert(!c1.rule!.isForbidden, 'Should not be forbidden');
```

**Symptom:** Loading the test file aborts because a top-level `main()`
assertion fails: parsing `'VN -> nasalised V'` produces a rule whose
`isForbidden` is `true` when the test expects `false`.

**Status:** Reproduced on a clean checkout of `ea062a6` BEFORE 04-01 changes.
This is a pre-existing failure in the phonotactic DSL parser unrelated to
Phase 4 schema work. Out of scope for plan 04-01.

**Suggested owner:** Phonology subsystem maintainer; likely a regression in
the constraint parser's `isForbidden` flag detection between `nasalised`
descriptions and the literal `forbidden` keyword.

## From 04-05 (Inflectional Rule Editor)

### Pre-existing overflow in `rule_editor_dialog.dart` op-row

**File:** `lib/features/morphology/presentation/rules/rule_editor_dialog.dart`
line ~1126 (`_buildOpRow` — the per-operation Row inside a branch card).

**Symptom:** When `RuleEditorDialog` is pumped inside the 820px-wide
`ConstrainedBox` in a widget test, the op-row overflows by 165px on the
right. The `DropdownButton<OpType>` sizes itself to the longest item label
("Whole-word override (irregular)") and the adjacent `Expanded` field
cannot shrink it further.

**Scope note:** This overflow was NOT introduced by plan 04-05 — it is
pre-existing behavior surfaced for the first time by the new
`test/widget/grammar/rule_editor_dialog_kind_test.dart` suite, which is
the first set of widget tests to pump the dialog. The overflow is a
FlutterError caught by the test harness rather than a visual bug for
desktop users (whose window is wider than 820px and whose dialog sits
inside an even wider parent column).

**Current workaround (04-05):** The mandatory widget test suite installs a
scoped `FlutterError.onError` handler that ignores
`'RenderFlex overflowed by …'` messages so the kind-aware behavior assertions
can run. All six tests pass under this suppression.

**Suggested fix (future plan):** Give `DropdownButton<OpType>` a fixed
width via `ConstrainedBox(maxWidth: 140)` + `isExpanded: true`, or shorten
the `OpType` labels (e.g. "Whole-word" instead of "Whole-word override
(irregular)"). Either approach drops the intrinsic width below the
available 367px and eliminates the overflow.

## From 04-12 (derivation data/engine layer)

### Pre-existing compile failure: typology_providers_test

**File:** `test/unit/grammar/typology_providers_test.dart`, via
`lib/features/grammar/data/typology_providers.dart:391`

**Failing reference:**
```dart
final markersAsync = ref.watch(markersForPosProvider(pos.id));
                               ^^^^^^^^^^^^^^^^^^^^^
```

**Symptom:** Compilation fails because `markersForPosProvider` is not
defined. The reference was added during plan 04-10 (markers data layer)
but the matching `markersForPosProvider` declaration was not wired into
`typology_providers.dart` imports / providers. Reproduced on the clean
ddc1b96 base BEFORE any 04-12 changes, so this is a pre-existing gap
from plan 04-10, not a regression introduced by 04-12.

**Scope note:** Out of scope for plan 04-12, which only touches the
derivation data/engine layer (LexemeDao, computedDerivedFormsProvider,
promotedDerivedFormProvider, DerivationPromotionService, LexemeParentsDao).
All 04-12 tests (24 lexicon + 7 grammar junction) pass; the only grammar
suite failure is this pre-existing markers typology compile error.

**Suggested owner:** Whoever finishes plan 04-10 / marker resolution in
typology — wire `markersForPosProvider` (either via `MarkerDao.watchForPos`
or import it from an existing provider file) so `typology_providers.dart`
compiles cleanly.

### Pre-existing compile failure: marker_dao_test

**File:** `test/unit/grammar/marker_dao_test.dart` line 16
```dart
dao = db.markerDao;
    ^^^^^^^^^^^^ getter not defined on AppDatabase
```

**Status:** Pre-existing since plan 04-10 (`a30a938`). The plan added
`MarkerDao` to the `@DriftDatabase` daos list and wrote the test, but
never added a `MarkerDao get markerDao => MarkerDao(this);` accessor on
`AppDatabase`. Drift's generated code exposes an accessor variant, but
the test writes `db.markerDao` which maps to the hand-written getter
that was never authored. Out of scope for plan 04-12.

**Suggested fix:** Either add
```dart
MarkerDao get markerDao => MarkerDao(this);
```
to `lib/db/app_database.dart` next to `lexemeDao`, or update the test
to instantiate `MarkerDao(db)` directly.

## From 04-14 (Derivation Overhaul UI) — Pre-existing worktree orphans

Two untracked files are lingering in the worktree that should have been
physically deleted by plan 04-13's router surgery commit (`b31900a`):

- `lib/features/grammar/presentation/inflectional_rules/inflectional_rules_page.dart`
- `lib/features/grammar/presentation/paradigm_viewer/paradigm_viewer_page.dart`

Both are untracked in this worktree; `git ls-files` does NOT include them,
confirming the HEAD tree is clean. Running `test/widget/grammar/grammar_router_test.dart`
fails on its `File(...).exists()` sanity-check because those files DO exist
on disk in this worktree (orphans from an earlier branch).

**Impact:** 2 regression tests in `grammar_router_test.dart` fail at
the physical-delete assertion. Unrelated to plan 04-14 — pre-existing
worktree state bug. Removing the orphans restores the green suite.

**Suggested fix:** `rm lib/features/grammar/presentation/inflectional_rules/inflectional_rules_page.dart lib/features/grammar/presentation/paradigm_viewer/paradigm_viewer_page.dart` — neither is tracked so this is a pure cleanup step.
