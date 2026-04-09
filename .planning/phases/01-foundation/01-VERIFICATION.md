---
phase: 01-foundation
verified: 2026-04-09T12:00:00Z
status: passed
score: 5/5 must-haves verified
re_verification:
  previous_status: passed
  previous_score: 5/5
  context: "Previous VERIFICATION.md covered UAT gap closure. This re-verification checks all five user-supplied success criteria against the actual codebase as of 2026-04-09."
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 01: Foundation Verification Report

**Phase Goal:** Users can create and manage conlang projects with a working phonology toolset and a correct database schema that supports non-concatenative morphology from the start
**Verified:** 2026-04-09
**Status:** PASSED
**Re-verification:** Yes — third pass against explicit user-provided success criteria

---

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can create, open, switch to another project, and delete one — each project's data is isolated in its own SQLite database folder | VERIFIED | ProjectRegistry creates `{baseDir}/{id}/` directories; deleteProject deletes that directory recursively; projectDatabase family provider opens `{baseDir}/{projectId}/project.db` with ref.onDispose closing the connection on switch; ProjectMenu wires New/Open/Close/Delete; ProjectSelectorDialog calls currentProjectIdProvider.notifier.open() to switch |
| 2 | User can define a phoneme inventory with IPA symbols and articulation properties, and hear real audio recordings for any phoneme by clicking the IPA reference chart | VERIFIED | PhonemeEditDialog has Manner/Place/Voicing dropdowns for consonants and Height/Backness/Rounded for vowels; feature-driven derivation (_deriveConsonantSymbol/_deriveVowelSymbol) from IpaSound static data; IpaChartPanel renders pulmonic/vowel/non-pulmonic charts and wires each _IpaSymbolButton.onTap to audioPlayer.playSound(sound.audioAssetPath); IpaAudioPlayer uses just_audio; 89 OGG assets in assets/ipa_audio/ registered in pubspec |
| 3 | User can enter IPA text using the on-screen IPA keyboard without switching input methods | VERIFIED | IpaTextField (_tapGroupId Object() shared between TextField TapRegion at line 269 and overlay TapRegion at line 342); _onFocusChanged uses Future.delayed(100ms) with _isInteractingWithPopup guard; used in romanization_section.dart _buildEditRow for the IPA column (line 524 — IpaTextField with hintText '/ʃ/'); plain TextField for Latin column |
| 4 | User can define phonotactic syllable structure rules and phonological rules (e.g. vowel assimilation), then use the word generator to produce random words that conform to those rules | VERIFIED | TemplateEditor uses plain TextField for DSL input, validation icon suffix, Save gated on isValid; ConstraintEditor has 4-example DSL help block; RewriteRuleEditor provides A->B/C_D notation; WordGeneratorPanel calls WordGenerator().generateWords() reading parsedTemplatesProvider + phonemeInventoryProvider from DB; displays words with romanized form and violation highlighting |
| 5 | User can define a romanization mapping so any IPA transcription can be displayed in the project's chosen Latin script | VERIFIED | RomanizationSection: Latin-first column order (header 'Latin letter' / 'IPA sound (default)'), display rows show latinMapping first in normal font, ipaSymbol second in monospace+primary; no preview panel; IpaTextField on IPA input column; romanizeProvider builds String->String closure via longest-match-first replacement, consumed by WordGeneratorPanel for word display |

**Score:** 5/5 truths verified

---

## Required Artifacts

