# Codebase Structure

**Analysis Date:** 2026-04-12

## Directory Layout

```
conlang_workbench/
├── lib/
│   ├── main.dart                 # App entry point, window manager, audio init
│   ├── app.dart                  # Root MaterialApp.router, theme config
│   ├── db/
│   │   ├── app_database.dart     # Drift database schema + DAOs
│   │   ├── app_database.g.dart   # Generated Drift code
│   │   └── migration_notation_classify.dart  # Schema migrations
│   ├── router/
│   │   └── app_router.dart       # Go Router config, StatefulShellRoute hierarchy
│   ├── shared/
│   │   └── widgets/
│   │       └── app_shell.dart    # Top-level tab bar + project menu
│   └── features/
│       ├── phonology/            # Phase 1: IPA phonology
│       ├── grammar/              # Phase 4: Inflectional morphology
│       ├── lexicon/              # Phase 3: Lexicon + derivations
│       ├── morphology/           # Shared: Morphology engine + DSL
│       ├── glossary/             # Cross-cutting: Help sidebar
│       └── project/              # Cross-cutting: Project lifecycle
├── test/
│   ├── unit/
│   │   └── grammar/              # Paradigm engine, grammar DAO tests
│   ├── phonology/                # Phoneme, sound rule, IPA tests
│   ├── lexicon/                  # Lexeme, swadesh, thesaurus tests
│   ├── features/                 # Feature-level integration tests
│   ├── integration/              # Multi-feature scenarios
│   ├── morphology_engine_test.dart
│   └── morphology_preview_raw_pipeline_test.dart
├── assets/
│   ├── ipa_audio/                # IPA phoneme audio files
│   ├── AUDIO_CREDITS.md
│   ├── swadesh_list.json         # Swadesh 100-word list
│   ├── conlangers_thesaurus.json # Semantic categories
│   └── glossary.json             # Help terms database
├── pubspec.yaml                  # Dependencies
├── pubspec.lock                  # Locked dependency versions
└── macos/, windows/, linux/      # Platform-specific code
```

## Directory Purposes

**lib/:**
- Purpose: Dart source code for the application
- Contains: Main app, features, database layer, routing
- Key files: `main.dart` (entry), `app.dart` (theme/material config)

**lib/db/:**
- Purpose: Database schema and data access objects
- Contains: Drift-generated tables, DAOs, migrations
- Key files: `app_database.dart` (125 table definitions), `app_database.g.dart` (generated), `migration_notation_classify.dart` (v7→v8 safety)

**lib/router/:**
- Purpose: Navigation configuration and route hierarchy
- Contains: GoRouter factory, StatefulShellRoute branches, error handling
- Key files: `app_router.dart` (generated via riverpod_generator)

**lib/shared/:**
- Purpose: Cross-feature widgets and utilities
- Contains: AppShell (top-level navigation), shared theming
- Key files: `app_shell.dart` (tab bar, project badge, glossary button)

**lib/features/{feature}/:**
- Purpose: Feature-specific logic organized by layer
- Structure: Each feature has `data/`, `presentation/`, and/or `domain/` subdirectories

### Feature: Phonology

**lib/features/phonology/presentation/:**
- `phonology_shell.dart` — Sub-shell with sidebar (Inventory, Sound Rules)
- `inventory/inventory_page.dart` — IPA grid, vowel trapezoid, natural class editor
- `sound_rules/sound_rules_page.dart` — Phonological rewrite rule editor
- `shared/ipa_keyboard/`, `shared/ipa_chart/` — Reusable IPA components

**lib/features/phonology/data/:**
- `phoneme_dao.dart` — CRUD for phonemes (consonants/vowels)
- `natural_class_dao.dart` — Natural class groups (e.g., "stops", "nasals")
- `phoneme_providers.dart` — Riverpod streams for active consonant/vowel lists
- `ipa_data.dart` — IPA reference data, constants

**lib/features/phonology/domain/:**
- `word_generator.dart` — Generates pseudo-words from phonotactic constraints
- `phonotactic_dsl.dart` — DSL parser for syllable patterns and constraints
- `default_natural_classes.dart` — Catalog of standard phonetic classes

### Feature: Grammar (Phase 4)

**lib/features/grammar/presentation/:**
- `grammar_shell.dart` — Sub-shell with sidebar (POS & Dimensions, Inflections, Typology)
- `pos_dimensions/pos_dimensions_page.dart` — POS manager + dimension editor
- `inflections/inflections_page.dart` — Stacked paradigm viewer + inflectional rules (merged from old split tabs)
- `paradigm_viewer/paradigm_viewer_page.dart` — Paradigm table rendering
- `inflectional_rules/inflectional_rules_page.dart` — Rule CRUD for a POS
- `typology/typology_page.dart` — Word order, alignment, modality settings
- `shared/` — Dimension picker dialogs, rule UI widgets

