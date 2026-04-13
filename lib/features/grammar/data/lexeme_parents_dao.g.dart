// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lexeme_parents_dao.dart';

// ignore_for_file: type=lint
mixin _$LexemeParentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PartsOfSpeechTable get partsOfSpeech => attachedDatabase.partsOfSpeech;
  $MorphologicalRulesTable get morphologicalRules =>
      attachedDatabase.morphologicalRules;
  $LexemesTable get lexemes => attachedDatabase.lexemes;
  $LexemeParentsTable get lexemeParents => attachedDatabase.lexemeParents;
  LexemeParentsDaoManager get managers => LexemeParentsDaoManager(this);
}

class LexemeParentsDaoManager {
  final _$LexemeParentsDaoMixin _db;
  LexemeParentsDaoManager(this._db);
  $$PartsOfSpeechTableTableManager get partsOfSpeech =>
      $$PartsOfSpeechTableTableManager(_db.attachedDatabase, _db.partsOfSpeech);
  $$MorphologicalRulesTableTableManager get morphologicalRules =>
      $$MorphologicalRulesTableTableManager(
        _db.attachedDatabase,
        _db.morphologicalRules,
      );
  $$LexemesTableTableManager get lexemes =>
      $$LexemesTableTableManager(_db.attachedDatabase, _db.lexemes);
  $$LexemeParentsTableTableManager get lexemeParents =>
      $$LexemeParentsTableTableManager(_db.attachedDatabase, _db.lexemeParents);
}
