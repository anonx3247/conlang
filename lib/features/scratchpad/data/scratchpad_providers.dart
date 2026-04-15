import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../project/data/project_providers.dart';
import '../../../db/app_database.dart';
import 'scratchpad_dao.dart';

/// Provides the [ScratchpadDao] for the current project database.
/// Returns null when no project is open.
final scratchpadDaoProvider = Provider<ScratchpadDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db?.scratchpadDao;
});

/// Watches all phrases for the current project, ordered newest-first.
final scratchpadPhrasesProvider =
    StreamProvider<List<ScratchpadPhrase>>((ref) {
  final dao = ref.watch(scratchpadDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchAllPhrases();
});