**lib/features/grammar/data/:**
- `grammar_dao.dart` — CRUD for dimensions (Phase 4 Dimensions table)
- `grammar_providers.dart` — Riverpod streams for dimensions, computed paradigms
- `marker_dao.dart` — Marker lookup for fallback cells (Phase 4 D-45)
- `dimension_templates.dart` — Catalog of dimension templates (Gender, Number, Case, etc.)
- `standard_form_pattern_dao.dart` — Standard form pattern matching
- `intrinsic_levels_codec.dart` — JSON codec for intrinsic dimension levels

**lib/features/grammar/domain/:**
- `paradigm_engine.dart` — Core algorithm for computing paradigm cells (feature consumption)
- `paradigm_cell.dart` — Result type: Filled, Uncovered, Unmatched, or Ambiguous
- `inflectional_rule.dart` — InflectionalRule type + bindings
- `feature_bindings.dart` — Dimension→Level mapping for rule conditions
- `binding_translator.dart` — Transform feature bindings for UI display
- `standard_form_matcher.dart` — Match inflected forms against standard patterns
- `tiebreak_detector.dart` — Find conflicting rules at same specificity
- `marker.dart` — Marker fallback declaration type
- `paradigm_axes.dart` — Organize paradigm dimensions into readable tables
- `coverage_matrix.dart` — Track which cells are computed vs. uncovered
- `pos_resolver.dart` — Map POS names to IDs

### Feature: Lexicon (Phase 3)

**lib/features/lexicon/presentation/:**
- `lexicon_shell.dart` — Sub-shell with sidebar (Dictionary, Swadesh, Thesaurus, Derivations)
- `dictionary/dictionary_page.dart` — Lexeme editor + list
- `swadesh/swadesh_page.dart` — Swadesh 100-word list tracker
- `thesaurus/thesaurus_page.dart` — Semantic category grouping
- `derivations/derivations_page.dart` — Derivational rule output list (wraps rules_page.dart)
- `widgets/` — Lexeme detail panels, meaning editor

**lib/features/lexicon/data/:**
- `lexeme_dao.dart` — CRUD for lexemes (words)
- `lexeme_providers.dart` — Riverpod streams for lexeme list, search
- `anki_export_service.dart` — Anki deck generation (.apkg files)

### Feature: Morphology (Shared)

**lib/features/morphology/domain/:**
- `morphology_engine.dart` — Core DSL processor: tokenize → pattern match → transform
- `morphology_dsl.dart` — DSL types and parser (rule syntax: "affix / condition")
- `result_types.dart` — MorphSuccess / MorphNoMatch

**lib/features/morphology/data/:**
- `morphology_dao.dart` — CRUD for MorphologicalRules table
- `morphology_providers.dart` — Riverpod streams for rules (inflectional + derivational)

**lib/features/morphology/application/:**
- `morphology_service.dart` — Orchestrates domain + data layers for rule processing

**lib/features/morphology/presentation/:**
- `rules/rules_page.dart` — Generic rule editor (reused by both Grammar and Lexicon)

### Feature: Project (Cross-cutting)

**lib/features/project/data/:**
- `project_providers.dart` — `currentProjectIdProvider`, `projectDatabaseProvider(family)`, `appDocsDirProvider`
- `project_registry.dart` — Registry of all projects on disk (registry.json)
- `project_backup.dart` — v7→v8 schema backup logic

**lib/features/project/presentation/:**
- `project_menu.dart` — File menu (New, Open, Save, Export)

### Feature: Glossary (Cross-cutting)

**lib/features/glossary/presentation/:**
- `glossary_drawer.dart` — Right-side help panel

**lib/features/glossary/data/:**
- `glossary_providers.dart` — `glossaryOpenProvider`, `glossaryCategoryFilterProvider`

**test/:**
- Purpose: Unit, integration, and widget tests
- Contains: Organized by feature; includes paradigm engine tests, morphology tests, lexicon tests

**assets/:**
- Purpose: Static data and media
- Contains: IPA audio files, JSON reference lists (Swadesh, thesaurus, glossary)

## Key File Locations

**Entry Points:**
- `lib/main.dart` — Application bootstrap
- `lib/app.dart` — Material app configuration and theming
- `lib/router/app_router.dart` — Navigation route tree

**Configuration:**
- `pubspec.yaml` — Package dependencies and build configuration
- `pubspec.lock` — Locked versions for reproducible builds

**Core Logic:**
- `lib/db/app_database.dart` — Database schema (Drift ORM definitions)
- `lib/features/grammar/domain/paradigm_engine.dart` — Paradigm cell computation
- `lib/features/morphology/domain/morphology_engine.dart` — Morphological transformations

**Testing:**
- `test/unit/grammar/paradigm_engine_test.dart` — Paradigm algorithm tests
- `test/morphology_engine_test.dart` — Morphology DSL tests
- `test/integration/` — Multi-feature scenario tests

## Naming Conventions

**Files:**
- Pages: `{feature}_page.dart` (e.g., `inventory_page.dart`, `dictionary_page.dart`)
- DAOs: `{entity}_dao.dart` (e.g., `phoneme_dao.dart`, `grammar_dao.dart`)
- Providers: `{entity}_providers.dart` (e.g., `phoneme_providers.dart`, `grammar_providers.dart`)
- Shells: `{feature}_shell.dart` (e.g., `phonology_shell.dart`, `grammar_shell.dart`)
- Dialogs: `{entity}_dialog.dart` (e.g., `phoneme_edit_dialog.dart`)
- Editors: `{entity}_editor.dart` (e.g., `natural_class_editor.dart`)

**Directories:**
- Features: lowercase plural (e.g., `phonology/`, `grammar/`, `lexicon/`)
- Sections within features: lowercase (e.g., `inventory/`, `sound_rules/`)
- Shared widgets: `shared/widgets/`

**Types & Classes:**
- DAO classes: `{Entity}Dao` (e.g., `PhonemeDao`, `GrammarDao`)
- Provider variables: `{entity}Provider` or `{entity}ListProvider` (e.g., `phonemesProvider`, `consonantListProvider`)
- Pages: `{Section}Page` (e.g., `InventoryPage`, `DictionaryPage`)
- Shells: `{Feature}Shell` (e.g., `PhonologyShell`)
- Domain types: PascalCase (e.g., `ParadigmCell`, `InflectionalRule`, `FeatureSet`)
- Result types: sealed class hierarchy (e.g., `MorphResult` → `MorphSuccess`, `MorphNoMatch`)

## Where to Add New Code

**New Feature:**
- Create `lib/features/{feature_name}/`
- Subdirectories: `data/`, `presentation/`, `domain/` (or `application/` for orchestration)
- Add shell to `lib/features/{feature_name}/presentation/{feature_name}_shell.dart`
- Add routes to `lib/router/app_router.dart` (StatefulShellBranch with GoRoute pages)
- Write providers in `lib/features/{feature_name}/data/{entity}_providers.dart`
- Tests in `test/unit/{feature_name}/`, `test/features/{feature_name}/`

**New Page Within Feature:**
- Create `lib/features/{feature}/presentation/{section}/{section}_page.dart`
- Extend `ConsumerWidget` or `ConsumerStatefulWidget`
- Add GoRoute to appropriate feature shell's StatefulShellRoute
- Tests in `test/features/{feature}/{section}/`

**New DAO (Database Access):**
- Create `lib/features/{feature}/data/{entity}_dao.dart`
- Annotate with `@DriftAccessor(tables: [...])`
- Include read streams (e.g., `watchAll()`, `watchById()`) and write methods
- Generate code: `dart run build_runner build`
- Create provider in same directory: `lib/features/{feature}/data/{entity}_providers.dart`

**New Domain Logic:**
- Create `lib/features/{feature}/domain/{concept}.dart`
- Use sealed classes for result types (Dart 3.0 pattern)
- No dependencies on data layer or presentation
- Write tests in `test/unit/{feature}/`

**Utilities/Helpers:**
- Shared across features: `lib/shared/`
- Feature-specific: `lib/features/{feature}/presentation/shared/`
- IPA handling: `lib/features/phonology/domain/`
- Morphology DSL: `lib/features/morphology/domain/`

## Special Directories

**lib/db/:**
- Purpose: Drift ORM database layer
- Generated: `app_database.g.dart` (via build_runner)
- Committed: Yes (keep generated code in git per Drift docs)
- Manual edit: Only `app_database.dart` and migration files

**test/unit/:**
- Purpose: Isolated unit tests (no Flutter/UI)
- Generated: None
- Committed: Yes
- Contains: Grammar engine tests, DSL parser tests, type tests

**test/integration/:**
- Purpose: Multi-feature scenarios (e.g., project load → paradigm compute)
- Generated: None
- Committed: Yes
- Uses: Real database snapshots or fixtures

**test/widget/:**
- Purpose: Flutter widget tests (UI layer)
- Generated: None
- Committed: Yes

**assets/:**
- Purpose: Static data bundled with app
- Generated: None
- Committed: Yes
- Contains: IPA audio (.mp3), JSON reference data

**build/:**
- Purpose: Compiled app binaries (native code)
- Generated: Yes (via `flutter build`)
- Committed: No (.gitignore)

**.dart_tool/:**
- Purpose: Build artifacts and Dart package cache
- Generated: Yes (via `pub get`)
- Committed: No (.gitignore)

---

*Structure analysis: 2026-04-12*
