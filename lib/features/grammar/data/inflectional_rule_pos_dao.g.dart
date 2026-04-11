// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inflectional_rule_pos_dao.dart';

// ignore_for_file: type=lint
mixin _$InflectionalRulePOSDaoMixin on DatabaseAccessor<AppDatabase> {
  $PartsOfSpeechTable get partsOfSpeech => attachedDatabase.partsOfSpeech;
  $MorphologicalRulesTable get morphologicalRules =>
      attachedDatabase.morphologicalRules;
  $InflectionalRulePOSTable get inflectionalRulePOS =>
      attachedDatabase.inflectionalRulePOS;
  InflectionalRulePOSDaoManager get managers =>
      InflectionalRulePOSDaoManager(this);
}

class InflectionalRulePOSDaoManager {
  final _$InflectionalRulePOSDaoMixin _db;
  InflectionalRulePOSDaoManager(this._db);
  $$PartsOfSpeechTableTableManager get partsOfSpeech =>
      $$PartsOfSpeechTableTableManager(_db.attachedDatabase, _db.partsOfSpeech);
  $$MorphologicalRulesTableTableManager get morphologicalRules =>
      $$MorphologicalRulesTableTableManager(
        _db.attachedDatabase,
        _db.morphologicalRules,
      );
  $$InflectionalRulePOSTableTableManager get inflectionalRulePOS =>
      $$InflectionalRulePOSTableTableManager(
        _db.attachedDatabase,
        _db.inflectionalRulePOS,
      );
}
