import 'package:flutter/material.dart';

import '../../../grammar/domain/rule_kind.dart';
import '../../../grammar/presentation/shared/migration_banner.dart';
import '../../../morphology/presentation/rules/rules_page.dart';

/// Lexicon → Derivations sub-tab (Phase 4 plan 04-07).
///
/// Reuses the shared [RulesPage] filtered to `kind=derivational` (D-37) and
/// shows a one-time migration banner explaining the relocation of
/// derivational rules from the old Morphology tab (D-24). The same
/// [RuleEditorDialog] that powers Grammar → Inflectional Rules powers this
/// page in derivational mode (input/output POS dropdowns per D-38).
///
/// See CONTEXT.md D-27 / D-36 / D-37 / D-38 for the design rationale.
class DerivationsPage extends StatelessWidget {
  const DerivationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MigrationBanner(
          settingsKey: 'ui.migration_v8_banner_dismissed.derivations',
        ),
        Expanded(child: RulesPage(kind: RuleKind.derivational)),
      ],
    );
  }
}
