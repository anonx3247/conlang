---
phase: 04-grammar-morphology-revised
reviewed: 2026-04-12T14:30:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - lib/features/grammar/domain/feature_bindings.dart
  - lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart
  - lib/features/grammar/presentation/pos_dimensions/dimension_template_picker.dart
  - lib/features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart
  - lib/features/lexicon/data/lexeme_providers.dart
  - lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart
  - lib/features/lexicon/presentation/dictionary/word_creation_form.dart
  - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
  - lib/features/morphology/presentation/rules/rule_editor_dialog.dart
  - lib/features/morphology/presentation/rules/rules_page.dart
findings:
  critical: 0
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-04-12T14:30:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

The 10 reviewed files cover the grammar/morphology/lexicon feature set including domain models, providers, and presentation widgets. The code is generally well-structured with thorough domain modeling and careful backward compatibility. No critical security or crash-risk issues were found. Five warnings address missing error handling, a type mismatch risk in search logic, missing mounted checks, and a side-effect in build. Four info items note dead code and minor quality concerns.

## Warnings

### WR-01: Type mismatch in derivedMatchRootIds lookup (String vs int)

**File:** `lib/features/lexicon/data/lexeme_providers.dart:194-195`
**Issue:** `derivedMatchRootIds` is a `Set<String>` (populated with `l.rootId!` which is a `String?`), but `computedDerivedMatchRootIds` is a `Set<int>` (populated with `root.id` which is an `int`). The final filter checks both sets, but against different key types. Line 194 checks `derivedMatchRootIds.contains(l.id.toString())` (converting int to String), while line 195 checks `computedDerivedMatchRootIds.contains(l.id)` (int). The `rootId` field appears to be a String column while `id` is an int. If `rootId` ever holds a non-numeric string or if `Lexeme.id` and `Lexeme.rootId` refer to different ID spaces, the `.toString()` conversion on line 194 could silently fail to match. This is fragile and could cause derived-form search matches to be missed.
**Fix:** Normalize both sets to the same type. Prefer `Set<int>` and parse `l.rootId` to int when populating:
```dart
final rootIdInt = int.tryParse(l.rootId!);
if (rootIdInt != null) derivedMatchRootIds.add(rootIdInt);
```
Then on line 194: `derivedMatchRootIds.contains(l.id)`.

### WR-02: Missing mounted check before Navigator.pop after async gap in dimension_template_picker

**File:** `lib/features/grammar/presentation/pos_dimensions/dimension_template_picker.dart:202`
**Issue:** The `_customCard` method awaits `showDialog<String>` (line 159), then calls `Navigator.of(ctx).pop(...)` on line 203. While there is a `ctx.mounted` check on line 202, the `ctx` variable is the outer `BuildContext` passed from `_customCard`, not the widget's own context. Since `_DimensionTemplatePickerDialogState` is a `StatefulWidget`, this is the state's build context aliased through the parameter. If the dialog is dismissed externally (e.g., route pop) during the inner dialog's lifetime, `ctx.mounted` correctly guards the pop, which is good. However, `nameCtrl.dispose()` on line 201 is called before the mounted check -- if `entered` is non-null but `ctx` is not mounted, the controller is disposed but the template is never returned, which is correct behavior. No functional bug, but the dispose-before-check ordering is unusual and could confuse maintainers.
**Fix:** Move `nameCtrl.dispose()` after the mounted check and return block, or wrap both in a try/finally:
```dart
try {
  if (entered != null && entered.isNotEmpty && ctx.mounted) {
    Navigator.of(ctx).pop(
      DimensionTemplate(/* ... */),
    );
  }
} finally {
  nameCtrl.dispose();
}
```

### WR-03: Side-effect in build method (fixDuplicateOrdering)

