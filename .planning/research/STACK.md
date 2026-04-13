# Stack Research

**Domain:** Flutter desktop conlang workbench — v2.0 additions
**Researched:** 2026-04-13
**Confidence:** MEDIUM–HIGH (versions verified live via pub.dev; architecture HIGH; implementation details MEDIUM)

---

## Scope

This document covers ONLY the new packages needed for v2.0 features. The v1.0 stack (drift, riverpod, petitparser, just_audio, go_router, archive, sqlite3) is validated and unchanged.

---

## Recommended Stack — New Additions

### AI Integration (Claude API + MCP)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| anthropic_sdk_dart | ^1.5.0 | Claude API client | Verified latest (published 3 days ago as of 2026-04-13). Type-safe, supports streaming SSE, tool use, extended thinking, and built-in MCP integration. The only well-maintained official-quality Dart Claude SDK. Streaming lets the in-app chat widget render tokens as they arrive. |
| mcp_client | ^1.1.0 | MCP client transport | Verified latest. Handles STDIO, SSE, and Streamable HTTP transports. STDIO is the right transport for spawning a local Dart MCP server process from the desktop app. Supports session management and auto-reconnection. |
| mcp_server | ^1.0.3 | MCP server (expose project data) | Verified latest. Implements the server side of MCP for the companion Dart server binary that exposes `get_lexicon`, `get_grammar_rules`, `get_phonology` tools. Ships as a separate `bin/mcp_server.dart` executable that the Flutter app spawns via `dart:io Process`. |

**Architecture note:** Two-mode AI design.

Mode A (in-app chat): `anthropic_sdk_dart` sends the Claude API directly from the Flutter app, with project context injected into the system prompt as JSON. No MCP needed — simpler and works without Claude Desktop.

Mode B (Claude Desktop / external host): A `bin/mcp_server.dart` binary built using `mcp_server` exposes the project's SQLite data as MCP tools. Claude Desktop or any MCP host is pointed at this binary via its config. The Flutter app just writes to the DB normally; the MCP server reads it on demand.

Both modes should be supported. Mode A is built first (easier), Mode B enables the full co-creator vision.

**macOS entitlement required:** `com.apple.security.network.client` in `DebugProfile.entitlements` and `Release.entitlements` for outbound Claude API calls.

---

### TTS (Writing Scratchpad phonetic readout)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| flutter_tts | ^4.2.5 | System TTS for macOS/Windows/Linux | Verified latest. macOS uses AVSpeechSynthesizer which supports `<phoneme alphabet="ipa">` SSML — the highest-fidelity path for conlang pronunciation. Requires macOS 10.15+. Works offline. |

**Conlang TTS strategy:** The pipeline is: conlang text → tokenize → apply phonology rules → generate IPA string → feed to flutter_tts via SSML `<phoneme alphabet="ipa">` tag. This reuses the existing phonology rules engine. On macOS this gives genuine IPA-driven synthesis. On Windows, SAPI phoneme support varies by voice. On Linux, consider subprocess call to espeak-ng (`Process.run('espeak-ng', ['-v', 'en', '--ipa', ipaString])`).

**Why not a cloud TTS API:** Breaks offline-first constraint. Could be an optional plugin later.

---

### Writing System (Custom Script / Orthography)

No new packages needed for the core implementation. Approach by rendering tier:

**Tier 1 — Custom font file (recommended for most users):**
Flutter's built-in font loading (`pubspec.yaml` assets + `TextStyle(fontFamily: ...)`) handles TTF/OTF custom fonts natively. Users design their script as a font file (using Glyphr Studio or FontForge, both free) and import it. The app renders glyphs using standard `Text` widgets with the custom font family. No additional package needed. This is the simplest and most powerful path.

**Tier 2 — Glyph mapping to Unicode PUA (Private Use Area):**
User draws glyphs and maps them to Unicode PUA codepoints (U+E000–U+F8FF) in their custom font. The app stores the mapping table in the project DB and uses `String.fromCharCode()` to encode text. Still uses standard Text widgets.

**Tier 3 — SVG-drawn glyphs (for users without font tools):**

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| flutter_svg | ^2.2.4 | Render SVG glyph definitions | Verified latest. Users define glyphs as SVG path data stored in the project DB. The app renders each glyph as an SVG widget at the appropriate size inline with other text. Slower than font rendering but enables in-app glyph design without external tools. |

**Recommendation:** Build Tier 1 first (font import + rendering). Add Tier 3 (SVG glyphs) as a follow-on — it's the "no tooling required" path for casual users. Do NOT add a glyph vector editor inside the app; that scope is enormous.

---

### Writing Scratchpad — Interlinear Gloss Rendering

