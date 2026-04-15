---
plan: 11-03
phase: 11-lexicon-etymology-chain
status: complete
completed: 2026-04-14
---

# Plan 11-03 Summary: EtymologyChainSection Widget

## What was built

`EtymologyChainSection` — a compact visual ancestry tree widget integrated into the word detail panel, replacing `WordDetailParentsSection`.

**Key files:**
- `lib/features/lexicon/presentation/dictionary/etymology_chain_section.dart` (created)
- `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart` (updated)

## Design

- **Compact pill chips** — word form + meaning, no arrows or large cards
- **Row-per-level layout** — same-depth ancestors render in a single horizontal row
- **CustomPaint connectors** — straight line for single parent, fan/bracket for multi-parent
- **Edge labels** ("via Actor") shown below each chip
- **Current word** highlighted with a primary-colored border
- **Children row** below current word with inverted fan connector
- **Inline parent management** via `SearchableParentSelector`

## Deviations

- Initial large-card design was replaced after human UAT feedback — user requested compact tree with same-rank nodes on one line
- Redesigned with `_ConnectorPainter` (CustomPaint) for connecting lines

## Self-Check: PASSED

- `dart analyze` — 0 errors
- `flutter test` — exit 0 (all tests pass)
- Human visual verification — approved
