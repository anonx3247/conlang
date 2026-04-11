import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart' hide MorphologicalRule;
import '../../../morphology/data/morphology_providers.dart';
import '../../../phonology/data/romanization_providers.dart';
import '../../data/lexeme_providers.dart';

/// Visual derivation tree widget.
///
/// Computes derived forms on-the-fly via [computedDerivedFormsProvider]
/// (backed by `MorphologyEngine`) — no stored derived-form rows are read.
/// This satisfies LEX-02: "derived words appear automatically" whenever
/// morphological rules are active, without any separate storage trigger.
///
/// Exception overrides (per D-05) are shown in [Colors.amber] with an
/// "Exception" badge; the engine-computed form is shown in normal style.
///
/// Plan 04-14 extensions:
///   - D-64 / G-15: each derived row shows an output POS abbreviation
///     badge next to the form (`[N]`, `[V]`, ...). The abbreviation comes
///     from the rule's outputPos row.
///   - D-57 / G-14: each row has an inline meaning TextField. Typing into
///     an empty field + onSubmitted promotes the derivation via
///     `LexemeDao.promoteDerivation`; clearing an existing value opens a
///     demote confirmation dialog.
///   - D-58 / G-14: promoted + rule-linked rows show a Tooltip that reads
///     `linked to rule "<name>"`. Tapping the pencil/edit icon opens an
///     AlertDialog warning the user that editing the form will unlink it
///     from the rule; confirming calls `LexemeDao.detachFromRule` with
///     the new rom + ipa.
class DerivationTreeWidget extends ConsumerWidget {
  const DerivationTreeWidget({
    super.key,
    required this.rootIpa,
    required this.rootId,
  });

  final String rootIpa;
  final int rootId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final romanize = ref.watch(romanizeProvider);
    final derivedForms = ref.watch(computedDerivedFormsProvider(rootId));
    final exceptionsAsync = ref.watch(exceptionsForLexemeProvider(rootId));
    final exceptions = exceptionsAsync.asData?.value ?? [];
    final allLexemes =
        ref.watch(allLexemeListProvider).asData?.value ?? const <Lexeme>[];
    final rulesAsync = ref.watch(morphologicalRuleListProvider);
    final rules = rulesAsync.asData?.value ?? const [];
    final posListAsync = ref.watch(posListProvider);
    final posList = posListAsync.asData?.value ?? const <PartsOfSpeechData>[];

    // Build a map from ruleId -> overrideForm for O(1) lookup.
    final exceptionMap = {
      for (final e in exceptions) e.ruleId: e.overrideForm,
    };

    final romanizedRoot = romanize(rootIpa);
    final showRomanizedRoot = romanizedRoot.isNotEmpty && romanizedRoot != rootIpa;

    // Resolve already-promoted (parent, rule) pairs so a computed row
    // whose Lexeme twin already exists is rendered as the promoted row
    // (with the user's meaning pre-filled) rather than as two separate
    // entries.
    Lexeme? promotedLexemeFor(int ruleId) {
      for (final lx in allLexemes) {
        if (lx.derivedFromLexemeId == rootId &&
            lx.derivedViaRuleId == ruleId) {
          return lx;
        }
      }
      return null;
    }

    String? posAbbrForRuleId(int ruleId) {
      for (final r in rules) {
        if (r.id == ruleId && r.outputPosId != null) {
          for (final pos in posList) {
            if (pos.id == r.outputPosId) return pos.abbreviation;
          }
        }
      }
      return null;
    }

    String ruleNameFor(int ruleId) {
      for (final r in rules) {
        if (r.id == ruleId) return r.name;
      }
      return 'Rule #$ruleId';
    }

