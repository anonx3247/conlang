# Phase 1: Foundation - Research

**Researched:** 2026-04-08
**Domain:** Flutter desktop app, SQLite/Drift, Riverpod 3, go_router, IPA audio, custom keyboard, phonotactic DSL
**Confidence:** MEDIUM-HIGH (no Context7 available; WebSearch + WebFetch against official docs)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**App navigation & layout**
- Top-level tabs for major sections (Phonology, Lexicon, Grammar, etc.) with a secondary sidebar for sub-navigation within each section
- Phase 1 shows only the Phonology tab; other tabs appear as their phases are completed
- Project management lives in the menu bar (File → New / Open / etc.), not a dedicated launcher screen
- Within Phonology, the sidebar has two items: **Inventory** (phonemes) and **Sound Rules** (phonotactics)
- IPA keyboard is not a sidebar section — it's a popup widget that appears in IPA text-input fields throughout the app
- IPA reference chart is a persistent side panel visible at all times as a reference, not a separate page

**Phonotactic rule notation**
- Template notation for syllable structures: `(C)(C)V(C)` with natural-class references like `[stop]`, `[liquid]`, `[nasal]`
- Phonotactic constraint rules use the same notation style: `VN -> nasalised V`
- Text-based DSL, not visual builder — power and flexibility over hand-holding
- **Critical constraint:** The DSL must be flexible enough to handle ALL language types (tonal, click, polysynthetic, agglutinative, etc.), not just Indo-European patterns

**Rule testing & feedback**
- Inline preview: as rules are edited, a live panel shows sample generated words updating in real-time
- Word generator is integrated into the rule editing flow, not a separate page

**Violation display**
- Red underline + tooltip on words/segments that violate phonotactic constraints (spell-check style)
- Hover reveals which specific rule is violated

### Claude's Discretion
- Desktop window default size and resize behavior
- IPA chart layout specifics (standard IPA grid arrangement)
- IPA keyboard popup trigger and positioning
- Exact phonotactic DSL syntax design (within the flexibility constraint)
- Empty state designs for new projects
- Romanization mapping UI (mentioned in success criteria, not discussed)

### Deferred Ideas (OUT OF SCOPE)
- Sound change rules (assimilation, vowel harmony, palatalization, etc.) — deferred from Phase 1
- Full phonological rule engine (ordered rule application, feeding/bleeding) — future phase
</user_constraints>

---

## Summary

Phase 1 is a Flutter desktop application with six main implementation domains: app shell/navigation, project management, database schema, phoneme inventory editor, IPA reference + audio, and phonotactic rule editing with word generation. Each domain has a clear best-practice stack; no exotic choices are needed. The biggest risks are (1) the multi-database-per-project architecture with Drift — there is no official "open/close/switch" pattern, so it must be implemented manually using `LazyDatabase` with a custom path and Riverpod family providers keyed to the project ID, and (2) the phonotactic DSL, which must be hand-built on top of `petitparser` since no domain-specific library exists for conlang phonotactics.

The audio stack for desktop requires an extra package: `just_audio_media_kit` for Windows and Linux. macOS works with `just_audio` alone. Wikipedia/Wikimedia Commons provides OGG recordings under Creative Commons licenses (attribution required); these can be bundled as Flutter assets. The IPA keyboard is best built as a plain Flutter overlay widget using `OverlayPortal` and `CompositedTransformFollower` — no third-party keyboard package is needed or suitable for desktop.

