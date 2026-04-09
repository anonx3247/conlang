import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'word_creation_form.dart';
import 'word_detail_panel.dart';
import 'word_list_panel.dart';

/// Dictionary page — master-detail layout for the lexicon.
///
/// Layout:
///   - Left: [WordListPanel] (fixed 280px, surfaceContainer background)
///   - Divider: 1px outlineVariant
///   - Right: [WordDetailPanel] / [WordCreationForm] / empty state
///
/// Supports deep-link navigation via GoRouter query params:
///   `/lexicon/dictionary?create=true&meaning=water`
/// opens the creation form with "water" pre-filled in the meaning field (D-16).
class DictionaryPage extends ConsumerStatefulWidget {
  const DictionaryPage({
    super.key,
    this.createWithMeaning,
  });

  /// When non-null, automatically open the word creation form and pre-fill
  /// the meaning field with this value. Set by GoRouter from `?create=true&meaning=X`.
  final String? createWithMeaning;

  @override
  ConsumerState<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends ConsumerState<DictionaryPage> {
  int? _selectedLexemeId;
  bool _isCreating = false;
  String? _prefillMeaning;

  @override
  void initState() {
    super.initState();
    if (widget.createWithMeaning != null) {
      _isCreating = true;
      _prefillMeaning = widget.createWithMeaning;
    }
  }

  @override
  void didUpdateWidget(DictionaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.createWithMeaning != null &&
        widget.createWithMeaning != oldWidget.createWithMeaning) {
      setState(() {
        _isCreating = true;
        _prefillMeaning = widget.createWithMeaning;
        _selectedLexemeId = null;
      });
    }
  }

  void _onWordSelected(int id) {
    setState(() {
      _selectedLexemeId = id;
      _isCreating = false;
      _prefillMeaning = null;
    });
  }

  void _onAddRoot() {
    setState(() {
      _isCreating = true;
      _selectedLexemeId = null;
      _prefillMeaning = null;
    });
  }

  void _onFormDone() {
    // Clear query params by navigating to the clean route.
    context.go('/lexicon/dictionary');
    setState(() {
      _isCreating = false;
      _prefillMeaning = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget rightPanel;
    if (_isCreating) {
      rightPanel = WordCreationForm(
        prefillMeaning: _prefillMeaning,
        onCancel: _onFormDone,
        onSaved: _onFormDone,
      );
    } else if (_selectedLexemeId != null) {
      rightPanel = WordDetailPanel(
        lexemeId: _selectedLexemeId!,
        onDeleted: () {
          setState(() {
            _selectedLexemeId = null;
          });
        },
      );
    } else {
      // Empty state
      rightPanel = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 64,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No words yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start building your vocabulary. Click "Add root" to add your first word.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 280,
          child: WordListPanel(
            selectedLexemeId: _selectedLexemeId,
            onWordSelected: _onWordSelected,
            onAddRoot: _onAddRoot,
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: cs.outlineVariant,
        ),
        Expanded(child: rightPanel),
      ],
    );
  }
}
