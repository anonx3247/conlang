---
phase: 01-foundation
plan: 13
subsystem: phonology
tags: [dart, flutter, drift, petitparser, SPE-notation, sound-changes, DSL, rewrite-rules]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: phonotactic_dsl.dart with Slot/ConstraintRule parser infrastructure

provides:
  - PhonologicalRewriteRule data class and ParsedRewriteRule result in phonotactic_dsl.dart
  - parseRewriteRule() function parsing A -> B / C_D SPE-style notation
  - RewriteRules Drift table with schema migration (v1 -> v2)
  - RewriteRuleDao with CRUD + watchAll() stream
  - RewriteRuleEditor widget on Sound Rules page with real-time validation
  - rewriteRuleDaoProvider + rewriteRuleListProvider in phonotactic_providers.dart

affects: [02-morphology, any phase using phonotactic_dsl.dart or sound rules page]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - SPE rewrite rule DSL: A -> B / C_D with _ for target position, # for word boundary
    - Drift table naming: Table class RewriteRules generates data class RewriteRule (watch for naming conflicts with domain classes)
    - Domain model renaming to avoid Drift collision: PhonologicalRewriteRule vs Drift-generated RewriteRule

key-files:
  created:
    - lib/features/phonology/data/rewrite_rule_dao.dart
    - lib/features/phonology/presentation/sound_rules/rewrite_rule_editor.dart
  modified:
    - lib/features/phonology/domain/phonotactic_dsl.dart
    - lib/db/app_database.dart
    - lib/features/phonology/data/phonotactic_providers.dart
    - lib/features/phonology/presentation/sound_rules/sound_rules_page.dart

key-decisions:
  - "Domain RewriteRule renamed to PhonologicalRewriteRule to avoid collision with Drift-generated RewriteRule data class from RewriteRules table"
  - "Word boundary (#) excluded from _ipaCharParser() char class and added as dedicated 4th alternative in _segmentParser()"
  - "parseRewriteRule() uses ' -> ' (with spaces) as arrow separator to disambiguate from IPA characters; same for ' / ' context separator"
  - "RewriteRule output field stored as raw string (not parsed as Slot list) — applying transformations is Phase 2 morphology engine work"
  - "Schema migrated v1->v2 with onUpgrade creating rewrite_rules table; existing projects upgraded on next open"

patterns-established:
  - "Rewrite rule UI pattern: RewriteRuleEditor mirrors ConstraintEditor (dialog, live validation, monospace display, edit/delete)"

# Metrics
duration: 4min
completed: 2026-04-09
---

# Phase 01 Plan 13: Rewrite Rules Summary

**SPE-style phonological rewrite rules (A -> B / C_D) with DSL parser, Drift persistence (schema v2), and Sound Rules page editor with real-time validation**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-09T06:44:28Z
- **Completed:** 2026-04-09T06:48:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Implemented `parseRewriteRule()` supporting full SPE notation: input, output, left/right context, word boundary (#)
- Added `RewriteRules` Drift table with schema migration (v1 to v2) and `RewriteRuleDao`
- Built `RewriteRuleEditor` widget wired into Sound Rules page with add/edit/delete and green/red validation icons

## Task Commits

1. **Task 1: Define rewrite rule data model and parser** - `c66d5f1` (feat)
2. **Task 2: Add rewrite rule editor UI to Sound Rules page** - `6fb5cae` (feat)

**Plan metadata:** (committed below)

## Files Created/Modified
- `lib/features/phonology/domain/phonotactic_dsl.dart` - Added PhonologicalRewriteRule, ParsedRewriteRule, parseRewriteRule(), word boundary in _segmentParser()
- `lib/db/app_database.dart` - Added RewriteRules table, schema v2, onUpgrade migration, RewriteRuleDao in daos list
- `lib/db/app_database.g.dart` - Regenerated (includes rewrite_rules table)
- `lib/features/phonology/data/rewrite_rule_dao.dart` - New DAO: watchAll(), insertRule(), updateRule(), deleteRule()
- `lib/features/phonology/data/rewrite_rule_dao.g.dart` - Drift-generated DAO mixin
- `lib/features/phonology/data/phonotactic_providers.dart` - Added rewriteRuleDaoProvider, rewriteRuleListProvider
- `lib/features/phonology/presentation/sound_rules/rewrite_rule_editor.dart` - New editor widget with dialog, validation, list display
- `lib/features/phonology/presentation/sound_rules/sound_rules_page.dart` - Wired RewriteRuleEditor after ConstraintEditor

## Decisions Made
- Renamed domain `RewriteRule` to `PhonologicalRewriteRule` to avoid collision with Drift-generated `RewriteRule` data class (Drift names data classes `{TableClass}Data` unless table class has no trailing 's', in which case it drops the 's' — `RewriteRules` table generates `RewriteRule` data class).
- Word boundary `#` excluded from `_ipaCharParser()` char exclusion set and added as dedicated 4th alternative parser, so it parses cleanly as `Slot(literalPhoneme: '#')`.
- Output field stored as raw string — applying the transformation requires knowing the phoneme inventory (Phase 2 morphology engine concern).
- Schema migrated v1→v2 with `onUpgrade`; existing project databases gain the `rewrite_rules` table on next open without data loss.

## Deviations from Plan

**1. [Rule 1 - Bug] Renamed domain RewriteRule to PhonologicalRewriteRule**
- **Found during:** Task 2 (flutter analyze after creating rewrite_rule_editor.dart)
- **Issue:** Drift generates a `RewriteRule` data class from the `RewriteRules` table; the domain `RewriteRule` class in phonotactic_dsl.dart caused an `ambiguous_import` error in any file importing both
- **Fix:** Renamed the domain class to `PhonologicalRewriteRule` and updated `ParsedRewriteRule.rule` field type and the `parseRewriteRule()` return constructor
- **Files modified:** lib/features/phonology/domain/phonotactic_dsl.dart
- **Verification:** flutter analyze shows 0 new errors; only pre-existing widget_test.dart error remains
- **Committed in:** 6fb5cae (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - naming collision bug)
**Impact on plan:** Required renaming the domain class; no functional change to behavior or API. Both task commits remain clean.

## Issues Encountered
None beyond the naming collision handled inline.

## User Setup Required
None — database schema migration runs automatically on next app open for existing projects.

## Next Phase Readiness
- Rewrite rules are defined and persisted but not yet applied to word generation (Phase 2 morphology engine concern)
- parseRewriteRule() is ready for Phase 2 to consume when building the sound change application engine
- Sound Rules page now has three sections: Templates, Constraints, Rewrite Rules

---
*Phase: 01-foundation*
*Completed: 2026-04-09*
