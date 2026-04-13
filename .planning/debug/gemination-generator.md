---
status: awaiting_human_verify
trigger: "Word generator still creates geminates despite 'No gemination: Everywhere' constraint being active"
created: 2026-04-13T00:00:00Z
updated: 2026-04-13T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED — WordGeneratorPanel calls generateWords without passing geminationConstraints
test: N/A — root cause confirmed by direct code inspection
expecting: N/A
next_action: Add geminationConstraints parameter to generateWords call in word_generator_panel.dart

## Symptoms

expected: When "No gemination: Everywhere" constraint is active, generated words should never contain geminate consonants
actual: Words like "sammimpim" (mm) and "ossfan" (ss) are generated with geminates
errors: No errors — constraint just not being enforced
reproduction: Set "No gemination: Everywhere" constraint, generate words, observe geminates in output
started: Pre-existing bug discovered during Phase 8 UAT

## Eliminated

- hypothesis: Constraint check compares romanized forms instead of IPA phonemes
  evidence: _checkGemination in word_generator.dart compares IPA symbols from the tokenizer against the consonant set — correct
  timestamp: 2026-04-13

- hypothesis: GeminationConstraint is stored with wrong type in DB
  evidence: phonotactic_dao.dart insertGeminationConstraint correctly writes type='gemination'; parsedGeminationConstraintsProvider correctly filters on type='gemination'
  timestamp: 2026-04-13

## Evidence

- timestamp: 2026-04-13
  checked: word_generator_panel.dart lines 63-70
  found: gen.generateWords() called with constraints: but WITHOUT geminationConstraints: parameter — defaults to const []
  implication: The entire gemination enforcement path is bypassed; _checkGemination is never called for the word panel

- timestamp: 2026-04-13
  checked: word_generator.dart generateWords signature
  found: geminationConstraints parameter has default value const [] — silently ignored when not passed
  implication: No error, constraint is just never applied

- timestamp: 2026-04-13
  checked: phonotactic_providers.dart generatedWordsProvider
  found: A second provider ALSO calls generateWords without sequence constraints (passes geminationConstraints but not constraints)
  implication: Both callers are partially broken; the panel is the primary display path

## Resolution

root_cause: word_generator_panel.dart creates its own WordGenerator and calls generateWords() without passing geminationConstraints. The parameter defaults to const [], so the gemination check is never invoked during generation. The constraint data flows correctly through parsedGeminationConstraintsProvider but that provider was never watched by the panel widget.
fix: |
  1. Added `ref.watch(parsedGeminationConstraintsProvider)` in WordGeneratorPanel.build() to load active gemination constraints.
  2. Passed `geminationConstraints:` to gen.generateWords() so the generator rejects words containing geminates during generation.
  3. Also passed `geminationConstraints:` to gen.validateWord() in the post-hoc violation highlighting loop, so geminates introduced by rewrite rules are underlined in the phonetic display.
verification:
files_changed:
  - lib/features/phonology/presentation/sound_rules/word_generator_panel.dart
