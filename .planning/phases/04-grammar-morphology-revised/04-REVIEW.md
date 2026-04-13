---
phase: 04-grammar-morphology-revised
reviewed: 2026-04-10T00:00:00Z
depth: standard
files_reviewed: 43
files_reviewed_list:
  - lib/db/app_database.dart
  - lib/features/grammar/data/dimension_templates.dart
  - lib/features/grammar/data/grammar_dao.dart
  - lib/features/grammar/data/grammar_providers.dart
  - lib/features/grammar/data/paradigm_cell_override_dao.dart
  - lib/features/grammar/data/paradigm_coverage_provider.dart
  - lib/features/grammar/data/typology_providers.dart
  - lib/features/grammar/domain/dimension_level.dart
  - lib/features/grammar/domain/feature_bindings.dart
  - lib/features/grammar/domain/inflectional_rule.dart
  - lib/features/grammar/domain/paradigm_axes.dart
  - lib/features/grammar/domain/paradigm_cell.dart
  - lib/features/grammar/domain/paradigm_engine.dart
  - lib/features/grammar/domain/pos_resolver.dart
  - lib/features/grammar/domain/rule_kind.dart
  - lib/features/grammar/domain/tiebreak_detector.dart
  - lib/features/grammar/presentation/grammar_shell.dart
  - lib/features/grammar/presentation/inflectional_rules/inflectional_rules_page.dart
  - lib/features/grammar/presentation/paradigm_viewer/axis_config_bar.dart
  - lib/features/grammar/presentation/paradigm_viewer/cell_override_dialog.dart
  - lib/features/grammar/presentation/paradigm_viewer/coverage_matrix_panel.dart
  - lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart
  - lib/features/grammar/presentation/paradigm_viewer/paradigm_viewer_page.dart
  - lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart
  - lib/features/grammar/presentation/pos_dimensions/dimension_template_picker.dart
  - lib/features/grammar/presentation/pos_dimensions/pos_crud_dialog.dart
  - lib/features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart
  - lib/features/grammar/presentation/shared/migration_banner.dart
  - lib/features/grammar/presentation/typology/typology_page.dart
  - lib/features/lexicon/data/lexeme_providers.dart
  - lib/features/lexicon/presentation/derivations/derivations_page.dart
  - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
  - lib/features/lexicon/presentation/lexicon_shell.dart
  - lib/features/morphology/data/morphology_dao.dart
  - lib/features/morphology/data/morphology_providers.dart
  - lib/features/morphology/presentation/rules/rule_editor_dialog.dart
  - lib/features/morphology/presentation/rules/rules_page.dart
  - lib/features/phonology/presentation/shared/ipa_chart/ipa_audio_player.dart
  - lib/features/project/data/project_backup.dart
  - lib/features/project/data/project_providers.dart
  - lib/features/project/presentation/project_menu.dart
  - lib/features/project/presentation/project_selector_dialog.dart
  - lib/router/app_router.dart
  - lib/shared/widgets/app_shell.dart
findings:
  critical: 3
  warning: 7
  info: 7
  total: 17
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-04-10T00:00:00Z
**Depth:** standard
**Files Reviewed:** 43
**Status:** issues_found

## Summary

Phase 4 introduces the Grammar feature (POS & Dimensions, Inflectional Rules, Paradigm Viewer, Typology) plus the split of morphological rules into inflectional vs derivational kinds with a schema v7→v8 migration. The overall architecture is coherent: the feature-consumption paradigm engine is well-documented, the override DAO uses canonical feature-set keys, and the migration has a v7 backup safety net.

Three critical issues surface from cross-cutting lifecycle paths:

1. Deleting a Part of Speech can crash at runtime because `MorphologicalRules.posId / inputPosId / outputPosId` FKs have no `ON DELETE` action while `PRAGMA foreign_keys = ON` is active.
2. Deleting a dimension does not clean up references from `MorphologicalRules.featureBindings.dims` or `Lexemes.skippedDimensionsJson`, and there is no confirmation prompt.
3. The JSON decoders for `DimensionLevel` and `ParadigmAxes` use hard casts (`as int`, `as String`) inside try blocks that catch only `FormatException`. A malformed stored shape (T-04-07 threat model case) raises `TypeError`, which escapes the guards and crashes the widget tree.

The paradigm engine loop is sound (the empty-subset guard in `_isSubset` plus winner-removes-dim invariant keeps it bounded). The paradigm_table_widget slice selector can out-of-range if the underlying dimensions shrink. Several legacy-vs-v8 inconsistencies remain: the rules page POS filter and the dictionary-side search derivation loop still use the legacy `posIds` CSV / skip the `kind` filter, yielding stale behaviour relative to the new `FeatureBindings` + `RuleKind` contract.

## Critical Issues

### CR-01: Deleting a POS with associated rules violates FK constraint

**File:** `lib/features/morphology/data/morphology_dao.dart:193-194`

**Issue:** `MorphologyDao.deletePos` issues a plain `delete(partsOfSpeech)` statement. `MorphologicalRules` has three foreign-key references to `parts_of_speech` (`posId`, `inputPosId`, `outputPosId`) declared without `ON DELETE` actions (see `lib/db/app_database.dart:153-177`). Because `beforeOpen` enables `PRAGMA foreign_keys = ON` (`app_database.dart:366`), attempting to delete a POS that any morphological rule references raises a SQLite constraint exception. Users who create a POS, attach an inflectional/derivational rule, then try to delete the POS will hit an uncaught error.

`Dimensions.posId` has `KeyAction.cascade`, which handles the dimensions side. The morphological-rule-side needs either cascade, SET NULL, or an explicit pre-delete update.

**Fix:**
```dart
Future<int> deletePos(int id) async {
  return transaction(() async {
    // Null out FK columns on every rule that referenced this POS.
    await (update(morphologicalRules)..where((t) => t.posId.equals(id)))
        .write(const MorphologicalRulesCompanion(posId: Value(null)));
    await (update(morphologicalRules)..where((t) => t.inputPosId.equals(id)))
        .write(const MorphologicalRulesCompanion(inputPosId: Value(null)));
    await (update(morphologicalRules)..where((t) => t.outputPosId.equals(id)))
        .write(const MorphologicalRulesCompanion(outputPosId: Value(null)));
    // Clear the POS from every rule's FeatureBindings.pos list.
    final rows = await (select(morphologicalRules)
          ..where((t) => t.posIds.isNotValue('')))
        .get();
    for (final r in rows) {
      final fb = r.featureBindings;
      if (fb.pos.contains(id)) {
        final cleaned = fb.copyWith(pos: fb.pos.where((p) => p != id).toList());
        await (update(morphologicalRules)..where((t) => t.id.equals(r.id)))
            .write(MorphologicalRulesCompanion(featureBindings: Value(cleaned)));
      }
    }
    return (delete(partsOfSpeech)..where((t) => t.id.equals(id))).go();
  });
}
```
Alternatively, change the FK declarations in `app_database.dart` to `onDelete: KeyAction.setNull` and bump the schema version.

---

### CR-02: Deleting a dimension leaves stale references in rules and lexemes

**File:** `lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart:148-156`

**Issue:** The trash-icon handler in `_dimensionCard` calls `dao.deleteDimension(dim.id)` directly — no confirmation, no cascade cleanup. Because `MorphologicalRules.featureBindings` stores dimension ids inside a JSON-backed `TypeConverter` column and `Lexemes.skippedDimensionsJson` stores ids as a JSON array, SQLite has no visibility into those references and cannot cascade. After deletion:

- Every inflectional rule whose `featureBindings.dims` mentioned the deleted id keeps that entry, making the rule bind to a non-existent dimension. `paradigm_engine.dart` will treat it as a regular binding and silently fail to match cells (specificity is still counted).
- Every lexeme with the dimension id in `skippedDimensionsJson` keeps a dangling skip.
- `ParadigmAxes` stored for the POS may still reference the id in `rows`/`cols`/`tabs`, leading to the axis-config-bar crash case CR-03 / WR-01.

