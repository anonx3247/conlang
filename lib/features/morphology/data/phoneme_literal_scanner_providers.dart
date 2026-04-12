import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../phonology/data/phonotactic_providers.dart';
import '../domain/morphology_dsl.dart';
import '../domain/phoneme_literal_scanner.dart';
import 'morphology_providers.dart';

/// Plan 04-16 Task 4 (WARN-5 revision) — cached per-rule scanner
/// results. Provides a reactive list of [PhonemeViolation]s for a
/// given rule id, reading the rule source + inventory and running
/// the scanner once per change.
///
/// The provider is a `Provider.family<List<PhonemeViolation>, int>`
/// keyed on ruleId. Riverpod caches the result until:
///   (a) the inventory changes (via `ref.watch(phonemeInventoryProvider)`)
///   (b) the rules stream emits a new list (via
///       `ref.watch(rulesByKindProvider(inflectional))`) and the
///       specific rule's source or name changes.
///
/// Consumers in the rules list read this provider per-row instead of
/// invoking the scanner inline in the build loop, eliminating the
/// per-build stutter on projects with many rules.
///
/// NOTE: this provider is scoped to **inflectional** rules because
/// that's the surface the rules-list warning icon renders on
/// (derivational rules render through a different branch in
/// rules_page.dart). If a derivational surface ever needs the same
/// scanner feedback, lift the lookup to the all-rules stream.
final phonemeViolationsForRuleProvider =
    Provider.family<List<PhonemeViolation>, int>((ref, ruleId) {
  final inventory = ref.watch(phonemeInventoryProvider);
  // Read all inflectional rules and find the target by id. Riverpod
  // recomputes this provider whenever the underlying stream emits.
  final rulesAsync = ref.watch(morphologicalRuleListProvider);
  final rules = rulesAsync.asData?.value ?? const [];
  final matches = rules.where((r) => r.id == ruleId);
  if (matches.isEmpty) return const [];
  final rule = matches.first;
  final parsed = parseMorphDsl(rule.source, id: rule.id, name: rule.name);
  return const PhonemeLiteralScanner().scan(parsed, inventory);
});
