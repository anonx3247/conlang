// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'construction_rule_dao.dart';

// ignore_for_file: type=lint
mixin _$ConstructionRuleDaoMixin on DatabaseAccessor<AppDatabase> {
  $PhraseConstructionsTable get phraseConstructions =>
      attachedDatabase.phraseConstructions;
  $ConstructionSlotsTable get constructionSlots =>
      attachedDatabase.constructionSlots;
  $ConstructionRulesTable get constructionRules =>
      attachedDatabase.constructionRules;
  $PartsOfSpeechTable get partsOfSpeech => attachedDatabase.partsOfSpeech;
  $ConstructionRulePOSTable get constructionRulePOS =>
      attachedDatabase.constructionRulePOS;
  ConstructionRuleDaoManager get managers => ConstructionRuleDaoManager(this);
}

class ConstructionRuleDaoManager {
  final _$ConstructionRuleDaoMixin _db;
  ConstructionRuleDaoManager(this._db);
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
  $$ConstructionRulesTableTableManager get constructionRules =>
      $$ConstructionRulesTableTableManager(
        _db.attachedDatabase,
        _db.constructionRules,
      );
  $$PartsOfSpeechTableTableManager get partsOfSpeech =>
      $$PartsOfSpeechTableTableManager(_db.attachedDatabase, _db.partsOfSpeech);
  $$ConstructionRulePOSTableTableManager get constructionRulePOS =>
      $$ConstructionRulePOSTableTableManager(
        _db.attachedDatabase,
        _db.constructionRulePOS,
      );
}
