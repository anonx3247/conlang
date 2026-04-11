// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The root GoRouter, provided via Riverpod.
///
/// Uses a two-level StatefulShellRoute architecture:
///  - Outer: AppShell — top-level tab bar (Phonology, Grammar, Lexicon, Culture)
///  - Inner: per-tab shells (PhonologyShell, GrammarShell, LexiconShell)
///
/// Phase 4 plan 04-04 surgery: the old Morphology branch (index 1) is
/// replaced by the new Grammar branch, and the old placeholder Grammar
/// branch is deleted. Final branch order matches the AppShell `_tabs`
/// list: 0=Phonology, 1=Grammar, 2=Lexicon, 3=Culture.

@ProviderFor(appRouter)
const appRouterProvider = AppRouterProvider._();

/// The root GoRouter, provided via Riverpod.
///
/// Uses a two-level StatefulShellRoute architecture:
///  - Outer: AppShell — top-level tab bar (Phonology, Grammar, Lexicon, Culture)
///  - Inner: per-tab shells (PhonologyShell, GrammarShell, LexiconShell)
///
/// Phase 4 plan 04-04 surgery: the old Morphology branch (index 1) is
/// replaced by the new Grammar branch, and the old placeholder Grammar
/// branch is deleted. Final branch order matches the AppShell `_tabs`
/// list: 0=Phonology, 1=Grammar, 2=Lexicon, 3=Culture.

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// The root GoRouter, provided via Riverpod.
  ///
  /// Uses a two-level StatefulShellRoute architecture:
  ///  - Outer: AppShell — top-level tab bar (Phonology, Grammar, Lexicon, Culture)
  ///  - Inner: per-tab shells (PhonologyShell, GrammarShell, LexiconShell)
  ///
  /// Phase 4 plan 04-04 surgery: the old Morphology branch (index 1) is
  /// replaced by the new Grammar branch, and the old placeholder Grammar
  /// branch is deleted. Final branch order matches the AppShell `_tabs`
  /// list: 0=Phonology, 1=Grammar, 2=Lexicon, 3=Culture.
  const AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'5b0495722b15c60322bb82e9ea7fb9c7f5f553ca';