No external packages needed. The interlinear gloss display (three aligned rows: conlang words / morpheme glosses / free translation) is built entirely with Flutter's layout primitives:

```
Row
  for each token:
    Column(crossAxisAlignment: center)
      Text(word, style: conlangFont)       // row 1: conlang text
      Text(gloss, style: smallCaps)        // row 2: morpheme glosses (3.SG.PRES etc.)
      (free translation spans full width below)
```

The alignment constraint (each column is as wide as the widest of its cells) is handled by `IntrinsicWidth` wrapping each token column inside a `Row`. For word-wrapping across lines, use a custom `Wrap` widget where each child is a token column.

`WidgetSpan` inside `RichText` is the Flutter-native way to embed widget columns inside flowing text. This matches standard interlinear gloss display (Leipzig glossing rules). No external library adds value here.

**Tokenization:** Reuse the existing `petitparser` infrastructure for splitting conlang text into tokens and running morphological analysis on each. No new parsing library needed.

---

### Language Evolution (Sound Change Modeling)

No external packages. Sound change modeling is pure algorithmic Dart. The existing petitparser is already present and can parse sound change rules of the form `p / _V → b` (Neogrammarian-style context-sensitive rewrite rules).

The implementation is:
1. Sound change rules stored as rows in a new DB table (`evolution_rules`), ordered sequentially
2. Each rule is a petitparser-parsed pattern with source phoneme, target phoneme, and optional environment
3. "Apply changes" iterates the lexicon and transforms each word through the rule sequence
4. Results shown as a diff (before/after) with a "promote to new lexicon" action

No NLP library or ML model needed. This is deterministic pattern application, identical in nature to the existing phonological rewrite rules engine — extend that engine to handle evolution rules.

---

### Automatic Etymology Suggestions

No external packages. Compound word detection and morphological decomposition uses the existing morphology engine:

1. When a new word is added to the lexicon, attempt to decompose it using known roots + morphological patterns
2. Candidate etymologies ranked by coverage (how much of the word is explained by known morphemes)
3. Results presented as suggestions, not automatic assignments

This is straightforward string matching against the existing lexicon roots table. No separate NLP or etymology library exists in Dart that would be useful here. The value comes from the project's own data, not external resources.

---

### Markdown (Culture Wiki)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| flutter_markdown_plus | ^1.0.7 | Render markdown in culture wiki | Verified latest. Google discontinued `flutter_markdown`; `flutter_markdown_plus` is the official community continuation (140k+ weekly downloads, verified publisher foresightmobile.com). Drop-in replacement. Supports custom inline syntax needed for `[[WikiLink]]` internal links. |

**Migration:** Replace `flutter_markdown: ^0.7.x` in pubspec.yaml with `flutter_markdown_plus: ^1.0.7`. The API is identical.

---

## pubspec.yaml Changes

Remove (deprecated):
```yaml
# flutter_markdown: ^0.7.x  ← discontinued, replaced below
```

Add:
```yaml
  # AI integration
  anthropic_sdk_dart: ^1.5.0
  mcp_client: ^1.1.0
  mcp_server: ^1.0.3

  # TTS
  flutter_tts: ^4.2.5

  # Writing system (SVG glyph tier)
  flutter_svg: ^2.2.4

  # Markdown (replaces discontinued flutter_markdown)
  flutter_markdown_plus: ^1.0.7
```

No dev dependency changes needed. All new packages are runtime dependencies.

---

## Alternatives Considered

