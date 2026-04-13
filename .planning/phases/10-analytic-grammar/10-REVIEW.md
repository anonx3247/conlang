---
phase: 10-analytic-grammar
reviewed: 2026-04-13T00:00:00Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - lib/db/app_database.dart
  - lib/features/grammar/data/construction_dao.dart
  - lib/features/grammar/data/construction_providers.dart
  - lib/features/grammar/data/particle_providers.dart
  - lib/features/grammar/data/typology_providers.dart
  - lib/features/grammar/domain/leipzig_catalog.dart
  - lib/features/grammar/presentation/constructions/construction_preview.dart
  - lib/features/grammar/presentation/constructions/constructions_page.dart
  - lib/features/grammar/presentation/constructions/slot_editor.dart
  - lib/features/grammar/presentation/grammar_shell.dart
  - lib/features/grammar/presentation/particles/particle_dialog.dart
  - lib/features/grammar/presentation/particles/particles_page.dart
  - lib/features/grammar/presentation/typology/typology_page.dart
  - lib/features/lexicon/data/lexeme_dao.dart
  - lib/router/app_router.dart
  - test/integration/migration_v14_to_v15_test.dart
  - test/unit/grammar/closed_class_dao_test.dart
  - test/unit/grammar/construction_dao_test.dart
  - test/unit/grammar/phrase_construction_dao_test.dart
  - test/unit/grammar/typology_providers_test.dart
  - test/widget/grammar/grammar_router_test.dart
findings:
  critical: 0
  warning: 4
  info: 4
  total: 8
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-04-13
**Depth:** standard
**Files Reviewed:** 21
**Status:** issues_found

## Summary

Phase 10 adds analytic grammar features: a closed-class particle inventory (backed by `Lexemes.isClosedClass` / `glossTag`), named phrase constructions with typed slots (`PhraseConstructions` / `ConstructionSlots`), and four new typology word-order fields (`headDirection`, `adpositionType`, `adjPlacement`, `genPlacement`). The database migration (v14 → v15), DAOs, providers, and presentation layer are all present and structurally sound.

Four warnings were found: a destructive mutation in the drag-reorder algorithm that corrupts the source list, a missing UI safety net for slot-editor drag when the DAO is null (causes a silent no-op that looks broken to the user), a `FocusNode` resource leak in `_buildDetailPanel`, and a missing IPA-required form validator that allows saving a particle with an empty IPA through the keyboard shortcut path. Four info items cover the router test's branch count mismatch, duplicate test coverage, a magic number in the slot-height calculation, and a `leipzigGlossAbbreviations` shadowing issue in `slot_editor.dart`.

---

## Warnings

### WR-01: Slot reorder corrupts source list (in-place mutation before use)

**File:** `lib/features/grammar/presentation/constructions/slot_editor.dart:73-74`

**Issue:** The reorder callback builds the reordered list with:

```dart
final reordered = List<ConstructionSlot>.from(slots)
  ..insert(newIndex, (slots..removeAt(oldIndex)).first);
```

`slots..removeAt(oldIndex)` mutates the *original* `slots` list in place — this is the same list passed in from the Riverpod stream. `List<ConstructionSlot>.from(slots)` is evaluated before the `..insert(...)` call, so `reordered` is a copy of the already-mutated list (with `oldIndex` element missing). The `removeAt` result `.first` is then taken from the modified original, which returns the *new* first element of `slots` (after removal), not the element that was at `oldIndex`. This produces an incorrect ordering any time `oldIndex != 0` and can silently persist a wrong slot order to the database.

**Fix:**
```dart
Future<void> _reorderSlots(
  ConstructionDao dao,
  List<ConstructionSlot> slots,
  int oldIndex,
  int newIndex,
) async {
  if (newIndex > oldIndex) newIndex -= 1;
  final item = slots[oldIndex];
  final reordered = List<ConstructionSlot>.from(slots)
    ..removeAt(oldIndex)
    ..insert(newIndex, item);
  await dao.reorderSlots(reordered);
}
```

