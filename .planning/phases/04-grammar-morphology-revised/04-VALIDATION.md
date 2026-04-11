---
phase: 4
slug: grammar-morphology-revised
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-10
updated: 2026-04-10
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> See `04-RESEARCH.md` § Validation Architecture for the authoritative test map.
>
> **Revision note (2026-04-10):** Plan 04-04 was split into four smaller plans (04-04 / 04-05 / 04-06 / 04-07). The original plan 04-05 (Lexicon Derivations) was renumbered to 04-07. The per-task verification map below reflects the 7-plan structure. See `04-04-PLAN.md`, `04-05-PLAN.md`, `04-06-PLAN.md`, `04-07-PLAN.md` for task details.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Dart SDK) |
| **Config file** | `pubspec.yaml` (dev_dependencies: flutter_test) |
| **Quick run command** | `flutter test --no-pub` |
| **Full suite command** | `flutter test --no-pub --coverage` |
| **Estimated runtime** | ~30 seconds (quick) / ~90 seconds (full + coverage) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test --no-pub test/unit/` (unit subset)
- **After every plan wave:** Run `flutter test --no-pub`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

Every Phase 4 task carries either an `<automated>` verify command or a Wave-0 dependency.
Task IDs use the format `04-{plan}-T{task#}`.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-T0 | 04-01 | 1 | GRAM-01, GRAM-06 | T-04-07 | FeatureBindings JSON round-trip defense against malformed DB state | unit (TDD) | `flutter test --no-pub test/unit/grammar/feature_bindings_converter_test.dart` | will-be-created | ⬜ pending |
| 04-01-T1 | 04-01 | 1 | GRAM-01, GRAM-06, GRAM-07 | T-04-01, T-04-02, T-04-04, T-04-06 | Migration parses legacy posIds defensively; schema changes are idempotent via beforeOpen safety net | integration | `dart run build_runner build --delete-conflicting-outputs && flutter test --no-pub test/integration/migration_v7_to_v8_test.dart` | will-be-created | ⬜ pending |
| 04-01-T2 | 04-01 | 1 | GRAM-07 | T-04-01, T-04-03 | File-level backup before migration prevents data loss | unit | `flutter test --no-pub test/unit/project/project_backup_test.dart` | will-be-created | ⬜ pending |
| 04-02-T1 | 04-02 | 2 | GRAM-01 | — | Template catalog integrity (20+ entries, unique ids, all with descriptions) | unit | `flutter test --no-pub test/unit/grammar/dimension_templates_test.dart` | will-be-created | ⬜ pending |
| 04-02-T2 | 04-02 | 2 | GRAM-01, GRAM-02, GRAM-06 | T-04-07 | DAO kind-aware queries; Dimensions CRUD with JSON round-trip | unit | `dart run build_runner build --delete-conflicting-outputs && flutter test --no-pub test/unit/grammar/grammar_dao_test.dart` | will-be-created | ⬜ pending |
| 04-02-T3 | 04-02 | 2 | GRAM-03 | — | POS resolver handles null/empty/malformed input safely | unit | `flutter test --no-pub test/unit/grammar/pos_resolver_test.dart` | will-be-created | ⬜ pending |
| 04-03-T1 | 04-03 | 3 | GRAM-02 | T-04-13 | D-13 enforced: unbound rules never fire on inflectional paths | unit | `flutter test --no-pub test/unit/grammar/paradigm_engine_test.dart test/unit/grammar/tiebreak_detector_test.dart` | will-be-created | ⬜ pending |
| 04-03-T2 | 04-03 | 3 | GRAM-03, GRAM-04 | T-04-11 | ParadigmAxes JSON parse is defensive (malformed → default); typology round-trip | unit | `flutter test --no-pub test/unit/grammar/paradigm_generation_test.dart test/unit/grammar/typology_providers_test.dart` | will-be-created | ⬜ pending |
| 04-04-T1 | 04-04 | 4 | GRAM-06 | — | Router branch replacement is atomic; no /morphology routes remain; morphology_shell.dart and pos_page.dart physically deleted | widget | `flutter test --no-pub test/widget/grammar/grammar_router_test.dart` | will-be-created | ⬜ pending |
| 04-04-T2 | 04-04 | 4 | GRAM-01 | — | Template picker modal behavior; POS+Dimensions CRUD; MigrationBanner widget dismissibility | widget | `flutter test --no-pub test/widget/grammar/pos_dimensions_page_test.dart` | will-be-created | ⬜ pending |
| 04-04-T3 | 04-04 | 4 | GRAM-04 | T-04-11 | Typology form auto-save + all three fields written correctly | widget | `flutter test --no-pub test/widget/grammar/typology_page_test.dart` | will-be-created | ⬜ pending |
| 04-05-T1 | 04-05 | 5 | GRAM-02, GRAM-06 | T-04-26, T-04-27 | Kind-aware RuleEditorDialog production code compiles clean; RulesPage parameterized | analyzer | `dart analyze --fatal-infos lib/features/morphology/presentation/rules/rule_editor_dialog.dart lib/features/morphology/presentation/rules/rules_page.dart lib/features/grammar/presentation/inflectional_rules/inflectional_rules_page.dart` | will-be-created | ⬜ pending |
| 04-05-T2 | 04-05 | 5 | GRAM-02, GRAM-06 | T-04-17, T-04-26 | Kind-aware dialog behavior + MANDATORY live tiebreak banner integration test + unbound validation error + InflectionalRulesPage filter | widget | `flutter test --no-pub test/widget/grammar/rule_editor_dialog_kind_test.dart` | will-be-created | ⬜ pending |
| 04-06-T1 | 04-06 | 6 | GRAM-03, GRAM-05 | T-04-28 | ParadigmCellOverrideDao CRUD; canonical featureSetKey; paradigmCoverageMatrixProvider | unit | `dart run build_runner build --delete-conflicting-outputs && flutter test --no-pub test/unit/grammar/paradigm_cell_override_test.dart` | will-be-created | ⬜ pending |
| 04-06-T2 | 04-06 | 6 | GRAM-03, GRAM-05 | T-04-15, T-04-16, T-04-18 | ParadigmTableWidget with MANDATORY D-25 tabs/dropdown affordance test, per-cell ViolationText wiring, amber override rendering, cell override dialog | widget | `flutter test --no-pub test/widget/grammar/paradigm_table_widget_test.dart` | will-be-created | ⬜ pending |
| 04-06-T3 | 04-06 | 6 | GRAM-03 | — | ParadigmViewerPage real widget replaces stub; no new tests (regression via grammar_router_test.dart from 04-04) | widget (regression) | `flutter test --no-pub test/widget/grammar/grammar_router_test.dart` | exists-from-04-04 | ⬜ pending |
| 04-07-T1 | 04-07 | 7 | GRAM-06, GRAM-07 | T-04-22 | Lexicon Derivations sub-tab routes + rules_page filter | widget | `flutter test --no-pub test/widget/grammar/lexicon_derivations_tab_test.dart` | will-be-created | ⬜ pending |
| 04-07-T2 | 04-07 | 7 | GRAM-06, GRAM-07 | T-04-19 | computedDerivedFormsProvider filters by kind='derivational' (pitfall #9) | unit | `flutter test --no-pub test/unit/lexicon/computed_derived_forms_kind_filter_test.dart` | will-be-created | ⬜ pending |
| 04-07-T3 | 04-07 | 7 | GRAM-03 | T-04-20, T-04-21 | Word detail paradigm embed is read-only and scoped per-lexeme | widget | `flutter test --no-pub test/widget/grammar/word_detail_paradigm_test.dart` | will-be-created | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Sampling continuity:** No 3 consecutive tasks in the same plan go without an automated verify — every task above has one.

**Plan 04-05 Task 1 note:** The rule editor extension is a production-code task whose behavior is fully covered by Task 2's mandatory widget test file (6 tests including the live tiebreak banner integration test). Task 1's verify is `dart analyze --fatal-infos` to catch compile errors early; the behavioral verification happens in Task 2.

---

## Wave 0 Requirements

All Wave-0 test files are **created by the task that owns them** (TDD — test file and source file land together). Execute-plan creates them during the same task commits.

- [ ] `test/unit/grammar/feature_bindings_converter_test.dart` — created by 04-01-T0 (GRAM-01)
- [ ] `test/integration/migration_v7_to_v8_test.dart` — created by 04-01-T1 (GRAM-06, GRAM-07)
- [ ] `test/unit/project/project_backup_test.dart` — created by 04-01-T2 (GRAM-07)
- [ ] `test/unit/grammar/dimension_templates_test.dart` — created by 04-02-T1 (GRAM-01)
- [ ] `test/unit/grammar/grammar_dao_test.dart` — created by 04-02-T2 (GRAM-01, GRAM-02, GRAM-06)
- [ ] `test/unit/grammar/pos_resolver_test.dart` — created by 04-02-T3 (GRAM-03)
- [ ] `test/unit/grammar/paradigm_engine_test.dart` — created by 04-03-T1 (GRAM-02)
- [ ] `test/unit/grammar/tiebreak_detector_test.dart` — created by 04-03-T1 (GRAM-02)
- [ ] `test/unit/grammar/paradigm_generation_test.dart` — created by 04-03-T2 (GRAM-03)
- [ ] `test/unit/grammar/typology_providers_test.dart` — created by 04-03-T2 (GRAM-04)
- [ ] `test/widget/grammar/grammar_router_test.dart` — created by 04-04-T1 (GRAM-06)
- [ ] `test/widget/grammar/pos_dimensions_page_test.dart` — created by 04-04-T2 (GRAM-01)
- [ ] `test/widget/grammar/typology_page_test.dart` — created by 04-04-T3 (GRAM-04)
- [ ] `test/widget/grammar/rule_editor_dialog_kind_test.dart` — created by 04-05-T2 (GRAM-02, GRAM-06) — includes MANDATORY live tiebreak banner integration test
- [ ] `test/unit/grammar/paradigm_cell_override_test.dart` — created by 04-06-T1 (GRAM-05)
- [ ] `test/widget/grammar/paradigm_table_widget_test.dart` — created by 04-06-T2 (GRAM-03, GRAM-05) — includes MANDATORY D-25 tabs/dropdown affordance tests
- [ ] `test/widget/grammar/lexicon_derivations_tab_test.dart` — created by 04-07-T1 (GRAM-06, GRAM-07)
- [ ] `test/unit/lexicon/computed_derived_forms_kind_filter_test.dart` — created by 04-07-T2 (GRAM-06, GRAM-07)
- [ ] `test/widget/grammar/word_detail_paradigm_test.dart` — created by 04-07-T3 (GRAM-03)

Each test file is created by the task that owns its behavior. No separate Wave-0 prep task; TDD is inlined into the task that implements the production code (per execute-plan execution model).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual paradigm chart readability (long dimension headers, cell wrapping, scroll behavior) | GRAM-03 | Visual/UX judgement — no automated oracle for "chart is readable" | Load a noun with 3 dimensions (gender × number × case: 2×2×4 = 16 cells). Verify headers don't truncate, cells expand for long forms, table scrolls horizontally without losing row labels. Verify the TabBar (3 slices) is visible and tabs switch slices correctly. |
| Template picker tooltip text quality across all 20+ entries | GRAM-01 | Content quality judgement; the automated tests only verify `.description.isNotEmpty` | Open template picker. Hover each template card. Verify description is accurate, readable, ≤3 sentences, free of typos. |
| Tiebreaker banner copy clarity under real conflict scenarios | GRAM-02 | UX judgement — the text is locked and the appearance/disappearance is automated in 04-05-T2 Test 5; this verifies real-world legibility | Create two rules with identical bindings. Open the second rule in the editor. Verify the red banner is instantly visible, legible, and mentions the other rule by name in a realistic project context. |
| Migration banner dismissibility and copy | GRAM-06 | UX judgement | Open v7 project → migrate → open /grammar/inflectional. Verify banner appears, copy matches UI-SPEC, dismiss button works, banner stays dismissed after restart. Repeat for /lexicon/derivations. |
| POS dimension editor UX on resize / small windows | GRAM-01 | Responsive layout judgement | Shrink Grammar tab to minimum width. Verify dimension/level chips wrap gracefully without overlap. |
| Paradigm cell override rom→IPA auto-derivation on first input | GRAM-05 | Interactive flow | Click any cell. Type romanization. Verify IPA field populates from deromanize. Edit IPA manually. Verify it no longer auto-updates when rom changes. |
| DropdownButton variant of D-25 slice selector with 7+ case levels | GRAM-03 | Visual/interactive judgement — the widget test asserts DropdownButton is present but not its real-world legibility | Create a POS with Case dimension of 7 levels (NOM/ACC/GEN/DAT/ABL/LOC/INSTR). Verify the DropdownButton label lists all 7 entries, selecting each switches the table correctly. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (filled in the Per-Task Verification Map above)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (all 19 test files listed above, owned by their parent tasks)
- [x] No watch-mode flags (no `flutter test --watch` in CI commands)
- [x] Feedback latency < 90s (quick run = unit subset; full run ≤ 90s per existing Phase 3 baseline)
- [x] Migration test covers data mutation AND rollback (file-level backup via Task 04-01-T2)
- [x] `nyquist_compliant: true` set in frontmatter
- [x] **Revision iteration 1 (2026-04-10):** Plan 04-04 split into 4 smaller plans (04-04/04-05/04-06/04-07); D-25 tabs/dropdown affordance concretely specified in 04-06-T2; mandatory live tiebreak banner test in 04-05-T2; mandatory D-25 affordance tests in 04-06-T2

**Approval:** pending execution