    // Build the rendered rows. Each row mirrors either a computed-only
    // derivation result or a promoted Lexeme with the same (parent, rule)
    // pair — never both.
    final rows = <Widget>[];
    for (final result in derivedForms) {
      final overrideForm = exceptionMap[result.ruleId];
      final hasException = overrideForm != null;
      final promoted = promotedLexemeFor(result.ruleId);

      final ipa = hasException ? overrideForm : result.derivedIpa;
      final romanized = romanize(ipa);
      final showRomanized = romanized.isNotEmpty && romanized != ipa;

      rows.add(_DerivedRow(
        parentLexemeId: rootId,
        ruleId: result.ruleId,
        ruleName: result.ruleName,
        computedIpa: ipa,
        displayLabel: showRomanized ? romanized : ipa,
        displayIpaSub: showRomanized ? '[$ipa]' : null,
        posAbbr: posAbbrForRuleId(result.ruleId),
        isException: hasException,
        promoted: promoted,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                'Derivations',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${derivedForms.length} derived form${derivedForms.length == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (derivedForms.isEmpty)
          Text(
            'No derivations. Add morphological rules to see derived forms.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TreeNode(
                label: showRomanizedRoot ? romanizedRoot : rootIpa,
                sublabel: showRomanizedRoot ? '[$rootIpa]' : null,
                level: 0,
                isException: false,
                theme: theme,
              ),
              ...rows,
            ],
          ),
      ],
    );
  }
}

/// A single derived-form row in the tree.
///
/// Encapsulates the POS badge, form display, link-to-rule affordance,
/// inline meaning field, and the form-edit / detach flow.
class _DerivedRow extends ConsumerStatefulWidget {
  const _DerivedRow({
    required this.parentLexemeId,
    required this.ruleId,
    required this.ruleName,
    required this.computedIpa,
    required this.displayLabel,
    required this.displayIpaSub,
    required this.posAbbr,
    required this.isException,
    required this.promoted,
  });

  final int parentLexemeId;
  final int ruleId;
  final String ruleName;
  final String computedIpa;
  final String displayLabel;
  final String? displayIpaSub;
  final String? posAbbr;
  final bool isException;
  final Lexeme? promoted;

  @override
  ConsumerState<_DerivedRow> createState() => _DerivedRowState();
}

class _DerivedRowState extends ConsumerState<_DerivedRow> {
  late final TextEditingController _meaningCtrl;
  String? _lastSavedMeaning;

  @override
  void initState() {
    super.initState();
    _meaningCtrl =
        TextEditingController(text: widget.promoted?.meaning ?? '');
    _lastSavedMeaning = widget.promoted?.meaning;
  }

  @override
  void didUpdateWidget(covariant _DerivedRow old) {
    super.didUpdateWidget(old);
    final newMeaning = widget.promoted?.meaning ?? '';
    if (newMeaning != _meaningCtrl.text &&
        newMeaning != _lastSavedMeaning) {
      _meaningCtrl.text = newMeaning;
      _lastSavedMeaning = widget.promoted?.meaning;
    }
  }

