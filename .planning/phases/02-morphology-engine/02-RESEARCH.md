# Phase 2: Morphology Engine - Research

**Researched:** 2026-04-09
**Domain:** Dart/Flutter, petitparser 7.x DSL design, morphological typology, Drift schema extension, Riverpod 3 patterns
**Confidence:** HIGH (primary evidence from codebase inspection + verified petitparser 7.x patterns; linguistic claims drawn from standard morphology literature + existing Phase 1 decisions)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Pattern mini-language syntax**
- Symbolic operator style — compact, regex-like expressions (not keyword-based)
- Numbered consonant slots for templatic patterns: plain digits represent consonant positions (e.g. `1a23aa` not `C1aC2C3aa`)
- Vowels are literal in templates — `a`, `aa` etc. are fixed pattern material, not variable slots; only consonant positions are variable
- Rules contain multiple Operations — a Rule is a container; each Operation inside it is one transformation (suffix, ablaut, template, etc.); operations chain together in order
- Environment-sensitive conditions — operations support conditional application based on the phonological environment of the word (e.g. "if word ends in -o, replace -o then add -in")
- Both string and class matching for conditions — literal string matching (`ends in "o"`) AND natural class matching (`[stop]`, `[nasal]`) using user-defined classes from Phase 1

**Rule editor experience**
- Hybrid authoring — structured form fields for building operations (dropdown for type, fields for parameters) with the mini-language expression shown live so users learn the syntax
- Dropdown menu for selecting operation type (Prefix, Suffix, Infix, Ablaut, Template, Reduplication, Suppletive)
- Conditions/branching approach — each operation needs a way to express environment-sensitive behavior (e.g. different suffix behavior for words ending in vowels vs consonants)

**Live preview behavior**
- Auto-generated sample words from phonotactic rules as preview input — shows the rule applied across varied word shapes
- Live debounced updates (~300ms after typing stops) — immediate feedback, consistent with word generator in Phase 1
- Inline error messages — when a sample word has no matching branch or the rule is invalid, show the error where the output would be with a hint about what's wrong
- Real lexicon words when available — once the lexicon exists (Phase 3+), show actual roots that match; fall back to generated samples if lexicon is empty

**Exception & override handling**
- Exceptions entered from the word — on a word's detail page, user overrides the output of any specific rule (exceptions live with the word, not the rule)
- Color differentiation for irregular forms — overridden derived forms shown in a distinct color (e.g. amber/orange) to distinguish from regular forms
- Exceptions persist on rule change — when a rule is modified, existing exceptions are kept but the user gets a warning to review them
- Per-rule vs blanket exemption scope: Claude's discretion

### Claude's Discretion
- Conditions vs branching structure for environment-sensitive operations (lean toward branching for readability)
- Per-rule-only overrides vs per-rule + blanket "fully irregular" exemption
- Exact structured form field layout for each operation type
- Error message wording and formatting
- Mini-language expression display format in the editor

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

## Summary

Phase 2 extends a working Flutter/Drift/Riverpod/petitparser codebase from Phase 1. The codebase is already well-structured: feature-by-feature under `lib/features/`, one Drift DAO per domain, Riverpod `StreamProvider` + `Provider` for reactive state, and petitparser 7.x for DSL parsing. The database schema already has a `Lexemes` table with `rootId`, `ruleIds`, and `computedForm` columns — the derivation-aware shape is fully designed, just waiting to be used.

The core new work is: (1) a morphology DSL for the four operation types (concatenative, Semitic template, ablaut, suppletive), (2) a branching condition system for environment-sensitive operations, (3) a rule engine that evaluates those DSL expressions against IPA strings, (4) a new Drift table for `MorphologicalRules` with a `MorphologyDao`, and (5) a new Flutter feature (`lib/features/morphology/`) with a rule-editor UI and live preview panel that mirrors the Sound Rules page pattern.

