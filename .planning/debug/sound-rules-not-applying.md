---
status: awaiting_human_verify
trigger: "Rewrite rule 'ei → ej' exists and is active, but word 'theidin' displays as θeidin (not θejdin). The rewrite rule isn't being applied to this word's phonetic form."
created: 2026-04-13T00:00:00Z
updated: 2026-04-13T00:00:00Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: CONFIRMED — _ipaCharParser uses .plus() (greedy multi-char), so "ei" is parsed as ONE Slot(literalPhoneme: "ei"). But _tokenize splits the word using the phoneme inventory, returning separate "e" and "i" tokens. The single slot "ei" never matches "e" or "i" individually. Multi-char rule inputs (like "ei") are never tokenized as a unit because they're not in the inventory.
test: code read of phonotactic_dsl.dart _ipaCharParser, word_generator.dart _tokenize and _slotMatches
expecting: fix applied — awaiting human verification
next_action: user confirms θejdin appears in lexicon for word "theidin"

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: Word "theidin" should display phonetic form θejdin (with ei→ej rule applied)
actual: Word "theidin" displays as θeidin (rule not applied)
errors: No errors — rule just not being applied
reproduction: Create a rewrite rule "ei → ej", have a word "theidin" in the lexicon, check its phonetic display
started: Pre-existing bug discovered during UAT

## Eliminated
<!-- APPEND only - prevents re-investigating -->

- hypothesis: Rule ordering issue
  evidence: The rule engine applies all rules in order; code confirmed rules are applied. The issue is earlier — in tokenization, before matching even begins.
  timestamp: 2026-04-13

- hypothesis: Rule parsing produces wrong output type
  evidence: parseRewriteRule correctly parses the rule; the output "ej" is stored as a raw string. Parsing is not the problem.
  timestamp: 2026-04-13

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-04-13
  checked: lib/features/phonology/domain/phonotactic_dsl.dart _ipaCharParser (line 154-155)
  found: _ipaCharParser = pattern('^\\[\\]() >\n\r-#_').plus().flatten() — the .plus() greedily matches one or more non-structural chars as a SINGLE token
  implication: "ei" input to parseRewriteRule produces ONE Slot(literalPhoneme: "ei"), not two separate slots

- timestamp: 2026-04-13
  checked: lib/features/phonology/domain/word_generator.dart _tokenize (line 412-444)
  found: Tokenizer builds phoneme list from inventory only. Since "ei" is not a single phoneme in the inventory, "theidin" tokenizes as ["θ","e","i","d","i","n"]
  implication: Rule input slot Slot("ei") can never match the token "e" or "i" — _slotMatches checks symbol == slot.literalPhoneme → "e" == "ei" → false

- timestamp: 2026-04-13
  checked: lib/features/phonology/domain/word_generator.dart _applyOneRule
  found: Tokenizes with inventory only, then tries _slotsMatch — mismatch guaranteed when rule uses multi-char literal clusters not present in inventory
  implication: Any rule with a multi-char literal like "ei", "ou", "ts" that isn't a single inventory phoneme will silently fail

- timestamp: 2026-04-13
  checked: _ipaCharParser design intent vs _tokenize design
  found: .plus() exists to handle genuine multi-char IPA phonemes like pʰ, aː, tʃ that ARE in the inventory as single symbols. For these, the tokenizer also recognizes them as single tokens. The bug only affects multi-char strings that are COMBINATIONS of separate inventory phonemes (e.g. "ei" = e + i).
  implication: Fix must make _applyOneRule's tokenizer aware of multi-char literals from the rule itself, without changing _tokenize (which is used for constraint validation where this doesn't apply)

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: _ipaCharParser's .plus() greedily parses multi-char strings (like "ei") as a single Slot(literalPhoneme: "ei"). The tokenizer in _applyOneRule uses only the phoneme inventory, so "ei" (two separate phonemes) is never emitted as a single token, making _slotMatches always return false for the rule.

fix: Added _tokenizeWithExtras method to WordGenerator that includes the rule's own literal phonemes as additional known tokens. Modified _applyOneRule to collect multi-char literal strings from the rule's input/context slots and pass them to _tokenizeWithExtras, so "ei" is tokenized as a single unit when the rule expects it.

verification: dart analyze reports no issues on word_generator.dart

files_changed:
  - lib/features/phonology/domain/word_generator.dart
