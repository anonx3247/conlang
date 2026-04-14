---
captured: 2026-04-13
scope: project
tags: [grammar, paradigms, constructions, analytic]
---

# Analytic Paradigm Cells — Design Decisions

Paradigm cells gain a third realization strategy alongside morphological rules and manual exceptions: **"via construction"**.

## How it works

When editing a paradigm cell (in the paradigm viewer), the user can pick a construction from the existing constructions list. The construction's "word slot" (the open-class POS slot) resolves to a chosen form of the word being conjugated — not necessarily the base form.

The word slot becomes a dropdown with options:
- Base/uninflected form
- Any existing realized paradigm form (e.g. imperfective, past, etc.)

## Key example

- **conditional** = AUX:COND + \[imperfective form of this verb\]
- **future** = AUX:FUT + \[present/base form\]

The cell renders a real example using the actual particle from the lexicon + the resolved form — consistent with the construction preview behavior from Phase 10.

## Ordering concern

If cell A references cell B as its input form, cell B must be resolvable first. Circular dependencies between cells would need to be detected and flagged (render as unresolvable rather than infinite loop).

## Phase

Implemented in Phase 10.1 — inserted before Phase 11 (Lexicon Etymology Chain).
