import '../../phonology/domain/word_generator.dart';
import 'morphology_dsl.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

sealed class MorphResult {
  const MorphResult();
}

class MorphSuccess extends MorphResult {
  const MorphSuccess(this.form);
  final String form;
}

class MorphNoMatch extends MorphResult {
  const MorphNoMatch(this.reason);
  final String reason;
}

// ---------------------------------------------------------------------------
// IPA Tokenizer (adapted from WordGenerator._tokenize, returns just symbols)
// ---------------------------------------------------------------------------

/// Splits [word] into an ordered list of phoneme tokens using longest-match-first.
///
/// Adapted from [WordGenerator._tokenize]. Returns just the symbol strings
/// (no offset tuples) for morphological processing.
List<String> tokenizeIpa(String word, PhonemeInventory inventory) {
  if (word.isEmpty) return [];

  // Build sorted phoneme list (longest first) to handle multi-char IPA symbols.
  final allPhonemes = <String>[
    ...inventory.consonants,
    ...inventory.vowels,
    for (final list in inventory.naturalClasses.values) ...list,
  ];
  final sorted = allPhonemes.toSet().toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  final tokens = <String>[];
  var i = 0;
  while (i < word.length) {
    String? matched;
    for (final p in sorted) {
      if (word.startsWith(p, i)) {
        matched = p;
        break;
      }
    }
    if (matched != null) {
      tokens.add(matched);
      i += matched.length;
    } else {
      tokens.add(word[i]);
      i++;
    }
  }
  return tokens;
}

// ---------------------------------------------------------------------------
// Class resolver (adapted from WordGenerator._resolveClass)
// ---------------------------------------------------------------------------

/// Resolves a phoneme class reference to its list of IPA symbols.
///
/// Recognised shorthands: 'C' = all consonants, 'V' = all vowels.
/// Everything else is looked up in [inventory.naturalClasses] (case-insensitive).
List<String> resolvePhonemeClass(String classRef, PhonemeInventory inventory) {
  switch (classRef) {
    case 'C':
      return inventory.consonants;
    case 'V':
      return inventory.vowels;
    default:
      final key = classRef.toLowerCase();
      if (inventory.naturalClasses.containsKey(key)) {
        return inventory.naturalClasses[key]!;
      }
      if (inventory.naturalClasses.containsKey(classRef)) {
        return inventory.naturalClasses[classRef]!;
      }
      return [];
  }
}

// ---------------------------------------------------------------------------
// Condition matching
// ---------------------------------------------------------------------------

/// Returns true if [cond] matches [root] given [inventory].
///
/// A null condition = default branch = always matches.
/// Guards against empty roots.
bool conditionMatches(
  MorphCondition? cond,
  String root,
  PhonemeInventory inventory,
) {
  if (cond == null) return true; // default branch
  if (root.isEmpty) return false;

  final tokens = tokenizeIpa(root, inventory);
  if (tokens.isEmpty) return false;

  return switch (cond) {
    EndsWithLiteralCond(:final suffix) => root.endsWith(suffix),
    StartsWithLiteralCond(:final prefix) => root.startsWith(prefix),
    EndsWithClassCond(:final classRef) =>
      resolvePhonemeClass(classRef, inventory).contains(tokens.last),
    StartsWithClassCond(:final classRef) =>
      resolvePhonemeClass(classRef, inventory).contains(tokens.first),
  };
}

// ---------------------------------------------------------------------------
// Operation appliers
// ---------------------------------------------------------------------------

/// Appends [affix] to [root].
String applySuffix(String root, String affix) => root + affix;

/// Prepends [affix] to [root].
String applyPrefix(String root, String affix) => affix + root;

/// Inserts [affix] after the [position]-th consonant (1-based) in [root].
///
/// E.g., InfixOp(affix:'um', position:1) on 'talis' (consonants: t,l,s)
/// inserts 'um' after the 1st consonant 't' -> 'tumalis'.
String applyInfix(
  String root,
  String affix,
  int position,
  PhonemeInventory inventory,
) {
  final tokens = tokenizeIpa(root, inventory);
  var consonantCount = 0;
  var insertAfterIndex = -1;

  for (var i = 0; i < tokens.length; i++) {
    if (inventory.consonants.contains(tokens[i])) {
      consonantCount++;
      if (consonantCount == position) {
        insertAfterIndex = i;
        break;
      }
    }
  }

  if (insertAfterIndex < 0) {
    // Not enough consonants — append at end
    return root + affix;
  }

  final before = tokens.sublist(0, insertAfterIndex + 1).join();
  final after = tokens.sublist(insertAfterIndex + 1).join();
  return before + affix + after;
}

/// Replaces all occurrences of [from] token with [to] in [root].
String applyAblaut(
  String root,
  String from,
  String to,
  PhonemeInventory inventory,
) {
  final tokens = tokenizeIpa(root, inventory);
  return tokens.map((t) => t == from ? to : t).join();
}

