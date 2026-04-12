# Codebase Concerns

**Analysis Date:** 2026-04-12

## Tech Debt

**Nullable value force-unwrapping (cast safety):**
- Issue: Multiple locations use unsafe type casts with `as` operator and `.cast<T>()`, particularly in DSL parsing and data transformation layers. These bypass null safety and can throw runtime exceptions if types don't match.
- Files: `lib/features/morphology/domain/morphology_dsl.dart` (lines 183-256, widespread `.cast<>()` usage), `lib/features/project/data/project_backup.dart` (line 36 with `as int? ?? 0`)
- Impact: Hidden runtime crashes when malformed DSL is parsed or data types unexpectedly differ. Especially dangerous in morphology DSL parsing where user-input grammar rules are processed.
- Fix approach: Replace force-casts with safe type-checking via `is`/`as?` patterns. Add validation pass on DSL input to detect malformed patterns early. Consider sealed union types instead of raw List casting.

**Legacy migration columns retained but not validated:**
- Issue: `lib/db/app_database.dart` retains v6 columns like `MorphologicalRules.posIds` (line 177) marked "keep-and-ignore" for migration safety. However, no validation logic prevents stale v6 data from being read if migration path breaks.
- Files: `lib/db/app_database.dart` (lines 173-177), `lib/features/morphology/domain/morphology_dsl.dart` (legacy anchor migration lines 198-256)
- Impact: If a user's migration fails silently, old posIds data could corrupt rule interpretation. The DSL migration path for legacy patterns is complex and fragile.
- Fix approach: Add explicit validation hook at schema-upgrade time to verify v6→v8 data consistency. Add test coverage for all legacy migration patterns. Consider a deprecation timeline to remove v6 columns entirely post-phase-5.

**Database getSingle() calls without fallback:**
- Issue: Multiple DAO methods use `.getSingle()` which throws StateError if the row is missing or multiple rows exist. This is used in critical paths like promoting derivations, resolving rules, and loading paradigm data.
- Files: `lib/features/grammar/data/grammar_dao.dart` (lines 59, 316), `lib/features/lexicon/data/lexeme_dao.dart` (lines 102, 114), `lib/features/morphology/data/morphology_dao.dart` (lines 118, 121, 165)
- Impact: Missing or duplicate DB rows will crash the app with unhandled StateError instead of graceful error handling. No logging of which query failed or what data was expected.
- Fix approach: Replace `getSingle()` with `getSingleOrNull()` and handle nulls explicitly with meaningful error messages. Add database integrity checks on project load. Log all database errors with context for debugging.

**Unsafe collection access patterns:**
- Issue: Code uses `.first`, `.last`, `.single` on collections without checking emptiness first. Particularly in paradigm table rendering and dimension handling.
- Files: `lib/features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart` (lines 68, 111, 125), `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` (line 1125)
- Impact: RangeError if expected collection is empty (e.g., when no dimensions exist for a POS, or paradigm pool is empty). Silent failures in multi-word selection.
- Fix approach: Use `.firstOrNull`, `.lastOrNull` instead. Check `isEmpty` before access. Add assertions with meaningful messages in debug mode.

## Known Bugs

**Abbreviation case-sensitivity display inconsistency:**
- Symptoms: Abbreviations should be treated case-insensitively (e.g., "v" and "V" are the same), but display inconsistency allows both forms in UI without normalization. No period suffix added consistently.
- Files: `lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart`, `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart`
- Trigger: Creating or renaming a dimension/POS with mixed-case abbreviations (e.g., "Sg", "SG")
- Workaround: Manually normalize abbreviations to lowercase when entering them

**Morpheme template literal form-storage deferred:**
- Symptoms: Template operations in morphological rules have a known partial implementation (D-73 mark). Literal runs inside templates are NOT deromanized when rom mode is active, causing stored rules to contain romanization instead of phonemic values.
- Files: `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` (lines 96-99, marked "D-73 partial deferred")
- Trigger: Creating template operations (e.g., "C.V.C") in rom mode, then switching to phonemic view
- Workaround: Currently just documented deferred—no workaround; avoid complex templates with rom mode

