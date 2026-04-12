// Plan 04-17 Task 11 -- unit tests for D-99 standard-form violation
// rendering. Tests the standardFormViolationsProvider logic and that
// violations are non-blocking (save always succeeds).

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/intrinsic_levels_codec.dart';
import 'package:conlang_workbench/features/grammar/data/standard_form_pattern_dao.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/standard_form_branch.dart';
import 'package:conlang_workbench/features/grammar/domain/standard_form_matcher.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late StandardFormPatternDao dao;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = StandardFormPatternDao(db);

    container = ProviderContainer(
      overrides: [
        currentDatabaseProvider.overrideWithValue(db),
      ],
    );

    // Seed POS.
    await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );

    // Seed Gender intrinsic dim with levels M=0, F=1.
    await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: 1,
            name: 'Gender',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 0, name: 'Masculine', abbr: 'M', ordering: 0),
              DimensionLevel(id: 1, name: 'Feminine', abbr: 'F', ordering: 1),
            ]),
            templateId: const Value('gender.mf'),
            intrinsic: const Value(true),
          ),
        );

    // Non-intrinsic dims (so paradigm has axes).
    await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: 1,
            name: 'Number',
            ordering: const Value(1),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(
                  id: 0, name: 'Singular', abbr: 'SG', ordering: 0),
              DimensionLevel(id: 1, name: 'Plural', abbr: 'PL', ordering: 1),
            ]),
            templateId: const Value('number.sg_pl'),
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // ---- Direct unit tests of the validation logic (no provider) ----

  test('Test 1: violation when lexeme form does not match pattern', () async {
    const matcher = StandardFormMatcher();
    const inventory = PhonemeInventory(
      consonants: ['k', 's'],
      vowels: ['a', 'o'],
      naturalClasses: {},
    );
    final branches = [
      const StandardFormBranch(kind: BranchKind.endsWith, literal: 'o'),
    ];
    // 'kasa' ends with 'a', not 'o' -- should NOT match.
    expect(matcher.matches('kasa', branches, inventory), isFalse);
  });

  test('Test 2: no violation when lexeme form matches pattern', () async {
    const matcher = StandardFormMatcher();
    const inventory = PhonemeInventory(
      consonants: ['t', 'p', 'r'],
      vowels: ['i', 'o'],
      naturalClasses: {},
    );
    final branches = [
      const StandardFormBranch(kind: BranchKind.endsWith, literal: 'o'),
    ];
    // 'tipro' ends with 'o' -- should match.
    expect(matcher.matches('tipro', branches, inventory), isTrue);
  });

  test('Test 3: empty branches trivially match (no violation)', () async {
    const matcher = StandardFormMatcher();
    const inventory = PhonemeInventory.empty;
    expect(matcher.matches('kasa', const [], inventory), isTrue);
  });

  test('Test 4: DAO getPattern round-trips branches correctly', () async {
    // Upsert a pattern for Masculine (dimId=1, levelId=0).
    await dao.upsertPattern(1, 0, [
      const StandardFormBranch(kind: BranchKind.endsWith, literal: 'o'),
      const StandardFormBranch(kind: BranchKind.startsWith, literal: 'k'),
    ]);

    final result = await dao.getPattern(1, 0);
    expect(result, isNotNull);
    expect(result!.length, 2);
    expect(result[0].kind, BranchKind.endsWith);
    expect(result[0].literal, 'o');
    expect(result[1].kind, BranchKind.startsWith);
    expect(result[1].literal, 'k');
  });

  test('Test 5: multi-branch OR - any match satisfies the pattern', () async {
    const matcher = StandardFormMatcher();
    const inventory = PhonemeInventory(
      consonants: ['k', 'r'],
      vowels: ['a', 'e', 'o'],
      naturalClasses: {},
    );
    final branches = [
      const StandardFormBranch(kind: BranchKind.endsWith, literal: 'o'),
      const StandardFormBranch(kind: BranchKind.endsWith, literal: 'a'),
    ];
    // 'kasa' ends with 'a' -- matches second branch.
    expect(matcher.matches('kasa', branches, inventory), isTrue);
    // 'karo' ends with 'o' -- matches first branch.
    expect(matcher.matches('karo', branches, inventory), isTrue);
    // 'kare' ends with 'e' -- matches neither.
    expect(matcher.matches('kare', branches, inventory), isFalse);
  });

  test('Test 6: save is never blocked by standard-form violations', () async {
    await dao.upsertPattern(1, 0, [
      const StandardFormBranch(kind: BranchKind.endsWith, literal: 'o'),
    ]);

    // Insert a violating lexeme -- should succeed without error.
    final lexId = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'kasa',
            partOfSpeech: const Value('Noun'),
            intrinsicLevelsJson:
                Value(IntrinsicLevelsCodec.encode({1: 0})),
          ),
        );
    expect(lexId, isPositive);

    // Update the lexeme -- should also succeed (violations never block).
    await (db.update(db.lexemes)..where((t) => t.id.equals(lexId)))
        .write(const LexemesCompanion(meaning: Value('house')));

    final row = await (db.select(db.lexemes)
          ..where((t) => t.id.equals(lexId)))
        .getSingle();
    expect(row.meaning, 'house');
  });
}