---

### WR-02: FocusNode resource leak when DAO is null in `_buildDetailPanel`

**File:** `lib/features/grammar/presentation/constructions/constructions_page.dart:280`

**Issue:** When `dao` is null the code creates a bare `FocusNode()` inline and hands it to the `TextField`, but this node is never stored anywhere and never disposed:

```dart
final focusNode =
    dao != null ? _focusNodeFor(construction, dao) : FocusNode();
```

Each rebuild when `dao == null` (no project open) leaks one `FocusNode`. Flutter prints a warning in debug mode for this and it can cause memory growth in production.

**Fix:** Store a single fallback node as a field, or — since editing is impossible when `dao == null` — disable the `TextField` entirely by passing `enabled: false` and avoid creating a focus node:

```dart
final focusNode = dao != null ? _focusNodeFor(construction, dao) : null;
// ...
TextField(
  controller: nameController,
  focusNode: focusNode,
  enabled: dao != null,
  // ...
)
```

---

### WR-03: Gloss-tag Autocomplete listener accumulates on every build (memory leak pattern)

**File:** `lib/features/grammar/presentation/particles/particle_dialog.dart:170-171`

**Issue:** The `fieldViewBuilder` callback for the `Autocomplete` widget is called on every rebuild. Each call registers a new listener on `fieldController`:

```dart
fieldController.addListener(() {
  _glossTagController.text = fieldController.text;
});
```

Because the internal `Autocomplete` controller can be reused across rebuilds, these listeners accumulate without any corresponding `removeListener`, causing the `_glossTagController` to be written multiple times per keystroke and creating a growing listener chain over the dialog's lifetime.

**Fix:** Track listener registration with a flag or use `didChangeDependencies`/`initState`-scoped coordination. The simplest repair at call site is to not use a secondary controller at all — read the value from the `fieldController` directly in `_save()`:

```dart
// In _save(), instead of reading _glossTagController.text:
// The Autocomplete's fieldController is not accessible here, so the
// cleanest fix is to only use one controller and pass it as initialValue.
// Alternative: use a ValueNotifier<String> updated in onSelected + onChanged.
```

A minimal fix is to guard against double-registration:
```dart
bool _glossListenerAdded = false;
// In fieldViewBuilder:
if (!_glossListenerAdded) {
  _glossListenerAdded = true;
  fieldController.addListener(() {
    _glossTagController.text = fieldController.text;
  });
}
```

---

### WR-04: IPA validation bypassed via keyboard submit in `ParticleDialog`

**File:** `lib/features/grammar/presentation/particles/particle_dialog.dart:218-226`

**Issue:** The "Save" button manually checks `_ipaController.text.trim().isEmpty` before calling `_save()`. However, `IpaTextField` does not wrap a `TextFormField`, so it cannot participate in `_formKey.currentState?.validate()`. The manual guard in the button's `onPressed` is correct — but it is not called when the user presses Enter/submit on a form field (e.g. from the Gloss tag field's `onFieldSubmitted`, which is `null` here but could be triggered in future). More immediately, there is no `validator` on the IPA field itself, so `_formKey.currentState?.validate()` in `_save()` will return `true` even with an empty IPA if the user somehow reaches `_save()` directly (e.g. by submitting the Meaning `TextFormField` via keyboard). The `_save()` function calls `validate()` and if it returns true, proceeds to insert/update with whatever `ipa` is.

**Fix:** Add an explicit empty-IPA guard at the top of `_save()` (before the DAO call) as a defense-in-depth measure independent of the button handler:

```dart
Future<void> _save() async {
  if (_ipaController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('IPA form is required.')),
    );
    return;
  }
  if (!(_formKey.currentState?.validate() ?? false)) return;
  // ...
}
```

---

## Info

### IN-01: Grammar router test uses 3-branch router but GrammarShell now has 5 items

