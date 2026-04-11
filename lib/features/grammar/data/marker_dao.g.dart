// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marker_dao.dart';

// ignore_for_file: type=lint
mixin _$MarkerDaoMixin on DatabaseAccessor<AppDatabase> {
  $PartsOfSpeechTable get partsOfSpeech => attachedDatabase.partsOfSpeech;
  $MarkersTable get markers => attachedDatabase.markers;
  MarkerDaoManager get managers => MarkerDaoManager(this);
}

class MarkerDaoManager {
  final _$MarkerDaoMixin _db;
  MarkerDaoManager(this._db);
  $$PartsOfSpeechTableTableManager get partsOfSpeech =>
      $$PartsOfSpeechTableTableManager(_db.attachedDatabase, _db.partsOfSpeech);
  $$MarkersTableTableManager get markers =>
      $$MarkersTableTableManager(_db.attachedDatabase, _db.markers);
}
