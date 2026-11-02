# Phase 12: Writing Scratchpad - Research

**Researched:** 2026-04-15
**Domain:** Flutter/Dart — Interlinear glossing, morphological reverse lookup, phonotactic validation, Drift schema migration, GoRouter branch extension
**Confidence:** HIGH

## Summary

Phase 12 builds a new top-level "Scratchpad" tab where users type phrases in their conlang and receive live interlinear glossing (Leipzig format), IPA transcription, and error highlighting. All required infrastructure already exists: phonotactic validation via `phonotacticValidatorProvider`, rewrite-rule IPA pipeline via `applyRewritePipelineProvider`, the paradigm engine via `computeParadigmCell`/`generateParadigm`, and the morphology engine via `MorphologyEngine.applyRule`. The phase is primarily an assembly task — wiring these existing pieces into a new feature directory and a new Drift table.

The most architecturally significant decision locked in CONTEXT.md is the **pre-computed inflected-form index**: the glosser must NOT call `computeParadigmCell` per token at keypress time. Instead, a Riverpod provider must build a project-wide `Map<String, GlossMatch>` at load time (or when the lexicon/grammar changes), mapping every known inflected/derived surface form to its decomposition. The scratchpad parser then does O(1) map lookups per token.

**Primary recommendation:** Build the inflected-form index as a single `Provider<Map<String, GlossMatch>>` that watches `allLexemeListProvider` + `computedInflectedParadigmProvider` family + `computedDerivedFormsProvider` family. Token lookup in the glosser is a pure synchronous map hit against this pre-built index.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Navigation & Layout**
- New top-level "Scratchpad" tab added as the 4th tab after Lexicon
- Two-panel layout: left sidebar with saved phrase list, right panel with current phrase editor + interlinear display
- "New phrase" button in toolbar; clicking it auto-focuses cursor in the input field
- Free translation is the third interlinear tier directly in the block, editable inline — shown as a dim "Add free translation..." prompt when empty

**Tokenization & Parsing**
- Input is whitespace-split into word tokens; each token is resolved via a multi-step lookup:
  1. Exact lexeme match — check root forms in the lexicon (including closed-class particles from Phase 10 with their gloss tags)
  2. Inflected form match — check against known inflected paradigm forms for all lexemes (via the paradigm engine); recognize e.g. "running" as run + PROG
  3. Derived form match — check derived forms computed by the morphology engine for derivational chains
  4. Unknown — if none of the above match, mark as "?"
- Gloss line for matched words: direct lexeme match → show word's primary gloss; derived/inflected form → show decomposition chain (e.g. "walk.PAST.3SG")
- IPA transcription line is on-demand via toggle button — applies phonological rewrite rules to each token's phonemic form (same pipeline as the lexicon's IPA preview)
- Re-parsing happens live with ~300ms debounce on each keystroke

**Error Highlighting**
- Unknown words: "?" in gloss cell + amber/yellow highlight on the word in the original text line
- Phonotactic violations: red underline on the offending token in the original line (consistent with phonotactic highlighting throughout the app)
- Scope in Phase 12: phonotactic violations and unknown words only — construction-rule validation deferred to later phases
- Error display is inline only — color coding on each token, no separate error panel

**Persistence**
- Auto-save with 1-second debounce — consistent with typology/settings pages (no explicit save button)
- Stored per phrase: original text + free translation + createdAt + updatedAt timestamps — gloss data is always recomputed live from current lexicon/grammar state (never cached)
- Phrase list ordered reverse chronologically (newest first); no manual reordering in Phase 12
- New `ScratchpadPhrases` Drift table in app_database.dart: `id` (autoincrement), `projectId` (FK — NOTE: projects are per-database files; there is no global projectId FK in this schema — see Pitfall 2), `originalText` (text), `freeTranslation` (text, nullable), `createdAt` (datetime), `updatedAt` (datetime)

### Claude's Discretion
- Exact visual styling for the interlinear block (font sizes, tier spacing, token cell borders)
- Icon choice for the Scratchpad tab
- Whether IPA toggle is per-phrase or global (per session)
- Exact sidebar phrase list item layout (preview snippet, timestamp display)

