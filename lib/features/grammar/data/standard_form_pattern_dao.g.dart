// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'standard_form_pattern_dao.dart';

// ignore_for_file: type=lint
mixin _$StandardFormPatternDaoMixin on DatabaseAccessor<AppDatabase> {
  $PartsOfSpeechTable get partsOfSpeech => attachedDatabase.partsOfSpeech;
  $DimensionsTable get dimensions => attachedDatabase.dimensions;
  $StandardFormPatternsTable get standardFormPatterns =>
      attachedDatabase.standardFormPatterns;
  StandardFormPatternDaoManager get managers =>
      StandardFormPatternDaoManager(this);
}

class StandardFormPatternDaoManager {
  final _$StandardFormPatternDaoMixin _db;
  StandardFormPatternDaoManager(this._db);
  $$PartsOfSpeechTableTableManager get partsOfSpeech =>
      $$PartsOfSpeechTableTableManager(_db.attachedDatabase, _db.partsOfSpeech);
  $$DimensionsTableTableManager get dimensions =>
      $$DimensionsTableTableManager(_db.attachedDatabase, _db.dimensions);
  $$StandardFormPatternsTableTableManager get standardFormPatterns =>
      $$StandardFormPatternsTableTableManager(
        _db.attachedDatabase,
        _db.standardFormPatterns,
      );
}
