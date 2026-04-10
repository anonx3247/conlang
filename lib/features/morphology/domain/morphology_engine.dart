import '../../phonology/domain/default_natural_classes.dart'
    show defaultNaturalClassAliases;
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
/// Recognised shorthands:
///   - `C` = all consonants
///   - `V` = all vowels
///   - Single-letter alias (S/N/F/L/R, case-sensitive) = predefined default
///     class list. Checked BEFORE lowercasing so `S` resolves to Stops without
///     colliding with literal /s/. See Phase 3.2 D-05a / RESEARCH F-2.
///
/// Everything else is looked up in [inventory.naturalClasses] (case-insensitive).
///
/// IMPORTANT: This function must stay in lockstep with
/// [WordGenerator._resolveClass] — both resolvers are exercised by the parity
/// test in `test/phonology/resolve_class_test.dart`.
List<String> resolvePhonemeClass(String classRef, PhonemeInventory inventory) {
  // 1. Reserved system shortcuts (C/V from Phase 1).
  switch (classRef) {
    case 'C':
      return inventory.consonants;
    case 'V':
      return inventory.vowels;
  }

  // 2. Single-letter alias (case-sensitive — checked BEFORE lowercasing so
  //    'S' resolves to Stops without colliding with literal /s/).
  //    Intersected with the user's inventory — the default catalog ships
  //    with full IPA sets but resolution must only yield symbols the user
  //    actually has. Parity with WordGenerator._resolveClass is enforced
  //    by test/phonology/resolve_class_test.dart. See Phase 3.2 D-05a /
  //    RESEARCH F-2 and 2026-04-10 UAT.
  final alias = defaultNaturalClassAliases[classRef];
  if (alias != null) {
    final userSymbols = <String>{
      ...inventory.consonants,
      ...inventory.vowels,
    };
    return alias.where(userSymbols.contains).toList();
  }

  // 3. Lowercased name lookup (existing behavior — hits user classes and
  //    default full-name classes seeded by buildInventory in Plan 01).
  final key = classRef.toLowerCase();
  if (inventory.naturalClasses.containsKey(key)) {
    return inventory.naturalClasses[key]!;
  }

  // 4. Exact-case fallback (legacy behavior preserved for edge cases).
  if (inventory.naturalClasses.containsKey(classRef)) {
    return inventory.naturalClasses[classRef]!;
  }

  return [];
}

// ---------------------------------------------------------------------------
// Pattern condition parser / matcher
// ---------------------------------------------------------------------------

/// A single segment in a parsed phonological pattern.
sealed class _PatternSegment {
  const _PatternSegment();
}

class _ClassSegment extends _PatternSegment {
  const _ClassSegment(this.classRef);
  final String classRef;
}

class _LiteralSegment extends _PatternSegment {
  const _LiteralSegment(this.text);
  final String text;
}

class _OptionalGroup extends _PatternSegment {
  const _OptionalGroup(this.segments);
  final List<_PatternSegment> segments;
}

/// Parses a raw pattern string into a list of [_PatternSegment]s.
///
/// Anchoring is now handled by [CondPosition] on the [PatternCond], not by
/// `_` characters in the pattern string.
List<_PatternSegment> _parsePattern(String pattern) {
  final segments = <_PatternSegment>[];
  var i = 0;
  final s = pattern;
  while (i < s.length) {
    if (s[i] == '[') {
      // Named class: [className]
      final close = s.indexOf(']', i + 1);
      if (close == -1) {
        // Malformed — treat rest as literal.
        segments.add(_LiteralSegment(s.substring(i)));
        break;
      }
      final name = s.substring(i + 1, close);
      segments.add(_ClassSegment(name));
      i = close + 1;
    } else if (s[i] == '(') {
      // Optional group: (...)
      final close = s.indexOf(')', i + 1);
      if (close == -1) {
        segments.add(_LiteralSegment(s.substring(i)));
        break;
      }
      final inner = s.substring(i + 1, close);
      // Parse inner segments recursively (no nesting required for now).
      final innerSegments = _parsePattern(inner);
      segments.add(_OptionalGroup(innerSegments));
      i = close + 1;
    } else if (s[i] == 'C' || s[i] == 'V') {
      // Uppercase shorthand: C = consonants, V = vowels
      segments.add(_ClassSegment(s[i]));
      i++;
    } else {
      // Literal: accumulate consecutive literal chars (non-special)
      final buf = StringBuffer();
      while (i < s.length &&
          s[i] != '[' &&
          s[i] != '(' &&
          s[i] != ')' &&
          s[i] != 'C' &&
          s[i] != 'V') {
        buf.write(s[i]);
        i++;
      }
      if (buf.isNotEmpty) segments.add(_LiteralSegment(buf.toString()));
    }
  }

  return segments;
}

