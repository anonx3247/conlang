---
phase: 03-lexicon
reviewed: 2026-04-09T00:00:00Z
depth: standard
files_reviewed: 26
files_reviewed_list:
  - lib/features/lexicon/data/anki_exporter.dart
  - lib/features/lexicon/data/lexeme_dao.dart
  - lib/features/lexicon/data/lexeme_dao.g.dart
  - lib/features/lexicon/data/lexeme_providers.dart
  - lib/features/lexicon/data/phonotactic_validation_provider.dart
  - lib/features/lexicon/data/semantic_providers.dart
  - lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart
  - lib/features/lexicon/presentation/dictionary/dictionary_page.dart
  - lib/features/lexicon/presentation/dictionary/inspiration_panel.dart
  - lib/features/lexicon/presentation/dictionary/word_creation_form.dart
  - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
  - lib/features/lexicon/presentation/dictionary/word_list_panel.dart
  - lib/features/lexicon/presentation/lexicon_shell.dart
  - lib/features/lexicon/presentation/swadesh/swadesh_page.dart
  - lib/features/lexicon/presentation/thesaurus/thesaurus_page.dart
  - lib/features/morphology/presentation/rules/morphology_preview_panel.dart
  - lib/features/phonology/presentation/sound_rules/word_generator_panel.dart
  - lib/router/app_router.dart
  - lib/shared/widgets/violation_text.dart
  - test/lexicon/anki_export_test.dart
  - test/lexicon/lexeme_dao_test.dart
  - test/lexicon/lexeme_filter_test.dart
  - test/lexicon/phonotactic_validation_test.dart
  - test/lexicon/swadesh_test.dart
  - test/lexicon/thesaurus_test.dart
  - lib/features/lexicon/data/lexeme_dao.g.dart
findings:
  critical: 1
  warning: 5
  info: 4
  total: 10
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-04-09T00:00:00Z
**Depth:** standard
**Files Reviewed:** 26
**Status:** issues_found

## Summary

Reviewed the complete Phase 3 Lexicon feature set: data layer (DAO, providers, Anki exporter), presentation layer (dictionary, Swadesh, Thesaurus, word creation/detail/list panels), routing additions, and the shared `ViolationText` widget, plus all six test files.

The implementation is generally solid and well-structured. The Riverpod provider graph, DAO design, and phonotactic validation integration are clean. One critical bug was found: the Anki `_csum` function deviates from Anki's actual SHA-1 checksum algorithm in a way that will cause Anki to silently reject duplicate-detection and produce incorrect database state when imported. Five warnings cover real behavioral issues: a note-count off-by-one risk when many entries are added in the same millisecond, missing context navigation for covered Swadesh words, an O(n²) inner-loop provider call per list item, an unvalidated JSON cast in export, and a `TextController` leak in the exception dialog. Four info items cover code quality.

---

## Critical Issues

### CR-01: `_csum` does not implement Anki's actual checksum algorithm — import will silently corrupt duplicate detection

**File:** `lib/features/lexicon/data/anki_exporter.dart:302-310`

**Issue:** The code comment at line 302-303 explicitly states: _"Anki's actual algorithm: `int(hashlib.sha1(sfld.encode("utf-8")).hexdigest()[:8], 16)`"_ — but the implementation uses a djb2 hash instead. Anki uses the `csum` column to detect duplicate notes. When a user imports the `.apkg` file, Anki recomputes SHA-1 on the sort field and compares it against the stored `csum`. If they differ, Anki will either fail to detect duplicates correctly or flag every note as a potential duplicate, triggering user-visible errors during import. The code comment itself acknowledges this discrepancy but dismisses it as "sufficient for uniqueness within a deck" — that misses the point: Anki does not use `csum` for uniqueness within the deck; it uses it server-side to detect cross-deck duplicates, and it recomputes it on import to verify integrity.

**Fix:** Replace the djb2 implementation with the actual SHA-1-based algorithm Anki uses. The `crypto` package (already common in Flutter projects) or Dart's `dart:convert` + `pointycastle` can supply SHA-1:

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

int _csum(String sfld) {
  final bytes = utf8.encode(sfld);
  final digest = sha1.convert(bytes).toString(); // 40-char hex
  return int.parse(digest.substring(0, 8), radix: 16);
}
```

If adding a dependency is undesirable, at minimum the comment should be removed and a `// TODO: use SHA-1 (Anki requirement)` note added so this is not forgotten.

---

## Warnings

### WR-01: Note ID collision when more than 1000 entries are exported in the same second

**File:** `lib/features/lexicon/data/anki_exporter.dart:224-226`

**Issue:** Note IDs are computed as `now * 1000 + i` where `now` is `millisecondsSinceEpoch ~/ 1000` (seconds). For a deck with more than 1000 entries, `i` will exceed 999, making note IDs from entry 1000 onward collide with those from entry 0 of the next second. Similarly, card IDs are computed with `now * 1000 + 100000 + i` — which can collide with note IDs when `i` gets large enough. Anki enforces integer primary keys; the SQLite `INSERT` will raise a `UNIQUE constraint failed` error at runtime, crashing the export for large lexicons.

