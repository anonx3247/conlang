// Plan 04-17 Task 2 — D-84 / D-85 intrinsic backfill + purge DAO tests.
//
// Locks:
//   D-84 Test 1: false→true backfill on a dim with N matching-POS lexemes
//                returns N; each lexeme's intrinsicLevelsJson gains
//                {dimId: firstLevelId}.
//   D-84 Test 2: backfill MERGES with existing entries for other dims —
//                it does not overwrite unrelated keys in the codec map.
//   D-85 Test 3: true→false does NOT touch lexeme rows — the purge
//                affordance is the separate, explicit cleanup step.
//   D-85 Test 4: purgeIntrinsicLevelEntries removes only that dim's key.
//   D-85 Test 5: countStaleIntrinsicEntries returns 0 when no stale
//                entries exist.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/grammar_dao.dart';
import 'package:conlang_workbench/features/grammar/data/intrinsic_levels_codec.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late GrammarDao dao;
  late int posId;
  late int genderDimId;
  late int numberDimId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.grammarDao;
    posId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    // gender with two levels
    genderDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Gender',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
              DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
            ]),
          ),
        );
    // number (used in Test 2 as the "other" dim the lexeme already has
    // an intrinsic entry for)
    numberDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Number',
            ordering: const Value(1),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
              DimensionLevel(id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
            ]),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertLexeme(String ipa, {String? intrinsicJson}) async {
    return db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: ipa,
            partOfSpeech: const Value('noun'),
            intrinsicLevelsJson: Value(intrinsicJson),
          ),
        );
  }

  Future<Lexeme> readLexeme(int id) async {
    return (db.select(db.lexemes)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  test('Test 1 — false→true backfill assigns firstLevelId to every matching-POS lexeme',
      () async {
    final l1 = await insertLexeme('kasa');
    final l2 = await insertLexeme('pinu');
    final l3 = await insertLexeme('taro');

    final affected = await dao.setDimensionIntrinsic(genderDimId, true);
    expect(affected, equals(3));

    for (final id in [l1, l2, l3]) {
      final row = await readLexeme(id);
      final decoded =
          IntrinsicLevelsCodec.decode(row.intrinsicLevelsJson);
      expect(decoded[genderDimId], equals(1),
          reason: 'Lexeme $id should have gender = first level id (1)');
    }

    // Dim row flipped.
    final dim = await (db.select(db.dimensions)
          ..where((t) => t.id.equals(genderDimId)))
        .getSingle();
    expect(dim.intrinsic, isTrue);
  });

  test('Test 2 — backfill merges with existing entries for other dims',
      () async {
    // Seed a lexeme that already has an intrinsic entry for numberDimId.
    final pre = IntrinsicLevelsCodec.encode({numberDimId: 2});
    final id = await insertLexeme('kasa', intrinsicJson: pre);

    await dao.setDimensionIntrinsic(genderDimId, true);

    final row = await readLexeme(id);
    final decoded = IntrinsicLevelsCodec.decode(row.intrinsicLevelsJson);
    // Both keys preserved.
    expect(decoded[numberDimId], equals(2));
    expect(decoded[genderDimId], equals(1));
  });

  test('Test 3 — true→false does NOT touch lexeme rows', () async {
    // Seed and flip ON.
    final id = await insertLexeme('kasa');
    await dao.setDimensionIntrinsic(genderDimId, true);

    final before = await readLexeme(id);
    final beforeJson = before.intrinsicLevelsJson;
    expect(beforeJson, isNotNull);

    // Flip OFF.
    final affected = await dao.setDimensionIntrinsic(genderDimId, false);
    expect(affected, equals(0));

    final after = await readLexeme(id);
    expect(after.intrinsicLevelsJson, equals(beforeJson),
        reason: 'true→false flip must leave lexeme intrinsic entries in place');

    // Dim row flipped off.
    final dim = await (db.select(db.dimensions)
          ..where((t) => t.id.equals(genderDimId)))
        .getSingle();
    expect(dim.intrinsic, isFalse);
  });

  test('Test 4 — purgeIntrinsicLevelEntries removes only that dim key',
      () async {
    // Two dims both intrinsic; purge only number.
    final id = await insertLexeme('kasa');
    await dao.setDimensionIntrinsic(genderDimId, true);
    await dao.setDimensionIntrinsic(numberDimId, true);

    var row = await readLexeme(id);
    var decoded = IntrinsicLevelsCodec.decode(row.intrinsicLevelsJson);
    expect(decoded.keys, containsAll([genderDimId, numberDimId]));

    // Flip number OFF so purge is valid for it.
    await dao.setDimensionIntrinsic(numberDimId, false);
    final removed = await dao.purgeIntrinsicLevelEntries(numberDimId);
    expect(removed, equals(1));

    row = await readLexeme(id);
    decoded = IntrinsicLevelsCodec.decode(row.intrinsicLevelsJson);
    expect(decoded.containsKey(numberDimId), isFalse);
    expect(decoded.containsKey(genderDimId), isTrue);
  });

  test('Test 5 — countStaleIntrinsicEntries is 0 when no stale entries',
      () async {
    await insertLexeme('kasa');
    await insertLexeme('pinu');

    // Never flipped intrinsic ON → no stale entries exist.
    final count = await dao.countStaleIntrinsicEntries(genderDimId);
    expect(count, equals(0));
  });
}
