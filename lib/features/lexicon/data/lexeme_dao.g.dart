// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lexeme_dao.dart';

// ignore_for_file: type=lint
mixin _$LexemeDaoMixin on DatabaseAccessor<AppDatabase> {
  $PartsOfSpeechTable get partsOfSpeech => attachedDatabase.partsOfSpeech;
  $MorphologicalRulesTable get morphologicalRules =>
      attachedDatabase.morphologicalRules;
  $LexemesTable get lexemes => attachedDatabase.lexemes;
  $MorphologicalRuleExceptionsTable get morphologicalRuleExceptions =>
      attachedDatabase.morphologicalRuleExceptions;
  LexemeDaoManager get managers => LexemeDaoManager(this);
}

class LexemeDaoManager {
  final _$LexemeDaoMixin _db;
  LexemeDaoManager(this._db);
  $$PartsOfSpeechTableTableManager get partsOfSpeech =>
      $$PartsOfSpeechTableTableManager(_db.attachedDatabase, _db.partsOfSpeech);
  $$MorphologicalRulesTableTableManager get morphologicalRules =>
      $$MorphologicalRulesTableTableManager(
        _db.attachedDatabase,
        _db.morphologicalRules,
      );
  $$LexemesTableTableManager get lexemes =>
      $$LexemesTableTableManager(_db.attachedDatabase, _db.lexemes);
  $$MorphologicalRuleExceptionsTableTableManager
  get morphologicalRuleExceptions =>
      $$MorphologicalRuleExceptionsTableTableManager(
        _db.attachedDatabase,
        _db.morphologicalRuleExceptions,
      );
}
