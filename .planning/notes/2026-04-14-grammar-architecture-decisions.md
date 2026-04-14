---
date: "2026-04-14 14:00"
promoted: false
---

## Grammar Architecture Decisions — Explore Session 2026-04-14

### Construction slots

- A slot targets either **(a) a POS** (any word of that POS fills the slot, open variable) or **(b) a specific lexeme** (fixed particle, always this word)
- Each slot additionally specifies a declension: either an **existing inflection rule** from that word's paradigm, or a **new private declension** inline to the construction
- The private declension handles portmanteau cases (e.g. V+-ak in a FUT construction) — it is never visible in the Inflections/Transformations tab, only in the construction rule editor
- Construction slot search UI: when picking a specific lexeme, user can filter by POS or `#tag` to narrow the list (same UX as the dictionary search)

### Paradigm grid — strictly morphological

- The paradigm grid shows **only morphologically realized forms** — no construction-filled cells
- ParadigmConstructionFilled architecture (10.1 plan) is superseded by this decision
- Constructions panel lives in the **word detail view**, alongside derivations

### Description field

- Both `InflectionRule` and `ConstructionRule` get a `description: String` free-text field
- Surfaced when clicking a paradigm cell (shows the rule's description in a tooltip/detail view)
- Will feed a future documentation generation phase

### Lexeme metadata model

- `role: String?` — individual grammatical identity label, e.g. `"FUT"`, `"1P"`, `"NEG"`. One word, one role. Replaces/clarifies the old `particleAbbreviation` concept. Applies to ALL lexemes (not just closed-class).
- `tags: List<String>` — free-form hashtag labels, e.g. `#pronoun`, `#auxiliary`, `#weekday`. Multiple per word. Created on the fly. Pure organizational filtering — no structural or glossing implications.
- `isClosedClass: bool` — unchanged; still determines particle screen membership
- Gloss composing (AUX.FUT.) concept deprioritized — role/tags are documentary/filter only

### Navigation structure

- "Transformations" tab replaces the separate "Inflections" and "Constructions" tabs
- Constructions section lives inside the word detail view panel (alongside derivations)