**Fix:** Use the entry index directly as the primary key component, or use the current microsecond timestamp instead of seconds:

```dart
// Option A: index-based (simplest)
final noteId = _modelId.hashCode ^ i; // guaranteed unique per export

// Option B: microseconds-based (matches Anki convention)
final noteId = DateTime.now().microsecondsSinceEpoch + i;
```

A safer approach is to use sequential integers starting from a safe base:

```dart
final baseId = DateTime.now().millisecondsSinceEpoch;
final noteId = baseId + i; // unique as long as export takes < 292 years
```

### WR-02: Covered Swadesh words navigate to dictionary root instead of the specific word

**File:** `lib/features/lexicon/presentation/swadesh/swadesh_page.dart:274-276`

**Issue:** `_LinkedWordLabel.onTap` calls `context.go('/lexicon/dictionary')` — this navigates to the dictionary without selecting the matched lexeme. The user sees the dictionary root page with no word selected, which is misleading: tapping a covered concept gives the impression of navigation but lands on an empty detail panel. The `lexeme.id` is available at this point.

**Fix:** Navigate to the dictionary with the lexeme ID as a query parameter (or implement a `selectedId` parameter), e.g.:

```dart
onTap: () {
  // Pass the lexeme ID so the dictionary opens to that word.
  // Requires DictionaryPage/router to support ?selectedId=X
  context.go('/lexicon/dictionary?selectedId=${lexeme.id}');
},
```

If the router does not yet support `selectedId`, this should at minimum be a `TODO` comment so the behavior is not mistaken for intentional.

### WR-03: `allLexemeListProvider` is re-watched inside the per-item list view builder — O(n) provider reads per frame

**File:** `lib/features/lexicon/presentation/dictionary/word_list_panel.dart:305-309`

**Issue:** Inside `_buildListView`, the `itemBuilder` callback calls `ref.watch(allLexemeListProvider)` on every list item rebuild (lines 305-306). For a list of N words, this emits N watch subscriptions to the same provider per frame. While Riverpod deduplicates the underlying stream, the `ref.watch` call inside `itemBuilder` is called outside a `ConsumerWidget` context — `WordListPanel` is a `ConsumerStatefulWidget` but `itemBuilder` is not a `build()` method with its own `ref`. This causes unnecessary list-wide rebuilds whenever `allLexemeListProvider` changes, even for items whose derived-match badge hasn't changed.

**Fix:** Compute the `derivedMatchCount` map outside `itemBuilder` (similar to how `violations` is already computed via `lexemeViolationsProvider`):

```dart
// Before itemBuilder:
final allLexemes = ref.watch(allLexemeListProvider).asData?.value ?? [];
// Build a map: rootIdStr -> count of derived matches
final derivedMatchCounts = <String, int>{};
for (final id in derivedMatches) {
  final lexeme = allLexemes.firstWhereOrNull((l) => l.id == id);
  if (lexeme?.rootId != null) {
    derivedMatchCounts[lexeme!.rootId!] =
        (derivedMatchCounts[lexeme.rootId!] ?? 0) + 1;
  }
}

// Inside itemBuilder:
final derivedMatchCount = derivedMatchCounts[lexeme.id.toString()] ?? 0;
```

### WR-04: `jsonDecode(lexeme.ruleIds!)` cast is unguarded against non-List JSON

**File:** `lib/features/lexicon/presentation/dictionary/dictionary_page.dart:148-150`

**Issue:** The `catch (_)` block at line 156 does suppress exceptions, but the cast on line 149 — `(jsonDecode(lexeme.ruleIds!) as List).map((e) => e as int)` — will throw a `TypeError` (not caught by `catch (_)`) if `ruleIds` contains valid JSON that is not a list (e.g., a JSON object `{}`). The outer `try/catch` at line 144 is `catch (_)` which would catch a `TypeError`, so this is actually safe from a crash perspective. However, the bare `catch (_)` swallows all exceptions including legitimate ones (null pointer, bad state), making debugging very difficult.

**Fix:** Narrow the catch clause and validate the decoded type:

```dart
try {
  final decoded = jsonDecode(lexeme.ruleIds!);
  if (decoded is List) {
    final ruleIdList = decoded.map((e) => e as int).toList();
    // ... rest of logic
  }
} on FormatException {
  // Malformed JSON — skip morphological context
} on TypeError {
  // Unexpected JSON structure — skip morphological context
}
```

### WR-05: `TextEditingController` in `_addException` dialog is disposed after `await showDialog` but may leak if the dialog is dismissed via route pop

**File:** `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart:126-191`