The key design insight is that the DSL is hierarchical: a `Rule` contains an ordered list of `Branch` objects; each `Branch` has a `condition` (or null = default) and an ordered list of `Operation` objects. Operations are the atomic transforms. This maps cleanly to a petitparser grammar, a Dart data model, and a structured form UI. The expression language for conditions (`ends in "o"`, `[stop]`) reuses the `Slot`/`PhonemeInventory` resolver already built in Phase 1.

**Primary recommendation:** Model the DSL as `Rule { name, branches: [Branch { condition?, ops: [Operation] }] }`, implement four operation plugins as pure Dart functions `String apply(String input, ...)`, parse the stored DSL string on read (never store a parsed AST), and wire the UI as a Morphology section parallel to Phonology.

---

## Standard Stack

### Core
All core libraries are already in `pubspec.yaml` — no new packages are required for Phase 2.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| petitparser | 7.0.2 | DSL parser for morphology expressions | Already used for phonotactic DSL; sealed Result requires `case Success/Failure` pattern matching |
| drift | 2.30.0 | SQLite ORM for MorphologicalRules table | Already provides all CRUD/streaming infrastructure |
| flutter_riverpod | 3.0.3 | Reactive state for rule list + preview | All Phase 1 providers follow this pattern; `StreamProvider` for DB-backed streams |
| riverpod_annotation | 3.0.3 | Code gen for providers | Same pattern as Phase 1 providers |

### No New Packages Needed
The morphology engine is a pure Dart implementation. All IPA string processing, DSL parsing, and UI components already exist or can be built from Flutter core + the Phase 1 infrastructure.

**Installation:** No new `pubspec.yaml` changes required.

---

## Architecture Patterns

### Recommended Project Structure

```
lib/features/morphology/
├── domain/
│   ├── morphology_dsl.dart          # DSL data model + petitparser grammar + operation engine
│   └── morphology_engine.dart       # MorphologyEngine class: applies Rule to a root word
├── data/
│   ├── morphology_dao.dart          # Drift DAO for MorphologicalRules + Exceptions tables
│   ├── morphology_dao.g.dart        # Generated
│   └── morphology_providers.dart    # Riverpod providers
└── presentation/
    ├── morphology_shell.dart        # Sidebar shell (parallel to PhonologyShell)
    └── rules/
        ├── rules_page.dart          # Main rules list page
        ├── rule_editor.dart         # Rule editor widget with operation builder + live preview
        └── preview_panel.dart       # Preview table: sample roots -> derived forms
```

New Drift tables go in `lib/db/app_database.dart` alongside existing tables.

