# Technology Stack

**Project:** Conlang Workbench
**Researched:** 2026-04-08
**Confidence note:** Research tools (WebSearch, WebFetch, Bash, file Read) were restricted in this session. All version numbers and recommendations are drawn from training data with an August 2025 cutoff. Every version marked [VERIFY] must be confirmed against pub.dev before pinning in pubspec.yaml.

---

## Recommended Stack

### Core Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Flutter | ^3.22 [VERIFY] | Cross-platform UI framework | User constraint; desktop stable on macOS/Windows/Linux since Flutter 3.x; single codebase covers all three targets |
| Dart | ^3.4 [VERIFY] | Language | Ships with Flutter; null-safe, strong typed, excellent async primitives for event-driven UI |

**Flutter desktop status (HIGH confidence):** Flutter desktop is production-stable. macOS, Windows, and Linux targets are all Tier 1 as of Flutter 3.10+. The toolchain uses native embedding (ANGLE/Metal/Vulkan) with platform channels for native calls. No experimental flags needed.

**Recommended target:** macOS primary (user's likely platform given Darwin 25.1.0 in env). Windows/Linux compile without code changes for most pure-Flutter work.

---

### State Management

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Riverpod | ^2.5 [VERIFY] | App-wide state | Code-gen variant (`riverpod_generator`) eliminates boilerplate; works well with async data (SQLite streams); strongly typed providers catch category errors at compile time. Preferred over Bloc for a solo project — less ceremony. |
| riverpod_generator | ^2.4 [VERIFY] | Code generation for Riverpod | Generates provider boilerplate from annotated classes; pairs with `build_runner` |

**Why not Bloc:** Bloc is excellent for large teams needing strict event/state separation. For a solo desktop app with complex domain logic (morphology engine), Riverpod's flexibility and tighter Dart integration wins.

**Why not Provider (the package):** Provider is legacy Riverpod; Riverpod supersedes it with better compile-time guarantees.

---

### Database — SQLite

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| drift | ^2.19 [VERIFY] | Type-safe SQLite ORM | Generates type-safe Dart query APIs from table definitions; supports reactive streams (watch queries) so UI rebuilds on data changes; supports WAL mode; desktop-compatible via `drift_sqflite` or `sqlite3_flutter_libs` backend |
| sqlite3_flutter_libs | ^0.5 [VERIFY] | Bundles SQLite native binary | Provides a pre-compiled SQLite shared library for all desktop targets; eliminates system SQLite version inconsistencies |
| drift_dev | ^2.19 [VERIFY] | Build-time code generation | Generates the type-safe query layer from table DSL |

**Architecture note:** Each conlang project is a self-contained folder with its own `.db` file. Drift supports opening databases by file path at runtime, making per-project SQLite trivial. Use `NativeDatabase.createInBackground` (drift's isolate mode) to avoid blocking the UI during heavy lexicon queries.

**Why not sqflite:** sqflite is mobile-first; desktop support was tacked on. Drift wraps `sqlite3` directly on desktop and has better ergonomics. Drift also adds schema migration tooling that sqflite lacks.

**Why not Isar / Hive:** Both are document stores. The lexicon's relational structure (roots → derived words → morphological rules → paradigm entries) maps naturally to relational tables. Querying "all words using inflection pattern X" or "all words violating phonotactic rule Y" is a SQL query, not a document scan.

---

### Audio Playback (IPA reference chart)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| just_audio | ^0.9 [VERIFY] | Audio playback engine | Supports MP3/OGG/WAV; works on macOS and Windows desktop; handles network URLs (for Wikipedia IPA recordings) and local file paths; exposes streams for player state |
| audio_session | ^0.1 [VERIFY] | Audio session management | Handles focus, interruptions; recommended companion to just_audio |

**IPA audio sourcing strategy:** Wikipedia hosts IPA sound files under Creative Commons at `https://upload.wikimedia.org/wikipedia/commons/`. These are typically OGG Vorbis. just_audio plays OGG on desktop via FFmpeg on Linux and native decoders on macOS/Windows. **Verify OGG support on Windows** — it may require `just_audio_windows` with FFmpeg; the team has noted Windows OGG support is platform-dependent. Safest approach: cache MP3 variants or transcode to MP3 on first download.

**Why not audioplayers:** audioplayers is simpler but has had platform inconsistencies on desktop. just_audio has broader desktop support and is actively maintained by the Flutter community's audio working group.

---

### TTS Synthesis (reading conlang text aloud)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| flutter_tts | ^4.0 [VERIFY] | System TTS bridge | Wraps platform TTS (AVSpeechSynthesizer on macOS, SAPI on Windows, speech-dispatcher on Linux); zero network requirement; works offline |

**Conlang TTS strategy (MEDIUM confidence):** System TTS cannot pronounce a constructed language natively. The approach is: convert conlang text to IPA using the phonology rules defined in the project, then feed the IPA string to TTS with a base language that approximates those phonemes (e.g., `en-US` for approximation, or `ipa` SSML tag if the platform supports it). macOS AVSpeechSynthesizer supports SSML and `<phoneme alphabet="ipa">` tags — this is the highest-fidelity path on macOS. Windows SAPI supports IPA phonemes via `<phoneme>` SSML in some voices. Linux speech-dispatcher support varies.

**Alternative for higher quality:** A local TTS engine like espeak-ng can be called as a subprocess. espeak-ng natively supports IPA input (`espeak-ng -v en --ipa "text"`). This works on all three desktop platforms and is entirely offline. The tradeoff is robotic voice quality. Consider exposing both paths (system TTS via SSML, espeak-ng via process) and letting users choose.

**Why not a cloud TTS API (ElevenLabs, Google Cloud TTS):** Breaks offline-first constraint. Could be offered as an optional enhancement behind a feature flag, but the base path must be fully local.

---

### AI Agent / MCP Integration

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| dart_mcp_server (custom) | N/A | Expose project data to Claude | MCP (Model Context Protocol) is the standard for giving AI agents structured tool access. Build a lightweight Dart MCP server that reads the project's SQLite DB and exposes tools: `get_lexicon`, `get_phonology`, `get_grammar_rules`, `add_word`, etc. |
| http | ^1.2 [VERIFY] | HTTP client for AI API calls | dart:io has a built-in HTTP client but the `http` package is idiomatic and supports interceptors |
| dart_jsonwebtoken or similar | [VERIFY] | API key management | For authenticating to Claude/OpenAI APIs if not using MCP relay |

**MCP implementation approach (MEDIUM confidence — MCP spec was young as of mid-2025):**

The Model Context Protocol defines a JSON-RPC 2.0 protocol over stdio or SSE. A Flutter desktop app can spawn an MCP server as a side process or run it in an isolate that communicates over stdio with Claude Desktop or any MCP-compatible client. The recommended architecture:

1. The Flutter app writes a `mcp_server.dart` that speaks the MCP protocol over stdin/stdout
2. Claude Desktop (or any MCP host) is configured to launch this server pointing at the active project's DB file
3. The Flutter app also exposes a local HTTP endpoint for direct AI chat within the app UI

This means the AI agent feature works in two modes: (a) Claude Desktop as the host with full tool access, (b) in-app chat widget that calls the Claude API directly with context injected via system prompt.

**Dart MCP library status:** As of August 2025, the `dart_mcp` package from the Dart team was in early development. Check pub.dev for the current state. If immature, implement the MCP protocol directly — it is ~200 lines of JSON-RPC handling.

---

### Morphology Engine

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| petitparser | ^6.0 [VERIFY] | PEG parser library | For parsing the morphological pattern mini-language; PEG parsers compose cleanly and handle the recursive grammar needed for templates like `C₁eC₂iC₃` or `{root}+{suffix[agr=pl]}` |
| string_scanner | ^1.2 [VERIFY] | Tokenizer utility | Lower-level scanning; useful for the phonotactics rule tokenizer |

**Morphology pattern mini-language (HIGH confidence on approach, LOW on specific library versions):**

The morphology engine is the core differentiator. It must handle:
- **Concatenative:** `{root}+ku` (suffix)
- **Templatic (Semitic):** `C₁aC₂iC₃` where C₁C₂C₃ are consonant slots from a root
- **Ablaut/mutation:** replace vowel pattern V→V' within root
- **Circumfixes:** `{prefix}+{root}+{suffix}`
- **Suppletive exceptions:** per-word overrides stored in DB

petitparser is the right choice because: (1) it's a pure Dart PEG combinator library with no codegen step needed for the engine itself, (2) it supports grammar definition in code with composable combinators, (3) it has good error reporting needed for user-facing parse errors in their rule definitions.

Do NOT use `RegExp` directly as the pattern mini-language — regexes are opaque to users, don't capture linguistic slot semantics, and make error messages unreadable.

---

### NLP / Linguistics Utilities

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| No external NLP library | N/A | Morphological analysis | Standard NLP libraries (spaCy, NLTK) are Python-only. There is no mature Dart NLP library. The morphology engine must be built from scratch using the pattern mini-language — this is intentional and is the app's core value |
| ffi + native process | N/A | Optional: call espeak-ng for phoneme conversion | If needed for TTS pipeline, spawn espeak-ng as subprocess via `dart:io` Process API |

**Conlanger's Thesaurus PDF integration:**

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| pdfium_bindings or syncfusion_flutter_pdf | [VERIFY] | Parse the Conlanger's Thesaurus PDF | Need to extract semantic domain text from the fiatlingua.org PDF |

**PDF parsing options (MEDIUM confidence):**
- `syncfusion_flutter_pdf`: Free community license, pure Dart, extracts text from PDFs. Does not require a native binary. Good for text extraction from a fixed, known PDF like the Conlanger's Thesaurus.
- `pdfx`: Renders PDF pages to images; not useful for text extraction.
- `pdf_text` (pub.dev): Older package, desktop support unclear.
- **Recommended:** Parse the Conlanger's Thesaurus PDF once at build time, extract the structured semantic domain list into a JSON asset bundled with the app. This avoids runtime PDF parsing entirely and makes the data instantly searchable. Ship the extracted JSON. Parsing the PDF live is only needed if the user can supply their own PDF references.

---

### Anki Export

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| No pub.dev package needed | N/A | Anki `.apkg` generation | Anki's `.apkg` format is a ZIP file containing a SQLite database (`collection.anki2`) with a specific schema plus a `media` file. Dart's `archive` package handles ZIP; drift or `sqlite3` handles writing the Anki DB schema. Implement directly — no library needed. |
| archive | ^3.4 [VERIFY] | ZIP file creation for .apkg | Dart package for reading/writing ZIP/tar archives |

**Anki .apkg format (MEDIUM confidence):** The Anki 2.1 collection format stores notes in a SQLite DB with a `notes` table (guid, flds pipe-delimited, tags) and a `cards` table. The schema is publicly documented. This is ~100 lines of Dart to implement. Do not reach for a heavy library.

---

### PDF/Document Export

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| pdf | ^3.10 [VERIFY] | Generate PDF exports | Pure Dart PDF generation; no native dependencies; supports text, tables, Unicode (important for IPA symbols and custom scripts) |
| printing | ^5.12 [VERIFY] | Print/save PDF on desktop | Companion to `pdf` package; handles print dialog and file save on macOS/Windows/Linux |

---

### File System & Project Management

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| path_provider | ^2.1 [VERIFY] | Platform-appropriate paths | Gets Documents directory for default project storage location |
| file_picker | ^8.0 [VERIFY] | Open/save project folder picker | Native folder picker dialog on all three desktop platforms |
| path | ^1.9 [VERIFY] | Path manipulation utilities | Dart path joining/splitting utilities |
| watcher | ^1.1 [VERIFY] | Watch project folder for external changes | Optional: detect if another process modifies the DB file |

---

### UI Components

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| flutter_markdown | ^0.7 [VERIFY] | Render markdown in culture wiki | Pure Flutter markdown renderer; supports custom inline syntax for internal links |
| super_editor | ^0.2 [VERIFY] | Rich text editing for culture wiki | If markdown source editing is not enough; super_editor is a production-grade document editor for Flutter |
| data_table_2 | ^2.5 [VERIFY] | Sortable data tables for lexicon view | More capable than Flutter's built-in DataTable; supports fixed headers, sorting, large datasets |
| two_dimensional_scrollables | ^0.1 [VERIFY] | 2D scroll for paradigm charts | Flutter's TableView for large declension/conjugation tables; part of flutter/packages |

**IPA keyboard approach:** Build a custom Flutter widget — a scrollable grid of IPA symbols drawn from a hardcoded JSON asset. On tap, insert the character into the focused text field using a `TextEditingController`. No pub.dev package needed; all IPA characters are Unicode and render with the system font on macOS/Windows.

---

### Navigation

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| go_router | ^14.0 [VERIFY] | App navigation | Deep-link-style routing; supports nested navigation needed for tab structure (project → phonology/lexicon/grammar/culture/writing tabs); declarative and testable |

---

### Build & Code Generation

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| build_runner | ^2.4 [VERIFY] | Runs code generators | Required by drift_dev and riverpod_generator |
| freezed | ^2.5 [VERIFY] | Immutable data classes | For domain model objects (Phoneme, MorphologyRule, LexiconEntry); generates copyWith, equality, pattern matching |
| freezed_annotation | ^2.4 [VERIFY] | Freezed annotations | |
| json_serializable | ^6.7 [VERIFY] | JSON serialization | For project config files, asset data, API payloads |

---

### Testing

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| flutter_test | (bundled) | Widget and unit tests | Standard |
| mocktail | ^1.0 [VERIFY] | Mocking | Null-safe, no codegen required unlike mockito |
| integration_test | (bundled) | End-to-end desktop tests | Flutter's integration test runner works on desktop |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| ORM | drift | sqflite | sqflite has weak desktop support and no type-safe query generation |
| ORM | drift | Isar | Isar is document-oriented; lexicon is relational |
| State | Riverpod | Bloc | Bloc is over-engineered for a solo project; more ceremony with event/state classes |
| State | Riverpod | Provider (pkg) | Provider is legacy; Riverpod supersedes it |
| Audio | just_audio | audioplayers | audioplayers has more reported desktop inconsistencies |
| TTS | flutter_tts + IPA SSML | Cloud TTS | Cloud breaks offline-first constraint |
| Parser | petitparser | dart:convert RegExp | RegExp can't express recursive grammar; poor error messages for user-facing rule language |
| PDF | Bundle as JSON asset | Runtime PDF parsing | Runtime parsing adds complexity and dependency; the Thesaurus PDF is fixed content |
| Anki export | Custom (archive + sqlite3) | Third-party Anki lib | No mature Dart Anki library exists; the format is simple enough to implement directly |
| Navigation | go_router | auto_route | go_router is now the Flutter team's officially recommended router |

---

## Installation (pubspec.yaml dependencies)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.0      # [VERIFY version]
  riverpod_annotation: ^2.3.0   # [VERIFY version]

  # Database
  drift: ^2.19.0                # [VERIFY version]
  sqlite3_flutter_libs: ^0.5.0  # [VERIFY version]

  # Audio
  just_audio: ^0.9.0            # [VERIFY version]
  audio_session: ^0.1.0         # [VERIFY version]

  # TTS
  flutter_tts: ^4.0.0           # [VERIFY version]

  # Parsing / morphology engine
  petitparser: ^6.0.0           # [VERIFY version]
  string_scanner: ^1.2.0        # [VERIFY version]

  # File system
  path_provider: ^2.1.0         # [VERIFY version]
  file_picker: ^8.0.0           # [VERIFY version]
  path: ^1.9.0                  # [VERIFY version]
  archive: ^3.4.0               # [VERIFY version]

  # UI
  flutter_markdown: ^0.7.0      # [VERIFY version]
  data_table_2: ^2.5.0          # [VERIFY version]
  go_router: ^14.0.0            # [VERIFY version]

  # PDF export
  pdf: ^3.10.0                  # [VERIFY version]
  printing: ^5.12.0             # [VERIFY version]

  # Data modeling
  freezed_annotation: ^2.4.0    # [VERIFY version]
  json_annotation: ^4.9.0       # [VERIFY version]

  # HTTP (for AI API calls)
  http: ^1.2.0                  # [VERIFY version]

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0          # [VERIFY version]
  drift_dev: ^2.19.0            # [VERIFY version]
  riverpod_generator: ^2.4.0    # [VERIFY version]
  freezed: ^2.5.0               # [VERIFY version]
  json_serializable: ^6.7.0     # [VERIFY version]
  mocktail: ^1.0.0              # [VERIFY version]
```

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Flutter desktop stability | HIGH | Production-stable since 3.x; well-established |
| drift for SQLite | HIGH | Dominant Flutter ORM; well-established pattern |
| Riverpod for state | HIGH | De facto standard for Flutter apps in 2024-2025 |
| just_audio for playback | MEDIUM | Desktop support is good but OGG on Windows needs verification |
| flutter_tts + IPA SSML | MEDIUM | macOS SSML IPA support is documented; Windows/Linux varies |
| petitparser for morphology | HIGH | Mature library, actively maintained, right tool for PEG parsing |
| MCP integration approach | LOW | MCP was rapidly evolving; Dart MCP library maturity unknown as of Aug 2025 — verify against current pub.dev |
| Anki export (DIY) | MEDIUM | Format is stable and documented; implementation straightforward |
| PDF generation | HIGH | `pdf` package is mature and actively maintained |
| All version numbers | LOW | Cannot verify live — all marked [VERIFY]; check pub.dev before pinning |

---

## Platform-Specific Notes

### macOS
- Primary development target (env shows Darwin 25.1.0)
- Requires `macos/Runner/DebugProfile.entitlements` to include network client entitlement for Wikipedia IPA audio fetching and AI API calls
- `com.apple.security.network.client` entitlement needed
- AVSpeechSynthesizer supports `<phoneme alphabet="ipa">` SSML — best TTS path for conlang

### Windows
- Verify OGG audio playback — may need to bundle FFmpeg for just_audio
- SAPI TTS supports SSML phonemes but voice coverage varies
- sqlite3_flutter_libs bundles its own SQLite DLL; no system dependency

### Linux
- espeak-ng likely available as system package; consider using it directly for TTS instead of flutter_tts
- SQLite via sqlite3_flutter_libs works on Linux
- just_audio uses GStreamer on Linux — verify GStreamer is available or needs bundling

---

## Sources

- Training data (August 2025 cutoff) — Flutter, Dart, pub.dev ecosystem knowledge
- All claims marked [VERIFY] must be confirmed at https://pub.dev before use
- Anki .apkg format: https://github.com/ankitects/anki/blob/main/pylib/anki/collection.py (schema reference)
- MCP Protocol specification: https://modelcontextprotocol.io/
- Wikipedia IPA audio files: https://en.wikipedia.org/wiki/IPA_pulmonic_consonant_chart_with_audio
- Conlanger's Thesaurus: https://www.fiatlingua.org/

*Note: Research tools (WebSearch, WebFetch, Bash, Read) were restricted during this session. Version numbers are based on training knowledge and MUST be verified against live pub.dev before implementation. The architectural recommendations are HIGH confidence; the specific version numbers are LOW confidence.*
