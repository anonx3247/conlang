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
///  - Outer: AppShell — top-level tab bar (Phonology, Lexicon, Grammar, Culture)
///  - Inner: PhonologyShell — sidebar (Inventory, Sound Rules)

@ProviderFor(appRouter)
const appRouterProvider = AppRouterProvider._();

/// The root GoRouter, provided via Riverpod.
///
/// Uses a two-level StatefulShellRoute architecture:
///  - Outer: AppShell — top-level tab bar (Phonology, Lexicon, Grammar, Culture)
///  - Inner: PhonologyShell — sidebar (Inventory, Sound Rules)

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// The root GoRouter, provided via Riverpod.
  ///
  /// Uses a two-level StatefulShellRoute architecture:
  ///  - Outer: AppShell — top-level tab bar (Phonology, Lexicon, Grammar, Culture)
  ///  - Inner: PhonologyShell — sidebar (Inventory, Sound Rules)
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

String _$appRouterHash() => r'fabaa13883736ef912ad8bb31b60ce72ce052abe';
