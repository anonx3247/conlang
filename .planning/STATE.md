# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-08)

**Core value:** A powerful, flexible morphology engine that handles the full spectrum of language types through a readable pattern mini-language
**Current focus:** Phase 1 complete — all gap closure plans executed (10-13)

## Current Position

Phase: 1 of 6 (Foundation) — COMPLETE (all gap closure plans executed)
Plan: 13 of 13 in current phase — PHASE COMPLETE
Status: Plan 12 complete — ProjectSettings table, romanization toggle, bidirectional phoneme-romanization sync
Last activity: 2026-04-09 — plan 12 executed (romanization toggle + bidirectional sync)

Progress: [███░░░░░░░] 29% (13/44 total plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 7
- Average duration: 12 min (updated)
- Total execution time: 1.3 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 7 | 82 min | 12 min |

**Recent Trend:**
- Last 5 plans: 6 min, 14 min, 7 min, 11 min, 35 min
- Trend: stable

*Updated after each plan completion*

**Detailed metrics (01-07):**
| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01-foundation P07 | 35 min | 2 tasks | 13 files |
| Phase 01-foundation P08 | 18 min | 2 tasks | 4 files |
| Phase 01-foundation P09 | 4 min | 2 tasks | 3 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: Morphology engine built in Phase 2 before lexicon/grammar — centrepiece must be stable before dependent layers
- Roadmap: Database schema designed in Phase 1 with derivation-aware structure (root_id + rule_ids + computed_form cache) — cannot be deferred without forcing a rewrite
- Roadmap: IPA audio assets bundled at build time (Wikipedia-sourced) — not fetched at runtime
- 01-01: Used riverpod_generator 3.0.3 (not 4.x) — transitive test_api conflict with flutter_test in Dart 3.10.4 ecosystem
- 01-01: Used drift 2.31.0 + drift_flutter 0.2.8 (not 2.32.x) — drift_dev 2.32.x requires analyzer >=10.0.0, incompatible with riverpod_generator 3.x's analyzer <9.0.0
- 01-01: Dark theme as default for professional desktop tool feel
- 01-02: DriftNativeOptions.databasePath callback used (not name: param) — enables per-project SQLite file at arbitrary absolute path
- 01-02: projectDatabase family provider is sync using ref.read().value peek — avoids AsyncValue wrapping throughout app; LazyDatabase defers actual file open
- 01-02: Empty state rendered inside AppShell (not via GoRouter redirect) — keeps router clean, avoids redirect loop complexity
- 01-03: Wikimedia Commons canonical OGG filenames discovered via Help:IPA article API (action=parse) — direct name guessing fails for ~70% of files; 6 sounds have no available recording (set to null audioAssetPath)
- 01-03: IpaAudioPlayer as plain Dart class in @riverpod factory — simpler than StateNotifier since no state notification needed; stop-before-play prevents audio overlap
- 01-04: IPA symbol data defined locally in keyboard widget — keyboard layout and chart layout serve different purposes; integrate with ipa_data.dart (Plan 03) later if needed
- 01-04: Popup trigger is focus-based + suffix icon toggle — auto-shows on focus (convenience), manual toggle (control)
- 01-04: TapRegion for outside-tap dismissal — cleaner than GestureDetector, correctly excludes popup from "outside" boundary
- [Phase 01-06]: 01-06: romanize uses longest-match-first sort (IPA symbol length desc) to correctly handle multi-char sequences like t͡s before t
- [Phase 01-06]: 01-06: Plain flutter_riverpod providers (not @riverpod codegen) for Drift-referenced types — avoids riverpod_generator InvalidTypeException from build ordering
- 01-05: riverpod_generator 3.x cannot resolve drift part-file types (Phoneme, NaturalClassesData) at codegen time — use manual Provider/StreamProvider for all drift-type providers
- 01-05: NaturalClasses table generates NaturalClassesData (not NaturalClass) in Drift 2.30 — generated data class name = table class name + Data suffix
- 01-05: Consonant/vowel grids show only occupied rows/columns (sparse display) — cleaner for small inventories than rendering full 88-cell IPA chart
- 01-07: petitparser 7.x sealed Result class requires pattern matching (case Success/Failure) — no isFailure getter exists in 7.x
- 01-07: flatten() in petitparser 7.x uses named param {String? message} not positional — breaking change from earlier versions
- 01-07: Private Dart classes cannot be imported across files — extract shared helpers to a public file when multiple widgets need them
- 01-07: WordGeneratorPanel uses ref.listen() + Timer debounce for live preview — prevents rebuild storms on every keystroke
- 01-08: TapRegion groupId (Object()) shared between TextField and overlay popup — clicks inside popup no longer trigger focus loss that collapses the popup before the symbol button onTap fires
- 01-08: IpaTextField.build() preserves caller's suffixIcon via Row when showIpaKeyboard=true — validation icons (check/error) are no longer overwritten by the keyboard toggle
- 01-08: Template editor pattern field switched to plain TextField — DSL uses C/V/[]/() not IPA symbols; removes unwanted keyboard, reveals validation icon, eliminates stale-error visual from popup overlap
- 01-08: _IpaSymbolButton minWidth reduced from 12 to 9 and horizontal padding zeroed — 11-column pulmonic grid fits within 280px panel without RIGHT OVERFLOWED BY 4px errors
- 01-09: IPA symbol derived from IpaSound static data by matching manner/place/voiced (consonants) or height/backness/rounded (vowels) — single source of truth covers all 85+ consonants and 28+ vowels
- 01-09: Custom symbol TextField shown only when all dropdowns selected but combo unknown — avoids clutter in common case while handling non-standard sounds
- 01-09: Delete button added to phoneme dialog actions — replaces hidden long-press on chip; uses existing confirmDeletePhoneme + pops dialog after deletion
- 01-09: Romanization table is Latin-first (Latin letter → IPA sound) — matches user mental model; DB columns unchanged
- 01-10: _isInteractingWithPopup Listener flag + 100ms delay in _onFocusChanged replaces microtask — eliminates race where focus-loss hide fires before requestFocus() in symbol insertion
- 01-10: IpaAudioPlayer passed as constructor param to IpaKeyboardPopup — IpaTextField (ConsumerStatefulWidget) reads provider and passes down to overlay
- 01-10: _symbolToAudioPath built lazily from IpaSound static lists in keyboard popup — single source of truth, no duplicated asset paths
- 01-11: _symbolToFeatures built as file-level lazy map from IpaSound static data using collection-for — reverse lookup with zero duplication of forward maps
- 01-11: IPA symbol field reuses existing _symbolController (pre-filled in edit mode) — no second controller needed
- 01-11: Reverse lookup is silent for unknown symbols — dropdowns stay unchanged, manual selection always works
- 01-13: Domain RewriteRule renamed to PhonologicalRewriteRule to avoid collision with Drift-generated RewriteRule data class from RewriteRules table
- 01-13: parseRewriteRule() uses ' -> ' (with spaces) as arrow separator; output stored as raw string (applying transformations is Phase 2 work)
- 01-13: Schema migrated v1->v2 with onUpgrade; existing project.db files gain rewrite_rules table automatically on next open
- 01-12: romanizationEnabledProvider watches full project_settings stream then filters by key — avoids a dedicated DAO method for a single-row fetch
- 01-12: asData?.value used for AsyncValue null-safe access (riverpod 3.x has no valueOrNull getter)
- 01-12: Feature-to-string reverse maps inlined as private static methods in romanization_section — 4 simple switch expressions not worth extracting to shared file
- 01-12: insertOnConflictUpdate on ProjectSettings.key unique column for upsert; schema bumped to v3 with from < 3 guard in onUpgrade

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 2 research flag: Pattern mini-language DSL design has no canonical reference — requires design spike before implementation commits (run one-page spec ceiling check)
- Phase 3: Conlanger's Thesaurus PDF (fiatlingua.org) must be pre-extracted to JSON — verify PDF structure is parseable before Phase 3 planning
- Phase 1: Verify OGG audio playback on Windows with just_audio before finalizing IPA audio asset format
- Phase 1: riverpod_lint custom_lint plugin cannot be used as IDE analyzer plugin in Dart 3.10.4 (AOT snapshot build hook incompatibility); use `dart run custom_lint` CLI instead

## Session Continuity

Last session: 2026-04-09
Stopped at: Completed 01-12-PLAN.md — romanization toggle and bidirectional phoneme-romanization sync. Phase 1 fully complete. Ready for Phase 2.
Resume file: None
