// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paradigm_cell_override_dao.dart';

// ignore_for_file: type=lint
mixin _$ParadigmCellOverrideDaoMixin on DatabaseAccessor<AppDatabase> {
  $PartsOfSpeechTable get partsOfSpeech => attachedDatabase.partsOfSpeech;
  $MorphologicalRulesTable get morphologicalRules =>
      attachedDatabase.morphologicalRules;
  $LexemesTable get lexemes => attachedDatabase.lexemes;
  $ParadigmCellOverridesTable get paradigmCellOverrides =>
      attachedDatabase.paradigmCellOverrides;
  ParadigmCellOverrideDaoManager get managers =>
      ParadigmCellOverrideDaoManager(this);
}

class ParadigmCellOverrideDaoManager {
  final _$ParadigmCellOverrideDaoMixin _db;
  ParadigmCellOverrideDaoManager(this._db);
  $$PartsOfSpeechTableTableManager get partsOfSpeech =>
      $$PartsOfSpeechTableTableManager(_db.attachedDatabase, _db.partsOfSpeech);
  $$MorphologicalRulesTableTableManager get morphologicalRules =>
      $$MorphologicalRulesTableTableManager(
        _db.attachedDatabase,
        _db.morphologicalRules,
      );
  $$LexemesTableTableManager get lexemes =>
      $$LexemesTableTableManager(_db.attachedDatabase, _db.lexemes);
  $$ParadigmCellOverridesTableTableManager get paradigmCellOverrides =>
      $$ParadigmCellOverridesTableTableManager(
        _db.attachedDatabase,
        _db.paradigmCellOverrides,
      );
}
