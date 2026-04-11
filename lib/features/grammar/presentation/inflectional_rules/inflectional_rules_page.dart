import 'package:flutter/material.dart';

import '../../../morphology/presentation/rules/rules_page.dart';
import '../../domain/rule_kind.dart';
import '../shared/migration_banner.dart';

/// Inflectional rules page — plan 04-05 real implementation.
///
/// Mounts the shared MigrationBanner (so users who are upgrading from v7
/// have a clear explanation of why their existing rules are now classified
/// as derivational) above a [RulesPage] filtered to
/// [RuleKind.inflectional].
///
/// The stub that plan 04-04 shipped (a placeholder Center + Icon) has been
/// replaced by this widget — see plan 04-05 Task 1 step 5.
class InflectionalRulesPage extends StatelessWidget {
  const InflectionalRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MigrationBanner(
          settingsKey: 'ui.migration_v8_banner_dismissed.inflectional',
        ),
        Expanded(
          child: RulesPage(kind: RuleKind.inflectional),
        ),
      ],
    );
  }
}
