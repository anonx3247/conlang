---
phase: 06-reference-glossary
verified: 2026-04-12T23:00:00Z
status: human_needed
score: 9/9 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Open the app, click the ? icon in the top app bar, and verify the 320px glossary drawer opens on the right side"
    expected: "Glossary drawer slides open with GLOSSARY header, search box, and list of terms"
    why_human: "UI rendering and layout cannot be verified without running the app"
  - test: "Type 'allophone' in the search box"
    expected: "Results filter in real time to show matching terms (by name and/or definition)"
    why_human: "Real-time filtering behavior requires interactive UI"
  - test: "Expand the 'allophone' entry"
    expected: "Definition text appears, plus See Also chips (e.g. 'phoneme') are clickable and navigate to that term"
    why_human: "ExpansionTile expand/collapse and chip navigation require interactive testing"
  - test: "Navigate to Phonology tab, click the ? button in its sidebar, verify glossary opens pre-filtered to Phonology category"
    expected: "Only Phonology-category terms shown, Phonology filter chip visible with X to clear"
    why_human: "Per-tab contextual pre-filter requires running the app to verify"
  - test: "Repeat for Grammar tab (expect Morphology filter) and Lexicon tab (expect Semantics filter)"
    expected: "Each tab's ? button opens glossary pre-filtered to the correct category"
    why_human: "Per-tab behavior requires interactive UI"
  - test: "Click X on the filter chip in the drawer to clear the category filter"
    expected: "All 162 terms visible, filter chip disappears"
    why_human: "Category chip clear requires interactive UI"
  - test: "Verify colored category chips are visually distinct on each term"
    expected: "Phonology=primaryContainer, Morphology=secondaryContainer, Syntax=tertiaryContainer, Semantics=errorContainer, Typology=surfaceContainerHighest"
    why_human: "Color rendering is not verifiable programmatically"
---

# Phase 6: Reference Glossary — Verification Report

**Phase Goal:** Users can look up unfamiliar linguistic terminology without leaving the application
**Verified:** 2026-04-12T23:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Glossary JSON asset loads and parses into typed GlossaryEntry list | VERIFIED | `glossaryProvider` uses `rootBundle.loadString('assets/glossary.json')` + `GlossaryEntry.fromJson`; asset registered in `pubspec.yaml` line 74 |
| 2 | Search filter matches on both term name and definition text | VERIFIED | `filteredGlossaryProvider` applies `entry.term.toLowerCase().contains(query) \|\| entry.definition.toLowerCase().contains(query)` |
| 3 | Category filter restricts results to a single category | VERIFIED | `filteredGlossaryProvider` applies `category == null \|\| entry.category == category` AND logic with search |
| 4 | 150-200 linguistic terms span all five categories | VERIFIED | 162 terms confirmed by JSON parse: Phonology(37), Morphology(38), Syntax(40), Semantics(29), Typology(18); all 5 categories present |
| 5 | User can open glossary drawer from any tab via ? icon in app bar | VERIFIED (code) | `app_shell.dart` line 100: `help_outline` IconButton wired to `glossaryOpenProvider.notifier.toggle()`; `GlossaryDrawer` mounted in body Row when open |
| 6 | User can open glossary pre-filtered by domain from per-tab ? buttons | VERIFIED (code) | phonology_shell sets 'Phonology', grammar_shell sets 'Morphology', lexicon_shell sets 'Semantics' via `glossaryCategoryFilterProvider.notifier.set()` |
| 7 | User can type in search box and see results filtered in real time | VERIFIED (code) | `GlossaryDrawer` TextField `onChanged` calls `glossarySearchProvider.notifier.set(value)`; `filteredGlossaryProvider` derives from both providers |
| 8 | User can tap a term to expand and read its definition | VERIFIED (code) | `_GlossaryTile` is an `ExpansionTile` with `entry.definition` in `bodySmall` text in children |
| 9 | User can tap See Also chips to jump to referenced terms | VERIFIED (code) | `ActionChip.onPressed` calls `_navigateToTerm(related)` which clears category, sets search to chip term |

