// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'morphology_dao.dart';

// ignore_for_file: type=lint
mixin _$MorphologyDaoMixin on DatabaseAccessor<AppDatabase> {
  $MorphologicalRulesTable get morphologicalRules =>
      attachedDatabase.morphologicalRules;
  $MorphologicalRuleExceptionsTable get morphologicalRuleExceptions =>
      attachedDatabase.morphologicalRuleExceptions;
  MorphologyDaoManager get managers => MorphologyDaoManager(this);
}

class MorphologyDaoManager {
  final _$MorphologyDaoMixin _db;
  MorphologyDaoManager(this._db);
  $$MorphologicalRulesTableTableManager get morphologicalRules =>
      $$MorphologicalRulesTableTableManager(
        _db.attachedDatabase,
        _db.morphologicalRules,
      );
  $$MorphologicalRuleExceptionsTableTableManager
  get morphologicalRuleExceptions =>
      $$MorphologicalRuleExceptionsTableTableManager(
        _db.attachedDatabase,
        _db.morphologicalRuleExceptions,
      );
}