**Primary recommendation:** Use go_router 17 `StatefulShellRoute` for the tab+sidebar shell, Drift 2.32+ `LazyDatabase` with per-project file paths for isolation, Riverpod 3 `@riverpod` with family providers keyed by project ID for state scoping, `petitparser` 7.x for the DSL parser, and `just_audio` + `just_audio_media_kit` for cross-platform audio playback.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| go_router | 17.2.0 | Declarative routing, nested navigation, tab shell | First-party Flutter team package; `StatefulShellRoute` preserves tab state on desktop |
| drift | 2.32.1 | Type-safe SQLite ORM with migrations | Reactive, type-safe, officially supports all desktop platforms; `LazyDatabase` enables dynamic file paths |
| drift_flutter | latest | Drift + path_provider integration for Flutter | Simplifies native SQLite setup on each platform |
| flutter_riverpod | 3.3.1 | State management, provider scoping | Riverpod 3.0 (Sep 2025) unified `Ref`, single `Notifier` class, code-gen via `@riverpod` annotation |
| riverpod_generator | latest | Code generation for `@riverpod` annotation | Eliminates boilerplate, enforces correct provider type selection |
| riverpod_annotation | latest | Annotation support for riverpod_generator | Required companion to riverpod_generator |
| petitparser | 7.0.2 | Parser combinator framework for DSL | MIT, 8.57M downloads, dynamic PEG parser combinators in plain Dart; builds correct grammars quickly |
| just_audio | 0.10.5 | Audio playback for IPA recordings | macOS native; needs just_audio_media_kit for Windows/Linux |
| just_audio_media_kit | 2.1.0 | Windows + Linux audio backend for just_audio | Provides media_kit bindings; required for cross-platform desktop audio |
| window_manager | 0.5.1 | Desktop window size, constraints, titlebar | Standard package for Flutter desktop window control; leanflutter.dev |
| path_provider | latest | Find app document directories | Required for per-project SQLite file paths |
| path | latest | Path string manipulation | Companion to path_provider |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| media_kit_libs_linux | any | Native media libraries for Linux audio | Required by just_audio_media_kit on Linux |
| media_kit_libs_windows_audio | any | Native media libraries for Windows audio | Required by just_audio_media_kit on Windows |
| riverpod_lint | latest | Lint rules for Riverpod correctness | Catches dispose errors, incorrect ref usage at analysis time |
| build_runner | latest | Code generation runner | Required to run riverpod_generator and drift codegen |
| drift_dev | latest | Drift code generation and migration tooling | Provides `drift_dev make-migrations` command |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| go_router (StatefulShellRoute) | auto_route, beamer | go_router is first-party and feature-complete; others add complexity without benefit here |
| drift | sqflite + manual queries | drift gives type safety, migrations tooling, reactivity — sqflite would require hand-rolling all of that |
| riverpod 3 | bloc, provider | Riverpod 3 has the lowest boilerplate for this use case; bloc is overkill for a solo project |
| petitparser | hand-rolled regex parser | petitparser handles ambiguous grammars, optional elements, and recursive structures correctly; regex cannot |
| just_audio + media_kit | audioplayers | just_audio has better API and asset:// loading; audioplayers has weaker desktop support |
| window_manager | Flutter built-in window API | Flutter's built-in desktop window API lacks minimum-size constraints and titlebar customization |

### Installation
```bash
flutter pub add go_router drift drift_flutter flutter_riverpod riverpod_annotation riverpod_generator petitparser just_audio just_audio_media_kit window_manager path_provider path media_kit_libs_linux media_kit_libs_windows_audio

flutter pub add --dev build_runner drift_dev riverpod_lint riverpod_generator
```

---

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── main.dart                    # App entry point, window setup, ProviderScope
├── app.dart                     # MaterialApp.router with go_router config
├── router/
│   └── app_router.dart          # go_router with StatefulShellRoute
├── features/
│   ├── project/                 # Project management (create/open/delete/switch)
│   │   ├── data/                # ProjectRegistry, database file management
│   │   ├── domain/              # Project model
│   │   └── presentation/        # File menu integration, empty state
│   └── phonology/
│       ├── data/                # Drift tables, DAOs for phonemes and rules
│       ├── domain/              # Phoneme, SyllableRule, PhonotacticRule models
│       └── presentation/
│           ├── inventory/       # Phoneme inventory CRUD editor
│           ├── sound_rules/     # Phonotactic rule editor + word generator panel
│           └── shared/
│               ├── ipa_chart/   # Persistent side panel with clickable grid
│               └── ipa_keyboard/ # Popup overlay widget for IPA text fields
├── db/
│   ├── app_database.dart        # Drift database class (tables, DAOs, schemaVersion)
│   └── migrations/              # drift_dev generated migration steps
└── shared/
    └── widgets/                 # Shared UI components
