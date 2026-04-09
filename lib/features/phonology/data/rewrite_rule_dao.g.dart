// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rewrite_rule_dao.dart';

// ignore_for_file: type=lint
mixin _$RewriteRuleDaoMixin on DatabaseAccessor<AppDatabase> {
  $RewriteRulesTable get rewriteRules => attachedDatabase.rewriteRules;
  RewriteRuleDaoManager get managers => RewriteRuleDaoManager(this);
}

class RewriteRuleDaoManager {
  final _$RewriteRuleDaoMixin _db;
  RewriteRuleDaoManager(this._db);
  $$RewriteRulesTableTableManager get rewriteRules =>
      $$RewriteRulesTableTableManager(_db.attachedDatabase, _db.rewriteRules);
}
