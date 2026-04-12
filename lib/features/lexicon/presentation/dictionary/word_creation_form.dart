import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../grammar/data/grammar_providers.dart';
import '../../../grammar/data/intrinsic_levels_codec.dart';
import '../../../grammar/domain/dimension_level.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../../phonology/data/phonotactic_providers.dart'
    show applyRewritePipelineProvider;
import '../../../phonology/data/romanization_providers.dart';
import '../../data/lexeme_providers.dart';
import 'inspiration_panel.dart';

import '../../../phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart';

/// Inline form for adding a new word to the lexicon.
///
/// Layout: Row with form on the left (~60%) and [InspirationPanel] on the
/// right (~40%). The right panel lets users click candidate words to fill
/// the IPA field (D-08).
///
/// When [prefillMeaning] is provided (from Swadesh / Thesaurus "Add word"
/// navigation via `?create=true&meaning=X`), the meaning field is pre-filled
/// on first build (D-16).
class WordCreationForm extends ConsumerStatefulWidget {
  const WordCreationForm({
    super.key,
    required this.onCancel,
    required this.onSaved,
    this.prefillMeaning,
  });

  final VoidCallback onCancel;
  final VoidCallback onSaved;

  /// When non-null, pre-fills the meaning field on first build.
  final String? prefillMeaning;

  @override
  ConsumerState<WordCreationForm> createState() => _WordCreationFormState();
}

class _WordCreationFormState extends ConsumerState<WordCreationForm> {
  final _formKey = GlobalKey<FormState>();
  final _ipaController = TextEditingController();
  final _romanizationController = TextEditingController();
  final _meaningController = TextEditingController();
  String? _selectedPos;
  bool _saving = false;
  String? _ipaError;

  /// Plan 04-18-04 Task 1 — POS is required unless [_rootOnlyViaDerivations].
  /// Non-null value is rendered as red helper text below the POS dropdown and
  /// cleared when the user selects any POS value.
  String? _posError;

  /// D-92 (plan 04-17 Task 7) — per-intrinsic-dim level selection for
  /// the currently-selected POS. Key = dim id, value = level id (null
  /// until picked). Cleared whenever the user switches POS.
  final Map<int, int?> _intrinsicLevelSelections = <int, int?>{};

  /// D-92 — per-dim validation error copy keyed by dim id. Non-null
  /// entries render below the dim's dropdown and block save.
  final Map<int, String?> _intrinsicLevelErrors = <int, String?>{};

  /// Plan 04-14 D-63: new lexeme gets marked as "this root only exists
  /// through derivations" — rendered muted in the Dictionary sidebar but
  /// still findable via search / exports.
  bool _rootOnlyViaDerivations = false;

  /// Plan 04-14 D-62: selected parent lexeme ids for the multi-select
  /// etymology picker. Committed via LexemeParentsDao on save.
  final Set<int> _selectedParents = <int>{};

  /// True once the user has typed directly in the IPA field. Until then,
  /// the IPA field is auto-populated from the romanization field via
  /// [deromanizeProvider]. After the user overrides it manually, we stop
  /// rewriting it so their override sticks.
  bool _ipaManuallyEdited = false;

