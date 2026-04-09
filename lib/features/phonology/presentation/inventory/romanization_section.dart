import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/romanization_dao.dart';
import '../../data/romanization_providers.dart';

/// Two-column editable table for defining IPA → Latin romanization mappings.
///
/// Each row shows one mapping with inline edit and delete controls. An "Add
/// mapping" button at the bottom lets users create new entries. A live preview
/// panel lets users type IPA text and see the romanized output immediately.
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

  // Preview field state.
  final _previewController = TextEditingController();

  @override
  void dispose() {
    _ipaController.dispose();
    _latinController.dispose();
    _previewController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  RomanizationDao? get _dao => ref.read(romanizationDaoProvider);

  void _startEdit(RomanizationMapping mapping) {
    setState(() {
      _editingId = mapping.id;
      _ipaController.text = mapping.ipaSymbol;
      _latinController.text = mapping.latinMapping;
    });
  }

  void _startAdd() {
    setState(() {
      _editingId = -1; // sentinel: new row
      _ipaController.clear();
      _latinController.clear();
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _ipaController.clear();
      _latinController.clear();
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
  // Live preview
  // ---------------------------------------------------------------------------

  String _applyPreview(
    String input,
    List<RomanizationMapping> mappings,
  ) {
    if (input.isEmpty || mappings.isEmpty) return input;

    final sorted = List<RomanizationMapping>.from(mappings)
      ..sort((a, b) => b.ipaSymbol.length.compareTo(a.ipaSymbol.length));

    var result = input;
    for (final m in sorted) {
      result = result.replaceAll(m.ipaSymbol, m.latinMapping);
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final mappingsAsync = ref.watch(romanizationMappingsProvider);

    return mappingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (mappings) => _buildContent(context, theme, colorScheme, mappings),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    List<RomanizationMapping> mappings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header.
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
                'Romanization Mappings',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(IPA \u2192 Latin script)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),

        // Table.
        if (mappings.isEmpty && _editingId == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No mappings defined. Add one to start romanizing IPA text.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          _buildTable(context, theme, colorScheme, mappings),

        const SizedBox(height: 8),

        // Add mapping button.
        if (_editingId == null)
          TextButton.icon(
            onPressed: _startAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add mapping'),
          ),

        const SizedBox(height: 24),

        // Live preview panel.
        _buildPreviewPanel(theme, colorScheme, mappings),
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
                  'IPA symbol',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Latin romanization',
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
              SizedBox(
                width: 160,
                child: Text(
                  mapping.ipaSymbol,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: colorScheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  mapping.latinMapping,
                  style: theme.textTheme.bodyMedium,
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
          // IPA symbol input.
          SizedBox(
            width: 152,
            child: TextField(
              controller: _ipaController,
              autofocus: true,
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

          // Latin romanization input.
          Expanded(
            child: TextField(
              controller: _latinController,
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

  Widget _buildPreviewPanel(
    ThemeData theme,
    ColorScheme colorScheme,
    List<RomanizationMapping> mappings,
  ) {
    final previewInput = _previewController.text;
    final previewOutput = _applyPreview(previewInput, mappings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Preview',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // IPA input.
            Expanded(
              child: TextField(
                controller: _previewController,
                decoration: const InputDecoration(
                  labelText: 'IPA input',
                  hintText: 'Type IPA here\u2026',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(
                Icons.arrow_forward,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),

            // Romanized output.
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  previewOutput.isEmpty ? '\u2014' : previewOutput,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: previewOutput.isEmpty
                        ? colorScheme.onSurface.withValues(alpha: 0.4)
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
