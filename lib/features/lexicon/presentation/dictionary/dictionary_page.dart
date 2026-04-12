import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/anki_exporter.dart';
import '../../data/lexeme_providers.dart';
import '../../../morphology/data/morphology_providers.dart';
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

  /// IDs of lexemes currently selected for Anki export (D-18).
  Set<int> _selectedForExport = {};

  /// Whether selection mode is active (D-06, D-07).
  bool _isSelectionMode = false;

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

  void _onToggleExport(int id) {
    setState(() {
      if (_selectedForExport.contains(id)) {
        _selectedForExport = Set.from(_selectedForExport)..remove(id);
      } else {
        _selectedForExport = Set.from(_selectedForExport)..add(id);
      }
    });
  }

  void _onSelectAll() {
    final filteredLexemes = ref.read(filteredLexemeListProvider);
    setState(() {
      _selectedForExport = filteredLexemes.map((l) => l.id).toSet();
    });
  }

  void _onDeselectAll() {
    setState(() {
      _selectedForExport = {};
    });
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedForExport = {};
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedForExport = {};
    });
  }

  /// Builds the Anki export and saves it to the Downloads folder (or temp dir),
  /// then shows a confirmation snackbar with the filename.
  Future<void> _onExport() async {
    final selectedIds = Set<int>.from(_selectedForExport);
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one word to export.'),
        ),
      );
      return;
    }

    // Gather all lexemes that are selected
    final allLexemes = ref.read(allLexemeListProvider).asData?.value ?? [];
    final selectedLexemes =
        allLexemes.where((l) => selectedIds.contains(l.id)).toList();

    // Build morphological context strings using rule names
    final morphRules =
        ref.read(morphologicalRuleListProvider).asData?.value ?? [];
    final ruleMap = {for (final r in morphRules) r.id: r.name};

    final entries = selectedLexemes.map((lexeme) {
      String? morphContext;
      if (lexeme.rootId != null && lexeme.ruleIds != null) {
        try {
          final root = allLexemes
              .where((l) => l.id.toString() == lexeme.rootId)
              .firstOrNull;
          final ruleIdList = (jsonDecode(lexeme.ruleIds!) as List)
              .map((e) => e as int)
              .toList();
          final ruleNames =
              ruleIdList.map((id) => ruleMap[id] ?? 'rule #$id').join(', ');
          if (root != null) {
            morphContext = 'Derived from [${root.ipa}] via [$ruleNames]';
          }
        } catch (_) {
          // Malformed ruleIds JSON — skip morphological context
        }
      }

      return AnkiExportEntry(
        ipa: lexeme.ipa,
        romanization: lexeme.romanization,
        meaning: lexeme.meaning,
        partOfSpeech: lexeme.partOfSpeech,
        morphologicalContext: morphContext,
      );
    }).toList();

    // Determine deck name from project context (use app name as fallback)
    const deckName = 'Conlang Workbench';

    try {
      final apkgBytes =
          AnkiExporter().buildApkg(deckName: deckName, entries: entries);

      // Use native save dialog — required for macOS sandbox and consistent
      // cross-platform UX. The user picks the save location.
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'conlang_export_$timestamp.apkg';

      final saveLocation = await FileSelectorPlatform.instance.getSaveLocation(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Anki Package',
            extensions: ['apkg'],
          ),
        ],
        options: SaveDialogOptions(suggestedName: filename),
      );

      if (saveLocation == null) return; // User cancelled

      await File(saveLocation.path).writeAsBytes(apkgBytes);

      if (mounted) {
        _exitSelectionMode();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${entries.length} words to ${saveLocation.path.split('/').last}'),
            action: SnackBarAction(
              label: 'Open folder',
              onPressed: () => _revealInFinder(
                File(saveLocation.path).parent.path,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Opens the folder in Finder/Explorer/Nautilus (best effort).
  void _revealInFinder(String dirPath) {
    try {
      if (Platform.isMacOS) {
        unawaited(Process.run('open', [dirPath]));
      } else if (Platform.isLinux) {
        unawaited(Process.run('xdg-open', [dirPath]));
      } else if (Platform.isWindows) {
        unawaited(Process.run('explorer', [dirPath]));
      }
    } catch (_) {
      // Non-fatal — folder reveal is a convenience feature
    }
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
        onNavigateToWord: _onWordSelected,
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
              'Start building your vocabulary. Click "New word" to add your first word.',
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
            isSelectionMode: _isSelectionMode,
            selectedForExport: _selectedForExport,
            onToggleExport: _onToggleExport,
            onSelectAll: _onSelectAll,
            onDeselectAll: _onDeselectAll,
            onExport: _onExport,
            onEnterSelectionMode: _enterSelectionMode,
            onExitSelectionMode: _exitSelectionMode,
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
