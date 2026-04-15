---
phase: 12
slug: writing-scratchpad
status: approved
design_system: Flutter Material 3
created: 2026-04-15
---

# Phase 12 — UI Design Contract: Writing Scratchpad

> Visual and interaction contract for the Writing Scratchpad feature.
> Flutter desktop app — Material 3, dark/light themes, seed-color `#5B8DEF` (dark) / `#1A56DB` (light).

---

## Design System

| Property | Value |
|----------|-------|
| Framework | Flutter Material 3 |
| Component library | Flutter built-ins (no third-party UI lib) |
| Icon library | `Icons.*` (Material Icons) |
| Seed color (dark) | `#5B8DEF` — professional blue |
| Seed color (light) | `#1A56DB` |
| Theme | `useMaterial3: true`, `ColorScheme.fromSeed()` |

---

## Spacing Scale

Follows existing app conventions (logical pixels):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Icon-label gaps, tight insets |
| sm | 8px | Compact padding, between tier rows |
| md | 16px | Default section padding |
| lg | 24px | Panel padding, section gaps |
| xl | 32px | Major layout gaps |

Exceptions: Interlinear tier row gap is 2px (tighter than xs — tiers are semantically linked).

---

## Typography

Follows existing app conventions (`theme.textTheme.*`):

| Role | Style | Size | Weight | Usage |
|------|-------|------|--------|-------|
| Original text (tier 1) | `bodyMedium` | 14px | w400 | User input line — the phrase as typed |
| Gloss cells (tier 2) | `labelSmall` | 11px | w500 | Leipzig gloss abbreviations per token |
| IPA tier (tier 3, optional) | `labelSmall` | 11px | w400 italic | IPA transcription line |
| Free translation (tier 4) | `bodyMedium` | 13px | w400 italic | Full-phrase free translation |
| Phrase list item — text | `bodyMedium` | 13px | w400 | Phrase preview in sidebar |
| Phrase list item — meta | `labelSmall` | 11px | w400 | Timestamp below preview |
| Section header | `bodyMedium` | 13px | w600 | "Scratchpad" section labels |

---

## Color

All values reference the active `ColorScheme` — never hardcoded hex in widget code.

| Role | Token | Usage |
|------|-------|-------|
| Background | `colorScheme.surface` | Right-panel editor background |
| Sidebar | `colorScheme.surfaceContainer` | Left phrase-list sidebar background |
| Selected phrase | `colorScheme.primaryContainer` | Active phrase highlight in sidebar |
| Input cursor | `colorScheme.primary` | TextField cursor color |
| Tier separator line | `colorScheme.outlineVariant` | Thin horizontal rule between interlinear tiers |
| Unknown token highlight | `Colors.amber.shade700` (dark) / `Colors.amber.shade300` (light) | Background tint on unknown words in original line |
| Phonotactic violation | `colorScheme.error` with `TextDecoration.underline` | Red underline on violating token in original line |
| Gloss "?" cell | `colorScheme.onSurface.withValues(alpha: 0.4)` | Muted "?" in gloss tier for unknown tokens |
| Free translation prompt | `colorScheme.onSurface.withValues(alpha: 0.3)` | Placeholder text "Add free translation…" |
| IPA toggle button (active) | `colorScheme.primary` | When IPA tier is shown |
| IPA toggle button (inactive) | `colorScheme.onSurface.withValues(alpha: 0.5)` | When IPA tier is hidden |

Accent (`colorScheme.primary`) reserved for: active tab indicator, selected phrase, IPA toggle active state, "New phrase" button icon.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Tab label | `Scratchpad` |
| Tab icon | `Icons.edit_note` |
| New phrase button | `New Phrase` |
| Empty state heading | `No phrases yet` |
| Empty state body | `Click "New Phrase" to start writing in your language.` |
| Unknown gloss cell | `?` |
| IPA toggle tooltip | `Toggle IPA transcription` |
| Free translation placeholder | `Add free translation…` |
| Phrase list empty meta | `—` (em-dash for phrases with no free translation preview) |
| Auto-save indicator | None visible — auto-save is silent |
| Phonotactic error tooltip | `Phonotactic violation` |
| Unknown word tooltip | `Unknown — not found in lexicon` |

