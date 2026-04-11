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