  @override
  void dispose() {
    _meaningCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleMeaningSubmit(String value) async {
    final trimmed = value.trim();
    final dao = ref.read(lexemeDaoProvider);
    if (dao == null) return;

    final currentPromoted = widget.promoted;
    if (currentPromoted == null && trimmed.isNotEmpty) {
      // D-57: promote the computed row.
      await dao.promoteDerivation(
        parentId: widget.parentLexemeId,
        ruleId: widget.ruleId,
        gloss: trimmed,
      );
      _lastSavedMeaning = trimmed;
      return;
    }

    if (currentPromoted != null && trimmed.isEmpty) {
      // D-57: clearing the meaning demotes — confirm first.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove derivation?'),
          content: const Text(
            'Remove this derivation from the dictionary? The row can be '
            're-promoted later by typing a meaning into the field again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await dao.demoteDerivation(lexemeId: currentPromoted.id);
        _lastSavedMeaning = null;
      } else {
        // Restore the previous meaning.
        _meaningCtrl.text = _lastSavedMeaning ?? '';
      }
      return;
    }

    if (currentPromoted != null && trimmed.isNotEmpty) {
      // D-58: meaning-only edits must NEVER touch derivedViaRuleId. Use a
      // bare update that writes only the meaning column.
      final db = currentPromoted;
      await (dao.update(dao.lexemes)
            ..where((t) => t.id.equals(db.id)))
          .write(LexemesCompanion(meaning: Value(trimmed)));
      _lastSavedMeaning = trimmed;
    }
  }

  Future<void> _handleFormEdit() async {
    final currentPromoted = widget.promoted;
    if (currentPromoted == null) {
      // Unpromoted rows have no editable form — the form is recomputed
      // from the rule. Show a snackbar hint instead of opening a dialog.
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Add a meaning first to promote this derivation before '
            'editing its form.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // D-58: implicit-detach warning. Only rule-linked promoted rows need
    // the warning — detached rows can be edited freely.
    if (currentPromoted.derivedViaRuleId != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unlink from rule?'),
          content: Text(
            'Editing this form will unlink it from rule "${widget.ruleName}". '
            'The row will become standalone — future edits to the rule will '
            'no longer update this form. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Unlink and edit'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    // Open a minimal form-edit dialog.
    final ipaCtrl = TextEditingController(text: widget.computedIpa);
    final romCtrl = TextEditingController(
      text: currentPromoted.romanization ?? '',
    );
    final edited = await showDialog<_FormEditResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit derived form'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipaCtrl,
              decoration: const InputDecoration(labelText: 'IPA'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: romCtrl,
              decoration: const InputDecoration(labelText: 'Romanization'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(
              _FormEditResult(
                ipa: ipaCtrl.text.trim(),
                rom: romCtrl.text.trim(),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (edited == null) return;

    final dao = ref.read(lexemeDaoProvider);
    if (dao == null) return;
    await dao.detachFromRule(
      lexemeId: currentPromoted.id,
      newIpa: edited.ipa,
      newRom: edited.rom.isEmpty ? null : edited.rom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final promoted = widget.promoted;
    final linkActive =
        promoted != null && promoted.derivedViaRuleId != null;

    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 6, top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Connector line — matches _TreeNode level=1 styling.
          Container(
            width: 12,
            height: 1,
            color: cs.outlineVariant,
            margin: const EdgeInsets.only(right: 4),
          ),
          // POS badge (D-64).
          if (widget.posAbbr != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '[${widget.posAbbr}]',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.7),
                  letterSpacing: 0.4,
                ),
              ),
            ),
          // Form display — label + optional IPA sublabel.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.displayLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color:
                            widget.isException ? Colors.amber : cs.onSurface,
                        fontWeight: widget.isException
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.ruleName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.55),
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (widget.isException) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Exception',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: Colors.amber,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (widget.displayIpaSub != null)
                  Text(
                    widget.displayIpaSub!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Linked-to-rule Tooltip icon (D-58).
          if (linkActive)
            Tooltip(
              message: 'linked to rule "${widget.ruleName}"',
              child: Icon(Icons.link, size: 14, color: cs.primary),
            ),
          const SizedBox(width: 6),
          // Inline meaning TextField.
          SizedBox(
            width: 140,
            child: TextField(
              controller: _meaningCtrl,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Add meaning to save…',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              onSubmitted: _handleMeaningSubmit,
            ),
          ),
          const SizedBox(width: 4),
          // Form-edit affordance (D-58 detach warning entry point).
          IconButton(
            icon: const Icon(Icons.edit, size: 14),
            tooltip: 'Edit form',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: _handleFormEdit,
          ),
        ],
      ),
    );
  }
}

class _FormEditResult {
  const _FormEditResult({required this.ipa, required this.rom});
  final String ipa;
  final String rom;
}

/// Root-level tree node (reused for the parent word).
class _TreeNode extends StatelessWidget {
  const _TreeNode({
    required this.label,
    required this.level,
    required this.isException,
    required this.theme,
    this.sublabel,
    this.ipaLabel,
  });

  final String label;
  final String? sublabel;
  final String? ipaLabel;
  final int level;
  final bool isException;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final indent = level * 24.0;

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (level > 0) ...[
            Container(
              width: 12,
              height: 1,
              color: cs.outlineVariant,
              margin: const EdgeInsets.only(right: 4),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: isException ? Colors.amber : cs.onSurface,
                    fontWeight:
                        isException ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (ipaLabel != null)
                  Text(
                    ipaLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                if (sublabel != null)
                  Text(
                    sublabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      color: isException
                          ? Colors.amber.withValues(alpha: 0.8)
                          : cs.onSurface.withValues(alpha: 0.55),
                      letterSpacing: 0.3,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
