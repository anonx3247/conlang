// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paradigm_cell_override_dao.dart';

// ignore_for_file: type=lint
mixin _$ParadigmCellOverrideDaoMixin on DatabaseAccessor<AppDatabase> {
  $LexemesTable get lexemes => attachedDatabase.lexemes;
  $ParadigmCellOverridesTable get paradigmCellOverrides =>
      attachedDatabase.paradigmCellOverrides;
  ParadigmCellOverrideDaoManager get managers =>
      ParadigmCellOverrideDaoManager(this);
}

class ParadigmCellOverrideDaoManager {
  final _$ParadigmCellOverrideDaoMixin _db;
  ParadigmCellOverrideDaoManager(this._db);
  $$LexemesTableTableManager get lexemes =>
      $$LexemesTableTableManager(_db.attachedDatabase, _db.lexemes);
  $$ParadigmCellOverridesTableTableManager get paradigmCellOverrides =>
      $$ParadigmCellOverridesTableTableManager(
        _db.attachedDatabase,
        _db.paradigmCellOverrides,
      );
}