/// Applies a Semitic-style template pattern to [root].
///
/// Extracts consonants from [root] and substitutes them into numbered slots
/// in [pattern]. Digits 1-9 are consonant slots; everything else is literal.
String applyTemplate(
  String root,
  String pattern,
  PhonemeInventory inventory,
) {
  final tokens = tokenizeIpa(root, inventory);
  final consonants =
      tokens.where((t) => inventory.consonants.contains(t)).toList();

  final buf = StringBuffer();
  for (final ch in pattern.split('')) {
    final digit = int.tryParse(ch);
    if (digit != null && digit >= 1 && digit <= consonants.length) {
      buf.write(consonants[digit - 1]);
    } else {
      buf.write(ch);
    }
  }
  return buf.toString();
}

/// Reduplicates part of [root] and prepends or appends it.
///
/// scope: 'full' = entire root, 'CV' = first consonant + following vowel,
///        'C' = first consonant only.
/// position: 'prefix' = prepend, 'suffix' = append.
String applyRedup(
  String root,
  String scope,
  String position,
  PhonemeInventory inventory,
) {
  final tokens = tokenizeIpa(root, inventory);
  if (tokens.isEmpty) return root;

  String redupPart;
  switch (scope) {
    case 'full':
      redupPart = root;
    case 'CV':
      // Take first consonant + immediately following vowel
      final buf = StringBuffer();
      var foundC = false;
      for (final t in tokens) {
        if (!foundC && inventory.consonants.contains(t)) {
          buf.write(t);
          foundC = true;
        } else if (foundC && inventory.vowels.contains(t)) {
          buf.write(t);
          break;
        }
      }
      redupPart = buf.toString();
      if (redupPart.isEmpty) redupPart = root; // fallback
    case 'C':
      // Take just the first consonant
      final firstC =
          tokens.firstWhere((t) => inventory.consonants.contains(t), orElse: () => '');
      redupPart = firstC;
    default:
      redupPart = root;
  }

  return switch (position) {
    'prefix' => redupPart + root,
    'suffix' => root + redupPart,
    _ => root,
  };
}

/// Returns the suppletive form, ignoring the root entirely.
String applySuppletive(String form) => form;

// ---------------------------------------------------------------------------
// Single-operation dispatcher
// ---------------------------------------------------------------------------

String _applyOp(MorphOperation op, String form, PhonemeInventory inventory) {
  return switch (op) {
    SuffixOp(:final affix) => applySuffix(form, affix),
    PrefixOp(:final affix) => applyPrefix(form, affix),
    InfixOp(:final affix, :final position) =>
      applyInfix(form, affix, position, inventory),
    AblautOp(:final from, :final to) => applyAblaut(form, from, to, inventory),
    TemplateOp(:final pattern) => applyTemplate(form, pattern, inventory),
    RedupOp(:final scope, :final position) =>
      applyRedup(form, scope, position, inventory),
    SuppleteOp(:final form) => applySuppletive(form),
    RemoveSuffixOp(:final suffix) =>
      form.endsWith(suffix)
          ? form.substring(0, form.length - suffix.length)
          : form,
  };
}

// ---------------------------------------------------------------------------
// Engine
// ---------------------------------------------------------------------------

class MorphologyEngine {
  const MorphologyEngine();

  /// Applies [rule] to [root] using [inventory] for phoneme class resolution.
  ///
  /// Iterates branches in order. The first branch whose condition matches wins.
  /// When [EndsWithLiteralCond] matches, the matched suffix is stripped from
  /// the working form before operations are applied.
  /// Returns [MorphNoMatch] if root is empty or no branch matches.
  MorphResult applyRule(
    MorphologicalRule rule,
    String root,
    PhonemeInventory inventory,
  ) {
    if (root.isEmpty) {
      return const MorphNoMatch('Root is empty');
    }

    for (final branch in rule.branches) {
      if (!conditionMatches(branch.condition, root, inventory)) continue;

      // Branch matched — determine the working form.
      // When EndsWithLiteralCond matched, strip the suffix before applying ops.
      var workingForm = root;
      if (branch.condition case EndsWithLiteralCond(:final suffix)) {
        if (workingForm.endsWith(suffix)) {
          workingForm =
              workingForm.substring(0, workingForm.length - suffix.length);
        }
      }
      // Similarly for StartsWithLiteralCond, strip the prefix.
      if (branch.condition case StartsWithLiteralCond(:final prefix)) {
        if (workingForm.startsWith(prefix)) {
          workingForm = workingForm.substring(prefix.length);
        }
      }

      // Apply operations in sequence.
      for (final op in branch.operations) {
        workingForm = _applyOp(op, workingForm, inventory);
      }
      return MorphSuccess(workingForm);
    }

    return MorphNoMatch('No branch matched root "$root"');
  }
}