### Deferred Ideas (OUT OF SCOPE)
- Construction-rule validation (word order checking) — Phase 12 scope is phonotactic + unknown-word errors only
- Drag-to-reorder phrase list — deferred to later phase
- Manual "Parse" button (always live re-parsing in Phase 12)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WRIT-01 | User can write phrases and have them tokenized into morphemes with automatic interlinear glossing in Leipzig format (original / morpheme gloss / free translation) | Multi-step lookup index built from `allLexemeListProvider` + paradigm/derivation providers; whitespace tokenization; `computeParadigmCell` for inflected-form enumeration |
| WRIT-02 | Unknown tokens display as "?" in the gloss, and words violating phonotactics or grammar rules are highlighted as errors | `phonotacticValidatorProvider` returns `ValidationResult`; `ViolationText` widget for red underline; amber highlight for unknown-token cells |
| WRIT-03 | User can generate IPA transcription of written phrases from phonology rules | `applyRewritePipelineProvider` returns a `String Function(String phonemic)` that applies all rewrite rules; IPA toggle per-phrase |
| WRIT-04 | User can enter a free translation line beneath each glossed phrase | `ScratchpadPhrases.freeTranslation` (nullable text); inline editable third tier in the interlinear block; auto-saved via 1-second debounce |
</phase_requirements>

## Standard Stack

### Core (all already in pubspec — no new packages needed)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| drift | project version | Drift DAO + table for `ScratchpadPhrases` | All persistence uses Drift [VERIFIED: codebase grep] |
| flutter_riverpod | project version | Providers for gloss index, phrase list, debounce | All state management uses Riverpod [VERIFIED: codebase grep] |
| go_router | project version | New `/scratchpad` branch | All routing uses GoRouter [VERIFIED: app_router.dart] |
| dart:async `Timer` | stdlib | 300ms parse debounce + 1s auto-save debounce | Established pattern: `preview_panel.dart` line 61 [VERIFIED: codebase grep] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ViolationText widget | internal | Red wavy underline for phonotactic violations | Reuse `lib/shared/widgets/violation_text.dart` for token error display |
| phonotacticValidatorProvider | internal | `ValidationResult Function({required String word})` | Call per-token at gloss compute time |
| applyRewritePipelineProvider | internal | `String Function(String phonemic)` | Apply when IPA toggle is on |

**Installation:** No new packages. All dependencies are already in pubspec.

## Architecture Patterns

### Recommended Project Structure
```
lib/features/scratchpad/
├── data/
│   ├── scratchpad_dao.dart          # Drift DAO for ScratchpadPhrases
│   ├── scratchpad_dao.g.dart        # Generated
│   ├── scratchpad_providers.dart    # Riverpod providers (DAO, phrase list, gloss index)
│   └── gloss_index_provider.dart   # The pre-computed Map<String, GlossMatch>
├── domain/
│   ├── gloss_match.dart             # GlossMatch sealed class + GlossResult
│   └── phrase_tokenizer.dart        # Whitespace tokenizer + token resolver
└── presentation/
    ├── scratchpad_page.dart         # Two-panel page (phrase list + editor)
    ├── phrase_list_panel.dart       # Left sidebar — saved phrases
    ├── phrase_editor_panel.dart     # Right panel — input + interlinear display
    └── interlinear_block.dart       # Leipzig-format gloss widget
```

### Pattern 1: Pre-computed Gloss Index

**What:** A single `Provider<Map<String, GlossMatch>>` that pre-indexes all known surface forms → their gloss decompositions. The scratchpad parser does O(1) lookups.

**When to use:** Required — brute-force per-token paradigm computation would run ~N_lexemes × N_cells × N_dimensions computations per keypress.

**Example:**
```dart
// Source: codebase — mirrors pattern of lexemeViolationsProvider (lexeme_providers.dart:637)
// and computedInflectedParadigmProvider (typology_providers.dart:378)

sealed class GlossMatch {
  const GlossMatch();
}

class ExactLexemeMatch extends GlossMatch {
  const ExactLexemeMatch({required this.lexeme});
  final Lexeme lexeme; // use lexeme.meaning or lexeme.glossTag
}

class InflectedFormMatch extends GlossMatch {
  const InflectedFormMatch({
    required this.lexeme,
    required this.ruleChain,   // List<InflectionalRule> from ParadigmFilled
    required this.featureSet,  // FeatureSet = Map<int,int>
  });
  final Lexeme lexeme;
  final List<InflectionalRule> ruleChain;
  final FeatureSet featureSet;
}

class DerivedFormMatch extends GlossMatch {
  const DerivedFormMatch({
    required this.rootLexeme,
    required this.ruleName,
  });
  final Lexeme rootLexeme;
  final String ruleName;
}

// Provider: watches allLexemeListProvider, closes over paradigm + derivation
// computation. Rebuilds when lexicon or grammar rules change.
final glossIndexProvider = Provider<Map<String, GlossMatch>>((ref) {
  final allLexemes = ref.watch(allLexemeListProvider).asData?.value ?? [];
  final index = <String, GlossMatch>{};

  for (final lex in allLexemes) {
    // Step 1: exact root/base form
    index[lex.ipa] = ExactLexemeMatch(lexeme: lex);
    if (lex.romanization != null) {
      index[lex.romanization!] = ExactLexemeMatch(lexeme: lex);
    }
    // Step 2 + 3: inflected and derived forms via existing providers
    // (use ref.read — these are family providers keyed by lexeme id)
    final paradigm = ref.watch(computedInflectedParadigmProvider(lex.id));
    for (final entry in paradigm.entries) {
      if (entry.cell case ParadigmFilled(:final form, :final ruleChain)) {
        index.putIfAbsent(form, () => InflectedFormMatch(
          lexeme: lex,
          ruleChain: ruleChain,
          featureSet: entry.featureSet,
        ));
      }
    }
    final derived = ref.watch(computedDerivedFormsProvider(lex.id));
    for (final d in derived) {
      index.putIfAbsent(d.derivedIpa, () => DerivedFormMatch(
        rootLexeme: lex,
        ruleName: d.ruleName,
      ));
    }
  }
  return index;
});
```

**Critical note on `ref.watch` in family loops:** Riverpod allows `ref.watch` inside provider bodies but iterating over all lexemes and watching a family provider per lexeme creates O(N) subscriptions. This is the established pattern used in `lexemesByIntrinsicCombinationProvider` (grammar_providers.dart:256) and `filteredLexemeListProvider`. For conlang-scale lexicons (< 10k words), this is acceptable. [VERIFIED: codebase pattern]

### Pattern 2: Debounced Text Field → Parse Trigger

**What:** `ConsumerStatefulWidget` holds two `Timer` instances: one for parse debounce (300ms), one for auto-save debounce (1s). Text changes restart both timers independently.

**Example:**
```dart
// Source: codebase — adapted from preview_panel.dart:32,54,61
Timer? _parseDebounce;
Timer? _saveDebounce;

void _onTextChanged(String value) {
  _parseDebounce?.cancel();
  _saveDebounce?.cancel();
  _parseDebounce = Timer(const Duration(milliseconds: 300), _triggerParse);
  _saveDebounce  = Timer(const Duration(milliseconds: 1000), _triggerSave);
}

@override
void dispose() {
  _parseDebounce?.cancel();
  _saveDebounce?.cancel();
  super.dispose();
}
```

### Pattern 3: Adding a 4th Top-Level Tab

**AppShell** (`lib/shared/widgets/app_shell.dart:33`):
```dart
// Extend _tabs list — static const, index position must match router branch
static const _tabs = [
  _TabItem(label: 'Phonology', icon: Icons.music_note, enabled: true, phase: null),
  _TabItem(label: 'Grammar', icon: Icons.account_tree, enabled: true, phase: null),
  _TabItem(label: 'Lexicon', icon: Icons.menu_book, enabled: true, phase: null),
  _TabItem(label: 'Scratchpad', icon: Icons.edit_note, enabled: true, phase: null), // NEW
];
```

**GoRouter** (`lib/router/app_router.dart`): Add a 4th `StatefulShellBranch` after Branch 2 (Lexicon). The Scratchpad page does NOT need a nested shell (no sub-tabs) — a flat `GoRoute` suffices:
```dart
// Branch 3: Scratchpad (Phase 12)
StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/scratchpad',
      builder: (_, _) => const ScratchpadPage(),
    ),
  ],
),
```
[VERIFIED: app_router.dart — branch order matches _tabs list index]

### Pattern 4: Drift DAO + Schema Migration

**Table definition:**
```dart
// Add to app_database.dart, @DriftDatabase tables list, and daos list
class ScratchpadPhrases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get originalText => text().withDefault(const Constant(''))();
  TextColumn get freeTranslation => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  // NOTE: No FK to a projects table — each project is a separate
  // SQLite file. The table is project-scoped by the database file itself.
}
```

**Migration block (schemaVersion → 17):**
```dart
// In MigrationStrategy.onUpgrade:
if (from < 17) {
  await m.createTable(scratchpadPhrases);
}
```
[VERIFIED: migration pattern — app_database.dart:544-781, schemaVersion currently 16]

### Pattern 5: Interlinear Block Widget

**What:** A horizontal scrolling row of token "cells", each showing three tiers: original text (top), gloss abbreviation (middle), and a shared free-translation field spanning all tokens (bottom, third tier).

```
┌──────────┬──────────┬──────────┐
│  nakalu  │   -to    │  -nu     │  ← original tokens (amber bg if unknown)
├──────────┼──────────┼──────────┤
│ eat.PAST │  1SG.ERG │  ACC     │  ← gloss line (? if unknown)
├──────────┴──────────┴──────────┤
│ I ate the fish                  │  ← free translation (spans all columns, editable)
└─────────────────────────────────┘
Optional IPA line (when toggle on):
│ /na.ka.lu/ │ /to/ │ /nu/        │
```

The free-translation field is a single `TextField` spanning the full width below the token grid, not per-token. The "Add free translation..." placeholder (dim text) follows the established pattern for nullable text fields in this app.

### Anti-Patterns to Avoid

- **Calling `computeParadigmCell` per token per keystroke:** This is O(N_dims × N_rules) per call. Pre-build the index via `glossIndexProvider` instead.
- **Caching gloss output in the DB:** CONTEXT.md explicitly locks this as "gloss data is always recomputed live" — never persist parsed gloss output.
- **Using `riverpod_annotation` / `@riverpod` codegen for scratchpad providers:** The project convention (STATE 01-05, confirmed in grammar_providers.dart:19 comment) is that providers trafficking in Drift-generated types MUST be hand-written plain providers. [VERIFIED: grammar_providers.dart:19-22]
- **Using `ref.read` inside provider bodies to access other providers:** Use `ref.watch` so the index rebuilds when dependencies change.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Phonotactic violation detection | Custom constraint checker | `phonotacticValidatorProvider` → `validateWord` | Already handles templates, constraints, gemination, position scoping |
| IPA transcription | Custom rewrite engine | `applyRewritePipelineProvider` (returns `String Function(String)`) | Already applies all user-defined rewrite rules in order |
| Inflected form computation | Custom paradigm loop | `computedInflectedParadigmProvider(lexemeId)` + `generateParadigm` | Already handles intrinsic dims, overrides, ambiguity, D-112 phonemic/phonetic split |
| Derived form computation | Custom rule applier | `computedDerivedFormsProvider(lexemeId)` | Already handles D-61 strict POS filter, engine integration |
| Red wavy underline | Custom RichText spans | `ViolationText` widget (`lib/shared/widgets/violation_text.dart`) | Established shared widget with tooltip support |
| Drift reactive streams | Manual SQLite polling | `StreamProvider` watching DAO streams | All DAOs expose `watch()` streams; Riverpod caches them |

**Key insight:** The scratchpad is essentially a new UI layer on top of existing engines. Virtually all computation is already tested in the lexicon and grammar viewer.

## Common Pitfalls

### Pitfall 1: Watching family providers in a loop inside glossIndexProvider
**What goes wrong:** Watching `computedInflectedParadigmProvider(id)` for every lexeme creates O(N) subscriptions. On large lexicons, this can cause slow rebuild times.
**Why it happens:** Family providers are cached per key — each `ref.watch(computedInflectedParadigmProvider(id))` is a separate subscription.
**How to avoid:** This is acceptable for conlang-scale lexicons (< 10k words) per the established pattern in `filteredLexemeListProvider` and `lexemesByIntrinsicCombinationProvider`. Document the assumption. If performance is an issue, fall back to synchronous computation inside the provider body using the raw data already watched.
**Warning signs:** Provider rebuild time > 500ms on keystroke in the phrase editor.

