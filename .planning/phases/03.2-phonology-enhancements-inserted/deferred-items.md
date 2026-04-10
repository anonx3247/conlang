# Deferred Items — Phase 03.2

Items discovered during execution that are out-of-scope for the current plan.

## From Plan 03.2-01

### Pre-existing failure: `test/phonotactic_dsl_smoke_test.dart`

**Status:** Out of scope — failure predates this plan.

**Failure:**
```
test/phonotactic_dsl_smoke_test.dart 72:10 main
Failed assertion: line 72 pos 10: '!c1.rule!.isForbidden': Should not be forbidden
```

**Context:** `parseConstraintRule('VN -> nasalised V')` is returning
`isForbidden=true` when the smoke test expects `false`. The test uses raw
`assert` statements (not the `flutter_test` harness) so it crashes on load.

**Verified pre-existing:** Ran `git stash && flutter test test/phonotactic_dsl_smoke_test.dart`
on the untouched Plan-01 commit — same failure. My changes (catalog file +
`buildInventory` rename) do not touch `phonotactic_dsl.dart` or constraint
parsing.

**Recommended disposition:** Investigate under a future plan in Phase 03.2
(most likely Plan 03.2-03 or 03.2-04 which touch constraint parsing) or as
a dedicated bug-fix plan. The smoke test file itself may also need migration
to the `flutter_test` harness so one failure doesn't crash the whole file
load.