The user gets no warning ("this deletes X rules' bindings"), so this is both a data-integrity bug and a UX risk.

**Fix:**
```dart
IconButton(
  icon: const Icon(Icons.delete_outline),
  tooltip: 'Delete dimension',
  onPressed: () async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete dimension?'),
        content: Text(
          'Delete "${dim.name}"? Inflectional rules that bind to its '
          'levels will lose that binding. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final dao = ref.read(grammarDaoProvider);
    if (dao == null) return;
    // TODO: also strip dim.id from every MorphologicalRule.featureBindings.dims
    //       map, every Lexeme.skippedDimensionsJson, and the ParadigmAxes
    //       persisted for this POS. Run inside a transaction.
    await dao.deleteDimension(dim.id);
  },
),
```
Even with the confirmation added, the cleanup of dependent JSON state should ship alongside — otherwise CR-03 / WR-01 manifest as soon as the user re-opens the paradigm viewer.

---

### CR-03: JSON decoders raise TypeError outside the FormatException guard

**File:** `lib/features/grammar/domain/dimension_level.dart:30-88` and `lib/features/grammar/domain/paradigm_axes.dart:27-48`

**Issue:** Both decoders were written as T-04-07 mitigations to tolerate hand-edited database state, but the casts inside the factories are hard casts:
- `DimensionLevel.fromJson` uses `json['id'] as int`, `json['name'] as String`, etc.
- `ParadigmAxes.fromJson` uses `json['rows'] as int?`, `json['cols'] as int?`.

If the stored JSON has the right outer shape (a Map / List) but a wrong inner type (e.g. `{"id": "1", "name": "Singular", ...}` where id was serialised as a string), `jsonDecode` succeeds and `decoded is! List/Map` is false, so execution enters the factory. The hard cast then throws `TypeError`, not `FormatException`. The `on FormatException` catch in `decodeLevelsJson` / `ParadigmAxes.fromJsonString` does NOT catch `TypeError`, so the exception propagates up through `paradigmCoverageMatrixProvider`, `axis_config_bar`, `paradigm_table_widget`, etc., and blocks the entire Paradigm Viewer for that project.

This is the T-04-07 scenario the code was trying to defend against — the defense is incomplete.

**Fix:**
```dart
// dimension_level.dart
factory DimensionLevel.fromJson(Map<String, dynamic> json) {
  final id = json['id'];
  final name = json['name'];
  final abbr = json['abbr'];
  final ordering = json['ordering'];
  if (id is! int || name is! String || abbr is! String || ordering is! int) {
    throw const FormatException('DimensionLevel: malformed fields');
  }
  return DimensionLevel(id: id, name: name, abbr: abbr, ordering: ordering);
}

List<DimensionLevel> decodeLevelsJson(String raw) {
  if (raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) {
          try {
            return DimensionLevel.fromJson(m.cast<String, dynamic>());
          } on FormatException {
            return null;
          }
        })
        .whereType<DimensionLevel>()
        .toList();
  } on FormatException {
    return const [];
  }
}
```
Apply the same pattern to `ParadigmAxes.fromJson`: replace `as int?` with explicit `is int` checks and return `const ParadigmAxes()` on any mismatch. Alternatively, broaden the catch to `catch (_)` if the intent is "swallow anything malformed" — but a typed catch is clearer.

---

## Warnings

### WR-01: AxisConfigBar crashes when a stored axis references a deleted dimension

**File:** `lib/features/grammar/presentation/paradigm_viewer/axis_config_bar.dart:50-77`

**Issue:** The Rows `DropdownButton` is constructed with `value: axes.rows` and items built from the full `dims` list. If the persisted `axes.rows` points at a dimension that no longer exists (a dimension was deleted elsewhere, see CR-02), `DropdownButton`'s internal assertion `assert(value == null || items.where((i) => i.value == value).length == 1)` fires on build. Same hazard for the Columns dropdown — its items filter out `axes.rows`, so if `axes.cols == axes.rows` (also impossible after deletion of the rows dim + stale axes) you can hit another mismatch.

