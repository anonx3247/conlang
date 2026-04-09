// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'natural_class_dao.dart';

// ignore_for_file: type=lint
mixin _$NaturalClassDaoMixin on DatabaseAccessor<AppDatabase> {
  $NaturalClassesTable get naturalClasses => attachedDatabase.naturalClasses;
  NaturalClassDaoManager get managers => NaturalClassDaoManager(this);
}

class NaturalClassDaoManager {
  final _$NaturalClassDaoMixin _db;
  NaturalClassDaoManager(this._db);
  $$NaturalClassesTableTableManager get naturalClasses =>
      $$NaturalClassesTableTableManager(
        _db.attachedDatabase,
        _db.naturalClasses,
      );
}
