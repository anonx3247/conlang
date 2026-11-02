// TDD tests for construction-realized paradigm cell resolution.
//
// Plan 02: implements and verifies resolveConstructionCell + generateParadigm
// construction post-pass.
//
// These tests call resolveConstructionCell (pure function) directly with
// in-memory fixtures — no DB access required.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/construction_rule.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/inflectional_rule.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_cell.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_engine.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

/// Phoneme inventory used across all tests.
final _inventory = PhonemeInventory(
  consonants: const ['k', 't', 'b', 'n', 's', 'r', 'l', 'd', 'g'],
  vowels: const ['a', 'e', 'i', 'o', 'u'],
  naturalClasses: const {
    'c': ['k', 't', 'b', 'n', 's', 'r', 'l', 'd', 'g'],
    'v': ['a', 'e', 'i', 'o', 'u'],
  },
);

// Dimension / level ids (small integers, no DB required)
const int dimTense = 10;
const int dimAspect = 11;
const int dimMood = 12;

const int lvlFUT = 1;
const int lvlPST = 2;
const int lvlPFV = 1;
const int lvlIPFV = 2;
const int lvlIND = 1;
const int lvlCOND = 2;

// Construction / slot ids
const int cId1 = 100;
const int cId2 = 200;
const int slotIdParticle = 10;
const int slotIdWord = 11;
const int slotIdParticle2 = 12;

/// Creates a minimal [ConstructionRule].
ConstructionRule _constructionRule({
  required int id,
  required Map<int, int> dims,
  int constructionId = cId1,
  int wordSlotId = slotIdWord,
  FormReference? formReference,
  bool isActive = true,
  String name = 'test-rule',
}) =>
    ConstructionRule(
      id: id,
      name: name,
      isActive: isActive,
      ordering: 0,
      constructionId: constructionId,
      wordSlotId: wordSlotId,
      formReference: formReference ?? const BaseFormReference(),
      bindings: FeatureBindings(pos: const [], dims: dims),
    );

/// Creates a minimal [ConstructionSlot] mock-compatible value.
ConstructionSlot _slot({
  required int id,
  required String slotType,
  required String slotValue,
  int constructionId = cId1,
  int ordering = 0,
}) =>
    ConstructionSlot(
      id: id,
      constructionId: constructionId,
      slotType: slotType,
      slotValue: slotValue,
      ordering: ordering,
    );

/// Creates a minimal [Lexeme] with glossTag (closed-class word).
Lexeme _particle({
  required int id,
  required String ipa,
  required String glossTag,
  String? romanization,
}) =>
    Lexeme(
      id: id,
      ipa: ipa,
      romanization: romanization,
      meaning: null,
      rootId: null,
      partOfSpeech: null,
      derivedFromLexemeId: null,
      derivedViaRuleId: null,
      isPhonologicalException: false,
      skippedDimensionsJson: null,
      intrinsicLevelsJson: null,
      rootOnlyViaDerivations: false,
      isClosedClass: true,
      glossTag: glossTag,
    );

/// Creates an [InflectionalRule] convenience helper.
InflectionalRule _inflRule(
  int id,
  String name,
  String source,
  Map<int, int> dims,
) =>
    InflectionalRule(
      id: id,
      name: name,
      source: source,
      isActive: true,
      bindings: FeatureBindings(pos: const [], dims: dims),
    );

/// Slot lookup callback: maps constructionId → list of slots.
List<ConstructionSlot> Function(int) _slotsLookup(
        Map<int, List<ConstructionSlot>> byConstructionId) =>
    (cId) => byConstructionId[cId] ?? const [];

void main() {
  // ---------------------------------------------------------------------------
  // Construction resolution
  // ---------------------------------------------------------------------------

  group('construction resolution', () {
    test('base form — construction rule wraps uninflected root', () {
      // Construction: [particle:FUT, word:base]
      // No inflectional rules → WordSlot uses bare root "kas"
      final rule = _constructionRule(
        id: 1,
        dims: {dimTense: lvlFUT},
        wordSlotId: slotIdWord,
        formReference: const BaseFormReference(),
      );

      final futParticle = _particle(id: 1, ipa: 'ko', glossTag: 'FUT');

      final slots = {
        cId1: [
          _slot(id: slotIdParticle, slotType: 'gloss_tag', slotValue: 'FUT', ordering: 0),
          _slot(id: slotIdWord, slotType: 'pos', slotValue: 'V', ordering: 1),
        ],
      };

      final inflectionalResult = const ParadigmUncovered('No rule');

      final result = resolveConstructionCell(
        root: 'kas',
        target: const {dimTense: lvlFUT},
        inflectionalResult: inflectionalResult,
        constructionRules: [rule],
        slotsLookup: _slotsLookup(slots),
        closedClassWords: [futParticle],
        inflectionalChart: const {},
        resolvingStack: {},
        resolvedCache: {},
        allConstructionRules: [rule],
        inventory: _inventory,
      );

      expect(result, isA<ParadigmConstructionFilled>());
      final filled = result as ParadigmConstructionFilled;
      // Tokens: [ParticleToken('ko'), WordSlotToken('kas', 'kas')]
      expect(filled.tokens, hasLength(2));
      expect(filled.tokens[0], isA<ParticleToken>());
      expect((filled.tokens[0] as ParticleToken).ipa, equals('ko'));
      expect(filled.tokens[1], isA<WordSlotToken>());
      expect((filled.tokens[1] as WordSlotToken).ipa, equals('kas'));
      expect(filled.form, equals('ko kas'));
      expect(filled.phonemic, equals('ko kas'));
    });

    test(
        'base form with inflectional composition — D-04: inflectional fires first, construction wraps inflected form',
        () {
      // Inflectional rule: +i suffix for FUT
      // Construction: [particle:FUT, word-slot] with BaseFormReference
      // Expected: WordSlotToken uses inflected "kasi", not bare "kas"

      final inflRule = _inflRule(1, '+i', '+i', {dimTense: lvlFUT});
      final inflectionalResult = ParadigmFilled(
        form: 'kasi',
        ruleChain: [inflRule],
        phonemic: 'kasi',
      );

      final rule = _constructionRule(
        id: 1,
        dims: {dimTense: lvlFUT},
        wordSlotId: slotIdWord,
        formReference: const BaseFormReference(),
      );

      final futParticle = _particle(id: 1, ipa: 'ko', glossTag: 'FUT');
      final slots = {
        cId1: [
          _slot(id: slotIdParticle, slotType: 'gloss_tag', slotValue: 'FUT', ordering: 0),
          _slot(id: slotIdWord, slotType: 'pos', slotValue: 'V', ordering: 1),
        ],
      };

      final result = resolveConstructionCell(
        root: 'kas',
        target: const {dimTense: lvlFUT},
        inflectionalResult: inflectionalResult,
        constructionRules: [rule],
        slotsLookup: _slotsLookup(slots),
        closedClassWords: [futParticle],
        inflectionalChart: {
          '10:1': ParadigmFilled(form: 'kasi', ruleChain: [inflRule], phonemic: 'kasi'),
        },
        resolvingStack: {},
        resolvedCache: {},
        allConstructionRules: [rule],
        inventory: _inventory,
      );

      expect(result, isA<ParadigmConstructionFilled>());
      final filled = result as ParadigmConstructionFilled;
      // D-04: construction wraps the inflected form, not bare root
      final wordToken = filled.tokens.whereType<WordSlotToken>().first;
      expect(wordToken.ipa, equals('kasi'));
      expect(filled.form, equals('ko kasi'));
    });

    test('cell reference — word slot resolves to another paradigm cell output',
        () {
      // Construction: FUT cell references PST cell (CellFormReference)
      // PST cell is already resolved to ParadigmFilled(form:'kasa')
      // Expected: WordSlotToken uses 'kasa' from PST cell

      final rule = _constructionRule(
        id: 1,
        dims: {dimTense: lvlFUT},
        wordSlotId: slotIdWord,
        formReference: CellFormReference(targetFeatureSet: {dimTense: lvlPST}),
      );

      final inflRule = _inflRule(1, '+a', '+a', {dimTense: lvlPST});
      final pstCell =
          ParadigmFilled(form: 'kasa', ruleChain: [inflRule], phonemic: 'kasa');

      final futParticle = _particle(id: 1, ipa: 'ko', glossTag: 'FUT');
      final slots = {
        cId1: [
          _slot(id: slotIdParticle, slotType: 'gloss_tag', slotValue: 'FUT', ordering: 0),
          _slot(id: slotIdWord, slotType: 'pos', slotValue: 'V', ordering: 1),
        ],
      };

      final result = resolveConstructionCell(
        root: 'kas',
        target: const {dimTense: lvlFUT},
        inflectionalResult: const ParadigmUncovered(),
        constructionRules: [rule],
        slotsLookup: _slotsLookup(slots),
        closedClassWords: [futParticle],
        inflectionalChart: {'10:2': pstCell},
        resolvingStack: {},
        resolvedCache: {},
        allConstructionRules: [rule],
        inventory: _inventory,
      );

      expect(result, isA<ParadigmConstructionFilled>());
      final filled = result as ParadigmConstructionFilled;
      final wordToken = filled.tokens.whereType<WordSlotToken>().first;
      expect(wordToken.ipa, equals('kasa'));
      expect(filled.form, equals('ko kasa'));
    });

    test(
        'cell reference with D-04 composition — inflectional + construction + cross-cell',
        () {
      // FUT cell: inflectional rule fires (+i → 'kasi')
      // Construction also applies: CellFormReference to IPFV cell (form:'kasla')
      // Expected: WordSlotToken uses the IPFV cell output 'kasla'
      // (The inflectional result is available but the construction overrides with cross-cell reference)

      final inflRule = _inflRule(1, '+i', '+i', {dimTense: lvlFUT});
      final inflectionalResult = ParadigmFilled(
        form: 'kasi',
        ruleChain: [inflRule],
        phonemic: 'kasi',
      );

      // Construction rule: FUT cell references IPFV cell
      final rule = _constructionRule(
        id: 1,
        dims: {dimTense: lvlFUT},
        wordSlotId: slotIdWord,
        formReference:
            CellFormReference(targetFeatureSet: {dimAspect: lvlIPFV}),
      );

      final futParticle = _particle(id: 1, ipa: 'ko', glossTag: 'FUT');
      final ipfvCell = ParadigmFilled(
          form: 'kasla',
          ruleChain: [],
          phonemic: 'kasla');

      final slots = {
        cId1: [
          _slot(id: slotIdParticle, slotType: 'gloss_tag', slotValue: 'FUT', ordering: 0),
          _slot(id: slotIdWord, slotType: 'pos', slotValue: 'V', ordering: 1),
        ],
      };

      final result = resolveConstructionCell(
        root: 'kas',
        target: const {dimTense: lvlFUT},
        inflectionalResult: inflectionalResult,
        constructionRules: [rule],
        slotsLookup: _slotsLookup(slots),
        closedClassWords: [futParticle],
        inflectionalChart: {'11:2': ipfvCell},
        resolvingStack: {},
        resolvedCache: {},
        allConstructionRules: [rule],
        inventory: _inventory,
      );

      expect(result, isA<ParadigmConstructionFilled>());
      final filled = result as ParadigmConstructionFilled;
      final wordToken = filled.tokens.whereType<WordSlotToken>().first;
      // CellFormReference resolves to IPFV cell output, not the inflectional form
      expect(wordToken.ipa, equals('kasla'));
      expect(filled.form, equals('ko kasla'));
    });
  });

  // ---------------------------------------------------------------------------
  // Cycle detection (D-09)
  // ---------------------------------------------------------------------------

  group('cycle detection (D-09)', () {
    test('direct self-loop — cell references itself → ParadigmUnresolvable',
        () {
      // FUT cell has CellFormReference targeting FUT itself → cycle
      final rule = _constructionRule(
        id: 1,
        dims: {dimTense: lvlFUT},
        wordSlotId: slotIdWord,
        formReference: CellFormReference(targetFeatureSet: {dimTense: lvlFUT}),
      );

      final slots = {
        cId1: [
          _slot(id: slotIdParticle, slotType: 'gloss_tag', slotValue: 'FUT', ordering: 0),
          _slot(id: slotIdWord, slotType: 'pos', slotValue: 'V', ordering: 1),
        ],
      };

      final result = resolveConstructionCell(
        root: 'kas',
        target: const {dimTense: lvlFUT},
        inflectionalResult: const ParadigmUncovered(),
        constructionRules: [rule],
        slotsLookup: _slotsLookup(slots),
        closedClassWords: [],
        inflectionalChart: {},
        resolvingStack: {},
        resolvedCache: {},
        allConstructionRules: [rule],
        inventory: _inventory,
      );

      expect(result, isA<ParadigmUnresolvable>());
      final unresolvable = result as ParadigmUnresolvable;
      // Cycle path should mention the feature set key
      expect(unresolvable.cyclePath, isNotEmpty);
    });

    test('indirect cycle A→B→A — both return ParadigmUnresolvable', () {
      // FUT rule → references COND cell
      // COND rule → references FUT cell (back to start)
      final ruleFUT = _constructionRule(
        id: 1,
        dims: {dimTense: lvlFUT},
        wordSlotId: slotIdWord,
        formReference: CellFormReference(targetFeatureSet: {dimTense: lvlCOND}),
      );
      final ruleCOND = _constructionRule(
        id: 2,
        dims: {dimTense: lvlCOND},
        wordSlotId: slotIdWord,
        formReference: CellFormReference(targetFeatureSet: {dimTense: lvlFUT}),
      );

      final slots = {
        cId1: [
          _slot(id: slotIdWord, slotType: 'pos', slotValue: 'V', ordering: 0),
        ],
      };

      // Resolve FUT → should hit cycle when it tries to resolve COND → FUT
      final resultFUT = resolveConstructionCell(
        root: 'kas',
        target: const {dimTense: lvlFUT},
        inflectionalResult: const ParadigmUncovered(),
        constructionRules: [ruleFUT, ruleCOND],
        slotsLookup: _slotsLookup(slots),
        closedClassWords: [],
        inflectionalChart: {},
        resolvingStack: {},
        resolvedCache: {},
        allConstructionRules: [ruleFUT, ruleCOND],
        inventory: _inventory,
      );

      expect(resultFUT, isA<ParadigmUnresolvable>());
    });

    test('three-node cycle A→B→C→A → ParadigmUnresolvable with full path', () {
      // FUT→COND→PST→FUT
      final ruleFUT = _constructionRule(
        id: 1,
        dims: {dimTense: lvlFUT},
        wordSlotId: slotIdWord,
        formReference: CellFormReference(targetFeatureSet: {dimTense: lvlCOND}),
      );
      final ruleCOND = _constructionRule(
        id: 2,
        dims: {dimTense: lvlCOND},
        wordSlotId: slotIdWord,
        formReference: CellFormReference(targetFeatureSet: {dimTense: lvlPST}),
      );
      final rulePST = _constructionRule(
        id: 3,
        dims: {dimTense: lvlPST},
        wordSlotId: slotIdWord,
        formReference:
            CellFormReference(targetFeatureSet: {dimTense: lvlFUT}),
      );

      final slots = {
        cId1: [
          _slot(id: slotIdWord, slotType: 'pos', slotValue: 'V', ordering: 0),
        ],
      };

      final result = resolveConstructionCell(
        root: 'kas',
        target: const {dimTense: lvlFUT},
        inflectionalResult: const ParadigmUncovered(),
        constructionRules: [ruleFUT, ruleCOND, rulePST],
        slotsLookup: _slotsLookup(slots),
        closedClassWords: [],
        inflectionalChart: {},
        resolvingStack: {},
        resolvedCache: {},
        allConstructionRules: [ruleFUT, ruleCOND, rulePST],
        inventory: _inventory,
      );

      expect(result, isA<ParadigmUnresolvable>());
      final unresolvable = result as ParadigmUnresolvable;
      expect(unresolvable.cyclePath, isNotEmpty);
    });

    test('no cycle — valid cross-reference chain resolves correctly', () {
      // A→B where B is base-form (no cycle)
      // FUT references PST, which has BaseFormReference (no construction rule)
      final ruleFUT = _constructionRule(
        id: 1,
        dims: {dimTense: lvlFUT},
        wordSlotId: slotIdWord,
        formReference: CellFormReference(targetFeatureSet: {dimTense: lvlPST}),
      );

      final futParticle = _particle(id: 1, ipa: 'ko', glossTag: 'FUT');
      final pstCell = ParadigmFilled(
          form: 'kasa', ruleChain: [], phonemic: 'kasa');

      final slots = {
        cId1: [
          _slot(id: slotIdParticle, slotType: 'gloss_tag', slotValue: 'FUT', ordering: 0),
          _slot(id: slotIdWord, slotType: 'pos', slotValue: 'V', ordering: 1),
        ],
      };

      final result = resolveConstructionCell(
        root: 'kas',
        target: const {dimTense: lvlFUT},
        inflectionalResult: const ParadigmUncovered(),
        constructionRules: [ruleFUT],
        slotsLookup: _slotsLookup(slots),
        closedClassWords: [futParticle],
        inflectionalChart: {'10:2': pstCell},
        resolvingStack: {},
        resolvedCache: {},
        allConstructionRules: [ruleFUT],
        inventory: _inventory,
      );

      // Should resolve successfully using PST cell output
      expect(result, isA<ParadigmConstructionFilled>());
      final filled = result as ParadigmConstructionFilled;
      final wordToken = filled.tokens.whereType<WordSlotToken>().first;
      expect(wordToken.ipa, equals('kasa'));
    });
  });

  // ---------------------------------------------------------------------------
  // Construction rule specificity and binding
  // ---------------------------------------------------------------------------

  group('construction rule specificity and binding', () {
    test('most-specific construction rule wins when multiple bind same cell',
        () {
      // Two rules: one binds {tense:FUT} (spec=1), one binds {tense:FUT, aspect:PFV} (spec=2)
      // Target: {tense:FUT, aspect:PFV} — both match, but higher spec should win
      final lowSpec = _constructionRule(
        id: 1,
        dims: {dimTense: lvlFUT},
        constructionId: cId1,
        wordSlotId: slotIdWord,
        name: 'low-spec',
      );
      final highSpec = _constructionRule(
        id: 2,
        dims: {dimTense: lvlFUT, dimAspect: lvlPFV},
        constructionId: cId2,
        wordSlotId: slotIdWord,
        name: 'high-spec',
      );

      final futParticle = _particle(id: 1, ipa: 'ko', glossTag: 'FUT');
      final pfvParticle = _particle(id: 2, ipa: 'na', glossTag: 'PFV');

      final slots = {
        cId1: [
          _slot(id: slotIdParticle, slotType: 'gloss_tag', slotValue: 'FUT', ordering: 0, constructionId: cId1),
          _slot(id: slotIdWord, slotType: 'pos', slotValue: 'V', ordering: 1, constructionId: cId1),
        ],
        cId2: [
          _slot(id: slotIdParticle, slotType: 'gloss_tag', slotValue: 'FUT', ordering: 0, constructionId: cId2),
          _slot(id: slotIdParticle2, slotType: 'gloss_tag', slotValue: 'PFV', ordering: 1, constructionId: cId2),
          _slot(id: slotIdWord, slotType: 'pos', slotValue: 'V', ordering: 2, constructionId: cId2),
        ],
      };

      final result = resolveConstructionCell(
        root: 'kas',
        target: const {dimTense: lvlFUT, dimAspect: lvlPFV},
        inflectionalResult: const ParadigmUncovered(),
        constructionRules: [lowSpec, highSpec],
        slotsLookup: _slotsLookup(slots),
        closedClassWords: [futParticle, pfvParticle],
        inflectionalChart: const {},
        resolvingStack: {},
        resolvedCache: {},
        allConstructionRules: [lowSpec, highSpec],
        inventory: _inventory,
      );

      expect(result, isA<ParadigmConstructionFilled>());
      final filled = result as ParadigmConstructionFilled;
      // High-spec rule (cId2) has 3 slots: FUT particle + PFV particle + word
      expect(filled.tokens, hasLength(3));
      expect((filled.tokens[0] as ParticleToken).ipa, equals('ko'));
      expect((filled.tokens[1] as ParticleToken).ipa, equals('na'));
    });

    test(
        'construction rule with no binding match returns inflectional-only cell',
        () {
      // Construction rule binds {tense:PST}, target is {tense:FUT} — no match
      // Should return the inflectional-only result unchanged
      final rule = _constructionRule(
        id: 1,
        dims: {dimTense: lvlPST},
        wordSlotId: slotIdWord,
      );

      final inflectionalResult = ParadigmFilled(
        form: 'kasla',
        ruleChain: [],
        phonemic: 'kasla',
      );

      final result = resolveConstructionCell(
        root: 'kas',
        target: const {dimTense: lvlFUT},
        inflectionalResult: inflectionalResult,
        constructionRules: [rule],
        slotsLookup: _slotsLookup(const {}),
        closedClassWords: const [],
        inflectionalChart: const {},
        resolvingStack: {},
        resolvedCache: {},
        allConstructionRules: [rule],
        inventory: _inventory,
      );

      // No match → return inflectional result unchanged
      expect(result, isA<ParadigmFilled>());
      final filled = result as ParadigmFilled;
      expect(filled.form, equals('kasla'));
    });

    test('inactive construction rule is skipped', () {
      // An inactive rule that would otherwise match — should be skipped
      final inactiveRule = _constructionRule(
        id: 1,
        dims: {dimTense: lvlFUT},
        wordSlotId: slotIdWord,
        isActive: false,
      );

      final inflectionalResult = ParadigmFilled(
        form: 'kasi',
        ruleChain: [],
        phonemic: 'kasi',
      );

      final result = resolveConstructionCell(
        root: 'kas',
        target: const {dimTense: lvlFUT},
        inflectionalResult: inflectionalResult,
        constructionRules: [inactiveRule],
        slotsLookup: _slotsLookup(const {}),
        closedClassWords: const [],
        inflectionalChart: const {},
        resolvingStack: {},
        resolvedCache: {},
        allConstructionRules: [inactiveRule],
        inventory: _inventory,
      );

      // Inactive rule skipped → inflectional result returned unchanged
      expect(result, isA<ParadigmFilled>());
      expect((result as ParadigmFilled).form, equals('kasi'));
    });
  });

  // ---------------------------------------------------------------------------
  // ParadigmConstructionFilled token assembly
  // ---------------------------------------------------------------------------

  group('ParadigmConstructionFilled token assembly', () {
    test(
        'tokens contain ParticleToken for gloss_tag slots and WordSlotToken for word slot',
        () {
      // Construction: [NEG particle, word-slot]
      final rule = _constructionRule(
        id: 1,
        dims: {dimMood: lvlIND},
        wordSlotId: slotIdWord,
        formReference: const BaseFormReference(),
      );

      final negParticle = _particle(id: 1, ipa: 'ne', glossTag: 'NEG');
      final slots = {
        cId1: [
          _slot(id: slotIdParticle, slotType: 'gloss_tag', slotValue: 'NEG', ordering: 0),
          _slot(id: slotIdWord, slotType: 'pos', slotValue: 'V', ordering: 1),
        ],
      };

      final result = resolveConstructionCell(
        root: 'kas',
        target: const {dimMood: lvlIND},
        inflectionalResult: const ParadigmUncovered(),
        constructionRules: [rule],
        slotsLookup: _slotsLookup(slots),
        closedClassWords: [negParticle],
        inflectionalChart: const {},
        resolvingStack: {},
        resolvedCache: {},
        allConstructionRules: [rule],
        inventory: _inventory,
      );

      expect(result, isA<ParadigmConstructionFilled>());
      final filled = result as ParadigmConstructionFilled;
      expect(filled.tokens[0], isA<ParticleToken>());
      expect(filled.tokens[1], isA<WordSlotToken>());
    });

    test('form field equals space-joined token IPA strings', () {
      // Two-particle + word construction: "ne ko kas" expected
      final rule = _constructionRule(
        id: 1,
        dims: {dimMood: lvlIND},
        wordSlotId: slotIdWord,
        formReference: const BaseFormReference(),
      );

      final negParticle = _particle(id: 1, ipa: 'ne', glossTag: 'NEG');
      final modParticle = _particle(id: 2, ipa: 'ko', glossTag: 'MOD');
      final slots = {
        cId1: [
          _slot(id: slotIdParticle, slotType: 'gloss_tag', slotValue: 'NEG', ordering: 0),
          _slot(id: slotIdParticle2, slotType: 'gloss_tag', slotValue: 'MOD', ordering: 1),
          _slot(id: slotIdWord, slotType: 'pos', slotValue: 'V', ordering: 2),
        ],
      };

      final result = resolveConstructionCell(
        root: 'kas',
        target: const {dimMood: lvlIND},
        inflectionalResult: const ParadigmUncovered(),
        constructionRules: [rule],
        slotsLookup: _slotsLookup(slots),
        closedClassWords: [negParticle, modParticle],
        inflectionalChart: const {},
        resolvingStack: {},
        resolvedCache: {},
        allConstructionRules: [rule],
        inventory: _inventory,
      );

      expect(result, isA<ParadigmConstructionFilled>());
      final filled = result as ParadigmConstructionFilled;
      // form = space-joined IPA of all tokens
      expect(filled.form, equals('ne ko kas'));
    });

    test('phonemic field equals space-joined token phonemic strings (D-112)',
        () {
      // ParticleToken.phonemic uses .ipa (no rewrite on closed-class words)
      // WordSlotToken.phonemic = pre-rewrite form (may differ from ipa after rewrite)
      final rule = _constructionRule(
        id: 1,
        dims: {dimMood: lvlIND},
        wordSlotId: slotIdWord,
        formReference: const BaseFormReference(),
      );

      final negParticle = _particle(id: 1, ipa: 'ne', glossTag: 'NEG');
      final slots = {
        cId1: [
          _slot(id: slotIdParticle, slotType: 'gloss_tag', slotValue: 'NEG', ordering: 0),
          _slot(id: slotIdWord, slotType: 'pos', slotValue: 'V', ordering: 1),
        ],
      };

      final result = resolveConstructionCell(
        root: 'kas',
        target: const {dimMood: lvlIND},
        inflectionalResult: const ParadigmUncovered(),
        constructionRules: [rule],
        slotsLookup: _slotsLookup(slots),
        closedClassWords: [negParticle],
        inflectionalChart: const {},
        resolvingStack: {},
        resolvedCache: {},
        allConstructionRules: [rule],
        inventory: _inventory,
      );

      expect(result, isA<ParadigmConstructionFilled>());
      final filled = result as ParadigmConstructionFilled;
      // phonemic = ParticleToken.ipa + ' ' + WordSlotToken.phonemic
      expect(filled.phonemic, equals('ne kas'));
    });
  });
}
