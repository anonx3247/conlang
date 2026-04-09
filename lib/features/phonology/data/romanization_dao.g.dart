// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'romanization_dao.dart';

// ignore_for_file: type=lint
mixin _$RomanizationDaoMixin on DatabaseAccessor<AppDatabase> {
  $RomanizationMappingsTable get romanizationMappings =>
      attachedDatabase.romanizationMappings;
  RomanizationDaoManager get managers => RomanizationDaoManager(this);
}

class RomanizationDaoManager {
  final _$RomanizationDaoMixin _db;
  RomanizationDaoManager(this._db);
  $$RomanizationMappingsTableTableManager get romanizationMappings =>
      $$RomanizationMappingsTableTableManager(
        _db.attachedDatabase,
        _db.romanizationMappings,
      );
}