/// Tries to match [segments] against [tokens] starting at [start].
/// Returns the number of tokens consumed if successful, -1 if not.
int _matchSegments(
    List<_PatternSegment> segments, List<String> tokens, int start,
    PhonemeInventory inventory) {
  var pos = start;
  for (final seg in segments) {
    switch (seg) {
      case _ClassSegment(:final classRef):
        if (pos >= tokens.length) return -1;
        final members = resolvePhonemeClass(classRef, inventory);
        if (!members.contains(tokens[pos])) return -1;
        pos++;

      case _LiteralSegment(:final text):
        // A literal segment may span multiple tokens (e.g. 'na' = 'n'+'a').
        // Match token by token against the literal text left-to-right.
        var remaining = text;
        while (remaining.isNotEmpty) {
          if (pos >= tokens.length) return -1;
          final tok = tokens[pos];
          if (remaining.startsWith(tok)) {
            remaining = remaining.substring(tok.length);
            pos++;
          } else {
            return -1;
          }
        }

      case _OptionalGroup(:final segments):
        // Try matching the group; if it fails, skip (zero occurrences).
        final tried = _matchSegments(segments, tokens, pos, inventory);
        if (tried >= 0) pos = tried;
        // If tried == -1, skip the group (optional).
    }
  }
  return pos;
}

/// Returns true if [cond] matches [root] given [inventory].
///
/// Uses [cond.position] to determine where the pattern must match:
/// - [CondPosition.startsWith]: pattern must match at position 0
/// - [CondPosition.endsWith]: pattern must match ending at the last token
/// - [CondPosition.contains]: pattern can match anywhere
bool patternConditionMatches(
  PatternCond cond,
  String root,
  PhonemeInventory inventory,
) {
  if (root.isEmpty) return false;

  final segments = _parsePattern(cond.pattern);
  final tokens = tokenizeIpa(root, inventory);
  if (tokens.isEmpty) return false;

  if (segments.isEmpty) {
    // Empty pattern = always matches (degenerate).
    return true;
  }

  switch (cond.position) {
    case CondPosition.startsWith:
      // Must match from position 0 but may end anywhere.
      return _matchSegments(segments, tokens, 0, inventory) >= 0;
    case CondPosition.endsWith:
      // Must end at the last token. Try matching at every start position.
      for (var start = 0; start <= tokens.length; start++) {
        final end = _matchSegments(segments, tokens, start, inventory);
        if (end == tokens.length) return true;
      }
      return false;
    case CondPosition.contains:
      // Match anywhere.
      for (var start = 0; start <= tokens.length; start++) {
        if (_matchSegments(segments, tokens, start, inventory) >= 0) return true;
      }
      return false;
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
  MorphCondition cond,
  String root,
  PhonemeInventory inventory,
) {
  if (root.isEmpty) return false;

  return switch (cond) {
    PatternCond() => patternConditionMatches(cond, root, inventory),
  };
}

/// Returns true if all conditions in [conditions] match [root].
///
/// Empty list = default branch = always matches.
bool allConditionsMatch(
  List<MorphCondition> conditions,
  String root,
  PhonemeInventory inventory,
) {
  if (conditions.isEmpty) return true; // default branch
  if (root.isEmpty) return false;

  return conditions.every((c) => conditionMatches(c, root, inventory));
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

/// Replaces occurrences of [from] token with [to] in [root].
///
/// [count] controls how many occurrences to replace (null = all).
/// [direction] controls from which end to start replacing.
String applyAblaut(
  String root,
  String from,
  String to,
  PhonemeInventory inventory, {
  int? count,
  AblautDirection direction = AblautDirection.fromStart,
}) {
  final tokens = tokenizeIpa(root, inventory);
  if (count == null) {
    // Replace all
    return tokens.map((t) => t == from ? to : t).join();
  }

  // Find all indices matching `from`
  final matchIndices = <int>[];
  for (var i = 0; i < tokens.length; i++) {
    if (tokens[i] == from) matchIndices.add(i);
  }

  // Select which indices to replace based on direction and count
  final Set<int> toReplace;
  if (direction == AblautDirection.fromStart) {
    toReplace = matchIndices.take(count).toSet();
  } else {
    final reversed = matchIndices.reversed.take(count).toSet();
    toReplace = reversed;
  }

  return List.generate(tokens.length,
      (i) => toReplace.contains(i) ? to : tokens[i]).join();
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
    AblautOp(:final from, :final to, :final count, :final direction) =>
      applyAblaut(form, from, to, inventory, count: count, direction: direction),
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
  /// Iterates branches in order. The first branch whose conditions all match wins.
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
      if (!allConditionsMatch(branch.conditions, root, inventory)) continue;

      // Apply operations in sequence.
      var workingForm = root;
      for (final op in branch.operations) {
        workingForm = _applyOp(op, workingForm, inventory);
      }
      return MorphSuccess(workingForm);
    }

    return MorphNoMatch('No branch matched root "$root"');
  }
}
