---
status: awaiting_human_verify
trigger: "Paradigm viewer checks gemination violations on romanized form instead of phonetic (post-rewrite) form"
created: 2026-04-13T00:00:00Z
updated: 2026-04-13T00:00:00Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: CONFIRMED — four call sites passed pre-rewrite IPA to validate(); fixed by threading applyRewritePipelineProvider through each site
test: dart analyze — clean (zero errors, only pre-existing info warnings)
expecting: Forms with rewrite rules that eliminate phonemic gemination no longer show false violation underlines
next_action: Human verification

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: Gemination violation checks should operate on the phonetic (post-rewrite) form, not the romanized form
actual: Violation is flagged based on romanized form — e.g., "acca" flagged even though phonetic form [ækk] may not have gemination, or forms with rewrite rules that eliminate gemination phonetically are still flagged
errors: No errors — just checking wrong representation
reproduction: Have a word with gemination in romanized form but not in phonetic form (via rewrite rules), observe it's still flagged as a violation
started: Pre-existing bug discovered during Phase 8 UAT

## Eliminated
<!-- APPEND only - prevents re-investigating -->

- hypothesis: Bug is only in _FilledCell (the filled paradigm cell)
  evidence: _FilledCell already used validate(word: form) correctly — it was _UnmarkedCell and _BaseFormViolationBadge that had the bug
  timestamp: 2026-04-13

- hypothesis: Bug only affects paradigm viewer
  evidence: lexemeViolationsProvider (word list) and word_detail_panel also passed pre-rewrite IPA
  timestamp: 2026-04-13

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-04-13
  checked: paradigm_table_widget.dart _FilledCell (line ~837)
  found: Already correct — uses validate(word: form) where form is post-rewrite
  implication: The _FilledCell bug was already fixed; the bug is in other widgets

- timestamp: 2026-04-13
  checked: paradigm_table_widget.dart _UnmarkedCell (line ~936)
  found: validate(word: root) — root is pre-rewrite phonemic form passed from computeParadigmCell
  implication: Zero-morpheme unmarked cells flagged incorrectly when rewrite rules exist

- timestamp: 2026-04-13
  checked: paradigm_table_widget.dart _BaseFormViolationBadge (line ~1483)
  found: validate(word: lexeme.ipa) — lexeme.ipa is raw stored IPA, pre-rewrite
  implication: Header violation badge for selected lexeme checked wrong form

- timestamp: 2026-04-13
  checked: lexeme_providers.dart lexemeViolationsProvider (line ~444)
  found: validate(word: l.ipa) — same pre-rewrite IPA bug in batch provider that feeds word list
  implication: Word list red wavy underlines also incorrectly based on phonemic not phonetic form

- timestamp: 2026-04-13
  checked: word_detail_panel.dart _buildViewMode (line ~462)
  found: validate(word: display.ipa) — display.ipa is pre-rewrite
  implication: Word detail panel violation display also affected

- timestamp: 2026-04-13
  checked: applyRewritePipelineProvider in phonotactic_providers.dart
  found: Provides String Function(String phonemic) that applies rewrite pipeline; already imported in relevant files
  implication: Simple fix — wrap IPA argument in applyRewrite() before passing to validate()

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: Four call sites passed the raw phonemic IPA (pre-rewrite) to phonotacticValidatorProvider instead of the post-rewrite phonetic form. The phonotactic validator performs gemination checks on the string it receives — if that string is the phonemic form, rewrites that eliminate gemination (e.g. nn -> ã) are invisible to the validator, causing false positives.

fix: At each bug site, watch applyRewritePipelineProvider and wrap the IPA argument: validate(word: applyRewrite(ipa)). The applyRewritePipelineProvider returns the identity function when no rewrite rules are configured, so this is safe when no rewrites exist.

verification: dart analyze clean on all changed files — zero errors

files_changed:
  - lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart
  - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
  - lib/features/lexicon/data/lexeme_providers.dart
