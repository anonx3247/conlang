import 'package:flutter/material.dart';

import '../../../../db/app_database.dart' as db;
import '../../../grammar/domain/feature_bindings.dart';
import '../../../grammar/domain/rule_kind.dart';
import 'rule_editor/rule_editor_body.dart';

// ---------------------------------------------------------------------------
// RuleEditorDialog — thin dialog shell (D-13/D-14 refactor)
//
// This file is intentionally kept small (<200 lines). All form state,
// validation, and save logic lives in rule_editor/rule_editor_body.dart.
// The extracted form-state models live in rule_editor/form_state_models.dart.
// ---------------------------------------------------------------------------

/// Hybrid rule editor dialog for creating and editing morphological rules.
///
/// Opens as a large dialog wrapping [RuleEditorBody].
///
/// Pass [existing] to open in edit mode (pre-populated from the Drift row);
/// otherwise opens in create mode.
///
/// Plan 04-05: dialog is kind-aware. In inflectional mode it renders a
/// "Target POS" dropdown + a row of FilterChips per grammatical dimension
/// (feature-binding picker, D-42) plus a live tiebreak banner (D-12). In
/// derivational mode it renders Input/Output POS dropdowns (D-38) and hides
/// the chip rows.
///
/// D-100/D-101 (plan 04-18-05): when [markerId] is non-null, the dialog
/// opens in marker mode — the "Leave as unmarked" checkbox is pre-checked,
/// the operations section and preview panel are hidden, and saving writes to
/// [MarkerDao] instead of [MorphologyDao].
class RuleEditorDialog extends StatelessWidget {
  const RuleEditorDialog({
    super.key,
    required this.kind,
    this.existing,
    this.preFilledBindings,
    this.preFilledPosIds,
    this.markerId,
    this.markerBindings,
  });

  /// Whether this dialog edits an inflectional or derivational rule.
  /// Required — callers must explicitly choose the kind (D-40 / plan 04-05).
  final RuleKind kind;

  /// Drift data row. When non-null, the dialog opens in edit mode.
  final db.MorphologicalRule? existing;

  /// D-51: When provided and [existing] is null and [kind] is inflectional,
  /// pre-fills the dimension chip picker with these (dimId -> levelId)
  /// bindings. Used when the user clicks an empty paradigm cell in the
  /// Grammar > Inflections sub-tab (D-52 ruleEditor click mode) so the
  /// new-rule dialog opens with the clicked cell's features already bound.
  /// Ignored for derivational kind and when editing an existing rule.
  final Map<int, int>? preFilledBindings;

  /// G-07 / plan 04-20-01: When provided and [existing] is null and [kind]
  /// is inflectional, pre-selects these POS IDs in the inflectional POS
  /// FilterChips so the user does not need to manually re-select the POS
  /// they are already looking at when clicking an empty paradigm cell.
  /// Ignored for derivational kind and when editing an existing rule.
  final Set<int>? preFilledPosIds;

  /// D-100 (plan 04-18-05): when non-null, the dialog opens in marker edit
  /// mode with [_leaveAsUnmarked] pre-checked and [markerBindings] loaded
  /// into the feature-binding picker.
  final int? markerId;

  /// D-100 (plan 04-18-05): pre-loaded bindings when editing an existing
  /// marker. Only meaningful when [markerId] is non-null.
  final FeatureBindings? markerBindings;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: RuleEditorBody(
        kind: kind,
        existing: existing,
        preFilledBindings: preFilledBindings,
        preFilledPosIds: preFilledPosIds,
        markerId: markerId,
        markerBindings: markerBindings,
      ),
    );
  }
}
