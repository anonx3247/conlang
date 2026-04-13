// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_projects_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Returns the most recently opened projects (up to 10), sorted by
/// [Project.lastOpenedAt] descending.
///
/// This is a thin wrapper around [projectRegistryProvider] — the registry
/// already sorts by lastOpenedAt, so we simply cap the list at 10 entries.
/// Consumed by the welcome screen (Plan 09-03) to show a quick-access list.

@ProviderFor(recentProjects)
const recentProjectsProvider = RecentProjectsProvider._();

/// Returns the most recently opened projects (up to 10), sorted by
/// [Project.lastOpenedAt] descending.
///
/// This is a thin wrapper around [projectRegistryProvider] — the registry
/// already sorts by lastOpenedAt, so we simply cap the list at 10 entries.
/// Consumed by the welcome screen (Plan 09-03) to show a quick-access list.

final class RecentProjectsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Project>>,
          List<Project>,
          FutureOr<List<Project>>
        >
    with $FutureModifier<List<Project>>, $FutureProvider<List<Project>> {
  /// Returns the most recently opened projects (up to 10), sorted by
  /// [Project.lastOpenedAt] descending.
  ///
  /// This is a thin wrapper around [projectRegistryProvider] — the registry
  /// already sorts by lastOpenedAt, so we simply cap the list at 10 entries.
  /// Consumed by the welcome screen (Plan 09-03) to show a quick-access list.
  const RecentProjectsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentProjectsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentProjectsHash();

  @$internal
  @override
  $FutureProviderElement<List<Project>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Project>> create(Ref ref) {
    return recentProjects(ref);
  }
}

String _$recentProjectsHash() => r'74bd52b76c3c19f3ae31f7336c8f0cac1971ff85';
