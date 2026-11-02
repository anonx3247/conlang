// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scratchpad_dao.dart';

// ignore_for_file: type=lint
mixin _$ScratchpadDaoMixin on DatabaseAccessor<AppDatabase> {
  $ScratchpadPhrasesTable get scratchpadPhrases =>
      attachedDatabase.scratchpadPhrases;
  ScratchpadDaoManager get managers => ScratchpadDaoManager(this);
}

class ScratchpadDaoManager {
  final _$ScratchpadDaoMixin _db;
  ScratchpadDaoManager(this._db);
  $$ScratchpadPhrasesTableTableManager get scratchpadPhrases =>
      $$ScratchpadPhrasesTableTableManager(
        _db.attachedDatabase,
        _db.scratchpadPhrases,
      );
}
