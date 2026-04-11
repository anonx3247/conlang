import 'package:flutter/material.dart';

import '../../data/dimension_templates.dart';

/// Shows the dimension template picker modal.
///
/// Returns the chosen [DimensionTemplate], or null if the user cancels /
/// dismisses the dialog. D-05 two-step picker: user picks a template
/// (or a per-group "Custom" blank entry), then the caller inserts the
/// dimension onto the selected POS.
Future<DimensionTemplate?> showDimensionTemplatePicker(
    BuildContext context) {
  return showDialog<DimensionTemplate>(
    context: context,
    builder: (_) => const _DimensionTemplatePickerDialog(),
  );
}

class _DimensionTemplatePickerDialog extends StatefulWidget {
  const _DimensionTemplatePickerDialog();

  @override
  State<_DimensionTemplatePickerDialog> createState() =>
      _DimensionTemplatePickerDialogState();
}

class _DimensionTemplatePickerDialogState
    extends State<_DimensionTemplatePickerDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final lowered = _search.toLowerCase().trim();

    // Group templates by `group` field, preserving their source order so
    // the picker matches the order in `dimensionTemplates` (Gender, Number,
    // Case, Tense, Aspect, Person, Mood, Voice, Definiteness).
    final groups = <String, List<DimensionTemplate>>{};
    for (final t in dimensionTemplates) {
      if (lowered.isNotEmpty &&
          !t.name.toLowerCase().contains(lowered) &&
          !t.group.toLowerCase().contains(lowered) &&
          !t.description.toLowerCase().contains(lowered)) {
        continue;
      }
      groups.putIfAbsent(t.group, () => <DimensionTemplate>[]).add(t);
    }

    // Append a Custom (blank) entry per visible group so users can start
    // from scratch without a preset. (D-05 — always show custom-blank.)
    for (final g in groups.keys.toList()) {
      groups[g]!.add(DimensionTemplate(
        id: 'custom.${g.toLowerCase()}',
        group: g,
        name: 'Custom',
        levels: const [],
        description: 'Start from scratch — no preset levels.',
      ));
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Add Dimension', style: theme.textTheme.titleLarge),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                  hintText: 'Search templates…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No templates match your search.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  else
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.2,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      for (final t in entry.value)
                        _templateCard(t, theme, cs, context),
                    ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _templateCard(
    DimensionTemplate t,
    ThemeData theme,
    ColorScheme cs,
    BuildContext ctx,
  ) {
    return Tooltip(
      message: t.description,
      waitDuration: const Duration(milliseconds: 500),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: () => Navigator.of(ctx).pop(t),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (t.levels.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    t.levels.map((l) => l.abbr).join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