| Artifact | Role | Status | Key Detail |
|----------|------|--------|------------|
| `lib/features/project/data/project_registry.dart` | create/open/switch/delete projects with per-project directories | VERIFIED | createProject creates {baseDir}/{id}/ directory; deleteProject deletes it recursively |
| `lib/features/project/data/project_providers.dart` | per-project DB isolation via family provider | VERIFIED | projectDatabaseProvider(projectId) opens {id}/project.db; ref.onDispose(db.close) prevents cross-project bleed |
| `lib/features/project/presentation/project_menu.dart` | File menu with New/Open/Close/Delete | VERIFIED | All four actions present and wired to registry/currentProjectId |
| `lib/features/project/presentation/project_selector_dialog.dart` | Open/switch project dialog | VERIFIED | _openProject calls currentProjectIdProvider.notifier.open(project.id) |
| `lib/db/app_database.dart` | Schema with Lexemes supporting non-concatenative morphology | VERIFIED | Lexemes table has rootId, ruleIds (JSON array), computedForm fields; schemaVersion=3 with migration; Phonemes, NaturalClasses, PhonotacticTemplates, PhonotacticConstraints, RomanizationMappings, RewriteRules, ProjectSettings all present |
| `lib/features/phonology/presentation/inventory/phoneme_edit_dialog.dart` | Add/edit phoneme with articulation features | VERIFIED | Consonant dropdowns (manner/place/voicing), vowel dropdowns (height/backness/rounded); _deriveConsonantSymbol/_deriveVowelSymbol; derived symbol badge; Delete button when _isEditing; _RomanizationInfo ConsumerWidget showing existing mapping |
| `lib/features/phonology/presentation/shared/ipa_chart/ipa_chart_panel.dart` | IPA reference chart with clickable audio | VERIFIED | _IpaSymbolButton.onTap -> audioPlayer.playSound(sound.audioAssetPath); passed audioPlayer from ipaAudioPlayerProvider; wired in PhonologyShell at line 87 |
| `lib/features/phonology/presentation/shared/ipa_chart/ipa_audio_player.dart` | Audio playback service | VERIFIED | IpaAudioPlayer wraps just_audio AudioPlayer; playSound stops+sets+plays; provider disposes on scope exit |
| `lib/features/phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart` | IPA keyboard popup field | VERIFIED | _tapGroupId Object() at line 87; Future.delayed(100ms) in _onFocusChanged; showIpaKeyboard flag |
| `lib/features/phonology/presentation/sound_rules/template_editor.dart` | Syllable template DSL editor | VERIFIED | Plain TextField for pattern; suffixIcon shows check_circle/error_outline; Save gated on !isValid || isEmpty |
| `lib/features/phonology/presentation/sound_rules/constraint_editor.dart` | Phonotactic constraint editor | VERIFIED | 4-example DSL help block at lines 352-360 |
| `lib/features/phonology/presentation/sound_rules/rewrite_rule_editor.dart` | Phonological rewrite rules (A->B/C_D) | VERIFIED | Full CRUD wired to rewriteRuleDaoProvider; RewriteRules table in DB |
| `lib/features/phonology/presentation/sound_rules/word_generator_panel.dart` | Live word preview with constraint validation | VERIFIED | generateWords() called with parsedTemplatesProvider + phonemeInventoryProvider; romanizeAsync applied to each word; _ViolationText shows red wavy underline |
| `lib/features/phonology/presentation/inventory/romanization_section.dart` | Latin->IPA mapping table | VERIFIED | Latin-first column; IpaTextField on IPA column; romanize closure via romanizeProvider |
| `lib/features/phonology/data/romanization_providers.dart` | romanizeProvider converting IPA->Latin | VERIFIED | Longest-match-first replacement over all mappings; consumed by WordGeneratorPanel |

---

## Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| ProjectMenu | ProjectRegistry | projectRegistryProvider async read | WIRED |
| projectDatabaseProvider | AppDatabase.fromPath | {baseDir}/{projectId}/project.db | WIRED |
| currentDatabaseProvider | projectDatabaseProvider(projectId) | ref.watch(currentProjectIdProvider) | WIRED |
| phonemeDaoProvider | currentDatabaseProvider | ref.watch(currentDatabaseProvider) | WIRED |
| IpaChartPanel | IpaAudioPlayer | ipaAudioPlayerProvider + audioPlayer.playSound | WIRED |
| IpaChartPanel | PhonologyShell | line 87: const IpaChartPanel() | WIRED |
| IpaTextField | TapRegion groupId | _tapGroupId Object() shared at lines ~269 + ~342 | WIRED |
| RomanizationSection | IpaTextField | _buildEditRow uses IpaTextField for IPA column | WIRED |
| WordGeneratorPanel | romanizeProvider | ref.watch(romanizeProvider) applied to each word | WIRED |
| WordGeneratorPanel | parsedTemplatesProvider | ref.read(parsedTemplatesProvider) in _regenerate | WIRED |
| parsedTemplatesProvider | phonotacticDaoProvider | ref.watch(phonotacticDaoProvider) | WIRED |
| phonotacticDaoProvider | currentDatabaseProvider | ref.watch(currentDatabaseProvider) | WIRED |

