import 'package:flutter/material.dart';

/// IPA symbol categories displayed in the popup keyboard.
enum _IpaCategory {
  consonants,
  vowels,
  diacritics,
  suprasegmentals,
  other;

  String get label => switch (this) {
        _IpaCategory.consonants => 'Consonants',
        _IpaCategory.vowels => 'Vowels',
        _IpaCategory.diacritics => 'Diacritics',
        _IpaCategory.suprasegmentals => 'Supraseg.',
        _IpaCategory.other => 'Other',
      };
}

/// IPA symbol data organized by category.
///
/// Pulmonic consonants grouped by manner of articulation, vowels by
/// height/backness, standard diacritics, suprasegmentals, and non-pulmonic
/// consonants.
const _ipaSymbols = <_IpaCategory, List<String>>{
  _IpaCategory.consonants: [
    // Plosives
    'p', 'b', 't', 'd', 'ʈ', 'ɖ', 'c', 'ɟ', 'k', 'g', 'q', 'ɢ', 'ʔ',
    // Nasals
    'm', 'ɱ', 'n', 'ɳ', 'ɲ', 'ŋ', 'ɴ',
    // Trills
    'ʙ', 'r', 'ʀ',
    // Taps / Flaps
    'ɾ', 'ɽ',
    // Fricatives
    'ɸ', 'β', 'f', 'v', 'θ', 'ð', 's', 'z', 'ʃ', 'ʒ', 'ʂ', 'ʐ', 'ç', 'ʝ',
    'x', 'ɣ', 'χ', 'ʁ', 'ħ', 'ʕ', 'h', 'ɦ',
    // Lateral fricatives
    'ɬ', 'ɮ',
    // Approximants
    'ʋ', 'ɹ', 'ɻ', 'j', 'ɰ',
    // Lateral approximants
    'l', 'ɭ', 'ʎ', 'ʟ',
  ],
  _IpaCategory.vowels: [
    // Close
    'i', 'y', 'ɨ', 'ʉ', 'ɯ', 'u',
    // Close-mid
    'e', 'ø', 'ɘ', 'ɵ', 'ɤ', 'o',
    // Mid
    'e̞', 'ə', 'ɵ̞',
    // Open-mid
    'ɛ', 'œ', 'ɜ', 'ɞ', 'ʌ', 'ɔ',
    // Near-open
    'æ', 'ɐ',
    // Open
    'a', 'ɶ', 'ä', 'ɑ', 'ɒ',
    // Near-close
    'ɪ', 'ʏ', 'ʊ',
  ],
  _IpaCategory.diacritics: [
    // Voicing
    '̥', '̬',
    // Aspiration / breathy / creaky
    'ʰ', 'ʱ', '̤', '̰',
    // Articulation
    '̪', '̺', '̻', '̟', '̠', '̈', '̽',
    // Rhoticity
    '˞',
    // Nasalization
    '̃',
    // Length and syllabicity
    'ː', 'ˑ', '̩', '̯',
    // Tone (combining)
    '̋', '́', '̄', '̀', '̏',
    // Labialization / palatalization / velarization / pharyngealization
    'ʷ', 'ʲ', 'ˠ', 'ˤ',
    // Release
    '̚',
    // Syllable boundary
    '.',
  ],
  _IpaCategory.suprasegmentals: [
    // Stress
    'ˈ', 'ˌ',
    // Length
    'ː', 'ˑ',
    // Tone letters (Chao)
    '˥', '˦', '˧', '˨', '˩',
    // Tone contour
    '˥˩', '˩˥', '˧˥', '˥˧', '˩˧', '˧˩',
    // Intonation
    '↗', '↘',
    // Linking
    '‿',
    // Syllable break
    '|', '‖',
  ],
  _IpaCategory.other: [
    // Clicks
    'ʘ', 'ǀ', 'ǁ', 'ǂ', 'ǃ',
    // Implosives
    'ɓ', 'ɗ', 'ʄ', 'ɠ', 'ʛ',
    // Ejectives (base + apostrophe shown separately)
    'pʼ', 'tʼ', 'kʼ', 'sʼ', 'ʃʼ', 'ʼ',
    // Affricates (common)
    'ts', 'dz', 'tʃ', 'dʒ', 'tɕ', 'dʑ',
    // Prenasalized
    'mb', 'nd', 'ŋg',
    // Other
    'ʍ', 'w', 'ɥ', 'ʜ', 'ʢ', 'ɺ',
  ],
};

/// A compact popup keyboard displaying categorized IPA symbols.
///
/// Displays a tab bar at the top for category selection and a scrollable
/// grid of tappable symbol buttons below. Calls [onSymbolSelected] when the
/// user taps a symbol — does not perform text insertion directly.
///
/// Intended to be shown via [OverlayPortal] inside [IpaTextField].
class IpaKeyboardPopup extends StatefulWidget {
  const IpaKeyboardPopup({
    super.key,
    required this.onSymbolSelected,
    required this.onClose,
  });

  /// Called with the tapped IPA symbol string.
  final ValueChanged<String> onSymbolSelected;

  /// Called when the user requests to close the popup (via the X button).
  final VoidCallback onClose;

  @override
  State<IpaKeyboardPopup> createState() => _IpaKeyboardPopupState();
}

class _IpaKeyboardPopupState extends State<IpaKeyboardPopup>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _categories = _IpaCategory.values;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: colorScheme.surfaceContainerHigh,
      child: SizedBox(
        width: 360,
        height: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: tabs + close button
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerHeight: 0,
                      labelStyle: theme.textTheme.labelSmall,
                      unselectedLabelStyle: theme.textTheme.labelSmall,
                      tabs: _categories
                          .map((c) => Tab(text: c.label, height: 32))
                          .toList(),
                    ),
                  ),
                  // Close button
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      padding: EdgeInsets.zero,
                      tooltip: 'Close IPA keyboard',
                      onPressed: widget.onClose,
                    ),
                  ),
                ],
              ),
            ),

            // Symbol grid — one tab per category
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _categories.map((category) {
                  final symbols = _ipaSymbols[category] ?? [];
                  return _SymbolGrid(
                    symbols: symbols,
                    onSymbolSelected: widget.onSymbolSelected,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scrollable wrap grid of IPA symbol buttons for a single category.
class _SymbolGrid extends StatelessWidget {
  const _SymbolGrid({
    required this.symbols,
    required this.onSymbolSelected,
  });

  final List<String> symbols;
  final ValueChanged<String> onSymbolSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(6),
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: symbols.map((symbol) {
          return _SymbolButton(
            symbol: symbol,
            onTap: () => onSymbolSelected(symbol),
            textStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            backgroundColor: colorScheme.surface,
            hoverColor: colorScheme.primary.withValues(alpha: 0.12),
            splashColor: colorScheme.primary.withValues(alpha: 0.2),
          );
        }).toList(),
      ),
    );
  }
}

/// A single tappable IPA symbol button.
class _SymbolButton extends StatelessWidget {
  const _SymbolButton({
    required this.symbol,
    required this.onTap,
    required this.textStyle,
    required this.backgroundColor,
    required this.hoverColor,
    required this.splashColor,
  });

  final String symbol;
  final VoidCallback onTap;
  final TextStyle? textStyle;
  final Color backgroundColor;
  final Color hoverColor;
  final Color splashColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: symbol,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onTap,
        hoverColor: hoverColor,
        splashColor: splashColor,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            symbol,
            style: textStyle,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
