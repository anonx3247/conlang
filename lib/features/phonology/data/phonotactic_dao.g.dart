// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phonotactic_dao.dart';

// ignore_for_file: type=lint
mixin _$PhonotacticDaoMixin on DatabaseAccessor<AppDatabase> {
  $PhonotacticTemplatesTable get phonotacticTemplates =>
      attachedDatabase.phonotacticTemplates;
  $PhonotacticConstraintsTable get phonotacticConstraints =>
      attachedDatabase.phonotacticConstraints;
  PhonotacticDaoManager get managers => PhonotacticDaoManager(this);
}

class PhonotacticDaoManager {
  final _$PhonotacticDaoMixin _db;
  PhonotacticDaoManager(this._db);
  $$PhonotacticTemplatesTableTableManager get phonotacticTemplates =>
      $$PhonotacticTemplatesTableTableManager(
        _db.attachedDatabase,
        _db.phonotacticTemplates,
      );
  $$PhonotacticConstraintsTableTableManager get phonotacticConstraints =>
      $$PhonotacticConstraintsTableTableManager(
        _db.attachedDatabase,
        _db.phonotacticConstraints,
      );
}
