---
title: "Phase 10.2 — Lexeme Role & Tags Schema"
trigger_condition: "Phase 10.1 UAT gaps closed and verified"
planted_date: "2026-04-14"
---

## Idea

Add `role` and `tags` to the lexeme model, and rework the particle screen to use them.

## Scope

### Schema changes
- Rename/repurpose `glossTag: String?` → `role: String?` on `Lexeme` — individual grammatical identity label (e.g. "FUT", "1P", "NEG")
- Add `tags: List<String>` (stored as JSON array or normalized table) on `Lexeme` — free-form hashtag labels (e.g. #pronoun, #auxiliary, #weekday)
- Migration: map existing `glossTag` values to `role`

### UI — Particle / Closed-Class screen
- Group words by `role` and/or `#tag`
- Coverage view: for a given tag group, show which roles are present (e.g. #pronoun — do I have 1P, 2P, 3P?)
- Tag filter in the main lexicon list

### Lexeme editor
- `role` text field (replaces particle abbreviation field)
- `tags` input with chip/pill UI — type `#` to add, click to remove
- Apply to all lexemes, not just closed-class

## Not in scope
- Automatic gloss composing from role/tags (deferred or dropped)
- Construction slot targeting by tag (slots target POS or specific lexeme, not tags)
