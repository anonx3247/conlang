import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lexicon/data/lexeme_providers.dart';
import '../../morphology/data/morphology_providers.dart';
import '../../phonology/data/phonotactic_providers.dart';
import '../../phonology/data/romanization_providers.dart';
import '../../phonology/domain/word_generator.dart' show Violation;
import '../domain/standard_form_branch.dart';
import '../domain/standard_form_matcher.dart';
import '../domain/dimension_level.dart';
import '../domain/pos_resolver.dart';
import 'grammar_providers.dart';
import 'intrinsic_levels_codec.dart';

/// D-99 -- 04-17. Emits soft-warning standard-form violations for a
/// lexeme against every applicable (intrinsic dim, level) pattern.
/// Rendered via ViolationText on dictionary list, word detail, paradigm
/// viewer base form, swadesh list, and thesaurus/inspiration surfaces.
/// Never blocks save.
///
/// UI surfaces watch this and merge into the combined violation list
/// alongside phonotactic violations before passing to ViolationText.
final standardFormViolationsProvider =
    FutureProvider.family<List<Violation>, int>((ref, lexemeId) async {
  final lexemeAsync = ref.watch(lexemeByIdProvider(lexemeId));
  final lexeme = lexemeAsync.asData?.value;
  if (lexeme == null) return const [];
  if (lexeme.isPhonologicalException) return const [];

  // Resolve POS for the lexeme.
  final posListAsync = ref.watch(posListProvider);
  final posList = posListAsync.asData?.value ?? const [];
  final pos = posForLexeme(lexeme, posList);
  if (pos == null) return const [];

  final dimsAsync = ref.watch(dimensionsForPosProvider(pos.id));
  final dims = dimsAsync.asData?.value ?? const [];
  final intrinsicDims = dims.where((d) => d.intrinsic).toList();
  if (intrinsicDims.isEmpty) return const [];

  final decoded = IntrinsicLevelsCodec.decode(lexeme.intrinsicLevelsJson);
  final dao = ref.read(standardFormPatternDaoProvider);
  if (dao == null) return const [];

  final inventory = ref.watch(phonemeInventoryProvider);
  final romanize = ref.watch(romanizeProvider);
  const matcher = StandardFormMatcher();
  final violations = <Violation>[];

  for (final dim in intrinsicDims) {
    final levelId = decoded[dim.id];
    if (levelId == null) continue;
    final branches = await dao.getPattern(dim.id, levelId);
    if (branches == null || branches.isEmpty) continue;
    final romForm = romanize(lexeme.ipa);
    if (matcher.matches(romForm, branches, inventory)) continue;
    // Violation: word does not match the standard form pattern.
    final levels = decodeLevelsJson(dim.levelsJson);
    final level = levels.where((l) => l.id == levelId).firstOrNull;
    final levelName = level?.name ?? 'unknown';
    final desc = _describeBranches(dim.name, levelName, branches);
    violations.add(Violation(
      position: 0,
      length: romForm.length,
      ruleDescription: desc,
    ));
  }
  return violations;
});

// INFO-5 revision: English hard-coded strings below (level name, dim name,
// "starts with" / "ends with" / "contains", " OR " separator, "should"
// verb). Future i18n pass will extract these to localized constants but
// keeping them inline here to avoid widening the revision scope.
// TODO(i18n): extract _describeBranches format strings to localization.
String _describeBranches(
    String dimName, String levelName, List<StandardFormBranch> branches) {
  final parts = branches.map((b) {
    final kindLabel = switch (b.kind) {
      BranchKind.startsWith => 'starts with',
      BranchKind.endsWith => 'ends with',
      BranchKind.contains => 'contains',
    };
    return '$kindLabel "${b.literal}"';
  }).join(' OR ');
  return '$levelName $dimName should $parts';
}