### Pitfall 2: ScratchpadPhrases table has no FK to a projects table
**What goes wrong:** CONTEXT.md mentions a `projectId` FK but this app has no global projects table — each project IS a separate SQLite database file (`{projectDir}/project.db`). A `projectId` FK would reference nothing.
**Why it happens:** The CONTEXT.md language was written anticipating a shared DB model, but the actual schema is per-file.
**How to avoid:** Omit the `projectId` column entirely. The table is project-scoped by the database file. [VERIFIED: app_database.dart — no global projects table exists]

### Pitfall 3: IPA toggle state lives in the wrong place
**What goes wrong:** If IPA toggle state is stored in a Riverpod provider, it persists across phrase selections and survives hot restart — may surprise the user.
**Why it happens:** CONTEXT.md leaves IPA toggle scope to Claude's discretion.
**How to avoid:** Store toggle state as a local `bool` in the `PhraseEditorPanel` `ConsumerStatefulWidget`. Per-phrase, per-session — reset when switching phrases. This matches the CONTEXT.md intent of "per-phrase button in the interlinear block header."

### Pitfall 4: romanization vs IPA for lookup key
**What goes wrong:** Users type in romanization, but the gloss index is keyed on IPA. Exact-match fails for every token.
**Why it happens:** The Lexemes table stores both `ipa` and `romanization`. The word generator and phonotactic validator operate on IPA. Users may type in either romanization or IPA.
**How to avoid:** The gloss index MUST include both IPA and romanization keys for each lexeme (and their inflected/derived forms). When building the index:
  1. Add `lex.ipa` → match
  2. Add `lex.romanization` → match (if non-null and non-empty)
  3. For inflected forms, also compute romanization via `romanizeProvider` and add as a key.

### Pitfall 5: ParadigmCell shape — only ParadigmFilled has a surface form
**What goes wrong:** Treating all `ParadigmCell` variants as having a form string. `ParadigmUncovered`, `ParadigmAmbiguous`, and `ParadigmUnmarked` do not.
**Why it happens:** `computeParadigmCell` returns a sealed `ParadigmCell` with four variants.
**How to avoid:** When iterating `paradigm.entries` in the gloss index builder, pattern-match on `ParadigmFilled` only:
```dart
if (entry.cell case ParadigmFilled(:final form, :final ruleChain)) { ... }
```
[VERIFIED: paradigm_engine.dart return types]

### Pitfall 6: The debounce timer leak on widget dispose
**What goes wrong:** If `_parseDebounce` or `_saveDebounce` are not cancelled in `dispose()`, they fire after the widget unmounts, calling `setState` on a dead widget.
**Why it happens:** `Timer` callbacks hold a reference to the widget closure.
**How to avoid:** Always cancel both timers in `dispose()`. [VERIFIED: preview_panel.dart:59]

### Pitfall 7: schemaVersion bump without beforeOpen safety net
**What goes wrong:** Hot restart during development may fire `beforeOpen` before `onUpgrade`, leaving the table absent.
**Why it happens:** The existing `beforeOpen` block has explicit `CREATE TABLE IF NOT EXISTS` safety nets for earlier tables. The new table must also be included.
**How to avoid:** Add a `CREATE TABLE IF NOT EXISTS scratchpad_phrases (...)` block in `beforeOpen`, following the exact pattern of existing safety nets. [VERIFIED: app_database.dart:783-840]

## Code Examples

Verified patterns from official codebase sources:

### Phonotactic Validation Per Token
```dart
// Source: lib/features/lexicon/data/phonotactic_validation_provider.dart:21
// Usage: call phonotacticValidatorProvider per token IPA string
final validate = ref.watch(phonotacticValidatorProvider);
final result = validate(word: token.ipa); // ValidationResult
if (!result.isValid) {
  // token has violations — show ViolationText widget
}
```

### IPA Transcription (Rewrite Pipeline)
```dart
// Source: lib/features/phonology/data/phonotactic_providers.dart:68
// applyRewritePipelineProvider returns String Function(String phonemic)
final applyRewrite = ref.watch(applyRewritePipelineProvider);
final surfaceIpa = applyRewrite(token.phonemicIpa);
```

### Paradigm Chart Iteration (for gloss index)
```dart
// Source: lib/features/grammar/data/typology_providers.dart:291
// ParadigmChart.entries → Iterable<ParadigmChartEntry>
final paradigm = ref.watch(computedInflectedParadigmProvider(lex.id));
for (final entry in paradigm.entries) {
  switch (entry.cell) {
    case ParadigmFilled(:final form, :final ruleChain):
      // form = surface form (post-rewrite); ruleChain = List<InflectionalRule>
      // entry.featureSet = Map<int,int> dimension→level
      index.putIfAbsent(form, () => InflectedFormMatch(...));
    default:
      break; // ParadigmUncovered / ParadigmAmbiguous / ParadigmUnmarked
  }
}
```