| Recommended | Alternative | When Alternative Is Better |
|-------------|-------------|---------------------------|
| anthropic_sdk_dart | Raw http + SSE parsing | Never for this project — sdk_dart is actively maintained, handles SSE and streaming properly, already wraps the protocol |
| anthropic_sdk_dart | Genkit Dart (Google) | If targeting multi-model (Gemini + Claude + OpenAI) in a single abstraction layer — overkill for a Claude-primary app |
| mcp_client + mcp_server | Custom JSON-RPC over stdio | If MCP packages prove too immature; the MCP wire protocol is simple (~200 lines) to implement manually |
| flutter_tts | espeak-ng subprocess | On Linux where flutter_tts/speech-dispatcher is unreliable; also better for IPA input on all platforms as a fallback |
| flutter_tts | Cloud TTS (ElevenLabs, Google) | If voice quality is a priority and offline constraint is relaxed — could be opt-in feature |
| Font-based writing system | In-app glyph vector editor | Never — glyph editor is a product unto itself (FontForge, Glyphr Studio are free and purpose-built) |
| Custom layout (interlinear) | Third-party gloss widget | No Dart interlinear gloss widget exists; custom Row/Column layout is 30 lines and fully controllable |
| Algorithmic sound changes | ML-based sound evolution | ML adds no value here — deterministic rule application is what conlangers need; probabilistic models produce random garbage for controlled language design |

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| genkit_dart | Abstracts away Claude-specific features (extended thinking, MCP, tool use) that we need direct access to | anthropic_sdk_dart directly |
| langchain_dart | Heavyweight RAG/chain framework designed for document Q&A pipelines; wrong abstraction for a creative tools app | Direct anthropic_sdk_dart calls with project context in system prompt |
| flutter_gemini | Google Gemini SDK — wrong model | anthropic_sdk_dart |
| tflite_flutter | On-device ML inference — unnecessary; no ML features planned | Nothing — evolution and etymology are rule-based |
| dart_openai | OpenAI SDK — wrong model | anthropic_sdk_dart |
| super_editor | Full document editor framework; too heavy for culture wiki scratchpad | flutter_markdown_plus with a plain TextField for editing |
| Any Python NLP library (via FFI/subprocess) | NLP libraries are Python-only; calling them via subprocess creates fragile cross-process dep | Pure Dart implementation using existing petitparser |

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| anthropic_sdk_dart ^1.5.0 | Dart SDK ^3.10.4 (current) | No conflict — requires Dart 3.x which is already the project SDK |
| mcp_client ^1.1.0 | Dart SDK ^3.x | Listed as cross-platform: Android, iOS, web, Linux, Windows, macOS |
| mcp_server ^1.0.3 | Dart SDK ^3.x | Same package family as mcp_client |
| flutter_tts ^4.2.5 | macOS 10.15+, Flutter 3.x | macOS requirement met; Darwin 25.1.0 is far above minimum |
| flutter_svg ^2.2.4 | Flutter 3.x | Long-stable package; no known conflicts with current deps |
| flutter_markdown_plus ^1.0.7 | Flutter 3.x | Drop-in for flutter_markdown; same API |

---

## Platform-Specific Notes

### macOS (primary target)
- Add `com.apple.security.network.client` to entitlements for Claude API calls
- AVSpeechSynthesizer + SSML `<phoneme alphabet="ipa">` is the best TTS path for conlang — use this
- Custom TTF/OTF fonts work identically to standard font loading; no additional entitlements

### Windows
- flutter_tts uses SAPI; phoneme support varies by voice — test with at least one voice
- Consider espeak-ng subprocess as Windows fallback for IPA TTS
- MCP STDIO transport: `Process.start()` spawning a Dart binary works the same as macOS

### Linux
- flutter_tts uses speech-dispatcher; quality varies — espeak-ng subprocess recommended
- MCP STDIO transport: same approach as macOS/Windows

---

## Architecture Integration Points

**Interlinear gloss flow:**
Scratchpad text → tokenizer (petitparser, existing) → morpheme analyzer (existing morphology engine) → gloss lookup (existing DB) → `GlossRow` widget (custom, Row of token columns)

**TTS flow:**
Scratchpad text → tokenizer → phonology rule application (existing) → IPA string assembly → `flutter_tts.speak(ssml)` on macOS / espeak-ng fallback

**AI chat flow (Mode A):**
User message → system prompt builder (reads project DB via drift, existing) → `anthropic_sdk_dart` streaming call → token stream → `StreamBuilder` chat widget

**AI MCP flow (Mode B):**
Claude Desktop launches `dart run bin/mcp_server.dart --project /path/to/project.conlang` → `mcp_server` package handles JSON-RPC over stdio → tools read/write via drift (existing)

**Writing system font flow:**
User imports TTF/OTF into project assets folder → app hot-loads font via `FontLoader` (dart:ui) → `TextStyle(fontFamily: 'UserScript')` used for conlang text widgets project-wide

**Sound change modeling:**
New `EvolutionRulesTable` in drift schema → petitparser (existing) extended with environment context syntax → rule application pipeline → diff view widget (before/after lexicon state)

---

## Sources

- pub.dev/packages/anthropic_sdk_dart — v1.5.0 verified live, streaming and tool use confirmed
- pub.dev/packages/mcp_client — v1.1.0 verified live, STDIO/SSE/HTTP transports confirmed, macOS listed
- pub.dev/packages/mcp_server — v1.0.3 verified live
- pub.dev/packages/flutter_tts — v4.2.5 verified live, macOS 10.15+ confirmed
- pub.dev/packages/flutter_svg — v2.2.4 verified live
- pub.dev/packages/flutter_markdown_plus — v1.0.7 verified live, confirmed replacement for discontinued flutter_markdown
- Flutter docs — FontLoader API, WidgetSpan, CustomPainter text layout — training data HIGH confidence
- MCP Protocol spec: https://modelcontextprotocol.io/

---
*Stack research for: Flutter conlang workbench v2.0 additions*
*Researched: 2026-04-13*