  /// Guards against reentrant listener callbacks during programmatic
  /// multi-field updates (e.g. tapping an InspirationPanel candidate, which
  /// sets both IPA and romanization in a single batch). While true, the
  /// controller listeners early-return so we don't treat our own writes as
  /// user edits.
  bool _updatingControllersProgrammatically = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillMeaning != null) {
      _meaningController.text = widget.prefillMeaning!;
    }
    _romanizationController.addListener(_onRomanizationChanged);
    _ipaController.addListener(_onIpaChanged);
  }

  @override
  void dispose() {
    _romanizationController.removeListener(_onRomanizationChanged);
    _ipaController.removeListener(_onIpaChanged);
    _ipaController.dispose();
    _romanizationController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  /// Called whenever the romanization field changes. Re-derives the IPA
  /// unless the user has manually edited it.
  void _onRomanizationChanged() {
    if (_updatingControllersProgrammatically) return;
    if (_ipaManuallyEdited) return;
    final deromanize = ref.read(deromanizeProvider);
    final derived = deromanize(_romanizationController.text);
    if (_ipaController.text == derived) return;
    _updatingControllersProgrammatically = true;
    _ipaController.text = derived;
    _updatingControllersProgrammatically = false;
  }

  /// Called on ANY change to the IPA field. We only mark it as manually
  /// edited when the change wasn't driven by a programmatic update above.
  void _onIpaChanged() {
    if (_updatingControllersProgrammatically) return;
    // If the current IPA text matches what we'd derive from the romanization,
    // the "override" is identical to the default — treat it as not manual.
    final deromanize = ref.read(deromanizeProvider);
    final derived = deromanize(_romanizationController.text);
    _ipaManuallyEdited = _ipaController.text != derived;
  }

  Future<void> _save() async {
    final ipa = _ipaController.text.trim();
    if (ipa.isEmpty) {
      setState(() => _ipaError = 'IPA is required');
      return;
    }

    // Plan 04-18-04 Task 1 — POS mandatory validation.
    // rootOnlyViaDerivations words are exempt: they never surface standalone
    // so requiring a POS is unnecessary and would frustrate the user.
    if (!_rootOnlyViaDerivations &&
        (_selectedPos == null || _selectedPos!.isEmpty)) {
      setState(() => _posError = 'Part of speech is required');
      return;
    }

    // D-92 / plan 04-17 Task 7 — required-intrinsic sub-form validator.
    // If the selected POS has any intrinsic dimensions, every dim must
    // have a non-null level selection before the lexeme can be inserted.
    // The validator copy is `Required — every {posName} must have a
    // fixed {dim.name}.` rendered inline under each dropdown AND
    // replayed into the error map here so a direct Save tap also lights
    // up the failing rows.
    final posList =
        ref.read(posListProvider).asData?.value ?? const <PartsOfSpeechData>[];
    PartsOfSpeechData? selectedPos;
    if (_selectedPos != null) {
      for (final p in posList) {
        if (p.name == _selectedPos) {
          selectedPos = p;
          break;
        }
      }
    }
    Map<int, int> encodedLevels = const {};
    if (selectedPos != null) {
      // Use the synchronously-cached .asData (the Builder sub-form is
      // already watching this provider, so the stream has resolved).
      final dims = ref
              .read(dimensionsForPosProvider(selectedPos.id))
              .asData
              ?.value ??
          const <Dimension>[];
      final intrinsicDims = dims.where((d) => d.intrinsic).toList();
      _intrinsicLevelErrors.clear();
      var anyMissing = false;
      for (final dim in intrinsicDims) {
        final current = _intrinsicLevelSelections[dim.id];
        if (current == null) {
          _intrinsicLevelErrors[dim.id] =
              'Required — every ${selectedPos.name} must have a '
              'fixed ${dim.name}.';
          anyMissing = true;
        }
      }
      if (anyMissing) {
        if (mounted) setState(() {});
        return;
      }
      encodedLevels = {
        for (final dim in intrinsicDims)
          dim.id: _intrinsicLevelSelections[dim.id]!,
      };
    }
    final encoded = IntrinsicLevelsCodec.encode(encodedLevels);

    setState(() {
      _ipaError = null;
      _saving = true;
    });

    try {
      final dao = ref.read(lexemeDaoProvider);
      if (dao == null) return;

      final newId = await dao.insertLexeme(
        LexemesCompanion(
          ipa: Value(ipa),
          romanization: Value(_romanizationController.text.trim().isEmpty
              ? null
              : _romanizationController.text.trim()),
          meaning: Value(_meaningController.text.trim().isEmpty
              ? null
              : _meaningController.text.trim()),
          partOfSpeech: Value(_selectedPos),
          // D-63 / G-16 (plan 04-14): persist the muted-root flag.
          rootOnlyViaDerivations: Value(_rootOnlyViaDerivations),
          // D-92 / plan 04-17 Task 7 — serialized intrinsic levels. Null
          // when the selected POS has no intrinsic dims (canonical
          // absence sentinel from [IntrinsicLevelsCodec.encode]).
          intrinsicLevelsJson: Value(encoded),
        ),
      );

      // D-62 / G-17 (plan 04-14): write parent links via LexemeParentsDao.
      // Insert is idempotent (InsertMode.insertOrIgnore) so repeated saves
      // on the same child won't duplicate rows.
      final parentsDao = ref.read(lexemeParentsDaoProvider);
      if (parentsDao != null && _selectedParents.isNotEmpty) {
        for (final parentId in _selectedParents) {
          await parentsDao.insertParent(
            childLexemeId: newId,
            parentLexemeId: parentId,
          );
        }
      }
      widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final romanizationEnabled =
        ref.watch(romanizationEnabledProvider).asData?.value ?? false;
    final posAsync = ref.watch(posListProvider);
    final posList = posAsync.asData?.value ?? [];

    // 04-18-02 Task 2 — Issue 35a: integrate phonetic preview into the IPA
    // field as helperText instead of rendering a separate Text below it.
    // Compute here (before the field is built) so we can pass helperText
    // directly into InputDecoration. Hidden when IPA is empty or when no
    // rewrite rules fire (phonetic == phonemic).
    final applyRewrite = ref.watch(applyRewritePipelineProvider);
    final phonemic = _ipaController.text;
    final phonetic = phonemic.isNotEmpty ? applyRewrite(phonemic) : phonemic;
    final showPhonetic = phonemic.isNotEmpty && phonetic != phonemic;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Form (left ~60%) -----------------------------------------------
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New word',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---- IPA / Romanization fields ---------------------------
                  // When romanization is enabled, the romanized form is the
                  // primary input — the IPA field is auto-populated via
                  // `deromanizeProvider` as the user types, and only needs
                  // manual entry when the pronunciation deviates from the
                  // orthography (e.g. irregular / loan words). The IPA field
                  // is labeled "IPA (override)" to signal this.
                  if (romanizationEnabled) ...[
                    // Romanization as primary input. The listener added in
                    // initState auto-derives IPA on every change, so we
                    // don't need an onChanged callback here beyond the
                    // implicit rebuild driven by the listener.
                    TextField(
                      controller: _romanizationController,
                      decoration: const InputDecoration(
                        labelText: 'Romanization *',
                        hintText: 'e.g. kala',
                        helperText: 'IPA is auto-derived from this',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    // D-113 / 04-18-02: phonetic preview integrated as
                    // helperText inside the IPA field decoration (not below).
                    IpaTextField(
                      controller: _ipaController,
                      decoration: InputDecoration(
                        labelText: _ipaManuallyEdited
                            ? 'IPA (manual override)'
                            : 'IPA (auto-derived — edit to override)',
                        hintText: 'e.g. /kala/',
                        errorText: _ipaError,
                        helperText: showPhonetic ? '[$phonetic]' : null,
                        helperStyle:
                            theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      onChanged: (_) => setState(() => _ipaError = null),
                    ),
                  ] else ...[
                    // IPA as primary input — phonetic preview also shown
                    // as helperText when rewrite rules produce a surface form.
                    IpaTextField(
                      controller: _ipaController,
                      decoration: InputDecoration(
                        labelText: 'IPA *',
                        hintText: 'e.g. /kala/',
                        errorText: _ipaError,
                        helperText: showPhonetic ? '[$phonetic]' : null,
                        helperStyle:
                            theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      onChanged: (_) => setState(() => _ipaError = null),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ---- Meaning field --------------------------------------
                  TextField(
                    controller: _meaningController,
                    decoration: const InputDecoration(
                      labelText: 'Meaning',
                      hintText: 'e.g. water, to run',
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ---- POS dropdown --------------------------------------
                  // 04-18-04: POS is required (unless rootOnlyViaDerivations).
                  // Hint text updated to reflect the requirement.
                  if (posList.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _selectedPos,
                      decoration: InputDecoration(
                        labelText: 'Part of speech *',
                        errorText: _posError,
                      ),
                      hint: const Text('Select POS'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('— none —'),
                        ),
                        ...posList.map(
                          (pos) => DropdownMenuItem<String>(
                            value: pos.name,
                            child: Text(pos.name),
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() {
                        _selectedPos = val;
                        // Clear POS error when user selects a value.
                        if (val != null && val.isNotEmpty) {
                          _posError = null;
                        }
                        // D-92 — every POS change resets the intrinsic
                        // sub-form. The create-flow has no pre-existing
                        // lexeme json to preserve so there is no overlap
                        // logic here; that lives in word_detail_panel's
                        // edit-mode D-93 path.
                        _intrinsicLevelSelections.clear();
                        _intrinsicLevelErrors.clear();
                      }),
                    ),

                  // D-92 (plan 04-17 Task 7) — dynamic intrinsic sub-form
                  // beneath the POS dropdown. Watches
                  // dimensionsForPosProvider for the selected POS and
                  // renders a required DropdownButtonFormField per
                  // intrinsic dim. Hides entirely when the POS has none.
                  if (_selectedPos != null)
                    Builder(
                      builder: (ctx) {
                        final currentPosId = () {
                          for (final p in posList) {
                            if (p.name == _selectedPos) return p.id;
                          }
                          return null;
                        }();
                        if (currentPosId == null) {
                          return const SizedBox.shrink();
                        }
                        final dimsAsync = ref
                            .watch(dimensionsForPosProvider(currentPosId));
                        final dims = dimsAsync.asData?.value ??
                            const <Dimension>[];
                        final intrinsicDims =
                            dims.where((d) => d.intrinsic).toList();
                        if (intrinsicDims.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final dim in intrinsicDims)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: DropdownButtonFormField<int>(
                                    key: ValueKey(
                                        'intrinsicDim_${dim.id}'),
                                    value:
                                        _intrinsicLevelSelections[dim.id],
                                    decoration: InputDecoration(
                                      labelText: dim.name,
                                      helperText:
                                          'Intrinsic — fixed for every $_selectedPos',
                                      errorText:
                                          _intrinsicLevelErrors[dim.id],
                                    ),
                                    items: [
                                      for (final lv in decodeLevelsJson(
                                          dim.levelsJson))
                                        DropdownMenuItem<int>(
                                          value: lv.id,
                                          child: Text(
                                              '${lv.name} (${lv.abbr})'),
                                        ),
                                    ],
                                    onChanged: (v) => setState(() {
                                      _intrinsicLevelSelections[dim.id] =
                                          v;
                                      _intrinsicLevelErrors[dim.id] = null;
                                    }),
                                    validator: (v) => v == null
                                        ? 'Required — every $_selectedPos '
                                            'must have a fixed '
                                            '${dim.name}.'
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                  if (_ipaError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _ipaError!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          color: cs.error,
                        ),
                      ),
                    ),

                  // ---- D-63 rootOnlyViaDerivations checkbox -----------
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _rootOnlyViaDerivations,
                    onChanged: (v) =>
                        setState(() => _rootOnlyViaDerivations = v ?? false),
                    title: const Text(
                        'This root only exists through derivations'),
                    subtitle: const Text(
                      "The word won't appear standalone in the dictionary "
                      "list — it's shown muted and still findable via search",
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),

                  // ---- D-62 Parents (etymology) multi-select --------
                  const SizedBox(height: 12),
                  Text(
                    'Parents (etymology)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Consumer(
                    builder: (context, innerRef, _) {
                      final all = innerRef
                              .watch(allLexemeListProvider)
                              .asData
                              ?.value ??
                          const <Lexeme>[];
                      if (all.isEmpty) {
                        return Text(
                          'No existing lexemes to link as parents.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        );
                      }
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final lx in all)
                            FilterChip(
                              label: Text(lx.romanization ?? lx.ipa),
                              tooltip: lx.meaning,
                              selected: _selectedParents.contains(lx.id),
                              onSelected: (on) => setState(() {
                                if (on) {
                                  _selectedParents.add(lx.id);
                                } else {
                                  _selectedParents.remove(lx.id);
                                }
                              }),
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ---- Action buttons ------------------------------------
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text('New word'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: widget.onCancel,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ---- Inspiration panel (right ~40%) --------------------------------
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: cs.outlineVariant,
        ),
        Expanded(
          flex: 4,
          child: InspirationPanel(
            onWordSelected: (ipa) {
              setState(() {
                // Treat a tapped candidate as a clean slate: neither field
                // is "manually edited" — both are consistent with whatever
                // the generator produced. Use the programmatic guard so
                // the listeners don't misclassify these writes as user
                // input and flip `_ipaManuallyEdited`.
                _updatingControllersProgrammatically = true;
                _ipaController.text = ipa;
                _ipaError = null;
                if (romanizationEnabled) {
                  final romanize = ref.read(romanizeProvider);
                  _romanizationController.text = romanize(ipa);
                }
                _ipaManuallyEdited = false;
                _updatingControllersProgrammatically = false;
              });
            },
          ),
        ),
      ],
    );
  }
}
