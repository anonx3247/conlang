import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/lexicon/data/lexeme_dao.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LexemeDao lexemeDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    lexemeDao = db.lexemeDao;
  });

  tearDown(() async {
    await db.close();
  });

  group('closed-class word queries', () {
    test(
      'closed-class lexeme appears in watchClosedClassWords() '
      'but NOT in watchRoots()',
      () async {
        await lexemeDao.insertLexeme(
          LexemesCompanion.insert(
            ipa: 'la',
            isClosedClass: const Value(true),
            meaning: const Value('the'),
            partOfSpeech: const Value('Determiner'),
            glossTag: const Value('DEF'),
          ),
        );

        final closedClass =
            await lexemeDao.watchClosedClassWords().first;
        expect(
          closedClass.any((l) => l.ipa == 'la'),
          isTrue,
          reason: 'closed-class lexeme must appear in watchClosedClassWords()',
        );

        final roots = await lexemeDao.watchRoots().first;
        expect(
          roots.any((l) => l.ipa == 'la'),
          isFalse,
          reason: 'closed-class lexeme must NOT appear in watchRoots()',
        );
      },
    );

    test(
      'regular (open-class) lexeme appears in watchRoots() '
      'but NOT in watchClosedClassWords()',
      () async {
        await lexemeDao.insertLexeme(
          LexemesCompanion.insert(
            ipa: 'ka.ta',
            isClosedClass: const Value(false),
            meaning: const Value('to walk'),
            partOfSpeech: const Value('Verb'),
          ),
        );

        final roots = await lexemeDao.watchRoots().first;
        expect(
          roots.any((l) => l.ipa == 'ka.ta'),
          isTrue,
          reason: 'regular lexeme must appear in watchRoots()',
        );

        final closedClass =
            await lexemeDao.watchClosedClassWords().first;
        expect(
          closedClass.any((l) => l.ipa == 'ka.ta'),
          isFalse,
          reason: 'regular lexeme must NOT appear in watchClosedClassWords()',
        );
      },
    );

    test(
      'glossTag is persisted and retrieved correctly',
      () async {
        await lexemeDao.insertLexeme(
          LexemesCompanion.insert(
            ipa: 'nu',
            isClosedClass: const Value(true),
            glossTag: const Value('NEG'),
          ),
        );

        final closedClass =
            await lexemeDao.watchClosedClassWords().first;
        final particle = closedClass.firstWhere((l) => l.ipa == 'nu');
        expect(particle.glossTag, equals('NEG'));
        expect(particle.isClosedClass, isTrue);
      },
    );

    test(
      'multiple closed-class words are ordered by partOfSpeech then ipa',
      () async {
        await lexemeDao.insertLexeme(
          LexemesCompanion.insert(
            ipa: 'ze',
            isClosedClass: const Value(true),
            partOfSpeech: const Value('Verb'),
            glossTag: const Value('AUX'),
          ),
        );
        await lexemeDao.insertLexeme(
          LexemesCompanion.insert(
            ipa: 'la',
            isClosedClass: const Value(true),
            partOfSpeech: const Value('Determiner'),
            glossTag: const Value('DEF'),
          ),
        );
        await lexemeDao.insertLexeme(
          LexemesCompanion.insert(
            ipa: 'mo',
            isClosedClass: const Value(true),
            partOfSpeech: const Value('Determiner'),
            glossTag: const Value('INDF'),
          ),
        );

        final closedClass =
            await lexemeDao.watchClosedClassWords().first;
        expect(closedClass.length, equals(3));

        // Determiner comes before Verb alphabetically.
        expect(closedClass[0].partOfSpeech, equals('Determiner'));
        expect(closedClass[1].partOfSpeech, equals('Determiner'));
        expect(closedClass[2].partOfSpeech, equals('Verb'));

        // Within Determiner, 'la' < 'mo'.
        expect(closedClass[0].ipa, equals('la'));
        expect(closedClass[1].ipa, equals('mo'));
      },
    );
  });
}