---

## Layout Contract

### Top-level Shell

- `AppShell._tabs` gains a 4th entry: `_TabItem(label: 'Scratchpad', icon: Icons.edit_note, enabled: true)`
- Tab appears at index 3, after Lexicon (index 2)
- `GoRouter` gains a 4th `StatefulShellBranch` for `/scratchpad`

### Scratchpad Page Layout

```
┌─────────────────────────────────────────────────────────┐
│  [Phonology] [Grammar] [Lexicon] [Scratchpad ●]         │  ← AppShell tab bar (48px)
├──────────────┬──────────────────────────────────────────┤
│  Phrases     │  [New Phrase ＋]          [IPA ⟨ ⟩]      │  ← toolbar (40px)
│  ──────────  ├──────────────────────────────────────────┤
│  • Phrase 1  │  ┌─────────────────────────────────────┐ │
│    preview   │  │  TEXT INPUT (tier 1)                 │ │
│  • Phrase 2  │  │  kaso  nele  ven                     │ │
│    preview   │  ├─────────────────────────────────────┤ │
│              │  │  GLOSS (tier 2)                      │ │
│              │  │  stone  ?   go.PST                   │ │
│              │  ├─────────────────────────────────────┤ │
│              │  │  IPA (tier 3, optional)              │ │
│              │  │  /kaso/ /nele/ /ven/                  │ │
│              │  ├─────────────────────────────────────┤ │
│              │  │  Free translation (tier 4, inline)  │ │
│              │  │  The stone did not go.               │ │
│              │  └─────────────────────────────────────┘ │
└──────────────┴──────────────────────────────────────────┘
```

- Sidebar width: 200px fixed (no user resize in Phase 12)
- Sidebar shows phrase list ordered newest-first; each item: preview text (truncated to 1 line) + relative timestamp
- Right panel: top toolbar + interlinear block below, padded `md` (16px) on all sides

### Interlinear Block — Token Layout

Each phrase is displayed as a single `InterlinearBlock` widget:
- Tier 1 (original): `RichText` — tokens as `TextSpan` with per-token background/underline decoration
- Tier 2 (gloss): `Row` of `Text` cells — one cell per token, same horizontal position as tier 1 tokens
- Tier 3 (IPA, optional): `Row` of `Text` cells — same alignment, italic
- Tier 4 (free translation): `TextField` inline — single editable line per phrase

Token alignment: use `IntrinsicWidth` or measure to ensure gloss cell width matches token width in tier 1. Minimum token cell width: 24px.

---

## Interaction Contract

| Interaction | Behavior |
|-------------|----------|
| Type in phrase input | Re-parse after 300ms debounce — update all tiers live |
| Click phrase in sidebar | Load phrase into right panel |
| Click "New Phrase" | Create new phrase record, focus input field |
| Toggle IPA button | Show/hide IPA tier for current phrase (per-phrase toggle) |
| Click free translation field | Enter edit mode inline |
| Leave free translation field | Auto-save with 1-second debounce |
| Edit original text | Auto-save with 1-second debounce after parse |
| Hover unknown token | Show tooltip "Unknown — not found in lexicon" |
| Hover red-underlined token | Show tooltip "Phonotactic violation" |

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS — all copy strings defined, empty/error states covered
- [x] Dimension 2 Visuals: PASS — layout diagram, widget roles, tier structure specified
- [x] Dimension 3 Color: PASS — all color roles reference ColorScheme tokens, no hardcoded hex in widget code (amber constants are acceptable for semantic error colors)
- [x] Dimension 4 Typography: PASS — all text roles mapped to textTheme styles with size/weight
- [x] Dimension 5 Spacing: PASS — scale defined, interlinear 2px exception documented
- [x] Dimension 6 Registry Safety: PASS — Flutter built-ins only, no third-party UI packages

**Approval:** approved 2026-04-15
