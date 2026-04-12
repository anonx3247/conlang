// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grammar_dao.dart';

// ignore_for_file: type=lint
mixin _$GrammarDaoMixin on DatabaseAccessor<AppDatabase> {
  $PartsOfSpeechTable get partsOfSpeech => attachedDatabase.partsOfSpeech;
  $DimensionsTable get dimensions => attachedDatabase.dimensions;
  $MorphologicalRulesTable get morphologicalRules =>
      attachedDatabase.morphologicalRules;
  $LexemesTable get lexemes => attachedDatabase.lexemes;
  $StandardFormPatternsTable get standardFormPatterns =>
      attachedDatabase.standardFormPatterns;
  GrammarDaoManager get managers => GrammarDaoManager(this);
}

class GrammarDaoManager {
  final _$GrammarDaoMixin _db;
  GrammarDaoManager(this._db);
  $$PartsOfSpeechTableTableManager get partsOfSpeech =>
      $$PartsOfSpeechTableTableManager(_db.attachedDatabase, _db.partsOfSpeech);
  $$DimensionsTableTableManager get dimensions =>
      $$DimensionsTableTableManager(_db.attachedDatabase, _db.dimensions);
  $$MorphologicalRulesTableTableManager get morphologicalRules =>
      $$MorphologicalRulesTableTableManager(
        _db.attachedDatabase,
        _db.morphologicalRules,
      );
  $$LexemesTableTableManager get lexemes =>
      $$LexemesTableTableManager(_db.attachedDatabase, _db.lexemes);
  $$StandardFormPatternsTableTableManager get standardFormPatterns =>
      $$StandardFormPatternsTableTableManager(
        _db.attachedDatabase,
        _db.standardFormPatterns,
      );
}
