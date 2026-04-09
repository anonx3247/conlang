// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Resolves and caches the application documents directory path.
///
/// Returns the absolute path to `{appDocumentsDir}/conlang/` which serves
/// as the root for all project directories and the registry.json file.

@ProviderFor(appDocsDir)
const appDocsDirProvider = AppDocsDirProvider._();

/// Resolves and caches the application documents directory path.
///
/// Returns the absolute path to `{appDocumentsDir}/conlang/` which serves
/// as the root for all project directories and the registry.json file.

final class AppDocsDirProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Resolves and caches the application documents directory path.
  ///
  /// Returns the absolute path to `{appDocumentsDir}/conlang/` which serves
  /// as the root for all project directories and the registry.json file.
  const AppDocsDirProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDocsDirProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDocsDirHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return appDocsDir(ref);
  }
}

String _$appDocsDirHash() => r'22469c566874902ab92f9e02807f95cee82566f3';

/// Holds the ID of the currently open project, or null when no project is open.
///
/// Set this via `ref.read(currentProjectIdProvider.notifier).state = id`
/// to switch projects anywhere in the app.

@ProviderFor(CurrentProjectId)
const currentProjectIdProvider = CurrentProjectIdProvider._();

/// Holds the ID of the currently open project, or null when no project is open.
///
/// Set this via `ref.read(currentProjectIdProvider.notifier).state = id`
/// to switch projects anywhere in the app.
final class CurrentProjectIdProvider
    extends $NotifierProvider<CurrentProjectId, String?> {
  /// Holds the ID of the currently open project, or null when no project is open.
  ///
  /// Set this via `ref.read(currentProjectIdProvider.notifier).state = id`
  /// to switch projects anywhere in the app.
  const CurrentProjectIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentProjectIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentProjectIdHash();

  @$internal
  @override
  CurrentProjectId create() => CurrentProjectId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$currentProjectIdHash() => r'50b336f39bb39d0eacd8085306e6e8adc9591546';

/// Holds the ID of the currently open project, or null when no project is open.
///
/// Set this via `ref.read(currentProjectIdProvider.notifier).state = id`
/// to switch projects anywhere in the app.

abstract class _$CurrentProjectId extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Returns an [AppDatabase] instance scoped to [projectId].
///
/// Uses a family provider so that each project gets exactly one database
/// connection, shared across all widgets in the same project context.
/// Disposal (via [ref.onDispose]) closes the SQLite connection — critical
/// to avoid "database is closed" errors when switching projects (Pitfall 1
/// from Phase 1 research).
///
/// Path: `{appDocsDir}/{projectId}/project.db`

@ProviderFor(projectDatabase)
const projectDatabaseProvider = ProjectDatabaseFamily._();

/// Returns an [AppDatabase] instance scoped to [projectId].
///
/// Uses a family provider so that each project gets exactly one database
/// connection, shared across all widgets in the same project context.
/// Disposal (via [ref.onDispose]) closes the SQLite connection — critical
/// to avoid "database is closed" errors when switching projects (Pitfall 1
/// from Phase 1 research).
///
/// Path: `{appDocsDir}/{projectId}/project.db`

final class ProjectDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// Returns an [AppDatabase] instance scoped to [projectId].
  ///
  /// Uses a family provider so that each project gets exactly one database
  /// connection, shared across all widgets in the same project context.
  /// Disposal (via [ref.onDispose]) closes the SQLite connection — critical
  /// to avoid "database is closed" errors when switching projects (Pitfall 1
  /// from Phase 1 research).
  ///
  /// Path: `{appDocsDir}/{projectId}/project.db`
  const ProjectDatabaseProvider._({
    required ProjectDatabaseFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'projectDatabaseProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectDatabaseHash();

  @override
  String toString() {
    return r'projectDatabaseProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    final argument = this.argument as String;
    return projectDatabase(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectDatabaseProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectDatabaseHash() => r'cce515c762afceb4d9a1fb0347d361048b9f9366';

/// Returns an [AppDatabase] instance scoped to [projectId].
///
/// Uses a family provider so that each project gets exactly one database
/// connection, shared across all widgets in the same project context.
/// Disposal (via [ref.onDispose]) closes the SQLite connection — critical
/// to avoid "database is closed" errors when switching projects (Pitfall 1
/// from Phase 1 research).
///
/// Path: `{appDocsDir}/{projectId}/project.db`

final class ProjectDatabaseFamily extends $Family
    with $FunctionalFamilyOverride<AppDatabase, String> {
  const ProjectDatabaseFamily._()
    : super(
        retry: null,
        name: r'projectDatabaseProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Returns an [AppDatabase] instance scoped to [projectId].
  ///
  /// Uses a family provider so that each project gets exactly one database
  /// connection, shared across all widgets in the same project context.
  /// Disposal (via [ref.onDispose]) closes the SQLite connection — critical
  /// to avoid "database is closed" errors when switching projects (Pitfall 1
  /// from Phase 1 research).
  ///
  /// Path: `{appDocsDir}/{projectId}/project.db`

  ProjectDatabaseProvider call(String projectId) =>
      ProjectDatabaseProvider._(argument: projectId, from: this);

  @override
  String toString() => r'projectDatabaseProvider';
}

/// Watches [currentProjectIdProvider] and returns the open [AppDatabase],
/// or null when no project is selected.
///
/// Consumers watch this to get database access. Null means "show empty state".

@ProviderFor(currentDatabase)
const currentDatabaseProvider = CurrentDatabaseProvider._();

/// Watches [currentProjectIdProvider] and returns the open [AppDatabase],
/// or null when no project is selected.
///
/// Consumers watch this to get database access. Null means "show empty state".

final class CurrentDatabaseProvider
    extends $FunctionalProvider<AppDatabase?, AppDatabase?, AppDatabase?>
    with $Provider<AppDatabase?> {
  /// Watches [currentProjectIdProvider] and returns the open [AppDatabase],
  /// or null when no project is selected.
  ///
  /// Consumers watch this to get database access. Null means "show empty state".
  const CurrentDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentDatabaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase? create(Ref ref) {
    return currentDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase?>(value),
    );
  }
}

String _$currentDatabaseHash() => r'21611d881ec8c111bcbf5033248d5dcb63a183ed';

/// Provides a [ProjectRegistry] rooted at the application documents directory.
///
/// The registry is async because [appDocsDirProvider] is async. In practice
/// it resolves within a few ms on app startup.

@ProviderFor(projectRegistry)
const projectRegistryProvider = ProjectRegistryProvider._();

/// Provides a [ProjectRegistry] rooted at the application documents directory.
///
/// The registry is async because [appDocsDirProvider] is async. In practice
/// it resolves within a few ms on app startup.

final class ProjectRegistryProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProjectRegistry>,
          ProjectRegistry,
          FutureOr<ProjectRegistry>
        >
    with $FutureModifier<ProjectRegistry>, $FutureProvider<ProjectRegistry> {
  /// Provides a [ProjectRegistry] rooted at the application documents directory.
  ///
  /// The registry is async because [appDocsDirProvider] is async. In practice
  /// it resolves within a few ms on app startup.
  const ProjectRegistryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectRegistryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectRegistryHash();

  @$internal
  @override
  $FutureProviderElement<ProjectRegistry> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProjectRegistry> create(Ref ref) {
    return projectRegistry(ref);
  }
}

String _$projectRegistryHash() => r'd0457c49b09f5b0941bbacbc8cde9bc5c97edb4c';