### Drift Table with DateTimeColumn
```dart
// Source: established Drift pattern (no existing DateTime col in schema, but
// DateTimeColumn is standard Drift API [ASSUMED from Drift docs patterns])
DateTimeColumn get createdAt => dateTime()();
// Drift stores as INTEGER (unix seconds). No extra config needed.
```

### Auto-Save Pattern (1s debounce)
```dart
// Source: preview_panel.dart:32,54,61 (300ms variant); adapted to 1s
Timer? _saveDebounce;

void _scheduleAutoSave() {
  _saveDebounce?.cancel();
  _saveDebounce = Timer(const Duration(milliseconds: 1000), () async {
    final db = ref.read(currentDatabaseProvider);
    if (db == null) return;
    await db.scratchpadDao.updatePhrase(...);
  });
}
```

### Drift Migration (v17 — add ScratchpadPhrases)
```dart
// Source: app_database.dart:773-781 (v16 pattern)
if (from < 17) {
  await m.createTable(scratchpadPhrases);
}
// Also add to beforeOpen block:
await customStatement('''
  CREATE TABLE IF NOT EXISTS scratchpad_phrases (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "original_text" TEXT NOT NULL DEFAULT '',
    "free_translation" TEXT,
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL
  )
''');
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `StateProvider` | `NotifierProvider` | flutter_riverpod 3.x | `StateProvider` removed — all mutable state uses `Notifier` |
| `riverpod_annotation` for Drift providers | Hand-written `Provider`/`StreamProvider` | Phase 4 (STATE 01-05) | Codegen cannot resolve Drift part-file types — Scratchpad providers MUST be hand-written |
| Paradigm per-call computation | Pre-built chart via `generateParadigm` | Phase 4 | `computedInflectedParadigmProvider(lexemeId)` caches the full chart per lexeme |

**Deprecated/outdated:**
- `StateProvider`: removed in riverpod 3.x — do not use for any scratchpad toggle or text state.
- `ref.read` in provider bodies: allowed but misses reactive updates — always use `ref.watch` for dependency tracking.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `DateTimeColumn get createdAt => dateTime()()` stores as INTEGER (unix seconds) in SQLite | Code Examples | Low — standard Drift behavior, but verify migration SQL if wrong; would affect beforeOpen safety net |
| A2 | `ParadigmChart.entries` exposes `Iterable<ParadigmChartEntry>` with `featureSet` and `cell` fields | Code Examples | Low — confirmed by reading `generateParadigm` and `ParadigmChart` shape in typology_providers.dart; only risk is a renamed field |

## Open Questions

1. **Gloss label format for inflected forms**
   - What we know: CONTEXT.md says e.g. "walk.PAST.3SG" using Leipzig abbreviations
   - What's unclear: Where do the abbreviation strings come from? `InflectionalRule` has a `name` (e.g. "Past Tense") but not necessarily a Leipzig abbreviation. `Dimension` has `abbreviation` (nullable, 3-char default) and each level has `abbr` in `levelsJson`.
   - Recommendation: Build the gloss label by concatenating `level.abbr` values from the winning rule's bindings. The `FeatureSet = Map<int,int>` in `ParadigmFilled` maps dimension ids to level ids; resolve each via the dimensions data already watched in `computedInflectedParadigmProvider`.

2. **Whether to rebuild glossIndexProvider when paradigm engine output changes**
   - What we know: `computedInflectedParadigmProvider` is a `Provider.family` — when rules or lexemes change, it recomputes, and anything watching it via `ref.watch` will too.
   - What's unclear: If `glossIndexProvider` watches the family provider for every lexeme, a change to one lexeme's paradigm triggers a full index rebuild. For 500+ lexemes this may be noticeable.
   - Recommendation: Accept the full rebuild for Phase 12 (conlangs are small). Add a TODO comment for future optimization via `select`-style fine-grained subscriptions if needed.

## Environment Availability

Step 2.6: SKIPPED — no external tools or services beyond the project's own Flutter/Dart stack. All dependencies are already in pubspec.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Flutter test (flutter_test) |
| Config file | none (standard flutter test runner) |
| Quick run command | `flutter test test/scratchpad/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WRIT-01 | Whitespace tokenization + multi-step lookup (exact → inflected → derived → unknown) | unit | `flutter test test/scratchpad/gloss_index_test.dart -x` | Wave 0 |
| WRIT-01 | Leipzig gloss label construction from FeatureSet | unit | `flutter test test/scratchpad/gloss_label_test.dart -x` | Wave 0 |
| WRIT-02 | Unknown tokens produce "?" gloss + amber highlight state | unit | `flutter test test/scratchpad/phrase_tokenizer_test.dart -x` | Wave 0 |
| WRIT-02 | Phonotactic violation tokens trigger red underline | widget | `flutter test test/scratchpad/scratchpad_widget_test.dart -x` | Wave 0 |
| WRIT-03 | IPA toggle applies rewrite pipeline per token | unit | `flutter test test/scratchpad/ipa_toggle_test.dart -x` | Wave 0 |
| WRIT-04 | Free translation persists via Drift DAO | unit | `flutter test test/scratchpad/scratchpad_dao_test.dart -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/scratchpad/ -x`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/scratchpad/gloss_index_test.dart` — covers WRIT-01 lookup pipeline
- [ ] `test/scratchpad/gloss_label_test.dart` — covers WRIT-01 Leipzig labels
- [ ] `test/scratchpad/phrase_tokenizer_test.dart` — covers WRIT-01/WRIT-02 tokenizer
- [ ] `test/scratchpad/ipa_toggle_test.dart` — covers WRIT-03
- [ ] `test/scratchpad/scratchpad_dao_test.dart` — covers WRIT-04 persistence
- [ ] `test/scratchpad/scratchpad_widget_test.dart` — covers WRIT-02 widget highlighting

## Security Domain

This phase has no network calls, authentication, user-supplied code execution, or external data ingestion beyond local SQLite reads. Standard Drift-managed parameterized queries prevent SQL injection. No ASVS categories apply beyond V5 (Input Validation) — the phrase text input is display-only and stored as TEXT; no execution or interpretation of user input occurs. Skipping full ASVS table for this reason.

## Sources

### Primary (HIGH confidence)
- `lib/features/phonology/data/phonotactic_providers.dart` — `phonotacticValidatorProvider`, `applyRewritePipelineProvider` signatures verified
- `lib/features/phonology/domain/word_generator.dart` — `validateWord`, `ValidationResult`, `Violation` types verified
- `lib/db/app_database.dart` — schemaVersion=16, migration pattern, table definitions, all verified
- `lib/router/app_router.dart` — `StatefulShellRoute.indexedStack` branch structure verified
- `lib/shared/widgets/app_shell.dart` — `_tabs` list, `_TabItem` structure verified
- `lib/shared/widgets/violation_text.dart` — `ViolationText` widget API verified
- `lib/features/grammar/domain/paradigm_engine.dart` — `computeParadigmCell`, `generateParadigm`, `ParadigmFilled` structure verified
- `lib/features/grammar/data/typology_providers.dart` — `computedInflectedParadigmProvider`, `generateParadigm` call verified
- `lib/features/lexicon/data/lexeme_providers.dart` — `computedDerivedFormsProvider`, debounce patterns, `DerivedFormResult` verified
- `lib/features/lexicon/data/phonotactic_validation_provider.dart` — `phonotacticValidatorProvider` return type verified
- `lib/features/grammar/data/particle_providers.dart` — `closedClassLexemeListProvider` verified
- `lib/features/morphology/presentation/rules/preview_panel.dart` — 300ms `_debounce` Timer pattern verified

### Secondary (MEDIUM confidence)
- `lib/features/grammar/data/grammar_providers.dart:19` — codegen restriction for Drift providers (hand-written pattern is verified in source, rationale in STATE.md)

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in use, no new packages
- Architecture: HIGH — all patterns verified directly from codebase
- Pitfalls: HIGH — each pitfall identified from direct code inspection (wrong FK assumption, family provider loops, romanization key gap)
- Test map: MEDIUM — test file names are proposed; actual test content is Wave 0 work

**Research date:** 2026-04-15
**Valid until:** 2026-05-15 (stable Flutter/Drift stack, low churn)
