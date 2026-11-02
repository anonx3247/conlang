---
title: "Documentation Generation — Illustrated Grammar Sketch"
trigger_condition: "Construction rules and inflection rules are well-populated with description fields; user wants to produce a shareable grammar reference"
planted_date: "2026-04-14"
---

## Idea

Allow the user to generate an illustrated grammar sketch directly from the rules they've defined.

## Core mechanic

1. For each inflection rule and construction rule, user selects **example words** that best illustrate the rule
2. The app generates a structured grammar document:
   - Rule name + description field content
   - Example words shown in all their derived/inflected forms
   - Constructions shown with slot filling examples
3. Output format TBD (PDF, Markdown, in-app view)

## Value

The `description` field on rules (added in 10.1) is the foundation — users who document their rules as they build get grammar documentation for free.

## Dependencies
- `description: String` on InflectionRule and ConstructionRule (Phase 10.1)
- Paradigm viewer showing all forms per word
- Construction panel in word detail view
