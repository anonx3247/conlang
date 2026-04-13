# Conlang Workbench

## What This Is

A Flutter desktop application for creating and managing constructed languages (conlangs). It provides an integrated environment for defining phonology, building lexicons, designing grammar systems, documenting culture, and writing/analyzing text in your conlang. Each conlang lives in its own project with a SQLite database. An AI agent (via MCP tools) acts as both a linguistics tutor and active co-creator throughout the workflow.

## Core Value

A powerful, flexible morphology engine that handles the full spectrum of language types — agglutinative, Semitic triconsonantal, analytic, fusional — through a readable pattern mini-language, so any word transformation rule can be expressed and applied consistently across the entire tool.

## Requirements

### Validated

- [x] Phonotactic violation highlighting (red) on words throughout the tool, allowing exceptions (e.g. loanwords) — Validated in Phase 3: Lexicon
- [x] Lexicon tab: root dictionary + derived word dictionary with meanings and etymology — Validated in Phase 3: Lexicon
- [x] Integration with Swadesh list and Conlanger's Thesaurus for word creation guidance — Validated in Phase 3: Lexicon
- [x] Anki card export from lexicon — Validated in Phase 3: Lexicon
- [x] Predefined natural classes (stops, nasals, fricatives, liquids, rhotics, obstruents, sonorants, approximants, affricates) usable in the phonotactic DSL with single-letter aliases (S/N/F/L/R) and user-class precedence — Validated in Phase 3.2: Phonology Enhancements
- [x] Contextual allophone viewer in the phoneme edit dialog that surfaces realizations from existing rewrite rules — Validated in Phase 3.2: Phonology Enhancements
- [x] Phonological rewrite rules produce phonetic transcription only, not romanization — romanization is always derived from the phonemic (pre-rewrite) form across all preview panels — Validated in Phase 3.2: Phonology Enhancements

### Active

- [ ] Multi-project management with per-project SQLite databases
- [ ] Phonology tab: define phoneme inventory, phonotactics rules, Latin transcription mappings, and phonological rules (e.g. a + nasal -> ã)
- [ ] IPA reference chart with clickable audio playback (real recordings from Wikipedia IPA charts)
- [ ] IPA keyboard for phonetic text input
- [ ] Word generator based on phonotactics constraints
- [ ] Phonotactic violation highlighting (red) on words throughout the tool, allowing exceptions (e.g. loanwords)
- [ ] Lexicon tab: root dictionary + derived word dictionary with meanings and etymology
- [ ] Morphological pattern mini-language for defining word derivation rules (suffixes, prefixes, infixes, vowel replacements, triconsonantal root templates, etc.)
- [ ] Automatic etymology suggestions (e.g. detecting compound words)
- [ ] Integration with Swadesh list and Conlanger's Thesaurus (fiatlingua.org PDF) for word creation guidance
- [ ] Anki card export from lexicon
- [ ] Grammar tab: parts of speech definitions, declension/conjugation rule systems, word order rules
- [ ] Flexible modality expression: choose morphological vs analytic (aux verbs/particles) strategies per grammatical feature
- [ ] Support for language typology choices (ergative/accusative, deontic modality, etc.)
- [ ] Declension/conjugation chart generation for any word, with per-word exception support
- [ ] Culture tab: wiki-style documentation with Markdown format and internal linking
- [ ] Writing scratchpad: write phrases and get automatic parsing (tokenize -> morphological analysis -> interlinear gloss)
- [ ] Phonetic reading generation from phonology rules for written phrases
- [ ] TTS synthesis for reading conlang text aloud
- [ ] Error highlighting in the writing scratchpad (unknown words, rule violations)
- [ ] Built-in searchable glossary of linguistic terminology
- [ ] AI agent (MCP-powered) as linguistics tutor and co-creator with access to all project data

### Out of Scope

- Mobile app — desktop-first, Flutter allows future expansion
- Collaborative/multi-user editing — single user tool
- Online hosting or cloud sync — all data stays local
- Natural language translation (full machine translation between conlang and natlangs)

## Context

- User is an experienced conlanger who works on multiple languages casually (pop-in sessions)
- The morphology system is the centerpiece — it must handle the full typological spectrum, not just concatenative morphology
- The pattern mini-language for morphological rules should be "like regex but clearer and more language-based"
- IPA audio for the reference chart should use real recordings (Wikipedia); TTS synthesis is for reading conlang text aloud
- The tool should attempt full parsing of written phrases using whatever rules and vocabulary exist, showing unknowns as gaps
- The Conlanger's Thesaurus PDF (fiatlingua.org) is a key reference resource for semantic coverage
- Each project is a self-contained folder with its own database

## Constraints

- **Tech stack**: Flutter desktop application
- **Storage**: SQLite per project
- **AI integration**: MCP tools exposing all project data/docs to an AI agent
- **Audio**: Real IPA recordings (sourced from Wikipedia), TTS for conlang speech synthesis
- **Offline-first**: Must work fully offline (AI features may require connection)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter for desktop | User preference; single codebase, native feel | Validated v1.0 |
| SQLite per project | Better querying for large lexicons vs flat files | Validated v1.0 — .conlang file format |
| Morphology pattern mini-language | Regex-like but readable; needed for diverse language types | Validated v1.0 |
| Real IPA audio + TTS split | Authentic sounds for reference, synthesis for conlang speech | Validated v1.0 (audio only, TTS deferred) |
| AI as tutor + co-creator | Dual role: explain linguistics concepts AND actively help build the language | Deferred to v2 |

## Current State

**v1.0 shipped** — 11 phases, 79 plans, 9 features complete:
- Phonology: inventory, IPA chart, keyboard, phonotactics, sound rules, natural classes, gemination
- Morphology: pattern DSL engine (agglutinative, Semitic, fusional, analytic)
- Lexicon: dictionary, derivations, Swadesh list, thesaurus, Anki export
- Grammar: POS with N-dimensional features, inflectional rules, paradigm viewer, typology
- Reference: 162-term linguistic glossary with examples
- Platform: macOS native menu, .conlang file format, welcome screen, custom app icon

Culture Wiki retired to branch for v2 rework.

---
*Last updated: 2026-04-13 after v1.0 milestone completion*