```

### Pattern 1: StatefulShellRoute for Tabs + Sidebar
**What:** A `StatefulShellRoute` wraps all top-level tab branches. Each branch keeps its own navigator stack (scroll positions, form state survive tab switches). A `ScaffoldWithSidebar` shell widget is the branch builder — it renders a top tab bar and a left navigation rail/sidebar.
**When to use:** Any desktop layout with persistent tab state.
**Example:**
```dart
// Source: https://pub.dev/packages/go_router (v17), flutter/packages examples
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) =>
      PhonologyShell(navigationShell: navigationShell),
  branches: [
    StatefulShellBranch(routes: [
      GoRoute(path: '/phonology/inventory', builder: (_, __) => InventoryPage()),
    ]),
    StatefulShellBranch(routes: [
      GoRoute(path: '/phonology/sound-rules', builder: (_, __) => SoundRulesPage()),
    ]),
  ],
)
```
The outer shell (top-level tabs) uses the same `StatefulShellRoute` pattern. Phase 1 only activates Phonology; other tab entries are rendered as disabled until their phase is complete.

### Pattern 2: Per-Project LazyDatabase with Riverpod Family
**What:** Each project has its own Drift database file. Opening a project creates a new `LazyDatabase` pointed at `{documentsDir}/conlang/{projectId}/project.db`. Riverpod `family` provider keyed by `projectId` holds the `AppDatabase` instance. Switching projects disposes the old provider and activates the new one.
**When to use:** Any app requiring isolated data per "workspace" or "file."
**Example:**
```dart
// Source: https://drift.simonbinder.eu/setup/ + Riverpod 3 @riverpod pattern
@riverpod
AppDatabase projectDatabase(Ref ref, String projectId) {
  final dir = ref.watch(appDocsDirProvider);
  final db = AppDatabase(
    LazyDatabase(() async {
      final file = File('$dir/conlang/$projectId/project.db');
      await file.parent.create(recursive: true);
      return NativeDatabase.createInBackground(file);
    }),
  );
  ref.onDispose(db.close);
  return db;
}
```
`ref.onDispose(db.close)` is critical — Riverpod auto-dispose will close the SQLite connection when the project is switched, preventing connection leaks.

### Pattern 3: Drift Schema with Derivation-Aware Lexeme Design
**What:** The schema must support non-concatenative morphology from the start (roadmap decision). The lexemes table includes `root_id`, `rule_ids` (JSON array of applied morphological rule IDs), and `computed_form` (cached output). This enables the Phase 2 morphology engine to layer on top without a schema rewrite.
**When to use:** Any linguistic database that must support root-and-pattern morphology (Arabic, Hebrew, etc.) in addition to concatenative morphology.
```dart
// Drift table definition (conceptual — actual codegen via @DriftDatabase)
class Lexemes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ipa => text()();
  TextColumn get rootId => text().nullable()();     // FK to roots table
  TextColumn get ruleIds => text().nullable()();    // JSON: ["rule-uuid-1", ...]
  TextColumn get computedForm => text().nullable()(); // cache, recomputed on rule change
  TextColumn get romanization => text().nullable()();
}
```
Phase 1 creates this schema as the baseline (`schemaVersion = 1`). Phase 2 adds to it without destructive migrations.

### Pattern 4: Phonotactic DSL with petitparser
**What:** The DSL accepts two constructs: (1) syllable structure templates like `(C)(C)V(C)` and (2) phonological rewrite rules like `VN -> nasalised V`. Natural classes like `[stop]`, `[liquid]` are defined by the user in the inventory and referenced by name in the DSL.
**When to use:** Any app requiring user-authored linguistic notation.

**DSL Design (Claude's Discretion — recommended):**

*Phoneme class definitions (in inventory editor):*
```
C = p b t d k g f v s z  # all consonants (auto-generated from inventory)
V = a e i o u            # all vowels (auto-generated)
[stop] = p b t d k g     # user-defined natural class
[nasal] = m n ŋ
[liquid] = l r
[click] = ǀ ǃ ǂ          # tonal/click language support
[tone:H] = ˥             # tone diacritics as phonemes
```

*Syllable structure template:*
```
(C)(C)V(C)               # parentheses = optional segment slot
([stop][liquid])V([nasal]) # natural class in slot
```

*Post-generation constraint rule:*
```
[stop] / _ [liquid] -> cluster allowed   # explicit allowance
* [nasal] / V _ V               # mark nasal between vowels as starred (marked)
VN -> nasalised V               # rewrite rule (future phase 2 sound changes)
```

petitparser grammar for the template parser:
```dart
// Source: https://pub.dev/packages/petitparser v7.0.2
final className = (char('[') & letter().plus().flatten() & char(']')).pick(1);
final segment = className | letter();  // [stop] or C or V
final optional = (char('(') & segment & char(')')).pick(1);
final slot = optional.map((s) => Slot(s, optional: true))
           | segment.map((s) => Slot(s, optional: false));
