import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../project/data/project_providers.dart';

/// Shared dismissible banner widget for one-time migration / relocation
/// notices (Phase 4 plan 04-04, reused by 04-05 and 04-07).
///
/// Dismissal state is stored in `project_settings` under [settingsKey]. The
/// banner watches the full project_settings stream and disappears once a
/// row with `key == settingsKey && value == 'true'` exists.
///
/// When no project is open the banner renders nothing.
class MigrationBanner extends ConsumerWidget {
  const MigrationBanner({
    super.key,
    required this.settingsKey,
    this.message =
        'Morphology rules have been moved here. Existing rules are now '
            'Derivational rules in Lexicon → Derivations. Create Inflectional '
            'rules here to drive paradigm tables.',
  });

  /// The project_settings key to persist the dismissal state under.
  final String settingsKey;

  /// Override the default migration copy (04-05 / 04-07 may customise).
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final db = ref.watch(currentDatabaseProvider);
    if (db == null) return const SizedBox.shrink();

    return StreamBuilder<List<ProjectSetting>>(
      stream: db.select(db.projectSettings).watch(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <ProjectSetting>[];
        final dismissed = rows.any(
          (r) => r.key == settingsKey && r.value == 'true',
        );
        if (dismissed) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            border: Border(
              left: BorderSide(color: cs.primary, width: 3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: cs.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Dismiss',
                onPressed: () async {
                  // Upsert using the existing helper pattern (update-then-insert)
                  // from writeTypologyKey / romanization_providers so we don't
                  // depend on insertOnConflictUpdate's PK targeting semantics.
                  final updated = await (db.update(db.projectSettings)
                        ..where((t) => t.key.equals(settingsKey)))
                      .write(
                    const ProjectSettingsCompanion(value: Value('true')),
                  );
                  if (updated == 0) {
                    await db.into(db.projectSettings).insert(
                          ProjectSettingsCompanion.insert(
                            key: settingsKey,
                            value: 'true',
                          ),
                        );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
