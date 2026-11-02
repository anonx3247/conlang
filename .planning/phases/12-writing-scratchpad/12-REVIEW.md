---
phase: 12-writing-scratchpad
reviewed: 2026-04-15T00:00:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - lib/db/app_database.dart
  - lib/features/scratchpad/data/scratchpad_dao.dart
  - lib/features/scratchpad/data/scratchpad_providers.dart
  - lib/features/scratchpad/data/gloss_index_provider.dart
  - lib/features/scratchpad/domain/gloss_match.dart
  - lib/features/scratchpad/domain/phrase_tokenizer.dart
  - lib/features/scratchpad/presentation/scratchpad_page.dart
  - lib/features/scratchpad/presentation/phrase_list_panel.dart
  - lib/features/scratchpad/presentation/phrase_editor_panel.dart
  - lib/features/scratchpad/presentation/interlinear_block.dart
  - lib/shared/widgets/app_shell.dart
  - lib/router/app_router.dart
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-04-15
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

The Phase 12 scratchpad feature is well-structured. The DB layer (table definition, v17 migration, `beforeOpen` safety net) follows the project's established migration pattern correctly. The DAO, provider, and domain types are clean. The `PhraseEditorPanel` timer/controller lifecycle is handled properly in `dispose()`. The router and app-shell additions are minimal and correct.

Four warnings are raised: one logic bug in the tokenizer (empty tokens from leading whitespace), two missing `mounted` guards on async `setState` calls in `ScratchpadPage`, and one stale-read pattern in `_triggerParse` where `ref.read` is used for providers whose value should reflect the latest reactive state. Three info items cover minor quality issues.

---

## Warnings

### WR-01: Tokenizer produces empty-string tokens for input with leading/trailing whitespace

**File:** `lib/features/scratchpad/domain/phrase_tokenizer.dart:38`

**Issue:** `input.split(RegExp(r'\s+'))` on a string with leading or trailing whitespace (e.g. `" foo bar "`) produces an empty string at position 0 and/or the last position because `split` splits on every match of the pattern and the pattern matches the whitespace before the first word and after the last word. The `trim().isEmpty` guard at line 36 only short-circuits all-whitespace input; it does not prevent the empty tokens produced by the split itself.

An empty token goes through the full pipeline: `glossIndex['']` returns `null` → `UnknownToken(text: '')`, which then renders an empty amber-highlighted column in the interlinear display and triggers `validateWord(word: '')` unnecessarily.

Verified by running:
```
'  foo  bar  '.split(RegExp(r'\s+'))  →  ['', 'foo', 'bar', '']
```

**Fix:** Trim the input before splitting, or filter empty tokens after the split:

```dart
List<PhraseToken> tokenizePhrase({...}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return const [];

  final words = trimmed.split(RegExp(r'\s+'));
  // No empty tokens possible after trimming
  return words.map((word) { ... }).toList();
}
```

Alternatively (belt-and-suspenders):
```dart
final words = input.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
```

---

### WR-02: Missing `mounted` guard after async gap in `_createNewPhrase`

**File:** `lib/features/scratchpad/presentation/scratchpad_page.dart:23-24`

**Issue:** `_createNewPhrase` `await`s `dao.createPhrase()` and then calls `setState(...)` unconditionally. If the user navigates away from `ScratchpadPage` while the DB insert is in-flight, the widget will have been disposed and `setState` will throw a `setState() called after dispose()` exception (or a warning in debug, crash in release builds that lack the debug-mode guard).

```dart
Future<void> _createNewPhrase() async {
  final dao = ref.read(scratchpadDaoProvider);
  if (dao == null) return;
  final id = await dao.createPhrase();
  setState(() => _selectedPhraseId = id);  // <-- no mounted check
}
```

**Fix:**
```dart
final id = await dao.createPhrase();
if (!mounted) return;
setState(() => _selectedPhraseId = id);
```

---

### WR-03: Missing `mounted` guard after async gap in `_deletePhrase`

**File:** `lib/features/scratchpad/presentation/scratchpad_page.dart:30-33`

**Issue:** Same pattern as WR-02. `_deletePhrase` `await`s `dao.deletePhrase(id)` and then conditionally calls `setState` with no `mounted` check.

```dart
Future<void> _deletePhrase(int id) async {
  final dao = ref.read(scratchpadDaoProvider);
  if (dao == null) return;
  await dao.deletePhrase(id);
  if (_selectedPhraseId == id) {
    setState(() => _selectedPhraseId = null);  // <-- no mounted check
  }
}
```

**Fix:**
```dart
await dao.deletePhrase(id);
if (!mounted) return;
if (_selectedPhraseId == id) {
  setState(() => _selectedPhraseId = null);
}
```

---

### WR-04: `_triggerParse` uses `ref.read` for reactive providers, causing stale reads

**File:** `lib/features/scratchpad/presentation/phrase_editor_panel.dart:82-83`

**Issue:** `_triggerParse` is called from a debounce `Timer` callback. Inside it reads two providers via `ref.read`:

```dart
void _triggerParse() {
  final glossIndex = ref.read(glossIndexProvider);
  final validate = ref.read(phonotacticValidatorProvider);
  ...
}
```