**Fix:** Clamp the stored axes to the current dims before passing to the dropdowns, or fall back to `ParadigmAxes.defaultsFor(dims)` when either side is stale.
```dart
final validIds = dims.map((d) => d.id).toSet();
final safeRows = validIds.contains(axes.rows) ? axes.rows : null;
final safeCols = validIds.contains(axes.cols) ? axes.cols : null;
// use safeRows / safeCols for DropdownButton.value
```
`paradigm_table_widget.dart` (lines 72-85) already has a similar fallback; the axis bar should mirror it.

---

### WR-02: `_DropdownSliceSelector` RangeError when slices shrink

**File:** `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart:541-578`

**Issue:** `_currentIndex` is stored in state and used unconditionally in `build()` via `widget.slices[_currentIndex]`. If the parent rebuilds with a shorter `slices` list (e.g. the user deleted a dimension that was flattened into the slice selector, or toggled a skipped dim), the old index can point past the new list and `widget.slices[_currentIndex]` throws `RangeError`.

**Fix:**
```dart
@override
void didUpdateWidget(covariant _DropdownSliceSelector old) {
  super.didUpdateWidget(old);
  if (_currentIndex >= widget.slices.length) {
    _currentIndex = 0;
  }
}
```
And inside `build()`, clamp defensively:
```dart
final safeIndex = _currentIndex < widget.slices.length ? _currentIndex : 0;
final current = widget.slices[safeIndex];
```

---

### WR-03: Rules page POS filter uses legacy `posIds` CSV instead of FeatureBindings

**File:** `lib/features/morphology/presentation/rules/rules_page.dart:99-110`

**Issue:** The filter chain parses `r.posIds` (the legacy CSV column, marked "do not write in v8+" in `app_database.dart:158-159`) to decide whether a rule applies to the selected POS. Rules created through the v8 path write `featureBindings.pos` but only mirror into `posIds` when the dialog is in the right mode (`rule_editor_dialog.dart:431`). Filtering on the CSV misses any rule whose POS was set only in the `FeatureBindings` payload — especially after the CSV column is eventually dropped (A9 plan). Users may see "no rules match" for a POS that does have rules.

**Fix:** Read `featureBindings.pos` instead.
```dart
final filtered = _selectedPosId == null
    ? rules
    : rules.where((r) {
        final fbPos = r.featureBindings.pos;
        // Empty bindings.pos = applies to all POS (matches watchInflectionalRulesForPos).
        return fbPos.isEmpty || fbPos.contains(_selectedPosId);
      }).toList();
```

---

### WR-04: Dictionary search runs inflectional rules through the derivation matcher

**File:** `lib/features/lexicon/data/lexeme_providers.dart:152-178`

**Issue:** In `filteredLexemeListProvider`, the compute-derived-match loop iterates `dbRules` and only gates on `isActive` — it does not filter by `kind`. Inflectional rules therefore fire against every root, and if the inflected form happens to contain the search query substring, the root is added to the result set. This contradicts `computedDerivedFormsProvider` just below (lines 284-290), which explicitly skips inflectional rules ("pitfall #9: ignore inflectional rules — they belong to the paradigm viewer, not the lexicon derivation tree").

Concretely: a user searching "-s" in the Dictionary will match every plural-forming paradigm cell of every noun, which is almost certainly not what the user wants. The pitfall #9 comment already captures the intent.

**Fix:**
```dart
for (final r in dbRules) {
  if (!r.isActive) continue;
  if (r.kind != RuleKind.derivational.dbString) continue; // same guard as computedDerivedFormsProvider
  final parsed = parseMorphDsl(r.source, id: r.id, name: r.name);
  ...
}
```

---

### WR-05: Exception dialog offers inflectional rules as candidates