final template = slot.plus(); // sequence of slots
```

The word generator walks the parsed template, resolving each slot to a randomly chosen phoneme from the matching class.

### Pattern 5: IPA Keyboard as Overlay Popup
**What:** An `IpaTextField` widget wraps a standard Flutter `TextField`. When focused, it renders an `OverlayPortal` popup anchored to the field using `CompositedTransformFollower`. The popup contains a grid of IPA buttons that call `TextEditingController.value` to insert characters.
**When to use:** Any desktop app needing special-character input without switching system input method.

```dart
// Source: flutter.dev overlay docs + custom_popup pattern
class IpaTextField extends StatefulWidget { ... }
// Uses CompositedTransformTarget on the field, CompositedTransformFollower on the overlay
// Popup dismisses on focus loss or explicit close button
// On desktop, the overlay never conflicts with system keyboard (no mobile keyboard)
```

Key: on desktop there is no system soft keyboard, so the overlay approach is clean. The known mobile issue (overlay going behind keyboard) does not apply.

### Pattern 6: IPA Reference Chart as Persistent Side Panel
**What:** The main layout `Scaffold` has a right-side panel (fixed width ~280px) that always renders the IPA chart. The chart is a widget grid matching the standard IPA table layout (pulmonic consonants by manner × place, vowels by height × backness). Each cell is a `GestureDetector` that triggers `AudioPlayer.setAsset()` and plays the corresponding OGG file from bundled assets.
**When to use:** Reference panels that must always be accessible without navigation.

### Anti-Patterns to Avoid
- **Global singleton database:** Using a single `AppDatabase` instance accessed globally means project switching is impossible without a full app restart. Use Riverpod family instead.
- **Three-level nested StatefulShellRoute:** Nesting more than two levels of `StatefulShellRoute` is documented as hard to debug. Keep the outer shell (tabs) and inner shell (sidebar) to exactly two levels.
- **Storing audio files in the database:** IPA audio is read-only reference data — bundle as Flutter assets, not in SQLite.
- **Regex for DSL parsing:** The syllable template grammar has optional elements and recursive natural class references. Regex fails on optional nesting; use petitparser.
- **Re-parsing DSL on every keystroke:** The word generator live preview fires on every edit. Parse the DSL on a debounced timer (e.g. 300ms) and cache the parsed template; regenerate words from the cached parse on each timer tick.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Type-safe SQLite queries | Manual SQL string builders | `drift` | Type safety, reactive streams, migration tooling, codegen — hand-rolled SQL breaks on schema changes |
| Database schema migrations | Version-check if/else chains | `drift_dev make-migrations` + `.steps.dart` | Generated migration steps are tested by drift's own test harness; manual migrations corrupt data silently |
| Routing with persistent tab state | `IndexedStack` + manual navigation stack | `go_router StatefulShellRoute` | StatefulShellBranch preserves full navigator stack; IndexedStack preserves widget state but not navigation history |
| Parser for DSL templates | Regex or hand-written recursive descent | `petitparser` | Optional segments `(C)` and natural class references `[stop]` require PEG or combinator; petitparser handles both correctly and is well-tested |
| Desktop window constraints | Platform-channel code | `window_manager` | Minimum size, titlebar style, and initial centering across macOS/Windows/Linux all differ; window_manager abstracts this |
| Audio playback on Windows/Linux | FFI to native audio API | `just_audio_media_kit` | Media playback on desktop requires platform-specific backends; media_kit is the Flutter ecosystem standard |

**Key insight:** In Flutter desktop development, the hardest bugs come from state management at the boundary between routing, databases, and async providers. Drift + Riverpod family handles this boundary correctly; building it manually creates race conditions and connection leaks.

---

## Common Pitfalls

### Pitfall 1: Forgetting `ref.onDispose(db.close)` in the database provider
**What goes wrong:** When the user switches projects, Riverpod auto-disposes the old `projectDatabase` family instance but the SQLite connection remains open. Subsequent writes to the new project can fail or (rarely) corrupt the old project's WAL file.
**Why it happens:** Drift's `NativeDatabase` holds a native file handle. Dart's GC will eventually close it, but not synchronously, causing SQLite "database is locked" errors.
**How to avoid:** Always call `ref.onDispose(db.close)` in every `@riverpod` provider that creates a `AppDatabase`. This is idiomatic Riverpod 3 and closes the connection the moment the provider is invalidated.
**Warning signs:** "database is locked" SQLite error after project switch.

### Pitfall 2: Running migrations on a per-file database without version tracking
**What goes wrong:** Each project's database file starts at `schemaVersion = 1`. If the app is updated and `schemaVersion` becomes `2`, every existing project file must be migrated individually on first open. If migration code assumes a fresh database, data is silently lost.
**Why it happens:** Developers test with a single database or always delete and recreate during development.
**How to avoid:** Write `onUpgrade` migration logic for every schema version bump. Use `drift_dev make-migrations` to generate and test migrations. Test against a real schema-v1 database file, not just `onCreate`.
**Warning signs:** `MigrationException` or missing columns after app update.

### Pitfall 3: petitparser grammar order matters (PEG ordering)
**What goes wrong:** In a PEG grammar, alternatives are tried in order and the first match wins. If `letter()` is listed before `className` (the `[stop]` pattern), a `[` character matches nothing, and natural class references silently fail to parse.
**Why it happens:** PEG semantics differ from CFG: `a | b` means "try a, only try b if a fails" — not "match whichever is longer."
**How to avoid:** Always place longer/more-specific alternatives before shorter/more-general ones: `className | letter()`, never `letter() | className`.
**Warning signs:** Natural class names parse as empty results; no error thrown, just wrong behavior.

### Pitfall 4: just_audio Windows/Linux requires initialization before MaterialApp
**What goes wrong:** On Windows and Linux, calling `AudioPlayer()` before `JustAudioMediaKit.ensureInitialized()` throws a runtime exception, crashing on app start.
**Why it happens:** `just_audio_media_kit` must register its platform factories before the first `AudioPlayer` instance is created.
**How to avoid:** Call `JustAudioMediaKit.ensureInitialized()` in `main()`, before `runApp()`.
**Warning signs:** `MissingPluginException` or `Unimplemented error` on first audio play on Windows/Linux.

### Pitfall 5: IPA chart audio assets — license attribution required
**What goes wrong:** Wikipedia OGG recordings are Creative Commons licensed. Redistributing without attribution in the app's About or credits screen violates the license.
**Why it happens:** Developers bundle the files as assets and forget the license requirement.
**How to avoid:** Include an "Audio credits: Wikimedia Commons contributors, CC BY-SA" attribution in the app's About dialog or a bundled credits file. Check each phoneme's specific Wikimedia Commons file page for the exact license variant (CC BY 3.0, CC BY-SA, or public domain vary per recording).
**Warning signs:** No attribution text anywhere in the app.

### Pitfall 6: Debouncing the live word generator preview
**What goes wrong:** The DSL editor fires a `TextEditingController` listener on every keystroke. If word generation (which requires DSL parse + random sampling) runs synchronously on each event, the UI jank is severe, especially for complex templates.
**Why it happens:** Real-time feedback without debouncing.
**How to avoid:** Debounce the preview update with a 300ms `Timer`. Parse the DSL and run the word generator in an `Isolate` or using `compute()` if word lists exceed ~100 words.
**Warning signs:** UI drops frames while typing in the rule editor.

---

## Code Examples

### Open a per-project Drift database
```dart
// Source: https://drift.simonbinder.eu/setup/ — LazyDatabase with custom path
AppDatabase openProjectDatabase(String projectDir) {
  return AppDatabase(LazyDatabase(() async {
    final file = File(p.join(projectDir, 'project.db'));
    await file.parent.create(recursive: true);
    return NativeDatabase.createInBackground(file);
  }));
}
```

### Drift migration strategy
```dart
// Source: https://drift.simonbinder.eu/migrations/
@override
int get schemaVersion => 1;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) async => await m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < 2) {
      await m.addColumn(lexemes, lexemes.computedForm);
    }
  },
  beforeOpen: (details) async {
    await customStatement('PRAGMA foreign_keys = ON');
  },
);
```

### Riverpod 3 family provider for per-project database
```dart
// Source: riverpod.dev/docs/whats_new (Riverpod 3.0), verified against pub.dev 3.3.1
@riverpod
AppDatabase projectDatabase(Ref ref, String projectId) {
  final docsDir = ref.watch(appDocsDirProvider);
  final projectDir = p.join(docsDir, 'conlang', projectId);
  final db = openProjectDatabase(projectDir);
  ref.onDispose(db.close);
  return db;
}

