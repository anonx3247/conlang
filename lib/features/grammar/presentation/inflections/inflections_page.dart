import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../lexicon/data/lexeme_providers.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../../morphology/presentation/rules/rules_page.dart';
import '../../../project/data/project_providers.dart';
import '../../data/grammar_providers.dart';
import '../../data/typology_providers.dart';
import '../../domain/pos_resolver.dart';
import '../../domain/rule_kind.dart';
import '../paradigm_viewer/paradigm_table_widget.dart';

/// Plan 04-13 — Grammar > Inflections sub-tab (D-48 / D-49 / G-06).
///
/// Replaces the previous `Paradigm Viewer` + `Inflectional Rules` sub-tabs
/// with a single stacked layout:
///
/// ```
/// [ POS picker ][ Word picker ]
/// -----------------------------
/// |                           |
/// |  ParadigmTableWidget      |   ~55% vertical (D-49)
/// |  (clickMode.ruleEditor)   |
/// |                           |
/// -----------------------------
/// |                           |
/// |  RulesPage                |   ~45% vertical (D-50)
/// |  (kind=inflectional,      |
/// |   posScopeFilter=selPos)  |
/// |                           |
/// -----------------------------
/// ```
///
/// Cell clicks in the paradigm open [RuleEditorDialog] with pre-filled
/// bindings (D-51) — both empty cells (create) and filled cells (edit).
///
/// The bottom rules pane is scoped to the selected POS via
/// [RulesPage.posScopeFilter] (plan 04-13 Task 4 / D-50), showing both
/// single-POS rules for that POS and any multi-POS rules whose junction
/// set includes it.
///
/// Last-selected-word per POS is persisted in `project_settings` via the
/// G-01 helpers ported from `paradigm_viewer_page.dart` before that page
/// was deleted in Task 5 of this plan.
class InflectionsPage extends ConsumerStatefulWidget {
  const InflectionsPage({super.key});

  @override
  ConsumerState<InflectionsPage> createState() => _InflectionsPageState();
}

class _InflectionsPageState extends ConsumerState<InflectionsPage> {
  int? _selectedPosId;
  int? _selectedLexemeId;

  /// G-01: restore the per-POS last-selected lexeme from project_settings
  /// when a POS is picked. Falls back to leaving `_selectedLexemeId` null
  /// (keeps the "(template)" default) when no stored value exists or the
  /// stored lexeme has been deleted since.
  Future<void> _restoreLastSelectedWord(int posId) async {
    final db = ref.read(currentDatabaseProvider);
    if (db == null) return;
    // paradigm.last_selected_word.$posId — the exact key used by the
    // pre-04-13 paradigm_viewer_page G-01 path.
    final stored = await readParadigmLastSelectedWord(db, posId);
    if (!mounted || _selectedPosId != posId) return;
    if (stored == null) {
      setState(() => _selectedLexemeId = null);
      return;
    }
    final lex = await (db.select(db.lexemes)
          ..where((t) => t.id.equals(stored)))
        .getSingleOrNull();
    if (!mounted || _selectedPosId != posId) return;
    setState(() => _selectedLexemeId = lex == null ? null : stored);
  }

  void _onPosChanged(int? posId) {
    setState(() {
      _selectedPosId = posId;
      _selectedLexemeId = null;
    });
    if (posId != null) {
      _restoreLastSelectedWord(posId);
    }
  }

