import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../lexicon/data/lexeme_providers.dart';

// NOTE: plain Provider / StreamProvider (not @riverpod codegen) — per STATE
// 01-05, riverpod_generator 3.x cannot resolve Drift part-file types at
// codegen time, so grammar-scoped providers that traffic in Drift-generated
// classes must be hand-written.

// ---------------------------------------------------------------------------
// Closed-class (particle) lexeme provider
// ---------------------------------------------------------------------------

/// Watches all closed-class lexemes (particles, auxiliaries, determiners, etc.)
/// for the current project, ordered by POS then IPA.
///
/// Emits an empty list when no project is open.
///
/// Phase 10 AGRAM-01 — D-02: isClosedClass flag on Lexemes table.
final closedClassLexemeListProvider = StreamProvider<List<Lexeme>>((ref) {
  final dao = ref.watch(lexemeDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchClosedClassWords();
});
