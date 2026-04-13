import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../data/construction_dao.dart';
import '../../data/construction_providers.dart';
import '../../domain/leipzig_catalog.dart';

/// Visual slot editor for a single phrase construction.
///
/// Shows a [ReorderableListView] of slot chips, each with a drag handle.
/// Supports adding new slots (gloss tag or POS-type) and deleting existing
/// ones immediately (no confirmation per UI-SPEC).
class SlotEditor extends ConsumerStatefulWidget {
  const SlotEditor({
    super.key,
    required this.constructionId,
  });

  final int constructionId;

  @override
  ConsumerState<SlotEditor> createState() => _SlotEditorState();
}

class _SlotEditorState extends ConsumerState<SlotEditor> {
  // 'gloss_tag' | 'pos'
  String _newSlotType = 'gloss_tag';
  String _newSlotValue = '';
  final _valueController = TextEditingController();
  bool _showAddSlotForm = false;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _addSlot(
    ConstructionDao dao,
    List<ConstructionSlot> existingSlots,
  ) async {
    final value = _newSlotValue.trim();
    if (value.isEmpty) return;
    await dao.insertSlot(
      ConstructionSlotsCompanion.insert(
        constructionId: widget.constructionId,
        slotType: _newSlotType,
        slotValue: value,
        ordering: Value(existingSlots.length),
      ),
    );
    setState(() {
      _newSlotValue = '';
      _valueController.clear();
      _showAddSlotForm = false;
    });
  }

  Future<void> _deleteSlot(ConstructionDao dao, int slotId) async {
    await dao.deleteSlot(slotId);
  }

  Future<void> _reorderSlots(
    ConstructionDao dao,
    List<ConstructionSlot> slots,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final reordered = List<ConstructionSlot>.from(slots);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    await dao.reorderSlots(reordered);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slotsAsync = ref.watch(constructionSlotsProvider(widget.constructionId));
    final dao = ref.read(constructionDaoProvider);
    final posListAsync = ref.watch(posListProvider);
    final posList = posListAsync.asData?.value ?? [];

    // The Leipzig gloss abbreviations catalog imported from leipzig_catalog.dart
    final glossAbbreviations = leipzigGlossAbbreviations;

    return slotsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('Error: $e'),
      data: (slots) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section label
            Text(
              'Slots',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // Slot list or empty state
            if (slots.isEmpty && !_showAddSlotForm)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Add slots to define this construction\'s pattern.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              )
            else if (slots.isNotEmpty) ...[
              SizedBox(
                // Enough height for all chips + padding
                height: (slots.length * 48.0).clamp(48.0, 300.0),
                child: ReorderableListView.builder(
                  itemCount: slots.length,
                  onReorder: dao == null
                      ? (int a, int b) {}
                      : (oldIndex, newIndex) => _reorderSlots(
                            dao,
                            slots,
                            oldIndex,
                            newIndex,
                          ),
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    return _SlotChip(
                      key: ValueKey(slot.id),
                      slot: slot,
                      onDelete: dao == null
                          ? null
                          : () => _deleteSlot(dao, slot.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Add Slot form (inline)
            if (_showAddSlotForm) ...[
              const SizedBox(height: 8),
              _AddSlotForm(
                slotType: _newSlotType,
                value: _newSlotValue,
                valueController: _valueController,
                posList: posList,
                leipzigGlossAbbreviations: glossAbbreviations,
                onSlotTypeChanged: (type) => setState(() {
                  _newSlotType = type;
                  _newSlotValue = '';
                  _valueController.clear();
                }),
                onValueChanged: (v) => setState(() => _newSlotValue = v),
                onAdd: dao == null
                    ? null
                    : () => _addSlot(dao, slots),
                onCancel: () => setState(() {
                  _showAddSlotForm = false;
                  _newSlotValue = '';
                  _valueController.clear();
                }),
              ),
              const SizedBox(height: 8),
            ],

            // "Add Slot" button
            if (!_showAddSlotForm)
              OutlinedButton.icon(
                onPressed: () => setState(() => _showAddSlotForm = true),
                icon: const Icon(Icons.add),
                label: const Text('Add Slot'),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Slot chip widget
// ---------------------------------------------------------------------------

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    super.key,
    required this.slot,
    required this.onDelete,
  });

  final ConstructionSlot slot;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label =
        slot.label?.isNotEmpty == true ? slot.label! : slot.slotValue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            avatar: Icon(
              Icons.drag_handle,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            label: Text(label),
            deleteIcon: Icon(
              Icons.close,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            onDeleted: onDelete,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add slot form
// ---------------------------------------------------------------------------

class _AddSlotForm extends StatelessWidget {
  const _AddSlotForm({
    required this.slotType,
    required this.value,
    required this.valueController,
    required this.posList,
    required this.leipzigGlossAbbreviations,
    required this.onSlotTypeChanged,
    required this.onValueChanged,
    required this.onAdd,
    required this.onCancel,
  });

  final String slotType;
  final String value;
  final TextEditingController valueController;
  final List<PartsOfSpeechData> posList;
  final List<String> leipzigGlossAbbreviations;
  final ValueChanged<String> onSlotTypeChanged;
  final ValueChanged<String> onValueChanged;
  final VoidCallback? onAdd;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slot type selector
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'gloss_tag',
                label: Text('Gloss Tag'),
              ),
              ButtonSegment(
                value: 'pos',
                label: Text('Part of Speech'),
              ),
            ],
            selected: {slotType},
            onSelectionChanged: (set) => onSlotTypeChanged(set.first),
          ),
          const SizedBox(height: 12),

          // Value field
          if (slotType == 'gloss_tag')
            Autocomplete<String>(
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return leipzigGlossAbbreviations.where(
                  (abbr) => abbr
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase()),
                );
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLength: 20,
                  decoration: InputDecoration(
                    labelText: 'Gloss tag',
                    hintText: 'e.g. NEG, DEF, PROG',
                    counterText: '',
                    border: const OutlineInputBorder(),
                    errorText: controller.text.length > 20
                        ? 'Gloss tags must be 20 characters or fewer.'
                        : null,
                  ),
                  onChanged: onValueChanged,
                  onSubmitted: (_) => onAdd?.call(),
                );
              },
              onSelected: onValueChanged,
            )
          else
            DropdownButtonFormField<String>(
              initialValue: value.isNotEmpty ? value : null,
              hint: const Text('Select Part of Speech'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Part of Speech',
              ),
              items: posList
                  .map((pos) => DropdownMenuItem(
                        value: pos.abbreviation,
                        child: Text('${pos.name} (${pos.abbreviation})'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onValueChanged(v);
              },
            ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              FilledButton(
                onPressed: value.isNotEmpty ? onAdd : null,
                child: const Text('Add'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
