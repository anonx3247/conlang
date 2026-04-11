// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grammar_dao.dart';

// ignore_for_file: type=lint
mixin _$GrammarDaoMixin on DatabaseAccessor<AppDatabase> {
  $PartsOfSpeechTable get partsOfSpeech => attachedDatabase.partsOfSpeech;
  $DimensionsTable get dimensions => attachedDatabase.dimensions;
  GrammarDaoManager get managers => GrammarDaoManager(this);
}

class GrammarDaoManager {
  final _$GrammarDaoMixin _db;
  GrammarDaoManager(this._db);
  $$PartsOfSpeechTableTableManager get partsOfSpeech =>
      $$PartsOfSpeechTableTableManager(_db.attachedDatabase, _db.partsOfSpeech);
  $$DimensionsTableTableManager get dimensions =>
      $$DimensionsTableTableManager(_db.attachedDatabase, _db.dimensions);
}
