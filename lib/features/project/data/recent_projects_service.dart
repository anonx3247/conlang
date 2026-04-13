import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/project.dart';
import 'project_providers.dart';

part 'recent_projects_service.g.dart';

/// Returns the most recently opened projects (up to 10), sorted by
/// [Project.lastOpenedAt] descending.
///
/// This is a thin wrapper around [projectRegistryProvider] — the registry
/// already sorts by lastOpenedAt, so we simply cap the list at 10 entries.
/// Consumed by the welcome screen (Plan 09-03) to show a quick-access list.
@riverpod
Future<List<Project>> recentProjects(Ref ref) async {
  final registry = await ref.watch(projectRegistryProvider.future);
  final all = await registry.listProjects(); // already sorted by lastOpenedAt desc
  return all.take(10).toList();
}