**File:** `test/widget/grammar/grammar_router_test.dart:37-65`

**Issue:** The `grammarOnlyRouter` helper builds a `StatefulShellRoute` with only 3 branches (`/grammar/pos`, `/grammar/inflections`, `/grammar/typology`), but `GrammarShell._sidebarItems` now has 5 entries (indices 0–4 for pos, inflections, particles, constructions, typology). When `_onSidebarTap` calls `widget.navigationShell.goBranch(index, ...)` with index 3 or 4, the test router will throw a range error. The smoke tests only tap indices 0–2, so they pass, but the router fixture does not reflect the real production shape.

**Suggestion:** Add the Particles (index 2) and Constructions (index 3) branches to `grammarOnlyRouter`, or add a test that explicitly navigates to `/grammar/particles` and `/grammar/constructions`.

---

### IN-02: Duplicate test coverage between `construction_dao_test.dart` and `phrase_construction_dao_test.dart`

**File:** `test/unit/grammar/construction_dao_test.dart` and `test/unit/grammar/phrase_construction_dao_test.dart`

**Issue:** Both test files test the same `ConstructionDao` methods (insert construction, insert slots in order, cascade delete, reorder slots, ordering). The tests cover identical behaviors with only minor fixture differences. This doubles the maintenance surface without adding coverage.

**Suggestion:** Consolidate into a single test file. If both were created at different milestones, remove `phrase_construction_dao_test.dart` and keep the more comprehensive `construction_dao_test.dart`.

---

### IN-03: Magic number in slot list height calculation

**File:** `lib/features/grammar/presentation/constructions/slot_editor.dart:118`

**Issue:** The `ReorderableListView` height is computed as `(slots.length * 48.0).clamp(48.0, 300.0)`. The values `48.0` and `300.0` are magic numbers with no named constant. The 48.0 chip height is assumed (not derived from the actual chip layout), so changes to chip padding will silently break the height calculation.

**Suggestion:**
```dart
static const double _slotRowHeight = 48.0;
static const double _slotListMaxHeight = 300.0;
// usage:
height: (slots.length * _slotRowHeight)
    .clamp(_slotRowHeight, _slotListMaxHeight),
```

---

### IN-04: `leipzigGlossAbbreviations` is shadowed by a local variable in `slot_editor.dart`

**File:** `lib/features/grammar/presentation/constructions/slot_editor.dart:87`

**Issue:** The build method imports `leicpzigGlossCatalog` from `leipzig_catalog.dart` (the `List<LexicalGlossEntry>`) but then immediately re-assigns it to a local with the same name as the imported flat-abbreviation constant:

```dart
final leipzigGlossAbbreviations = leipzigGlossCatalog;
```

`leipzigGlossCatalog` is `List<LexicalGlossEntry>`, while `leipzigGlossAbbreviations` (from the same import) is `List<String>`. The local variable shadows the top-level `List<String>` constant, and the `_AddSlotForm` widget receives the `List<LexicalGlossEntry>` typed as `List<String>` through this shadowing — this only works because `_AddSlotForm` uses `leipzigGlossAbbreviations` only in an `Autocomplete<String>` filter where `.where((abbr) => abbr.toLowerCase()...)` would fail at runtime since `abbr` would actually be a `LexicalGlossEntry` at runtime.

Wait — the parameter type on `_AddSlotForm` is `List<String>`, so Dart would catch the type mismatch at compile time (the local `final leipzigGlossAbbreviations = leipzigGlossCatalog` infers `List<LexicalGlossEntry>`). This means the code either does not compile as-is or the build tooling infers something different. Either way, the intent is wrong: the local variable should use the correct `List<String>` constant directly:

```dart
// Remove the local variable entirely and update _AddSlotForm call:
leipzigGlossAbbreviations: leipzigGlossAbbreviations, // use imported List<String>
```

---

_Reviewed: 2026-04-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
