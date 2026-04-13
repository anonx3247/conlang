---
status: awaiting_human_verify
trigger: "Some paradigm cells show only [phonetics] with no romanization line above. Example: [vala] showing without 'vala' romanization line."
created: 2026-04-13T00:00:00Z
updated: 2026-04-13T00:01:00Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: CONFIRMED — showRom = romText != phonemic suppresses romanization when rom output is identical to phonemic input (e.g. simple latin phonemes like "vala" → romanizes to "vala")
test: Read paradigm_table_widget.dart — found the exact condition on line 841 and 916
expecting: Fix by checking whether romanization mappings exist rather than whether output differs
next_action: Apply fix in _FilledCell and _UnmarkedCell: watch romanizationMappingsProvider and show rom whenever mappings are non-empty AND romText is non-empty

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: Every paradigm cell should show romanization above phonetic form (e.g., "vala" above "[vala]")
actual: Some cells show only [phonetics] with no romanization line
errors: No errors — romanization line just missing
reproduction: Open paradigm viewer, look for cells that only show bracketed phonetic form without romanization above
started: Pre-existing bug discovered during UAT

## Eliminated
<!-- APPEND only - prevents re-investigating -->

- hypothesis: inflected form generation not producing phonemic value
  evidence: ParadigmFilled.phonemic defaults to form if not set (line 32 of paradigm_cell.dart: phonemic = phonemic ?? form), and _FilledCell correctly receives it via pattern match on line 756. The phonemic value exists.
  timestamp: 2026-04-13T00:01:00Z

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-04-13T00:01:00Z
  checked: paradigm_table_widget.dart lines 839-841 (_FilledCell.build)
  found: showRom = romText.isNotEmpty && romText != phonemic — suppresses rom when romanize(phonemic) == phonemic
  implication: Any inflected form whose phonemic symbols map 1:1 to identical latin characters (e.g. "vala") will have romText == phonemic and showRom = false

- timestamp: 2026-04-13T00:01:00Z
  checked: romanization_providers.dart lines 98-109 (romanizeProvider)
  found: Returns identity function when mappings null/empty. When mappings exist, calls smartRomanize. There is NO way to distinguish "no mappings" from "mappings that produce same output" just from romText alone.
  implication: Need to also check whether mappings are configured to set showRom correctly

- timestamp: 2026-04-13T00:01:00Z
  checked: paradigm_table_widget.dart line 916 (_UnmarkedCell.build)
  found: Same showRom = romText.isNotEmpty && romText != root condition, same bug
  implication: Fix must be applied to both _FilledCell and _UnmarkedCell

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: In _FilledCell and _UnmarkedCell, showRom = romText != phonemic. This suppresses the romanization line when romanize(phonemic) == phonemic — which happens whenever the phonemes map to identical latin characters (very common for simple alphabets). The comment "avoids double rendering when no romanization mapping is configured" describes a correct secondary effect but uses the wrong test: romText != phonemic conflates "no mappings" with "mappings that yield identity output".
fix: Watch romanizationMappingsProvider in both widgets. showRom should be: romText.isNotEmpty && (romMappingsConfigured || romText != phonemic) — where romMappingsConfigured = mappings exist and are non-empty. This ensures: (a) when mappings configured, always show rom line; (b) when no mappings, suppress to avoid double-rendering identical text.
verification:
files_changed:
  - lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart
