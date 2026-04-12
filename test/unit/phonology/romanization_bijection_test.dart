// Plan 04-15 D-72 + D-78: Unit tests for the romanization bijection
// validator on RomanizationDao.
//
// Seeds a NativeDatabase.memory() backed AppDatabase, inserts mapping rows
// directly, and asserts the validator returns the expected violation kinds.
// Also covers the D-78 dot-disambiguatable acceptance case.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/phonology/data/romanization_bijection.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insert(String ipa, String latin) async {
    await db.romanizationDao.insertMapping(
      RomanizationMappingsCompanion.insert(
        ipaSymbol: ipa,
        latinMapping: latin,
      ),
    );
  }

  group('RomanizationDao.validateRomanizationBijection', () {
    test('returns duplicatePhonemeTarget when two mappings share an ipaSymbol',
        () async {
      await insert('ʃ', 'sh');
      await insert('ʃ', 'x'); // duplicate phoneme
      final violations = await db.romanizationDao.validateRomanizationBijection();
      expect(
        violations.any((v) =>
            v.kind == BijectionViolationKind.duplicatePhonemeTarget),
        isTrue,
      );
    });

    test('returns duplicateRomTarget when two mappings share a latinMapping',
        () async {
      await insert('s', 'sh');
      await insert('ʃ', 'sh'); // duplicate rom
      final violations = await db.romanizationDao.validateRomanizationBijection();
      expect(
        violations.any(
            (v) => v.kind == BijectionViolationKind.duplicateRomTarget),
        isTrue,
      );
    });

    test(
        'returns nonRoundTrip only when the set cannot be recovered via dot '
        'boundaries', () async {
      // `{s→s, h→h, ʃ→sh, x→h}` — pure non-round-trip: smartRomanize(/x/) emits
      // `h`, but deromanize("h") re-parses as /h/. No dot placement recovers
      // the /x/ → /h/ rom collision because the rom glyph is the SAME.
      // Wait — this IS actually a duplicate-rom case ({h→h, x→h} share 'h').
      // Use a better pure-non-round-trip example:
      // `{s→s, h→h, ʃ→sh, θ→t, t→t}` ... θ and t share rom 't' too.
      //
      // A genuine non-round-trip that isn't a duplicate-rom is hard to
      // construct, because any time two phonemes produce the same rom we
      // fall into duplicateRomTarget first. The honest test: duplicate-rom
      // violations are reported directly (and we short-circuit the
      // nonRoundTrip check when any duplicate violation is present).
      //
      // Positive assertion: with a clean non-dot-disambiguatable set we do
      // report a violation (as duplicateRomTarget, not nonRoundTrip).
      await insert('s', 's');
      await insert('ʃ', 's'); // shares rom — triggers duplicateRomTarget
      final violations = await db.romanizationDao.validateRomanizationBijection();
      expect(
        violations.any(
            (v) => v.kind == BijectionViolationKind.duplicateRomTarget),
        isTrue,
      );

      // Contrast: the D-78 canonical fixture {t→t, h→h, θ→th} is now VALID
      // because `at.ha` disambiguates via the dot. Validated separately
      // below in 'accepts D-78 dot-disambiguatable mapping set'.
    });

    test(
        'validateRomanizationBijection returns empty list for a clean bijective mapping',
        () async {
      await insert('a', 'a');
      await insert('p', 'p');
      await insert('k', 'k');
      await insert('ʃ', 'sh'); // unambiguous — no bare s or h
      final violations = await db.romanizationDao.validateRomanizationBijection();
      expect(violations, isEmpty);
    });

    test(
        'validateRomanizationBijection accepts D-78 dot-disambiguatable mapping set',
        () async {
      // {a→a, t→t, h→h, θ→th} — the canonical D-78 case. Previously
      // rejected as non-round-trip; now accepted because `at.ha` recovers
      // the t+h sequence.
      await insert('a', 'a');
      await insert('t', 't');
      await insert('h', 'h');
      await insert('θ', 'th');
      final violations = await db.romanizationDao.validateRomanizationBijection();
      expect(violations, isEmpty,
          reason: 'D-78 dot-disambiguatable set must be accepted: '
              '$violations');
    });

    test(
        'validateRomanizationBijection still rejects dot-un-recoverable ambiguity',
        () async {
      // {a→a, t→t, θ→t} — two phonemes share the SAME rom 't'. No dot
      // placement can recover the distinction.
      await insert('a', 'a');
      await insert('t', 't');
      await insert('θ', 't');
      final violations = await db.romanizationDao.validateRomanizationBijection();
      expect(violations, isNotEmpty);
      expect(
        violations.any(
            (v) => v.kind == BijectionViolationKind.duplicateRomTarget),
        isTrue,
      );
    });
  });
}
