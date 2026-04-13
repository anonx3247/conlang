---
captured: 2026-04-13T00:30:00
scope: project
tags: [uat, ui, lexicon, paradigm, macos, project-management]
---

## UAT Feedback — Post Phase 7

### Abbreviation display context rules
1. Use CAPITALS for rule-list UI and paradigm viewer titles (e.g. "NOM", "SG")
2. Use lowercase for words in the lexicon list (e.g. "n.", "adj.")
3. Lexicon word list: show "word (n.)" inline — do NOT show "Noun" on a new line under the word
4. Derived words in lexicon: show "n." without [ ] brackets (currently shows "[n.]")
5. Derived words: if automatically derived, do NOT show the "meaning" text field (only show for manually entered words)

### Paradigm viewer
6. There's a visible horizontal line/divider in the paradigm viewer that needs to be removed (see screenshot)

### Resizable panels
7. ResizableDivider cursor shows resize affordance but panels don't actually resize in practice — constraints prevent it. This is app-wide. The word detail panel is too narrow as a result.

### Lexicon table
8. One word is always selected (checkbox ticked) for no visible reason on load
9. Selection checkboxes should only appear when Anki export is active, not all the time

### macOS native menu
10. Move the "File" menu from in-app to the macOS global menu bar (native platform menu)

### Project management
11. Add "Rename project" option
12. Add "Save as..." option
13. Projects should be storable as .conlang files (SQLite DB with custom extension) in user-chosen locations
14. User should pick where to save the project folder/file