**Paradigm cell override abbreviation column nullable but not handled consistently:**
- Symptoms: `ParadigmCellOverrides.overrideRomanization` is nullable (line 235), but some code paths assume it's populated when an override exists.
- Files: `lib/db/app_database.dart` (line 235), `lib/features/grammar/presentation/paradigm_viewer/cell_override_dialog.dart`
- Trigger: Manually creating a cell override with IPA only (no rom), then accessing it in multi-word paradigm view
- Workaround: Always fill rom when creating overrides via UI dialog

## Security Considerations

**No validation of user-provided DSL patterns:**
- Risk: Morphological rule DSL and phonotactic constraint DSL are parsed with minimal input validation. Malformed patterns could cause parser crashes or infinite loops during generation.
- Files: `lib/features/morphology/domain/morphology_dsl.dart`, `lib/features/phonology/domain/phonotactic_dsl.dart`
- Current mitigation: Parser combinator library (petitparser) provides some structure, but no pre-flight validation of pattern semantics
- Recommendations: Add a validation pass that checks DSL patterns for known problematic constructs (infinite loops, unbounded quantifiers). Timeout rule generation/matching operations. Log all parsing errors with user-friendly messages.

**Word generation and morphology preview can be expensive:**
- Risk: Users can trigger expensive word generation or morphological rule application on entire inventories without rate limiting. Large phoneme inventories + complex morphology rules = potential performance DOS.
- Files: `lib/features/phonology/presentation/sound_rules/word_generator_panel.dart`, `lib/features/morphology/presentation/rules/preview_panel.dart`
- Current mitigation: "Regenerate" button is manual (advisory), not automatic. Preview is per-rule only. However, nothing prevents a user from hitting regenerate repeatedly.
- Recommendations: Add debouncing to generation triggers. Cap output size (e.g., max 1000 generated words). Show progress/cancellation UI for long operations. Add timeout (e.g., 5s max generation time).

**Romanization bijection not enforced:**
- Risk: `romanization_bijection_provider` expects unique 1:1 mapping of IPA ↔ ROM. If user creates duplicate mappings (e.g., both "p" → "p" and "p" → "b"), the bijection breaks silently and first-match-wins behavior occurs without warning.
- Files: `lib/features/phonology/data/romanization_providers.dart`, `lib/features/phonology/domain/notation_helpers.dart` (line 141 comment: "First entry wins on collision")
- Current mitigation: Comment notes collision behavior but no UI warning or validation
- Recommendations: Add bijection validation on phoneme edit/save. Warn user of duplicate mappings and prevent saving until resolved.

## Performance Bottlenecks

**Paradigm table widget with intrinsic dimensions generates multiple stacked slices:**
- Problem: When intrinsic (fixed) dimensions are present, the paradigm table renders a stacked layout with one section per intrinsic combination. Each slice re-renders all cells even if data hasn't changed.
- Files: `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` (lines 96-99, `_buildStackedIntrinsicSlices` method)
- Cause: No memoization or caching of slice data; every build rebuilds all slices. With 3+ dimensions and large feature spaces, this is O(dims × levels) complexity.
- Improvement path: Memoize slice data using Riverpod family providers. Use `RepaintBoundary` on each slice to prevent sibling rebuilds. Lazy-load slice content with pagination.

**Morphology DSL parser runs on every rule edit:**
- Problem: Rule preview panel parses the DSL on every keystroke to show syntax errors, without debouncing.
- Files: `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` (lines 1-150, form state)
- Cause: No debounce on DSL text changes; parser combinator is O(n) per character typed
- Improvement path: Add 500ms debounce to DSL parsing. Cache parse results if input hasn't changed. Move parsing to background isolate for long rules.

**Natural class resolution during word generation is O(n*m):**
- Problem: `resolvePhonemeClass` in morphology_engine iterates through sorted phoneme list and then looks up naturalClasses. During word generation with many custom classes, this is called repeatedly.
- Files: `lib/features/morphology/domain/morphology_engine.dart` (lines 83-120), `lib/features/phonology/domain/word_generator.dart` (uses same pattern)
- Cause: No caching of class resolution results; same class resolved many times per generation
- Improvement path: Pre-compute class resolution map at session start. Cache in PhonemeInventory struct. Use a trie for multi-char phoneme matching.

## Fragile Areas

