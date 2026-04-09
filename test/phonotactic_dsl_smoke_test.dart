// Smoke test for the phonotactic DSL parser and word generator.
// Run with: dart run test/phonotactic_dsl_smoke_test.dart

import '../lib/features/phonology/domain/phonotactic_dsl.dart';
import '../lib/features/phonology/domain/word_generator.dart';

void main() {
  print('=== Phonotactic DSL Smoke Tests ===\n');

  // ---------------------------------------------------------------------------
  // Template parsing
  // ---------------------------------------------------------------------------

  // Test 1: "(C)V(C)" — three slots, first and last optional
  final t1 = parseSyllableTemplate('(C)V(C)');
  assert(t1.isValid, 'Expected valid: ${t1.error}');
  assert(t1.slots.length == 3, 'Expected 3 slots, got ${t1.slots.length}');
  assert(
    t1.slots[0].classReference == 'C' && t1.slots[0].isOptional,
    'Slot 0 should be optional C, got ${t1.slots[0]}',
  );
  assert(
    t1.slots[1].classReference == 'V' && !t1.slots[1].isOptional,
    'Slot 1 should be required V, got ${t1.slots[1]}',
  );
  assert(
    t1.slots[2].classReference == 'C' && t1.slots[2].isOptional,
    'Slot 2 should be optional C, got ${t1.slots[2]}',
  );
  print('PASS 1: (C)V(C) → ${t1.slots.length} slots, correct optionality');

  // Test 2: Natural class brackets "[stop][nasal]V"
  final t2 = parseSyllableTemplate('[stop][nasal]V');
  assert(t2.isValid, 'Expected valid: ${t2.error}');
  assert(t2.slots.length == 3, 'Expected 3 slots, got ${t2.slots.length}');
  assert(t2.slots[0].classReference == 'stop', 'Slot 0 should be stop');
  assert(t2.slots[1].classReference == 'nasal', 'Slot 1 should be nasal');
  print('PASS 2: [stop][nasal]V → natural class references parse correctly');

  // Test 3: Tone markers (non-Indo-European)
  final t3 = parseSyllableTemplate('V[tone:H]V');
  assert(t3.isValid, 'Expected valid: ${t3.error}');
  assert(
    t3.slots[1].classReference == 'tone:H',
    'Expected tone:H, got ${t3.slots[1].classReference}',
  );
  print('PASS 3: V[tone:H]V → tone marker class parses correctly');

  // Test 4: Complex cluster "(C)(C)V(C)(C)"
  final t4 = parseSyllableTemplate('(C)(C)V(C)(C)');
  assert(t4.isValid, 'Expected valid: ${t4.error}');
  assert(t4.slots.length == 5, 'Expected 5 slots, got ${t4.slots.length}');
  assert(t4.slots.every((s) => s.classReference != null || s.literalPhoneme != null));
  print('PASS 4: (C)(C)V(C)(C) → 5 slots, all valid');

  // Test 5: Invalid template — empty
  final t5 = parseSyllableTemplate('');
  assert(!t5.isValid, 'Empty template should be invalid');
  print('PASS 5: Empty template → correctly rejected with error');

  // ---------------------------------------------------------------------------
  // Constraint parsing
  // ---------------------------------------------------------------------------

  // Test 6: "VN -> nasalised V" — 2-slot LHS, not forbidden
  final c1 = parseConstraintRule('VN -> nasalised V');
  assert(c1.isValid, 'Expected valid: ${c1.error}');
  assert(c1.rule!.pattern.length == 2, 'Expected 2-slot LHS');
  assert(c1.rule!.pattern[0].classReference == 'V', 'LHS[0] should be V');
  assert(c1.rule!.pattern[1].classReference == 'N', 'LHS[1] should be N');
  assert(c1.rule!.description == 'nasalised V', 'Expected "nasalised V"');
  assert(!c1.rule!.isForbidden, 'Should not be forbidden');
  print('PASS 6: VN -> nasalised V → 2-slot LHS, isForbidden=false');

  // Test 7: "[stop][stop] -> forbidden" — isForbidden=true
  final c2 = parseConstraintRule('[stop][stop] -> forbidden');
  assert(c2.isValid, 'Expected valid: ${c2.error}');
  assert(c2.rule!.isForbidden, 'Should be forbidden');
  assert(c2.rule!.pattern.length == 2);
  print('PASS 7: [stop][stop] -> forbidden → isForbidden=true');

  // Test 8: Invalid constraint — no arrow
  final c3 = parseConstraintRule('VN nasalised V');
  assert(!c3.isValid, 'Expected invalid');
  print('PASS 8: Missing arrow → correctly rejected');

  // Test 9: Invalid constraint — empty LHS
  final c4 = parseConstraintRule('-> forbidden');
  assert(!c4.isValid, 'Expected invalid with empty LHS');
  print('PASS 9: Empty LHS → correctly rejected');

  // ---------------------------------------------------------------------------
  // Word generator
  // ---------------------------------------------------------------------------

  // Test 10: Generate words from simple (C)V template
  final templates = [parseSyllableTemplate('(C)V')];
  final inventory = PhonemeInventory(
    consonants: ['p', 't', 'k'],
    vowels: ['a', 'e', 'i'],
    naturalClasses: {},
  );
  final words = WordGenerator().generateWords(
    templates: templates,
    inventory: inventory,
    count: 10,
    minSyllables: 1,
    maxSyllables: 2,
  );
  assert(words.isNotEmpty, 'Expected generated words');
  assert(words.every((w) => w.isNotEmpty), 'All words should be non-empty');
  print('PASS 10: Generated ${words.length} words: ${words.join(", ")}');

  // Test 11: Empty inventory → no words generated
  final emptyWords = WordGenerator().generateWords(
    templates: templates,
    inventory: PhonemeInventory.empty,
    count: 5,
  );
  assert(emptyWords.isEmpty, 'Empty inventory should produce no words');
  print('PASS 11: Empty inventory → no words generated');

  print('\n=== All smoke tests PASSED ===');
}