  void _onWordChanged(int? lexemeId) {
    setState(() => _selectedLexemeId = lexemeId);
    final posId = _selectedPosId;
    if (posId == null || lexemeId == null) return;
    final db = ref.read(currentDatabaseProvider);
    if (db == null) return;
    writeParadigmLastSelectedWord(db, posId: posId, lexemeId: lexemeId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final posAsync = ref.watch(posListProvider);
    final posList = posAsync.asData?.value ?? const <PartsOfSpeechData>[];

    // D-84 — 04-17. Intrinsic backfill banner consumer. Surfaces one
    // MaterialBanner per pending row in project_settings that has not
    // been dismissed. Dismiss writes a sibling `_dismissed_<dimId>`
    // marker and invalidates the provider.
    final bannersAsync = ref.watch(intrinsicBackfillBannerProvider);
    final banners = bannersAsync.asData?.value ?? const <IntrinsicBackfillBanner>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final banner in banners)
          MaterialBanner(
            content: Text(
              'Review ${banner.count} words with auto-assigned default '
              'level for ${banner.dimName}.',
            ),
            actions: [
              TextButton(
                onPressed: () => _onReviewBanner(banner),
                child: const Text('Review'),
              ),
              TextButton(
                onPressed: () => _onDismissBanner(banner),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        // ---- Top controls: POS + word picker ---------------------------
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Text('POS:', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _selectedPosId,
                hint: const Text('Select a POS'),
                items: posList
                    .map((p) =>
                        DropdownMenuItem(value: p.id, child: Text(p.name)))
                    .toList(),
                onChanged: _onPosChanged,
              ),
              const SizedBox(width: 24),
              if (_selectedPosId != null) _buildWordPicker(posList),
            ],
          ),
        ),
        Divider(height: 1, color: cs.outlineVariant),
        // ---- Middle: paradigm table (~55% of remaining space) ----------
        // D-95 — 04-17. When no explicit word is selected, fall back to
        // first-matching-lexeme for the POS (lowest id). The -1 sentinel
        // is only passed when firstMatchingLexeme is also null (no words).
        Expanded(
          flex: 55,
          child: _selectedPosId == null
              ? _emptyState(
                  theme,
                  cs,
                  icon: Icons.table_chart_outlined,
                  message: 'Select a POS to view its paradigm.',
                )
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: Builder(
                    builder: (context) {
                      final effectiveLexemeId = _selectedLexemeId ??
                          ref.watch(firstMatchingLexemeForPosProvider(
                              _selectedPosId!))?.id ??
                          -1;
                      return ParadigmTableWidget(
                        lexemeId: effectiveLexemeId,
                        posId: _selectedPosId!,
                        // D-52 Grammar host: cell clicks open RuleEditorDialog
                        // with pre-filled bindings (D-51).
                        clickMode: ParadigmClickMode.ruleEditor,
                      );
                    },
                  ),
                ),
        ),
        Divider(height: 1, color: cs.outlineVariant),
        // ---- Bottom: rules pane (~45% of remaining space) --------------
        // D-78 / plan 04-16: when no POS is selected, render the full
        // inflectional rules list. RulesPage already treats
        // posScopeFilter: null as "show all groups" (per D-50 /
        // plan 04-13 Task 4). The paradigm pane above still shows a
        // placeholder because it genuinely requires a POS; the rules
        // list does not.
        Expanded(
          flex: 45,
          child: RulesPage(
            kind: RuleKind.inflectional,
            // D-50 / plan 04-13: scope the rules pane to the selected
            // POS when one is chosen (includes any multi-POS rules
            // whose junction set contains this POS). When
            // _selectedPosId is null, RulesPage falls through to the
            // full grouped inflectional list.
            posScopeFilter: _selectedPosId,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(
    ThemeData theme,
    ColorScheme cs, {
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// D-84 — 04-17. "Review" action on the backfill banner. For now this
  /// just dismisses the banner — Task 7 adds the filtered Lexicon
  /// navigation. We dismiss on Review because the user's stated intent is
  /// "I've seen it" and leaving it up after a click feels broken.
  void _onReviewBanner(IntrinsicBackfillBanner banner) {
    _onDismissBanner(banner);
  }

  /// D-84 — 04-17. Dismiss handler writes a `_dismissed_<dimId>` marker to
  /// project_settings and invalidates the banner provider so the
  /// MaterialBanner disappears from the Inflections sub-tab.
  Future<void> _onDismissBanner(IntrinsicBackfillBanner banner) async {
    final db = ref.read(currentDatabaseProvider);
    if (db == null) return;
    final dismissKey =
        'intrinsic_backfill_banner_dismissed_${banner.dimId}';
    await (db.delete(db.projectSettings)
          ..where((t) => t.key.equals(dismissKey)))
        .go();
    await db.into(db.projectSettings).insert(
          ProjectSettingsCompanion.insert(
            key: dismissKey,
            value: 'true',
          ),
        );
    ref.invalidate(intrinsicBackfillBannerProvider);
  }

  Widget _buildWordPicker(List<PartsOfSpeechData> posList) {
    final lexemesAsync = ref.watch(allLexemeListProvider);
    final lexemes = lexemesAsync.asData?.value ?? const <Lexeme>[];
    // Filter lexemes whose resolved POS matches _selectedPosId.
    final filtered = lexemes.where((lex) {
      final pos = posForLexeme(lex, posList);
      return pos?.id == _selectedPosId;
    }).toList();

    return Expanded(
      child: DropdownButton<int?>(
        value: _selectedLexemeId,
        hint: const Text('Word (optional — blank for template)'),
        isExpanded: true,
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('(template)')),
          for (final l in filtered)
            DropdownMenuItem<int?>(value: l.id, child: Text(l.ipa)),
        ],
        onChanged: _onWordChanged,
      ),
    );
  }
}