**Lexeme parent relationships and derivation promotion logic:**
- Files: `lib/features/lexicon/data/lexeme_dao.dart` (lines 94-140, promoteDerivation), `lib/features/lexicon/data/lexeme_providers.dart` (computed derived form logic)
- Why fragile: Promotion creates a new Lexeme row with a placeholder IPA and derives rom on-the-fly via re-applying the morphological rule. If the rule is later edited or deleted, the derived form's rom becomes stale. No cascade delete or invalidation logic.
- Safe modification: Before editing or deleting a rule, audit all promoted derivations that depend on it. Add a "Rule used by promoted derivations" warning in rule edit dialog. Document the promotion re-application contract explicitly in code.
- Test coverage: `test/unit/lexicon/promoted_derivation_test.dart` covers basic flow but missing edge cases: rule deletion, rule modification mid-session, rom-only derivations.

**Paradigm cell override storage and multi-word selection:**
- Files: `lib/db/app_database.dart` (lines 229-237, ParadigmCellOverrides table), `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` (lines 78-83, lexemeIds parameter)
- Why fragile: Cell overrides are keyed by `(lexemeId, featureSetJson)`, but `featureSetJson` is a stringified JSON object with no versioning. If dimensions are later reordered or IDs shift, the featureSetJson key becomes orphaned and the override is lost invisibly.
- Safe modification: Before modifying dimension ID or ordering, migrate all existing overrides to new feature set keys. Add a migration function that reconstructs the feature map from dimension IDs. Test extensively with multi-word paradigm data.
- Test coverage: `test/unit/grammar/paradigm_cell_override_test.dart` covers basic CRUD but missing dimension-change migration scenarios.

**Standard form pattern validation and derivation logic:**
- Files: `lib/features/grammar/data/standard_form_validation_provider.dart` (line 75, i18n TODO), `lib/features/grammar/domain/standard_form_branch.dart`, `lib/features/grammar/domain/paradigm_engine.dart` (lines 111+)
- Why fragile: Standard form patterns are DSL strings that get compiled into branch logic for paradigm generation. The validation provider checks these at render time but errors are not cached, and malformed patterns silently fail to generate standard forms.
- Safe modification: Add pre-flight validation of all standard form patterns on project load. Cache validation results. Return structured error objects instead of silent failures.
- Test coverage: `test/unit/grammar/standard_form_matcher_test.dart` and `test/unit/grammar/paradigm_generation_test.dart` provide coverage but missing internationalization test (marked TODO on line 75).

**Complex state machines in rule editor and morphology preview:**
- Files: `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` (2486 lines, massive single file), `lib/features/morphology/presentation/rules/preview_panel.dart` (547 lines)
- Why fragile: `_OpState`, `_CondState`, `_BranchState` classes manage form state with mutable TextEditingControllers. No immutable state machine; manual lifecycle management with dispose. Easy to leak resources or lose state on rebuild.
- Safe modification: Split rule_editor_dialog into smaller sub-widgets with scoped state. Consider migrating to immutable state + Riverpod family providers instead of mutable classes. Add memory profiling during long editing sessions.
- Test coverage: `test/widget/grammar/rule_editor_multi_pos_test.dart` and related widget tests cover basic UI flow but missing memory/resource leak scenarios.

## Scaling Limits

**Single-file widget size (rule_editor_dialog.dart):**
- Current capacity: 2486 lines in one file
- Limit: Beyond 2000 lines, IDE navigation and refactoring becomes slow. Hot reload latency increases. Cognitive load for understanding all state and lifecycle.
- Scaling path: Extract _OpState, _CondState, _BranchState into separate files. Break into child widgets per section (condition editor, operation editor, preview panel). Move DSL parsing to domain layer.

**Database query complexity with intrinsic dimensions:**
- Current capacity: Paradigm rendering with 3-4 intrinsic dimensions works smoothly
- Limit: 5+ intrinsic dimensions or 100+ lexeme words in multi-word paradigm triggers noticeable lag
- Scaling path: Implement pagination for stacked slices. Cache slice layouts in Riverpod. Add incremental data loading (load visible slices first). Consider virtual scroll for paradigm tables.

**Phonotactic constraint DSL complexity:**
- Current capacity: ~10-15 phonotactic constraints without performance issues
- Limit: 30+ constraints or very complex constraint patterns (heavily nested groups) slow down phonotactic checking during word generation
- Scaling path: Pre-compile constraints to a bytecode/AST at load time. Parallelize constraint checking via Isolates. Add caching of constraint results per phoneme sequence.