// Usage: ref.watch(projectDatabaseProvider('project-uuid-here'))
```

### go_router StatefulShellRoute for tabs + sidebar
```dart
// Source: https://pub.dev/packages/go_router (v17.2.0)
final router = GoRouter(
  initialLocation: '/phonology/inventory',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, __, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/phonology',
            redirect: (_, __) => '/phonology/inventory',
          ),
          StatefulShellRoute.indexedStack(
            builder: (_, __, shell) => PhonologyShell(shell: shell),
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(path: '/phonology/inventory', builder: (_, __) => const InventoryPage()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/phonology/sound-rules', builder: (_, __) => const SoundRulesPage()),
              ]),
            ],
          ),
        ]),
      ],
    ),
  ],
);
```

### window_manager initial setup
```dart
// Source: https://pub.dev/packages/window_manager (v0.5.1)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  JustAudioMediaKit.ensureInitialized(); // Windows/Linux audio

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(900, 600),
    center: true,
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(const ProviderScope(child: ConlangApp()));
}
```

### petitparser: syllable template parser (skeleton)
```dart
// Source: https://pub.dev/packages/petitparser v7.0.2
import 'package:petitparser/petitparser.dart';

Parser<SlotNode> buildTemplateParser() {
  // [ClassName] like [stop], [nasal], [liquid]
  final className = (char('[') & letter().plus().flatten() & char(']'))
      .map((values) => ClassSlot(values[1] as String));

  // Single uppercase letter like C, V, N, T
  final singleClass = uppercase().map((ch) => ClassSlot(ch));

  // Single IPA character (lowercase or special)
  final segment = className | singleClass;

  // Optional segment: (C), ([stop])
  final optional = (char('(') & segment & char(')'))
      .map((values) => (values[1] as SlotNode).copyWith(optional: true));

  // Required or optional
  final slot = optional | segment;

  return slot.plus().end();
}
```

### IPA audio playback from bundled asset
```dart
// Source: https://pub.dev/packages/just_audio v0.10.5
final player = AudioPlayer();
await player.setAsset('assets/ipa_audio/voiced_bilabial_plosive.ogg');
await player.play();
```
Audio files go in `assets/ipa_audio/` and are listed in `pubspec.yaml` under `flutter: assets:`.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Notifier`, `FamilyNotifier`, `AutoDisposeNotifier` separate classes | Single `Notifier` class | Riverpod 3.0 (Sep 2025) | Fewer class types to learn; breaking change for 2.x codebases |
| `ref.read`/`ref.watch` in build method — unchecked | `riverpod_lint` rules enforce correct usage | Riverpod 3.0 | Lint-time errors for incorrect Ref usage |
| `AsyncValue.valueOrNull` | `AsyncValue.value` | Riverpod 3.0 | Rename — breaking if not updated |
| Manual sqlite3 bundling for drift on desktop | Automatic bundling since drift 2.32.0 | drift 2.32.0 | No longer need `sqlite3_flutter_libs` explicitly |
| `just_audio_windows` / `just_audio_libwinmedia` for Windows audio | `just_audio_media_kit` | ~2024 | Unified Windows + Linux backend via media_kit |
| go_router v14 (feature-complete claim in 2024) | go_router v17.2.0 | 2025-2026 | Still bug-fixes and stability; `StatefulShellRoute.preload` added |

