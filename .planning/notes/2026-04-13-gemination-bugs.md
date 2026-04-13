---
captured: 2026-04-13T01:00:00
scope: project
tags: [bug, gemination, phonology]
---

## Gemination Bugs (Phase 8)

1. **Word generator still creates geminates despite "No gemination: Everywhere" constraint**
   - Example: "sammimpim" has "mm", "ossfan" has "ss" — both are geminates
   - Root cause: likely comparing romanized forms instead of IPA phonemes, or the constraint isn't being passed correctly to the generator

2. **Paradigm viewer shows gemination violation on romanization instead of phonetic representation**
   - Example: "acca" underlined in red — but gemination is a SOUND restriction, should check the phonetic form [ækk] not the romanized form
   - Important distinction: if 'anna' has a rule 'an -> ã', the romanized form has gemination (nn) but phonetically it doesn't (ãa) — so the violation check must operate on the phonetic (post-rewrite) form, not the romanized form