**File:** `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart:168-245`

**Issue:** `_addException` populates the rule dropdown from `morphologicalRuleListProvider` without filtering by `kind` or by the lexeme's POS. The Phase 4 design moves inflectional exceptions to `ParadigmCellOverrides` (see `paradigm_cell_override_dao.dart` docstring: "cleaner than the sentinel-ruleId approach because a cell can be overridden even when NO inflectional rule would have filled it"). Letting users attach a `MorphologicalRuleException` row to an inflectional rule resurrects the exact pattern D-22 / D-28 were designed to replace, and the override will not show up in the paradigm table (which reads `ParadigmCellOverrides`, not `MorphologicalRuleExceptions`).

**Fix:** Filter the dropdown to derivational rules only, with an explanatory helper.
```dart
final derivational = rules
    .where((r) => r.kind == RuleKind.derivational.dbString)
    .toList();
if (derivational.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('No derivational rules defined. '
          'Inflectional exceptions live in the paradigm viewer as cell overrides.'),
    ),
  );
  return;
}
int? selectedRuleId = derivational.first.id;
// ...use `derivational` instead of `rules` in the DropdownButtonFormField items.
```

---

### WR-06: v7→v8 migration silently drops all POS ids beyond the first

**File:** `lib/db/app_database.dart:341-361`

**Issue:** For each legacy rule, the migration parses the full `pos_ids` CSV into `parsedPos`, then sets `inputPosId` / `outputPosId` to `parsedPos.first` and writes `FeatureBindings(pos: parsedPos, dims: const {})`. `featureBindings.pos` correctly preserves the full list, so most downstream code is fine — however `rule_editor_dialog._loadFromExisting` then uses `bindings.pos.first` as the single target POS for both inflectional and derivational mode (lines 243, 247), and `inputPosId == outputPosId == firstPos` flattens what may have been a multi-POS derivational rule into a single-target rule.

Users upgrading from v7 with a rule attached to (e.g.) Noun+Verb will see only Noun selected after upgrade. The rule still executes correctly thanks to `featureBindings.pos`, but editing and saving in the new dialog will overwrite the field back to `[Noun]`, losing Verb on the next save round-trip.

**Fix:** Either:
- Keep the migration as-is but add a one-time user-visible notice (the `MigrationBanner` already exists — extend the copy to mention "review rules that applied to multiple POSes").
- Preserve the list by setting both `inputPosId` and `outputPosId` to `parsedPos.first` while still storing the full set — and teach `rule_editor_dialog` to warn on save when `bindings.pos.length > 1` so users don't lose the extra POSes unknowingly.

---

### WR-07: `rules_page.fixDuplicateOrdering` fire-and-forget during build()

**File:** `lib/features/morphology/presentation/rules/rules_page.dart:46-49`

**Issue:** On first build of the page, `dao.fixDuplicateOrdering()` is launched without `await` from inside `build()`. The write runs asynchronously, which is functionally OK (`_didFixOrdering` prevents re-runs), but:
1. Uncaught errors from the DAO call are swallowed (no `.catchError`).
2. The write can race the first `ref.watch(morphologicalRuleListProvider)` emission, causing the page to briefly render with the old (duplicate-ordering) list, flicker, then re-render once the write propagates.
3. Triggering writes during `build()` is a known Flutter anti-pattern — `WidgetsBinding.instance.addPostFrameCallback` is the canonical place.

