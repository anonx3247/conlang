# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-08)

**Core value:** A powerful, flexible morphology engine that handles the full spectrum of language types through a readable pattern mini-language
**Current focus:** Phase 1 — Foundation

## Current Position

Phase: 1 of 6 (Foundation)
Plan: 4 of 7 in current phase
Status: In progress
Last activity: 2026-04-09 — Plan 03 complete (IPA reference chart panel + 89 OGG audio recordings)

Progress: [█░░░░░░░░░] 7% (3/42 total plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: 5 min
- Total execution time: 0.2 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 3 | 15 min | 5 min |

**Recent Trend:**
- Last 5 plans: 7 min, 2 min, 6 min
- Trend: —

*Updated after each plan completion*

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

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 2 research flag: Pattern mini-language DSL design has no canonical reference — requires design spike before implementation commits (run one-page spec ceiling check)
- Phase 3: Conlanger's Thesaurus PDF (fiatlingua.org) must be pre-extracted to JSON — verify PDF structure is parseable before Phase 3 planning
- Phase 1: Verify OGG audio playback on Windows with just_audio before finalizing IPA audio asset format
- Phase 1: riverpod_lint custom_lint plugin cannot be used as IDE analyzer plugin in Dart 3.10.4 (AOT snapshot build hook incompatibility); use `dart run custom_lint` CLI instead

## Session Continuity

Last session: 2026-04-09
Stopped at: Completed 01-foundation/01-03-PLAN.md (IPA chart panel, audio playback, 89 OGG assets)
Resume file: None