`ref.read` captures the current value at the moment of the call but does not subscribe the widget to future changes. If the lexicon or phonotactic constraints change while the scratchpad is open (the user switches to the Lexicon tab, adds a word, then returns), the debounce timer will fire and reparse using the stale snapshot from the last time `_triggerParse` ran, not the current reactive values.

The correct pattern for a `ConsumerStatefulWidget` that needs live reactive data inside an imperative method is to use `ref.read` only when you intentionally want a one-shot value, or to subscribe via `ref.watch` in `build` and pass the values down. For debounced callbacks, `ref.read` at the moment the timer fires is actually the right choice — BUT only if Riverpod's `ProviderContainer` already recomputed the provider. In practice, `ref.read(glossIndexProvider)` from a `ConsumerState` returns the latest computed value (it does not return a stale cached result), so this is a code clarity/documentation issue more than a functional bug.

**However**, a real edge case exists: if the `glossIndexProvider` is in a loading/uncomputed state because `allLexemeListProvider` has not yet resolved its async value, `ref.read(glossIndexProvider)` returns the current (possibly empty) synchronous value `{}`. This means a parse triggered during the initial data-load window produces all-unknown tokens, which is then displayed and persists until the next keystroke or navigation.

**Fix — bind to build-time values passed into `_triggerParse`:** Let `build()` watch both providers (it already watches `applyRewritePipelineProvider`) and pass them as parameters to `_triggerParse`, or trigger a re-parse reactively:

```dart
// In build():
final glossIndex = ref.watch(glossIndexProvider);
final validate = ref.watch(phonotacticValidatorProvider);
// ... store as fields or pass to _triggerParse

void _triggerParse() {
  final tokens = tokenizePhrase(
    input: _textController.text,
    glossIndex: glossIndex,   // from build-time watch
    validateWord: ({required String word}) => validate(word: word).isValid,
  );
  if (mounted) setState(() => _tokens = tokens);
}
```

Alternatively, add a `ref.listen` on `glossIndexProvider` to trigger a re-parse whenever the gloss index rebuilds (so stale interlinear results self-correct without user interaction).

---

## Info

### IN-01: `v17 beforeOpen` safety net is not wrapped in `try/catch` unlike earlier tables

**File:** `lib/db/app_database.dart:1053-1062`

**Issue:** The v17 `beforeOpen` safety-net block for `scratchpad_phrases` uses `CREATE TABLE IF NOT EXISTS` without a `try/catch`, unlike several other safety-net blocks for earlier versions that do wrap in `try/catch` (e.g., line 856). The `IF NOT EXISTS` clause makes the statement idempotent on its own, so this is not a bug, but it is inconsistent with the pattern used for some (not all) other safety nets in this file. Low risk since SQLite `IF NOT EXISTS` is reliable.

**Fix:** For consistency with the surrounding code pattern, or leave as-is since the statement is idempotent. No code change required.

---

### IN-02: `_formatTimestamp` uses local `DateTime.now()` on every cell render

**File:** `lib/features/scratchpad/presentation/phrase_list_panel.dart:159-167`

**Issue:** `_formatTimestamp` is a method on a `StatelessWidget` that calls `DateTime.now()` inside `build()`. Because this widget is rebuilt on every frame that re-renders the list, the timestamp string is recomputed on each build. This is not a performance problem at 60fps (the computation is cheap), but it means that the displayed "just now" / "Xm ago" string can be slightly inaccurate (off by the time between the actual save and the next rebuild). More importantly, the relative timestamp will not update live after the initial render — it will only re-evaluate when the parent's `StreamProvider` emits (i.e. when the DB changes). This is the expected and acceptable behavior for most apps, so this is informational only.

**Fix:** No change required unless live-updating timestamps are desired, in which case a `Timer.periodic` in a `StatefulWidget` would be needed.

---

### IN-03: Empty tooltip message on non-violation, non-unknown tokens creates a visible empty tooltip

**File:** `lib/features/scratchpad/presentation/interlinear_block.dart:122-123`

**Issue:** The `Tooltip` widget is always present for every token. For a matched, non-violating token the `message` is set to `''`:

```dart
Tooltip(
  message: token.isUnknown
      ? 'Unknown — not found in lexicon'
      : token.hasViolation
          ? 'Phonotactic violation'
          : '',   // <-- empty string
  waitDuration: const Duration(milliseconds: 500),
  ...
)
```

Flutter's `Tooltip` with an empty string still renders a tooltip; it shows an empty box after `waitDuration` on hover/long-press. This is a minor visual bug on desktop (macOS hover).

**Fix:** Conditionally wrap with `Tooltip` only when there is a message, or use a null message:
```dart
child: token.isUnknown || token.hasViolation
    ? Tooltip(
        message: token.isUnknown
            ? 'Unknown \u2014 not found in lexicon'
            : 'Phonotactic violation',
        waitDuration: const Duration(milliseconds: 500),
        child: tokenWidget,
      )
    : tokenWidget,
```

---

_Reviewed: 2026-04-15_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
