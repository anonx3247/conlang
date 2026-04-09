import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/romanization_dao.dart';
import '../../data/romanization_providers.dart';
import '../shared/ipa_keyboard/ipa_text_field.dart';

/// Two-column editable table for defining Latin letter → IPA romanization mappings.
///
/// Each row shows one mapping with inline edit and delete controls. An "Add
/// letter" button at the bottom lets users create new entries.
///
/// Columns are Latin-first: the Latin letter (romanization key) appears in the
/// first column, and the associated IPA sound in the second. This matches the
/// mental model of "I write 'sh', which sounds like /ʃ/".
///
/// Mappings are project-scoped and persisted in the project SQLite database via
/// [RomanizationDao]. The section is self-contained — it can be dropped into
/// any scrollable parent.
class RomanizationSection extends ConsumerStatefulWidget {
  const RomanizationSection({super.key});

  @override
  ConsumerState<RomanizationSection> createState() =>
      _RomanizationSectionState();
}

class _RomanizationSectionState extends ConsumerState<RomanizationSection> {
  // Row-level state: which row is being edited (by mapping id, or -1 for new).
  int? _editingId;

  // Controllers for the inline editing fields.
  final _ipaController = TextEditingController();
  final _latinController = TextEditingController();

  @override
  void dispose() {
    _ipaController.dispose();
    _latinController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  RomanizationDao? get _dao => ref.read(romanizationDaoProvider);

  void _startEdit(RomanizationMapping mapping) {
    setState(() {
      _editingId = mapping.id;
      _latinController.text = mapping.latinMapping;
      _ipaController.text = mapping.ipaSymbol;
    });
  }

  void _startAdd() {
    setState(() {
      _editingId = -1; // sentinel: new row
      _latinController.clear();
      _ipaController.clear();
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _latinController.clear();
      _ipaController.clear();
    });
  }

  Future<void> _saveEdit(RomanizationMapping? existing) async {
    final ipa = _ipaController.text.trim();
    final latin = _latinController.text.trim();
    if (ipa.isEmpty || latin.isEmpty) return;

    final dao = _dao;
    if (dao == null) return;

    if (existing == null) {
      // Insert new mapping.
      await dao.insertMapping(
        RomanizationMappingsCompanion.insert(
          ipaSymbol: ipa,
          latinMapping: latin,
        ),
      );
    } else {
      // Update existing mapping.
      await dao.updateMapping(
        existing.copyWith(ipaSymbol: ipa, latinMapping: latin),
      );
    }

    _cancelEdit();
  }

  Future<void> _deleteMapping(int id) async {
    await _dao?.deleteMapping(id);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final enabledAsync = ref.watch(romanizationEnabledProvider);
    final mappingsAsync = ref.watch(romanizationMappingsProvider);

    final enabled = enabledAsync.asData?.value ?? true;

    return mappingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (mappings) =>
          _buildContent(context, theme, colorScheme, mappings, enabled),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    List<RomanizationMapping> mappings,
    bool enabled,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with toggle.
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
          child: Row(
            children: [
              Icon(
                Icons.translate_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Romanization',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(Latin letters \u2192 IPA sounds)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const Spacer(),
              Text(
                'Enabled',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                value: enabled,
                onChanged: (val) => setRomanizationEnabled(ref, val),
              ),
            ],
          ),
        ),

        // Content: hidden when disabled.
        if (!enabled)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Romanization is disabled for this project.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.45),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else ...[
          // Table.
          if (mappings.isEmpty && _editingId == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No romanization letters defined yet. Add a Latin letter and associate its default IPA sound.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            )
          else
            _buildTable(context, theme, colorScheme, mappings),

          const SizedBox(height: 8),

          // Add letter button.
          if (_editingId == null)
            TextButton.icon(
              onPressed: _startAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add letter'),
            ),
        ],
      ],
    );
  }

  Widget _buildTable(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    List<RomanizationMapping> mappings,
  ) {
    return Column(
      children: [
        // Header row.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 160,
                child: Text(
                  'Latin letter',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'IPA sound (default)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 80), // Space for action buttons.
            ],
          ),
        ),

        // Existing mapping rows.
        ...mappings.map((mapping) => _buildMappingRow(
              context,
              theme,
              colorScheme,
              mapping,
            )),

        // New mapping row (when adding).
        if (_editingId == -1)
          _buildEditRow(context, theme, colorScheme, null),
      ],
    );
  }

  Widget _buildMappingRow(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    RomanizationMapping mapping,
  ) {
    final isEditing = _editingId == mapping.id;

    if (isEditing) {
      return _buildEditRow(context, theme, colorScheme, mapping);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: InkWell(
        onTap: () => _startEdit(mapping),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Latin letter — normal font (first column)
              SizedBox(
                width: 160,
                child: Text(
                  mapping.latinMapping,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              // IPA sound — monospace with primary color (second column)
              Expanded(
                child: Text(
                  mapping.ipaSymbol,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: colorScheme.primary,
                  ),
                ),
              ),
              // Edit / Delete buttons.
              SizedBox(
                width: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      tooltip: 'Edit',
                      onPressed: () => _startEdit(mapping),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: colorScheme.error,
                      ),
                      tooltip: 'Delete',
                      onPressed: () => _deleteMapping(mapping.id),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditRow(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    RomanizationMapping? existing,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // Latin letter input (first column — plain TextField, no IPA keyboard).
          SizedBox(
            width: 152,
            child: TextField(
              controller: _latinController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'sh',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              style: theme.textTheme.bodyMedium,
              onSubmitted: (_) => _saveEdit(existing),
            ),
          ),

          const SizedBox(width: 8),

          // IPA sound input (second column — IpaTextField with IPA keyboard).
          Expanded(
            child: IpaTextField(
              controller: _ipaController,
              decoration: const InputDecoration(
                hintText: '/ʃ/',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
              onSubmitted: (_) => _saveEdit(existing),
            ),
          ),

          const SizedBox(width: 8),

          // Save / Cancel.
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.check,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  tooltip: 'Save',
                  onPressed: () => _saveEdit(existing),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: 'Cancel',
                  onPressed: _cancelEdit,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