**Issue:** `overrideController` (line 126) is disposed at line 190 after `await showDialog`. If the dialog is dismissed by pressing the system back button or tapping outside (which is the default `barrierDismissible: true` behavior on `AlertDialog`), the `showDialog` future resolves normally and `overrideController.dispose()` at line 190 is reached — this is fine. However, if the `WordDetailPanel` widget is disposed while the dialog is open (e.g., the user navigates away), the `_addException` method's stack frame keeps the `overrideController` alive until `showDialog` resolves, which may be never if the dialog context is also torn down. The controller will then not be disposed until the GC collects it.

**Fix:** Use a `try/finally` block to guarantee disposal:

```dart
final overrideController = TextEditingController();
try {
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(/* ... */),
  );
} finally {
  overrideController.dispose();
}
```

---

## Info

### IN-01: Table view column headers are misaligned — "Word" maps to IPA, "IPA" maps to romanization

**File:** `lib/features/lexicon/presentation/dictionary/word_list_panel.dart:465-498`

**Issue:** The `DataTable` has four columns labeled `Word`, `IPA`, `POS`, `Meaning`. Column 0 (`Word`) renders `lexeme.ipa` (line 509) and column 1 (`IPA`) renders `lexeme.romanization` (line 514). This is backwards: the "Word" column shows the IPA transcription, and the "IPA" column shows the romanized form. This is likely a copy-paste error. The sort logic is also misaligned: `_sortColumnIndex == 1` sorts by `romanization` (line 432) when the column labeled "IPA" is sorted.

**Fix:** Either swap the column labels (`Word` → `Romanization`, `IPA` → `IPA/Word`) or swap the `DataCell` render order so column 0 renders romanization and column 1 renders IPA.

### IN-02: `_tempDbPath` in `AnkiExporter` uses timestamp only — not process-safe for concurrent exports

**File:** `lib/features/lexicon/data/anki_exporter.dart:291-296`

**Issue:** `_tempDbPath` uses `DateTime.now().microsecondsSinceEpoch` as the sole source of uniqueness. If two export operations start within the same microsecond (unlikely in UI, but theoretically possible in tests run concurrently), they will write to the same temp path, causing one to corrupt the other's file. The original comment mentions "timestamp + pid" but the pid is not included.

**Fix:** Include the object's `hashCode` or an `isolate` identifier to guarantee uniqueness:

```dart
String _tempDbPath() {
  final tmpDir = Directory.systemTemp.path;
  final ts = DateTime.now().microsecondsSinceEpoch;
  final unique = identityHashCode(this);
  return '$tmpDir/anki_export_${ts}_$unique.db';
}
```

### IN-03: Anki export test `_verifyNoteCount` does not actually verify the note count

**File:** `test/lexicon/anki_export_test.dart:175-189`

**Issue:** The `_verifyNoteCount` helper (called from Test 5) only verifies that the SQLite byte array is longer than 100 bytes — it does not verify that the `notes` table has `expectedCount` rows. The comment in the function acknowledges this: _"For now, verify the SQLite magic header presence as a proxy"_. This means Test 5 would pass even if all notes were missing from the export.

**Fix:** Open the exported SQLite bytes via a temp file (which `AnkiExporter._serializeDb` already does internally) and run `SELECT COUNT(*) FROM notes` to assert the count:

```dart
void _verifyNoteCount(List<int> dbBytes, int expectedCount) {
  final tmpPath = '${Directory.systemTemp.path}/anki_test_${DateTime.now().microsecondsSinceEpoch}.db';
  try {
    File(tmpPath).writeAsBytesSync(dbBytes);
    final db = sqlite3.open(tmpPath);
    try {
      final result = db.select('SELECT COUNT(*) AS cnt FROM notes');
      expect(result.first['cnt'], expectedCount);
    } finally {
      db.dispose();
    }
  } finally {
    try { File(tmpPath).deleteSync(); } catch (_) {}
  }
}
```

### IN-04: `word_list_panel.dart` uses `List<dynamic>` parameter types instead of `List<Lexeme>`

**File:** `lib/features/lexicon/presentation/dictionary/word_list_panel.dart:281, 416`

**Issue:** Both `_buildListView` and `_buildTableView` accept `List<dynamic>` as their `lexemes` parameter type (lines 281 and 416). All callers pass `List<Lexeme>` (the `filteredLexemeListProvider` return type). Using `dynamic` disables static type checking on all field accesses within those methods (`lexeme.ipa`, `lexeme.romanization`, etc.) — any field name typo would compile and fail only at runtime.

**Fix:** Change the parameter types to `List<Lexeme>`:

```dart
Widget _buildListView(
  BuildContext context,
  List<Lexeme> lexemes,   // was List<dynamic>
  Set<int> derivedMatches,
) { ... }

Widget _buildTableView(BuildContext context, List<Lexeme> lexemes) { ... }
```

---

_Reviewed: 2026-04-09T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