**Fix:**
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final dao = ref.read(morphologyDaoProvider);
    if (dao != null) await dao.fixDuplicateOrdering();
  });
}
```
Drop the `_didFixOrdering` / in-build check.

---

## Info

### IN-01: Dead no-op branch in `pos_dimensions_page.dart`

**File:** `lib/features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart:33-36`

**Issue:** The `if (_selectedPosId == null && posList.isNotEmpty)` block contains only a comment explaining why the auto-select was reverted. Remove the block entirely — the comment can live on the `_selectedPosId` field declaration.

**Fix:** Delete lines 33-36 and move the rationale to a doc comment on `_selectedPosId`.

---

### IN-02: Silent audio catch-all with no logging

**File:** `lib/features/phonology/presentation/shared/ipa_chart/ipa_audio_player.dart:34-41`

**Issue:** The `try/catch` around `player.stop/setAsset/play` swallows every exception without even a debugPrint. Missing OGG assets and corrupted audio files are indistinguishable from the user's perspective.

**Fix:**
```dart
} catch (e, st) {
  assert(() {
    debugPrint('IpaAudioPlayer: failed to play $assetPath: $e');
    return true;
  }());
}
```

---

### IN-03: Convoluted `whenOrNull` misuse

**File:** `lib/features/project/presentation/project_menu.dart:155-157`

**Issue:** `registryAsync.whenOrNull(data: (r) async => r)` returns a `Future<ProjectRegistry>?` (since the `data` callback returns a Future), which is then awaited. The simpler and more idiomatic form is `registryAsync.valueOrNull`.

**Fix:**
```dart
final registry = ref.read(projectRegistryProvider).valueOrNull;
if (registry == null) return;
```

---

### IN-04: `build()` mutates `_tiebreakConflict`

**File:** `lib/features/morphology/presentation/rules/rule_editor_dialog.dart:803`

**Issue:** `_recomputeTiebreak(allRows)` is called synchronously inside `build()`, mutating a member field. The rationale comment says "no concurrent setState", which is true on the UI isolate, but mutating state inside build is still a Flutter anti-pattern — if any widget higher in the tree decides to call `build()` twice in one frame (e.g. due to LayoutBuilder), the banner may flicker between stale and fresh state.

**Fix:** Move the recompute to `didChangeDependencies` + a cached Riverpod listener, or derive the banner entirely from a `Provider<TiebreakConflict?>` that reads `rulesByKindProvider` + the in-progress form state.

---

### IN-05: `RemoveSuffixOp` case relies on `continue` inside a switch

**File:** `lib/features/morphology/presentation/rules/rule_editor_dialog.dart:318-320`

**Issue:** The `case RemoveSuffixOp(): continue;` works because it targets the enclosing `for (final op in branch.operations)` loop, but readers need to trace the statement's target. A short comment would help future maintainers.

**Fix:**
```dart
case RemoveSuffixOp():
  // Internal DSL op — not user-editable; skip to next op in the loop.
  continue;
```

---

### IN-06: Redundant `break` inside Dart switch cases

**File:** `lib/features/grammar/domain/paradigm_engine.dart:109-114`

**Issue:** `case MorphSuccess(:final form): winner = candidate; winnerForm = form; break;` — Dart's switch statements disallow fall-through by default, so `break` after the last statement in a `case` is a no-op. It is not harmful (and in this case `break` targets the switch, not the `for`, which might briefly confuse readers of the paradigm engine given the `if (winner != null) break;` immediately after).

**Fix:** Drop the explicit `break`s inside the `MorphSuccess` and `MorphNoMatch` cases; rely on the `if (winner != null) break;` after the switch to exit the `for` loop.

---

### IN-07: `typology_providers` docstring contradicts `typology_page` options

**File:** `lib/features/grammar/data/typology_providers.dart:38-40` and `lib/features/grammar/presentation/typology/typology_page.dart:21-29`

**Issue:** The `TypologySettings` class doc says `wordOrder` is `'SVO' | 'SOV' | 'VSO' | 'VOS' | 'OVS' | 'OSV' | null`, but `TypologyPage._wordOrderOptions` adds a seventh value `'free'`. The settings persist correctly either way; the mismatch is cosmetic but misleads future readers of the value-object docstring.

**Fix:** Update the doc comment to include `'free'`:
```dart
/// `'SVO'` | `'SOV'` | `'VSO'` | `'VOS'` | `'OVS'` | `'OSV'` | `'free'` | null
final String? wordOrder;
```

---

_Reviewed: 2026-04-10T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