**Deprecated/outdated:**
- `sqlite3_flutter_libs`: No longer needed for drift 2.32+ — drift bundles SQLite automatically
- `just_audio_windows` package: Superseded by `just_audio_media_kit`
- Riverpod `FamilyNotifier` / `AutoDisposeNotifier`: Merged into single `Notifier` in Riverpod 3.0

---

## Open Questions

1. **Exact IPA audio asset count and file naming**
   - What we know: Wikipedia/Wikimedia Commons has OGG recordings for most IPA consonants (pulmonic, non-pulmonic) and vowels. Individual file licenses vary (CC BY 3.0, CC BY-SA, or PD).
   - What's unclear: The exact file count needed (full IPA chart is ~107 pulmonic consonants + ~28 vowels + non-pulmonic sounds). Some rare phonemes may have no recording available on Commons.
   - Recommendation: Before finalizing the IPA chart widget, enumerate needed phonemes from the IPA chart and verify each has a Commons recording. Build an asset manifest. Missing recordings get a "no audio" placeholder.

2. **ProjectRegistry storage format**
   - What we know: Each project has its own SQLite file. The app needs to list all known projects (name, id, last-opened, file path).
   - What's unclear: Where the registry itself lives — a single shared SQLite, a JSON file, or OS-native (UserDefaults/registry).
   - Recommendation: A single `registry.json` in `getApplicationDocumentsDirectory()/conlang/` is the simplest approach — human-readable, no ORM needed, low risk of corruption if a project database is deleted. Use `dart:convert` and file I/O directly.

