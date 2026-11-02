// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'construction_dao.dart';

// ignore_for_file: type=lint
mixin _$ConstructionDaoMixin on DatabaseAccessor<AppDatabase> {
  $PhraseConstructionsTable get phraseConstructions =>
      attachedDatabase.phraseConstructions;
  $ConstructionSlotsTable get constructionSlots =>
      attachedDatabase.constructionSlots;
  ConstructionDaoManager get managers => ConstructionDaoManager(this);
}

class ConstructionDaoManager {
  final _$ConstructionDaoMixin _db;
  ConstructionDaoManager(this._db);
  $$PhraseConstructionsTableTableManager get phraseConstructions =>
      $$PhraseConstructionsTableTableManager(
        _db.attachedDatabase,
        _db.phraseConstructions,
      );
  $$ConstructionSlotsTableTableManager get constructionSlots =>
      $$ConstructionSlotsTableTableManager(
        _db.attachedDatabase,
        _db.constructionSlots,
      );
}
