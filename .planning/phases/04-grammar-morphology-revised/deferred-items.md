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
