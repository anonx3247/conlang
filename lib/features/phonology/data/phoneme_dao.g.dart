// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phoneme_dao.dart';

// ignore_for_file: type=lint
mixin _$PhonemeDaoMixin on DatabaseAccessor<AppDatabase> {
  $PhonemesTable get phonemes => attachedDatabase.phonemes;
  PhonemeDaoManager get managers => PhonemeDaoManager(this);
}

class PhonemeDaoManager {
  final _$PhonemeDaoMixin _db;
  PhonemeDaoManager(this._db);
  $$PhonemesTableTableManager get phonemes =>
      $$PhonemesTableTableManager(_db.attachedDatabase, _db.phonemes);
}
