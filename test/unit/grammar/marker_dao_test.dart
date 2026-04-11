import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/marker_dao.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MarkerDao dao;
  late int posNounId;
  late int posVerbId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.markerDao;
    posNounId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    posVerbId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('MarkerDao', () {
    test('insertMarker writes a row with the given bindings', () async {
      final id = await dao.insertMarker(
        posId: posNounId,
        bindings: const FeatureBindings(pos: [], dims: {5: 2}),
      );
      expect(id, greaterThan(0));

      final rows = await db.select(db.markers).get();
      expect(rows, hasLength(1));
      expect(rows.first.posId, equals(posNounId));
      expect(rows.first.featureBindings.dims, equals({5: 2}));
    });

    test('watchMarkersForPos emits only markers for the requested POS',
        () async {
      await dao.insertMarker(
        posId: posNounId,
        bindings: const FeatureBindings(pos: [], dims: {5: 2}),
      );
      await dao.insertMarker(
        posId: posNounId,
        bindings: const FeatureBindings(pos: [], dims: {7: 1}),
      );
      await dao.insertMarker(
        posId: posVerbId,
        bindings: const FeatureBindings(pos: [], dims: {9: 3}),
      );

      final nounMarkers = await dao.watchMarkersForPos(posNounId).first;
      expect(nounMarkers, hasLength(2));
      expect(
        nounMarkers.map((m) => m.bindings.dims).toList(),
        equals([
          {5: 2},
          {7: 1},
        ]),
      );

      final verbMarkers = await dao.watchMarkersForPos(posVerbId).first;
      expect(verbMarkers, hasLength(1));
      expect(verbMarkers.first.bindings.dims, equals({9: 3}));
    });

    test('deleteMarker removes the row and the stream reflects the removal',
        () async {
      final id = await dao.insertMarker(
        posId: posNounId,
        bindings: const FeatureBindings(pos: [], dims: {5: 2}),
      );

      final removed = await dao.deleteMarker(id);
      expect(removed, equals(1));

      final list = await dao.watchMarkersForPos(posNounId).first;
      expect(list, isEmpty);
    });

    test('updateMarker replaces the feature bindings on an existing row',
        () async {
      final id = await dao.insertMarker(
        posId: posNounId,
        bindings: const FeatureBindings(pos: [], dims: {5: 2}),
      );

      await dao.updateMarker(
        id,
        const FeatureBindings(pos: [], dims: {5: 3, 7: 4}),
      );

      final list = await dao.watchMarkersForPos(posNounId).first;
      expect(list, hasLength(1));
      expect(list.first.id, equals(id));
      expect(list.first.bindings.dims, equals({5: 3, 7: 4}));
    });
  });
}
