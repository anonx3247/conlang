import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../project/data/project_providers.dart';
import 'natural_class_dao.dart';
import 'phoneme_dao.dart';

// ---------------------------------------------------------------------------
// DAO providers
// ---------------------------------------------------------------------------

/// Returns the [PhonemeDao] for the currently open project database, or null
/// when no project is open.
final phonemeDaoProvider = Provider<PhonemeDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db?.phonemeDao;
});

/// Returns the [NaturalClassDao] for the currently open project database, or
/// null when no project is open.
final naturalClassDaoProvider = Provider<NaturalClassDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db?.naturalClassDao;
});

// ---------------------------------------------------------------------------
// Phoneme list providers
// ---------------------------------------------------------------------------

/// Watches all consonants in the current project's phoneme inventory.
///
/// Emits an empty list when no project is open.
final consonantListProvider = StreamProvider<List<Phoneme>>((ref) {
  final dao = ref.watch(phonemeDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchConsonants();
});

/// Watches all vowels in the current project's phoneme inventory.
///
/// Emits an empty list when no project is open.
final vowelListProvider = StreamProvider<List<Phoneme>>((ref) {
  final dao = ref.watch(phonemeDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchVowels();
});

/// Watches all phonemes (consonants + vowels) in the current project.
///
/// Emits an empty list when no project is open.
final allPhonemesProvider = StreamProvider<List<Phoneme>>((ref) {
  final dao = ref.watch(phonemeDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchAllPhonemes();
});

// ---------------------------------------------------------------------------
// Natural class list provider
// ---------------------------------------------------------------------------

/// Watches all natural classes defined in the current project.
///
/// Emits an empty list when no project is open.
final naturalClassListProvider = StreamProvider<List<NaturalClassesData>>((ref) {
  final dao = ref.watch(naturalClassDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchAllClasses();
});
