import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../lexicon/data/lexeme_providers.dart';

// NOTE: plain StreamProvider (not @riverpod codegen) — per STATE 01-05,
// riverpod_generator 3.x cannot resolve Drift part-file types at
// codegen time.

/// Watches all closed-class lexemes (particles, auxiliaries, determiners, etc.)
/// for the currently open project, ordered by POS then IPA.
///
/// Emits an empty list when no project is open. Backed by
/// [LexemeDao.watchClosedClassWords] which filters on [Lexemes.isClosedClass].
///
/// These words are stored in the shared Lexemes table (D-02) so they
/// automatically appear in unified lexicon search and Anki export without
/// any additional plumbing.
final closedClassLexemeListProvider = StreamProvider<List<Lexeme>>((ref) {
  final dao = ref.watch(lexemeDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchClosedClassWords();
});