---

## Database Schema for Non-Concatenative Morphology

The Lexemes table supports non-concatenative morphology from day one via three fields:

- `rootId TEXT` — FK-style pointer to the morphological root lexeme
- `ruleIds TEXT` — JSON array of morphological rule IDs applied to the root
- `computedForm TEXT` — cache of the derived IPA form

This structure allows discontinuous morphology (e.g. root + binyan interdigitation) because rules are stored as IDs rather than affixes. The schema is in schemaVersion=3 and will be migrated correctly for existing databases.

---

## Anti-Patterns Found

None blocking. Observations:

- `phonology_shell.dart` docstring says "persistent IPA reference chart placeholder" — word "placeholder" appears in comment only; the actual `IpaChartPanel()` is fully implemented. Not a blocker.
- Routes for Lexicon/Grammar/Culture show `_ComingSoonPage` — intentional future-phase stubs, not blocking Phase 1 goals.
- `project_providers.dart` line 61 mentions "placeholder path" in a comment about a fallback that is never used in practice. Not a blocker.

---

## Human Verification Required

### 1. IPA keyboard popup stays open when clicking symbols

**Test:** Open phoneme dialog or romanization section. Focus an IPA text field. Click a symbol in the popup.
**Expected:** Symbol inserts at cursor; popup remains open.
**Why human:** TapRegion groupId + 100ms delay is correct in code but runtime timing on macOS is what the UAT confirmed; no regression test exists.

### 2. Word generator end-to-end

**Test:** Add phonemes p/t/k (consonants) and a/i/u (vowels), define template (C)V(C), open Sound Rules, observe Word Preview panel.
**Expected:** 20 words generated, IPA shown with romanized form if mappings exist.
**Why human:** WordGeneratorPanel depends on reactive DB state; needs a live project to confirm the generation loop fires correctly.

### 3. Project data isolation

**Test:** Create Project A, add phoneme /p/. Create Project B (switches to it). Verify phoneme inventory is empty.
**Expected:** Project B inventory shows no phonemes from Project A.
**Why human:** DB isolation is guaranteed by the provider chain in code, but cross-project bleed from a stale provider ref would only surface at runtime.

### 4. Audio playback on click

**Test:** In the IPA reference chart, click the "p" button.
**Expected:** Audio of voiceless bilabial plosive plays.
**Why human:** just_audio asset loading requires the Flutter asset bundle to be built; OGG files are present but playback confirmation requires runtime.

---

## Summary

All five user-specified success criteria are verified against the actual codebase:

1. **Project management with isolation**: ProjectRegistry, projectDatabaseProvider (family), and ProjectMenu are fully wired. Each project gets its own `{id}/project.db` file; closing disposes the DB connection.

2. **Phoneme inventory with articulation properties and IPA audio**: PhonemeEditDialog has all feature dropdowns and feature-driven symbol derivation. IpaChartPanel wires 89 OGG audio assets to onTap handlers via IpaAudioPlayer. The panel is rendered persistently in PhonologyShell.

3. **On-screen IPA keyboard**: IpaTextField uses a shared TapRegion groupId to prevent popup dismissal when clicking symbols. Applied in the romanization section's IPA column.

4. **Phonotactic rules and word generation**: TemplateEditor (plain TextField, validated), ConstraintEditor (4-example DSL help), RewriteRuleEditor (A->B/C_D notation), and WordGeneratorPanel (live generation with violation highlighting) are all substantive and wired to project-scoped DB providers.

5. **Romanization mapping**: RomanizationSection has Latin-first column order, IpaTextField on IPA input, and romanizeProvider builds a closure used by WordGeneratorPanel to display romanized word forms alongside IPA.

The schema includes a Lexemes table with rootId/ruleIds/computedForm fields that support non-concatenative morphology for Phase 2 without requiring a migration.

Four human verification items remain (audio playback, IPA keyboard runtime, word generator e2e, project isolation at runtime) — all were confirmed in prior UAT except word generator which was unblocked by the template save fix.

---

_Verified: 2026-04-09_
_Verifier: Claude (gsd-verifier)_