3. **Romanization mapping UI**
   - What we know: Success criteria includes "user can define a romanization mapping so any IPA transcription can be displayed in a chosen Latin script."
   - What's unclear: Whether this is a simple key-value table (IPA symbol → Latin character(s)) or something more complex like rules (e.g., context-sensitive mappings).
   - Recommendation: Implement as a simple two-column table (IPA → romanization) stored in the project database. Complex context-sensitive rules are a future phase concern.

4. **DSL handling of tonal and click languages**
   - What we know: The DSL must not be limited to Indo-European patterns. Click consonants (ǀ, ǃ, ǂ, ǁ) and tone markers (˥ ˦ ˧ ˨ ˩) are valid IPA.
   - What's unclear: How the user defines "tone" as a phoneme class in the inventory — tone may be a feature on a vowel rather than a separate segment in some analysis traditions.
   - Recommendation: Treat tone diacritics as individual "phonemes" in the inventory (a valid IPA position-based approach); let the user assign them to natural classes like `[tone:H]`. This keeps the DSL consistent without special-casing tone languages.

---

## Sources

### Primary (HIGH confidence)
- https://drift.simonbinder.eu/setup/ — Drift setup, LazyDatabase, custom file paths, desktop notes
- https://drift.simonbinder.eu/migrations/ — MigrationStrategy, `make-migrations` command, best practices
- https://riverpod.dev/docs/whats_new — Riverpod 3.0 release notes, API unifications, breaking changes (fetched directly)
- https://pub.dev/packages/go_router — Version 17.2.0, feature-complete status, StatefulShellRoute
- https://pub.dev/packages/flutter_riverpod — Version 3.3.1 confirmed
- https://pub.dev/packages/petitparser — Version 7.0.2, MIT, 8.57M downloads, operator-overloaded PEG combinators
- https://pub.dev/packages/just_audio — Version 0.10.5, asset:// loading, macOS native, Windows/Linux via media_kit
- https://pub.dev/packages/just_audio_media_kit — Version 2.1.0, Windows + Linux backend, initialization pattern
- https://pub.dev/packages/window_manager — Version 0.5.1, WindowOptions, ensureInitialized pattern

### Secondary (MEDIUM confidence)
- https://en.wikipedia.org/wiki/IPA_consonant_chart_with_audio — OGG format confirmed, CC license structure, Wikimedia Commons URL pattern
- go_router StatefulShellRoute nested navigation patterns — verified from multiple Flutter community sources + flutter/packages official examples
- Riverpod family provider per-project scoping — pattern confirmed from riverpod.dev docs + community sources

### Tertiary (LOW confidence)
- Phonotactic DSL design recommendations — synthesized from conlang tool research (colingorrie.com, lingweenie.org, Logopoeist on GitHub) and linguistic notation conventions; no single authoritative source
- petitparser grammar ordering pitfalls — inferred from PEG semantics documentation; not explicitly stated in petitparser docs

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all library versions confirmed from pub.dev directly
- Architecture: MEDIUM-HIGH — patterns verified from official docs; per-project Drift pattern inferred from LazyDatabase API + Riverpod family semantics (not a documented "official pattern")
- Pitfalls: MEDIUM — most verified from official sources; DSL pitfalls LOW (inferred from PEG theory)
- DSL design: MEDIUM — informed by existing conlang tools and linguistic notation, but this is a novel implementation

**Research date:** 2026-04-08
**Valid until:** 2026-05-08 (30 days — go_router and Riverpod move fast; verify versions before planning)