## Dependencies at Risk

**Drift (database library) version pinned:**
- Risk: `pubspec.lock` shows specific Drift version. Breaking changes in Drift could require schema migrations. SQLite format changes could affect backup/restore.
- Impact: Backup/restore operations in `lib/features/project/data/project_backup.dart` depend on Drift's JSON export/import stability.
- Migration plan: Test backup/restore on every Drift version upgrade. Document the backup format version explicitly. Consider exporting to a Drift-independent JSON schema (with explicit versioning) for long-term compatibility.

**Flutter Riverpod state management dependency:**
- Risk: Entire app state is managed by Riverpod. Provider graph is deep and complex. Breaking changes in Riverpod would require global refactor.
- Impact: Async data loading, caching, invalidation all depend on Riverpod's watch/invalidate semantics. Incorrect usage causes stale data bugs.
- Migration plan: Audit all provider dependencies for cycles and incorrect invalidation. Add integration tests that verify Riverpod watch/invalidate behavior under state mutations.

## Missing Critical Features

**No undo/redo system:**
- Problem: Users can lose significant work with a single mistake (e.g., deleting a dimension used by many rules, or overwriting a phoneme inventory). No undo button.
- Blocks: Complex workflows like paradigm redesign, mass rule editing, phoneme inventory overhauls
- Impact: High user frustration. Workaround is manual backups via project export.

**No multi-user collaboration or conflict resolution:**
- Problem: Only one user can edit a project at a time (enforced by single .db file). No merge capability if two users edit in parallel.
- Blocks: Team conlang projects, classroom use
- Impact: Limits usability in collaborative contexts

**No rule testing/validation sandbox:**
- Problem: When a user edits a morphological rule or phonotactic constraint, there's no "test this rule on example words" feature before committing.
- Blocks: Exploratory rule design, incremental rule refinement
- Impact: Users must create test words manually to verify rule behavior

## Test Coverage Gaps

**Morphological rule edge cases (null/empty handling):**
- What's not tested: Edge cases where rules have empty conditions, empty operations, or malformed DSL that nearly parses (e.g., `[C_` with missing closing bracket)
- Files: `lib/features/morphology/domain/morphology_dsl.dart`, `lib/features/morphology/domain/morphology_engine.dart`
- Risk: Silent failures when rules partially parse but don't apply, confusing users about whether a rule is broken or just inactive
- Priority: High — affects rule reliability

**Paradigm generation with cross-dimensional interactions:**
- What's not tested: Intrinsic dimensions + standard form patterns + multiple morphological rules all applying to the same cell. The interaction of these three systems is complex and under-tested.
- Files: `lib/features/grammar/domain/paradigm_engine.dart`, `lib/features/grammar/data/typology_providers.dart`
- Risk: Paradigm cells show wrong forms when multiple rules compete or standard form doesn't match inflectional rule output
- Priority: High — affects grammar correctness

**Romanization round-trip with special characters:**
- What's not tested: Non-ASCII romanization mappings (e.g., IPA ɸ → German ß), combining diacritics, and complex multi-char mappings in both directions (IPA → ROM → back to IPA)
- Files: `lib/features/phonology/data/romanization_dao.dart`, `lib/features/phonology/domain/notation_helpers.dart`
- Risk: Data corruption during round-trip if bijection assumptions break with special characters
- Priority: Medium — affects romanization reliability

**Database migration path coverage:**
- What's not tested: Full lifecycle of all past schema versions (v6 → v7 → v8 → v12). Particularly the morphological rule POS migration (v6 posIds → v8+ featureBindings).
- Files: `lib/db/app_database.dart`, `lib/db/migration_*.dart`
- Risk: Users with old projects fail to migrate or get silently corrupted data
- Priority: High — affects project loading

**Widget lifecycle with async Riverpod providers:**
- What's not tested: What happens when a provider is invalidated while a widget is being rebuilt, or when a mounted check fails in an async callback.
- Files: Multiple presentation widgets using `ref.watch()` and async callbacks with `if (mounted)` guards
- Risk: Race conditions, stale UI state, or exceptions from disposed widgets trying to update
- Priority: Medium — affects UI stability

---

*Concerns audit: 2026-04-12*
