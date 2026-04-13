---
status: awaiting_human_verify
trigger: "Unfilled paradigm cells show a broken character/missing glyph icon instead of empty or a dash/placeholder"
created: 2026-04-13T00:00:00Z
updated: 2026-04-13T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED — dark theme sets fontFamily: 'monospace' globally; em dash U+2014 inherits that font and renders as broken glyph because monospace fonts lack em dash
test: Applied fix — fontFamily: null / fontFamilyFallback: null on the em dash Text style
expecting: Em dash now uses system default font which includes U+2014
next_action: Human verification — run app and check paradigm viewer with unfilled cells

## Symptoms

expected: Empty paradigm cells should show empty space or a dash/placeholder character
actual: Cells show a broken character (missing glyph icon — typically a box with question mark or similar)
errors: No errors — just visual display issue
reproduction: Open paradigm viewer for a paradigm that has unfilled cells (not all inflection forms generated)
started: Pre-existing bug discovered during UAT

## Eliminated

- hypothesis: Unicode character unsupported by Flutter's default system font
  evidence: Flutter's default system font (SF Pro, Roboto, etc.) always includes em dash; the issue is the theme-level fontFamily override
  timestamp: 2026-04-13

## Evidence

- timestamp: 2026-04-13
  checked: paradigm_table_widget.dart _uncoveredCell() method
  found: em dash '—' (U+2014) rendered via theme.textTheme.bodyMedium with no fontFamily override
  implication: inherits theme-level fontFamily

- timestamp: 2026-04-13
  checked: lib/app.dart _buildDarkTheme()
  found: fontFamily: 'monospace' set on dark ThemeData at line 297; light theme has no fontFamily override
  implication: every Text widget in dark mode inherits 'monospace'; monospace fonts (Menlo, Courier New, DejaVu) frequently lack U+2014 EM DASH, producing broken glyph box

- timestamp: 2026-04-13
  checked: themeMode in ConlangApp
  found: themeMode: ThemeMode.dark (line 167) — app always starts in dark mode
  implication: bug affects all users by default

## Resolution

root_cause: Dark theme sets fontFamily 'monospace' globally (lib/app.dart line 297). The _uncoveredCell em dash inherits this font family. Monospace fonts commonly lack U+2014 EM DASH, rendering a broken-glyph placeholder box instead.
fix: Added fontFamily: null and fontFamilyFallback: null to the em dash Text.style copyWith call in _uncoveredCell, forcing fallback to the system default font which includes the em dash.
verification:
files_changed:
  - lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart
