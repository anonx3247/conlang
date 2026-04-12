// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'culture_dao.dart';

// ignore_for_file: type=lint
mixin _$CultureDaoMixin on DatabaseAccessor<AppDatabase> {
  $CulturePagesTable get culturePages => attachedDatabase.culturePages;
  CultureDaoManager get managers => CultureDaoManager(this);
}

class CultureDaoManager {
  final _$CultureDaoMixin _db;
  CultureDaoManager(this._db);
  $$CulturePagesTableTableManager get culturePages =>
      $$CulturePagesTableTableManager(_db.attachedDatabase, _db.culturePages);
}