New router branch in `lib/router/app_router.dart` for `/morphology` (enable the Morphology tab — or keep it disabled until Phase 2 is complete and enable as part of this phase's final task).

---

### Pattern 1: DSL Data Model (Hierarchical Rule / Branch / Operation)

**What:** A `MorphologicalRule` is a named container. Inside it, an ordered list of `Branch` objects each have an optional `Condition` and an ordered list of `Operation` objects. During evaluation, the engine tries each branch in order; the first branch whose condition matches (or the first branch with no condition) wins and its operations are applied in sequence.

**When to use:** Always — this is the canonical model.

```dart
// Source: designed from CONTEXT.md decisions + linguistic analysis

// --- Operations (atomic transforms) ---

sealed class MorphOperation {
  const MorphOperation();
}

class PrefixOp extends MorphOperation {
  const PrefixOp(this.affix);
  final String affix; // e.g. "un", "re"
}

class SuffixOp extends MorphOperation {
  const SuffixOp(this.affix);
  final String affix; // e.g. "in", "al"
}

class InfixOp extends MorphOperation {
  const InfixOp({required this.affix, required this.position});
  final String affix;
  final int position; // 0-based consonant slot index (after Nth consonant)
}

class AblauttOp extends MorphOperation {
  const AblauttOp({required this.from, required this.to});
  final String from; // vowel or class reference to replace
  final String to;   // replacement
}

class TemplateOp extends MorphOperation {
  const TemplateOp(this.pattern);
  // Pattern uses digit consonant slots: "1a23aa"
  // Digits 1..N refer to consonants extracted left-to-right from root
  final String pattern;
}

class SuppleteOp extends MorphOperation {
  const SuppleteOp(this.lookup);
  // Lookup key in a suppletive map (Phase 4 concern); for Phase 2,
  // this is a no-op passthrough that stores the literal form.
  final String lookup;
}

class RedupOp extends MorphOperation {
  const RedupOp({required this.scope, required this.position});
  // scope: "full" | "CV" | "C" — what portion of root to reduplicate
  // position: "prefix" | "suffix"
  final String scope;
  final String position;
}

// --- Condition ---

sealed class MorphCondition {
  const MorphCondition();
}

class EndsWithLiteralCond extends MorphCondition {
  const EndsWithLiteralCond(this.suffix);
  final String suffix; // e.g. "o", "a"
}

class StartsWithLiteralCond extends MorphCondition {
  const StartsWithLiteralCond(this.prefix);
  final String prefix;
}

class EndsWithClassCond extends MorphCondition {
  const EndsWithClassCond(this.classRef);
  final String classRef; // e.g. "stop", "nasal", "V", "C"
}

class StartsWithClassCond extends MorphCondition {
  const StartsWithClassCond(this.classRef);
  final String classRef;
}

// --- Branch ---

class MorphBranch {
  const MorphBranch({
    required this.condition,   // null = default/else branch
    required this.operations,
  });
  final MorphCondition? condition;
  final List<MorphOperation> operations;
}

// --- Rule ---

class MorphologicalRule {
  const MorphologicalRule({
    required this.id,
    required this.name,
    required this.branches,
    required this.source, // raw DSL string for round-tripping
  });
  final int id;
  final String name;
  final List<MorphBranch> branches;
  final String source;
}
```

---

### Pattern 2: DSL Expression Format

**What:** The mini-language expression string that encodes a rule. Stored in the database as `source` and re-parsed on each read (never store parsed AST). Displayed live in the editor so users learn the syntax.

**Design (from locked decisions):**

```
# Suffix rule with branches (the "-in" example from CONTEXT.md):
[C_] + in | [V_] + ain | [o] -o + in

# General syntax:
condition_spec operation_sequence ( | condition_spec operation_sequence )*

# condition_spec:
[C_]          ends with consonant class C
[V_]          ends with vowel class V
[stop_]       ends with natural class "stop"
"o"           ends with literal "o"
_             (lone underscore) = default/fallback branch, matches anything

# operation tokens:
+ affix       suffix (append)
affix +       prefix (prepend) ... alternative: use "pre:affix"
-"o"          remove trailing "o" (replacement prep step)
/from/to/     ablaut: replace 'from' with 'to' in root
template      template mode: digits = consonant slots (e.g. 1a23aa)
```

**Storage format:** The `source` column in `morphological_rules` stores this string verbatim. `MorphologicalRule.source` round-trips it. The UI shows it read-only alongside the structured form — users build rules via the form, not by typing DSL directly.

**Condition evaluation order:** Branches are tried in order; first match wins. A branch with `condition == null` is the default (else) branch. The planner should ensure the engine never falls through all branches without a match when a default branch exists.

---

### Pattern 3: Template Operation — Extracting Consonants

**What:** For Semitic-style root-and-pattern morphology, the root is a sequence of consonants (radicals). Given root `ktb` (k, t, b) and pattern `1a23aa`, the engine extracts consonants in order and slots them into the numbered positions:
- `1` → `k`, `2` → `t`, `3` → `b`
- Output: `katbaa`

**Algorithm:**
1. Tokenize the root using `PhonemeInventory` (the existing `_tokenize` method in `WordGenerator` — or an equivalent in the morphology engine).
2. Filter tokens to consonants: `inventory.consonants.contains(token)`.
3. Assign consonants to slot numbers 1..N left to right.
4. Walk the pattern string: digits 1-9 are consonant slots; everything else is literal.

**Pitfall:** The root tokenizer must use the project's phoneme inventory to correctly handle multi-character IPA symbols (e.g. `t͡ʃ` is one consonant, not three). Reuse `WordGenerator._tokenize` logic directly or copy it into `MorphologyEngine`.

```dart
// Source: derived from WordGenerator._tokenize pattern (word_generator.dart)
List<String> extractConsonants(String root, PhonemeInventory inventory) {
  final tokens = tokenizeIpa(root, inventory); // same logic as WordGenerator
  return tokens.where((t) => inventory.consonants.contains(t)).toList();
}

String applyTemplate(String pattern, List<String> consonants) {
  final buf = StringBuffer();
  for (final ch in pattern.runes) {
    final s = String.fromCharCode(ch);
    final digit = int.tryParse(s);
    if (digit != null && digit >= 1 && digit <= consonants.length) {
      buf.write(consonants[digit - 1]);
    } else {
      buf.write(s);
    }
  }
  return buf.toString();
}
```

---

### Pattern 4: Condition Matching Against PhonemeInventory

**What:** Conditions like `[stop_]` (ends with a stop) require checking the last phoneme token of the root against the project's natural class definition. Reuse the `PhonemeInventory.naturalClasses` map and the `Slot`-matching logic from `WordGenerator._slotMatches`.

```dart
// Source: adapted from WordGenerator._slotMatches (word_generator.dart)
bool conditionMatches(MorphCondition? cond, String root, PhonemeInventory inventory) {
  if (cond == null) return true; // default branch always matches
  final tokens = tokenizeIpa(root, inventory);
  if (tokens.isEmpty) return false;

  return switch (cond) {
    EndsWithLiteralCond(suffix: final s) => root.endsWith(s),
    StartsWithLiteralCond(prefix: final p) => root.startsWith(p),
    EndsWithClassCond(classRef: final c) => _resolveClass(c, inventory).contains(tokens.last),
    StartsWithClassCond(classRef: final c) => _resolveClass(c, inventory).contains(tokens.first),
  };
}
```

---

### Pattern 5: Drift Schema Extension

**What:** New `MorphologicalRules` table. The `Lexemes` table already has `ruleIds` (JSON array) and `computedForm` (derivation cache) — do NOT change that schema. Add a new `MorphologicalRuleExceptions` table for per-word overrides.

```dart
// Source: app_database.dart pattern — add to existing tables list

class MorphologicalRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();          // e.g. "Plural", "Agentive -er"
  TextColumn get source => text()();        // Raw DSL string for round-tripping
  IntColumn get ordering => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Per-word exception: overrides the output of a specific rule for a specific lexeme.
class MorphologicalRuleExceptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lexemeId => integer()();      // FK to Lexemes (enforced by PRAGMA foreign_keys = ON)
  IntColumn get ruleId => integer()();        // FK to MorphologicalRules
  TextColumn get overrideForm => text()();    // The irregular/exceptional form
}
```

**Migration:** Add as schema version 4 in `AppDatabase.migration.onUpgrade`. Also add to the `beforeOpen` `CREATE TABLE IF NOT EXISTS` safety net (following the existing pattern for `rewrite_rules` and `project_settings`).

---

### Pattern 6: Riverpod Provider Chain

**What:** Mirror the phonotactic provider pattern from `phonotactic_providers.dart`.

```dart
// morphology_providers.dart pattern (mirror of phonotactic_providers.dart)

final morphologyDaoProvider = Provider<MorphologyDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db?.morphologyDao;
});

final morphologicalRuleListProvider = StreamProvider<List<MorphologicalRule>>((ref) {
  final dao = ref.watch(morphologyDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchAllRules();
});

// Parsed rules provider: parse source strings into MorphologicalRule objects
final parsedMorphRulesProvider = Provider<List<MorphologicalRule>>((ref) {
  final rulesAsync = ref.watch(morphologicalRuleListProvider);
  final rawRules = rulesAsync.asData?.value ?? [];
  return rawRules
      .map((r) => parseMorphRule(r.source, id: r.id, name: r.name))
      .where((r) => r.isValid)
      .map((r) => r.rule!)
      .toList();
});
```

---

### Pattern 7: Live Preview Table

**What:** The preview panel shows a two-column table: `root` on the left, `derived form` on the right, with an arrow between. Errors (no matching branch) show inline in the derived-form column. This mirrors the `WordGeneratorPanel` but is a static table rather than a list.

**Debounce:** Use the same Riverpod watch-triggers-rebuild pattern as `WordGeneratorPanel`. The rule editor page is a `ConsumerStatefulWidget` that watches `parsedMorphRulesProvider`. Rebuilds trigger re-evaluation of the preview. No explicit `Timer` needed if rule edits are gated through save — the preview only shows the saved state. For the unsaved in-editor preview, use a `_localRule` state variable and `Timer(Duration(milliseconds: 300), () => setState(...))`.

---

### Pattern 8: UI Structure (Hybrid Authoring)

**What:** The rule editor combines structured form fields with a read-only DSL display. Operations are shown as a vertical list of cards; each card has a type dropdown and type-specific fields. The DSL expression is rendered below the form in a monospace read-only container.

**Operation card fields by type:**

| Type | Fields |
|------|--------|
| Prefix | `affix` text field |
| Suffix | `affix` text field |
| Infix | `affix` text field, `after consonant #` number field |
| Ablaut | `from` text field, `to` text field |
| Template | `pattern` text field (e.g. `1a23aa`), help: "digits = consonant slots, vowels are literal" |
| Reduplication | `scope` dropdown (Full / CV / C), `position` dropdown (Prefix / Suffix) |
| Suppletive | `lookup key` text field (stores the irregular form directly for Phase 2) |

**Branch UI:** Each branch is a card with a `condition` row at top (type dropdown: None/EndsWith-Literal/EndsWith-Class/StartsWith-Literal/StartsWith-Class + value field) and then its operations list. An "Add branch" button appends a new branch card at the end.

---

### Anti-Patterns to Avoid

- **Storing parsed AST in the DB:** Store only the `source` string. Re-parse on read. Avoids migration complexity.
- **Applying rules inside the parser:** The parser produces a data model; the engine applies it. Keep them separate (same discipline as Phase 1's `parseRewriteRule` which stores output as a raw string).
- **Single-branch rule assumption:** A rule ALWAYS has a list of branches. Even a simple "always add -in" is `[Branch(condition: null, ops: [SuffixOp("in")])]`. This avoids a two-code-path design.
- **Mixing phonological rewrite rules with morphological rules:** Phase 1 `RewriteRules` are SPE-style sound changes applied to a word's phoneme sequence. Morphological rules in Phase 2 are word-formation rules (affixation, template, etc.). They are different tables, different engines, different UI sections. Do not merge them.
- **Tokenizing with `split('')`:** Always use the inventory-aware tokenizer (longest-match) when dealing with IPA strings. Multi-character IPA symbols (e.g. `t͡ʃ`, `kʷ`) will otherwise be split incorrectly.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| IPA string tokenization | Custom regex splitter | Reuse `WordGenerator._tokenize` logic | Multi-character IPA symbols require longest-match; this already works |
| Natural class resolution | Custom Map lookup | Reuse `PhonemeInventory.naturalClasses` + `_resolveClass` | Already handles C/V shorthands, bracketed names, case-insensitive lookup |
| Reactive DB streams | Manual polling | Drift `watchAll()` → `StreamProvider` | Already the pattern for all Phase 1 DAOs |
| Provider debounce | Custom `Timer` class | Riverpod `ref.watch` + `ConsumerStatefulWidget` local state `Timer` | Already used in `WordGeneratorPanel` |
| DSL parsing | Hand-coded string split | petitparser 7.x combinators | Handles nested expressions, better error messages, same library already in project |

**Key insight:** The morphology engine is almost entirely new business logic layered on top of existing infrastructure. The heavy lifting (tokenization, class resolution, DB access, reactive streams) is already built — just adapt it.

---

## Common Pitfalls

### Pitfall 1: petitparser 7.x sealed Result — no `isFailure` getter
**What goes wrong:** Calling `result.isFailure` or `result.isSuccess` on a parse result causes a compile error. These don't exist in petitparser 7.x.
**Why it happens:** 7.x sealed the `Result` class; must use `case Success() / case Failure()` pattern matching.
**How to avoid:** Use `switch (result) { case Success(): ... case Failure(): ... }` everywhere.
**Warning signs:** Compiler errors about undefined getters on `Result`.

```dart
// CORRECT (petitparser 7.x):
final result = myParser.parse(input);
switch (result) {
  case Success():
    return ParsedFoo.success(rule: result.value);
  case Failure():
    return ParsedFoo.failure(error: '${result.message} at ${result.position}');
}
```

### Pitfall 2: `flatten()` named parameter
**What goes wrong:** Calling `flatten('message')` (positional) causes a compile error.
**Why it happens:** 7.x changed `flatten()` to use a named param `{String? message}`.
**How to avoid:** `parser.flatten()` with no argument, or `parser.flatten(message: 'expected X')`.

### Pitfall 3: Template digit parsing — multi-digit consonant indices
**What goes wrong:** If a root has more than 9 consonants (unusual but possible in polysynthetic languages), single-digit parsing breaks.
**Why it happens:** Simple `int.tryParse(char)` only handles 1-9.
**How to avoid:** For Phase 2, single-digit slots (1-9) are sufficient (Semitic roots are typically 3-5 consonants). Document the 1-9 limit clearly. No need to over-engineer.

### Pitfall 4: Condition matching on empty root
**What goes wrong:** `tokens.last` throws `RangeError` when root is empty.
**Why it happens:** Generated sample words can occasionally be empty if the phonotactic template produces nothing.
**How to avoid:** Guard: `if (tokens.isEmpty) return false` before any condition check. The engine returns a `MorphResult.noMatch` for empty roots.

### Pitfall 5: Exception warning on rule change — stale state
**What goes wrong:** When a rule's `source` changes, exceptions for that rule may no longer make sense (the rule's output changed). The user decision says "keep exceptions but warn."
**Why it happens:** Exceptions reference a `ruleId` but not the rule's content hash.
**How to avoid:** Store a `ruleSourceSnapshot` column in `MorphologicalRuleExceptions` — the `source` string at the time the exception was created. When the rule's `source` changes, query for exceptions where `ruleSourceSnapshot != currentSource` and display a warning banner in the exception list.

### Pitfall 6: Drift schema version drift
**What goes wrong:** Adding tables without incrementing `schemaVersion` causes the `onUpgrade` migration to not run on existing databases.
**Why it happens:** Developer forgets to bump the integer.
**How to avoid:** Increment `schemaVersion` from 3 to 4. Add `if (from < 4)` block in `onUpgrade`. Also add `CREATE TABLE IF NOT EXISTS` safety nets in `beforeOpen` (same pattern as existing `rewrite_rules` and `project_settings`).

### Pitfall 7: build_runner partial regeneration
**What goes wrong:** After adding new Drift tables or Riverpod providers, the `.g.dart` files are stale, causing type errors.
**Why it happens:** `build_runner build` must be run after any `@DriftDatabase`, `@DriftAccessor`, or `@riverpod` annotation change.
**How to avoid:** Always run `dart run build_runner build --delete-conflicting-outputs` after schema or provider changes. Verification steps in every task must include this.

### Pitfall 8: Morphology tab enablement
**What goes wrong:** The `AppShell` has `enabled: false` for Lexicon, Grammar, Culture. When Morphology is added as a top-level section, it must either be a sub-section under an existing tab or a new top-level tab that gets enabled.
**Why it happens:** The router and `_tabs` array in `app_shell.dart` are tightly coupled.
**How to avoid:** Phase 2 adds Morphology as a new top-level tab in `AppShell._tabs` (or wires it as a sub-section under an existing tab — Claude's discretion). The cleaner choice is a top-level "Morphology" tab enabled in Phase 2, consistent with the existing tab architecture. The router adds a `/morphology` branch.

---

## Code Examples

### Applying a SuffixOp
```dart
// Source: designed for Phase 2 (no equivalent in Phase 1 codebase yet)
String applySuffix(String root, String affix) => root + affix;
```

### Applying a TemplateOp
```dart
// Source: Phase 2 design — consonant extraction + pattern substitution
String applyTemplate(String root, String pattern, PhonemeInventory inventory) {
  final tokens = tokenizeIpa(root, inventory);
  final consonants = tokens.where((t) => inventory.consonants.contains(t)).toList();
  final buf = StringBuffer();
  for (final ch in pattern.split('')) { // safe for ASCII digits + IPA vowels
    final digit = int.tryParse(ch);
    if (digit != null && digit >= 1 && digit <= consonants.length) {
      buf.write(consonants[digit - 1]);
    } else {
      buf.write(ch);
    }
  }
  return buf.toString();
}
```

### Applying an AblauttOp
```dart
// Vowel replacement — applies to all occurrences unless conditions restrict
String applyAblaut(String root, String from, String to, PhonemeInventory inventory) {
  final tokens = tokenizeIpa(root, inventory);
  return tokens.map((t) => t == from ? to : t).join();
}
```

### Engine Entry Point
```dart
// MorphologyEngine.apply — evaluates all branches, returns first match
sealed class MorphResult {}
class MorphSuccess extends MorphResult {
  const MorphSuccess(this.form);
  final String form;
}
class MorphNoMatch extends MorphResult {
  const MorphNoMatch(this.reason);
  final String reason;
}

MorphResult applyRule(
  MorphologicalRule rule,
  String root,
  PhonemeInventory inventory,
) {
  for (final branch in rule.branches) {
    if (conditionMatches(branch.condition, root, inventory)) {
      var form = root;
      for (final op in branch.operations) {
        form = applyOp(op, form, inventory);
      }
      return MorphSuccess(form);
    }
  }
  return MorphNoMatch('No branch matched root "$root"');
}
```

### Drift DAO Pattern (mirror of RewriteRuleDao)
```dart
// Source: adapted from rewrite_rule_dao.dart
@DriftAccessor(tables: [MorphologicalRules, MorphologicalRuleExceptions])
class MorphologyDao extends DatabaseAccessor<AppDatabase>
    with _$MorphologyDaoMixin {
  MorphologyDao(super.db);

  Stream<List<MorphologicalRule>> watchAllRules() =>
      (select(morphologicalRules)
            ..orderBy([(t) => OrderingTerm.asc(t.ordering)]))
          .watch();

  Future<int> insertRule(MorphologicalRulesCompanion c) =>
      into(morphologicalRules).insert(c);

  Future<bool> updateRule(MorphologicalRulesData r) =>
      update(morphologicalRules).replace(r);

  Future<int> deleteRule(int id) =>
      (delete(morphologicalRules)..where((t) => t.id.equals(id))).go();

  // Exceptions
  Stream<List<MorphologicalRuleExceptionsData>> watchExceptionsForRule(int ruleId) =>
      (select(morphologicalRuleExceptions)
            ..where((t) => t.ruleId.equals(ruleId)))
          .watch();
}
```

---

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|------------------|-------|
| petitparser `result.isSuccess` | `case Success():` pattern match | 7.x sealed Result; compile error if old approach used |
| petitparser `flatten('msg')` positional | `flatten(message: 'msg')` named param | Breaking change from pre-7.x |
| Riverpod 2.x `@riverpod` with separate Notifier import | Riverpod 3.x unified `Ref`, single `@riverpod` annotation | Project already on 3.0.3 |
| Drift 2.x direct `database.select(...)` | Drift DAO pattern with `@DriftAccessor` | Project already follows DAO pattern |

---

## Open Questions

1. **Where does Morphology live in the app navigation?**
   - What we know: `AppShell` has 4 tabs (Phonology, Lexicon, Grammar, Culture). None is "Morphology". The Lexicon tab is Phase 3.
   - What's unclear: Should Morphology be a 5th top-level tab, a sub-section under an existing tab, or folded into Phonology's sidebar?
   - Recommendation: Add "Morphology" as a new top-level tab (index 1), shifting Lexicon to index 2. This is the cleanest architectural choice and consistent with the project structure. Update `AppShell._tabs` and the router. Alternatively, put it inside Phonology's sidebar as a third item if Phase 3 Lexicon proximity matters more. Claude's discretion — recommend a top-level tab.

2. **DSL expression serialization for the conditions/branching structure**
   - What we know: The `source` string must encode branches, conditions, and operations. The example from CONTEXT.md suggests a pipe-separated branch syntax.
   - What's unclear: The exact grammar for the DSL hasn't been formally specified yet (that's plan 02-01).
   - Recommendation: The 02-01 spike task should produce a one-page spec and PEG grammar before any implementation. The examples above (`[C_] + in | [V_] + ain`) are a starting point, not a final spec.

3. **Suppletive operation scope in Phase 2**
   - What we know: "Analytic (particle/aux verb, defined as a no-transform passthrough)" is in the success criteria. Suppletive lookup across a full lexicon is Phase 3+ work.
   - What's unclear: What does the UI allow for a Suppletive operation in Phase 2?
   - Recommendation: For Phase 2, a Suppletive operation stores a literal string (the suppletive form) typed by the user — no lookup. This satisfies the "passthrough" success criterion without requiring a lexicon.

---

## Sources

### Primary (HIGH confidence)
- `/Users/neosapien/dev/conlang/lib/features/phonology/domain/phonotactic_dsl.dart` — petitparser 7.x patterns: sealed Result, `case Success/Failure`, `flatten()` usage
- `/Users/neosapien/dev/conlang/lib/features/phonology/domain/word_generator.dart` — IPA tokenizer, `_resolveClass`, `applyRewriteRules` patterns
- `/Users/neosapien/dev/conlang/lib/db/app_database.dart` — Drift schema pattern, `Lexemes` table (ruleIds, computedForm), migration structure
- `/Users/neosapien/dev/conlang/lib/features/phonology/data/phonotactic_providers.dart` — Riverpod provider chain pattern
- `/Users/neosapien/dev/conlang/lib/features/phonology/data/rewrite_rule_dao.dart` — DAO pattern
- `/Users/neosapien/dev/conlang/pubspec.yaml` — confirmed library versions

### Secondary (MEDIUM confidence)
- `.planning/phases/01-foundation/01-RESEARCH.md` — petitparser 7.x pitfalls documented from Phase 1 research
- `.planning/phases/01-foundation/01-13-PLAN.md` — `parseRewriteRule` with ' -> ' (spaces) separator; output stored as raw string

### Linguistic reference (MEDIUM confidence)
- Standard morphological typology (Anderson 1992, Haspelmath 2002): concatenative (affix), non-concatenative (template), process morphology (ablaut), suppletion, reduplication — these four cover all required success criteria.
- Semitic root-and-pattern: triconsonantal root `ktb` + pattern `CaCaCa` → `kataba`. The digit-slot notation (`1a23aa`) is an adaptation that avoids variable vs literal ambiguity identified in the locked decisions.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries confirmed in pubspec.yaml and actively used
- Architecture patterns: HIGH — derived directly from Phase 1 codebase structure
- petitparser pitfalls: HIGH — confirmed in existing phonotactic_dsl.dart source
- Morphology operation logic: HIGH — standard linguistic typology, simple Dart string operations
- DSL expression format: MEDIUM — the exact grammar is the 02-01 spike's output; examples here are design guidance, not final spec

**Research date:** 2026-04-09
**Valid until:** 2026-05-09 (stable stack; petitparser/Drift versions pinned in pubspec.lock)