**Score:** 9/9 truths verified (automated checks pass; interactive behavior requires human confirmation)

### Roadmap Success Criteria

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| SC1 | User can open built-in glossary, search for a term (e.g. "ergative", "allophone", "paradigm"), and read a clear definition without leaving the app | VERIFIED (code) | 162-term JSON asset loaded via providers; `GlossaryDrawer` with search + `ExpansionTile` definitions wired into `AppShell` |
| SC2 | Glossary entries for terms relevant to current context (morphology, phonology, grammar) are accessible from those tabs | VERIFIED (code) | Per-tab ? buttons in phonology_shell, grammar_shell, lexicon_shell set `glossaryCategoryFilterProvider` to respective category before opening drawer |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `assets/glossary.json` | Bundled linguistic glossary dataset | VERIFIED | 162 entries, all 5 categories, 'allophone' present, all entries have seeAlso key |
| `lib/features/glossary/domain/glossary_entry.dart` | GlossaryEntry data class with fromJson | VERIFIED | `class GlossaryEntry` with `fromJson` factory, seeAlso nullable-safe |
| `lib/features/glossary/data/glossary_providers.dart` | 5 Riverpod providers | VERIFIED | All 5 providers present: `glossaryProvider`, `filteredGlossaryProvider`, `glossaryOpenProvider`, `glossarySearchProvider`, `glossaryCategoryFilterProvider` |
| `lib/features/glossary/presentation/glossary_drawer.dart` | 320px right-side glossary drawer | VERIFIED | `GlossaryDrawer` ConsumerStatefulWidget, 320px SizedBox, `ExpansionTile`, `ActionChip`, `FilterChip`, category color mapping |
| `lib/shared/widgets/app_shell.dart` | Modified AppShell with ? button and glossary drawer | VERIFIED | `help_outline` IconButton, `glossaryOpenProvider` wiring, `GlossaryDrawer` in Row body |
| `test/features/glossary/glossary_entry_test.dart` | Unit tests for GlossaryEntry.fromJson | VERIFIED | 42 lines, 10 test/expect calls |
| `test/features/glossary/glossary_providers_test.dart` | Unit tests for filter logic | VERIFIED | 153 lines, 30 test/expect calls |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/features/glossary/data/glossary_providers.dart` | `assets/glossary.json` | `rootBundle.loadString` | WIRED | Line 17: `rootBundle.loadString('assets/glossary.json')` |
| `lib/features/glossary/data/glossary_providers.dart` | `lib/features/glossary/domain/glossary_entry.dart` | import | WIRED | Line 6: `import '../domain/glossary_entry.dart'` |
| `lib/shared/widgets/app_shell.dart` | `lib/features/glossary/data/glossary_providers.dart` | import + `glossaryOpenProvider` | WIRED | Line 5 import; lines 100-157 use `glossaryOpenProvider` and `GlossaryDrawer` |
| `lib/features/glossary/presentation/glossary_drawer.dart` | `lib/features/glossary/data/glossary_providers.dart` | import + `filteredGlossaryProvider` | WIRED | Line 4 import; line 60 `ref.watch(filteredGlossaryProvider)` |
| `lib/features/grammar/presentation/grammar_shell.dart` | `lib/features/glossary/data/glossary_providers.dart` | import + `glossaryCategoryFilterProvider` | WIRED | Line 5 import; line 86-88 set 'Morphology' + open |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| `glossary_drawer.dart` | `filteredEntries` | `filteredGlossaryProvider` → `glossaryProvider` → `rootBundle.loadString('assets/glossary.json')` | Yes — 162 entries from bundled JSON asset | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All 5 providers declared in glossary_providers.dart | `node` script checking file contents | All 5 found | PASS |
| glossary.json has 150+ entries across 5 categories | Python JSON parse | 162 entries, 5 categories match exactly | PASS |
| glossary.json contains 'allophone' (plan acceptance criterion) | Python JSON parse | Found | PASS |
| All artifact files exist | `ls` checks | All 7 files exist | PASS |
| Commit hashes from SUMMARY exist in git | `git log` | c3d8e65, f9c5883, 69c3f12, f52f19b all present | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| REF-01 | 06-01-PLAN.md, 06-02-PLAN.md | User can search a built-in glossary of linguistic terminology with definitions | SATISFIED | 162-term bundled glossary, search/category providers, GlossaryDrawer UI wired into AppShell and 3 tab shells |

### Anti-Patterns Found

No anti-patterns detected. No TODO/FIXME/placeholder comments, no stub returns, no hardcoded empty data in the data flow path.

### Human Verification Required

All automated checks pass. The following behaviors require interactive app testing:

#### 1. Glossary Drawer Opens via App Bar ? Button

**Test:** Launch the macOS app with any project open. Click the `?` (help_outline) icon in the top app bar.
**Expected:** A 320px glossary drawer opens on the right side of the window, showing the GLOSSARY header, search field, and a scrollable list of terms.
**Why human:** UI rendering and drawer layout cannot be verified programmatically.

#### 2. Real-Time Search Filtering

**Test:** With the glossary drawer open, type "allophone" in the search box.
**Expected:** Results filter in real time to show only terms matching "allophone" in either name or definition. Backspacing restores all terms.
**Why human:** Real-time UI responsiveness requires interactive testing.

#### 3. ExpansionTile Expand and Definition Display

**Test:** Tap the "allophone" term in the list.
**Expected:** Term expands to show the full definition text. If seeAlso cross-references are present (e.g. "phoneme"), they appear as tappable ActionChip buttons.
**Why human:** ExpansionTile accordion behavior and chip rendering require interactive testing.

#### 4. See Also Navigation

**Test:** With "allophone" expanded and See Also chips visible, tap a chip (e.g. "phoneme").
**Expected:** The search box updates to the tapped term name, results re-filter to show that term, category filter is cleared.
**Why human:** Navigation between related terms requires interactive verification.

#### 5. Per-Tab Contextual ? Button — Phonology

**Test:** Navigate to the Phonology tab. Click the small ? button in the sidebar header area.
**Expected:** Glossary drawer opens pre-filtered to "Phonology" category. A Phonology filter chip is visible with an X to clear it.
**Why human:** Per-tab contextual pre-filtering requires running the app.

#### 6. Per-Tab Contextual ? Button — Grammar and Lexicon

**Test:** Repeat for Grammar tab (expect Morphology filter) and Lexicon tab (expect Semantics filter).
**Expected:** Each tab's ? button opens glossary with the correct domain pre-filter active.
**Why human:** Per-tab behavior requires running the app.

#### 7. Category Chip Clear

**Test:** After opening with a per-tab ? button, click the X on the filter chip.
**Expected:** All 162 terms appear, filter chip disappears, search continues working unaffected.
**Why human:** FilterChip deletion and state reset require interactive testing.

#### 8. Category Color Coding

**Test:** Browse terms across different categories and observe chip colors.
**Expected:** Phonology=primaryContainer (blue tones), Morphology=secondaryContainer, Syntax=tertiaryContainer, Semantics=errorContainer (warm amber/red), Typology=surfaceContainerHighest.
**Why human:** Color rendering and visual distinctiveness require human judgment.

### Gaps Summary

No gaps. All 9 observable truths are verified by code inspection. REF-01 is satisfied. The phase is structurally complete and wired correctly. Remaining items are visual/interactive behaviors that require human testing before the phase can be fully approved.

---

_Verified: 2026-04-12T23:00:00Z_
_Verifier: Claude (gsd-verifier)_