**File:** `lib/features/morphology/presentation/rules/rules_page.dart:46-49`
**Issue:** `dao.fixDuplicateOrdering()` is called inside `build()`, guarded by a `_didFixOrdering` flag. While the flag prevents repeated calls, triggering a database write from a `build()` method violates the Flutter principle that `build` should be side-effect-free. If the widget is rebuilt before the future completes (e.g., due to a parent rebuild), the returned `Future` is silently discarded with no error handling.
**Fix:** Move this call to `didChangeDependencies()` or a post-frame callback in `initState`:
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final dao = ref.read(morphologyDaoProvider);
    if (dao != null) dao.fixDuplicateOrdering();
  });
}
```

### WR-04: Missing error handling in _save for word creation

**File:** `lib/features/lexicon/presentation/dictionary/word_creation_form.dart:206-247`
**Issue:** The `_save()` method has a try/finally but no catch block. If `dao.insertLexeme` or `parentsDao.insertParent` throws (e.g., a database constraint violation such as a unique IPA conflict), the error propagates unhandled. The `finally` block resets `_saving` to false, but the user sees no error message. The form's `onSaved` callback is never reached, leaving the UI in an ambiguous state.
**Fix:** Add a catch block that surfaces the error to the user:
```dart
try {
  // ... existing insert logic ...
  widget.onSaved();
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save word: $e')),
    );
  }
} finally {
  if (mounted) setState(() => _saving = false);
}
```

### WR-05: Missing error handling in _saveEdit for word detail

**File:** `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart:240-256`
**Issue:** Similar to WR-04, `_saveEdit` calls `dao.updateLexeme` and `reconcile()` with no try/catch. A database error during save would propagate unhandled, leaving the editing state inconsistent (`_isEditing` set to false on line 256 would still run, but the user has no feedback about the failure).
**Fix:** Wrap the save logic in a try/catch that shows a SnackBar on failure, mirroring the fix for WR-04.

## Info

### IN-01: Dead code -- showCustom constant is always true

**File:** `lib/features/grammar/presentation/pos_dimensions/dimension_template_picker.dart:52`
**Issue:** `const showCustom = true;` is a compile-time constant that is always true. The `if (showCustom)` guard on line 90 will never exclude the custom card. This appears to be leftover from a feature toggle during development.
**Fix:** Remove the `showCustom` variable and the `if (showCustom)` guard, rendering the custom card unconditionally.

### IN-02: Dead auto-select comment block

**File:** `lib/features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart:125-128`
**Issue:** Lines 125-128 contain a conditional block with an empty body and a comment explaining why it's a no-op. This dead code serves as documentation but is confusing -- a reader might think the auto-select feature is intended but broken.
**Fix:** Replace with a single-line comment above the `return Row(...)`:
```dart
// Auto-select first POS intentionally disabled — see UI-SPEC empty-state.
```

### IN-03: DropdownButtonFormField uses initialValue instead of value

**File:** `lib/features/morphology/presentation/rules/rule_editor_dialog.dart:1184,1222,1285`
**Issue:** `DropdownButtonFormField` is constructed with `initialValue:` parameter. In Flutter's material library, the correct parameter is `value:` for `DropdownButtonFormField`. If this is a custom wrapper, it may work, but standard Flutter API uses `value` and `initialValue` is deprecated or non-existent depending on the Flutter version. This could cause the dropdown to not reflect state changes after the initial render.
**Fix:** Verify Flutter version compatibility. If using standard `DropdownButtonFormField`, change `initialValue:` to `value:`.

### IN-04: _buildDomainRule does not apply literalTransform

**File:** `lib/features/morphology/presentation/rules/rule_editor_dialog.dart:557-575`
**Issue:** `_buildDomainRule` calls `b.toBranch()` without passing `literalTransform`, while the actual `_save` method separately builds branches with `literalTransform`. This means `_buildDomainRule` always produces phonemic-untransformed output. If `_buildDomainRule` is used for preview purposes this is likely intentional (preview shows rom text), but the inconsistency between the two branch-building paths could lead to subtle bugs if `_buildDomainRule` is ever called for persistence.
**Fix:** Document the intentional divergence with a comment in `_buildDomainRule`:
```dart
// NOTE: No literalTransform applied — this method is for preview only.
// The _save() method applies deromanize separately.
```

---

_Reviewed: 2026-04-12T14:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
