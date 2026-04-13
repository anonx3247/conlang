# External Integrations

**Analysis Date:** 2026-04-12

## APIs & External Services

**None detected** - This is a standalone desktop application with no external API integrations.

## Data Storage

**Databases:**
- SQLite (local filesystem only)
  - Connection: SQLite3 via `sqlite3` package
  - Client: Drift ORM (`drift` package)
  - Storage: Per-project database file at `{appDocsDir}/{projectId}/project.db`
  - Schema: 11+ tables including Phonemes, NaturalClasses, Lexemes, RewriteRules, etc.

**File Storage:**
- Local filesystem only
  - Project files: `{appDocumentsDir}/conlang/{projectId}/`
  - Application documents directory resolved via `path_provider` package
  - Backup files: `project.db.v7.bak` (automatic pre-migration backups)

**Caching:**
- None (SQLite queries are primary data source)
- Runtime state held in Riverpod providers

## Authentication & Identity

**Auth Provider:**
- None - Application is single-user, no cloud authentication
- All projects stored locally on user's machine

## Monitoring & Observability

**Error Tracking:**
- None - No external error reporting service
- Errors logged to console via standard `print()` calls

**Logs:**
- Console logging only
- Analysis comments via TODO/FIXME in code (see `.planning/codebase/CONCERNS.md`)

## Import/Export

**Anki Export:**
- Framework: `archive` package (ZIP encoding) + `sqlite3` (in-memory database)
- Format: `.apkg` files (Anki 2.1+ compatible)
- Process:
  1. Create in-memory SQLite database with Anki collection schema v11
  2. Populate with notes and cards from selected lexemes
  3. ZIP the `collection.anki21` and `media` files
  4. Export as `.apkg` file via file picker
- Location: `lib/features/lexicon/data/anki_exporter.dart`
- Cards include: IPA form, romanization, meaning, POS tag, morphological context
- Security: HTML-escapes all text fields to prevent injection into Anki HTML renderer

**Project Backup:**
- Framework: `sqlite3` package for direct database copying
- Process: Automatic pre-v8 migration backup before schema upgrade
- Location: `lib/features/project/data/project_backup.dart`
- File: `project.db.v7.bak` created if migrating from schema v7 or earlier
- Purpose: Recovery mechanism for corrupt databases or rollback scenarios

**File Selection:**
- macOS: `file_selector_macos` (native NSOpenPanel)
- Linux: `file_selector_linux` (native GTK file dialog)
- Windows: `file_selector_windows` (native Win32 file picker)
- Usage: Export location selection, potential future import dialogs

## Audio Resources

**Audio Playback:**
- Framework: `just_audio` + `just_audio_media_kit`
- Feature: IPA chart pronunciation via embedded audio files
- Platform initialization: Windows/Linux require `JustAudioMediaKit.ensureInitialized()` before app startup
- Asset location: `assets/ipa_audio/` (MP3 files)
- Session management: `audio_session` package handles iOS/Android background audio (transitive dependency)

**Audio Attribution:**
- `assets/AUDIO_CREDITS.md` documents all IPA audio sources

## Reference Data

**Built-in Resources:**
- `assets/swadesh_list.json` - Swadesh wordlist (100-word comparative vocabulary list)
- `assets/conlangers_thesaurus.json` - Specialized linguistic terminology
- `assets/glossary.json` - Application feature glossary

## Network & Sync

**Cloud Storage:**
- Not supported - No cloud sync, backup, or collaboration features

**Inter-Process Communication:**
- None - Single-process desktop application

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## Third-Party Licenses

**Bundled Under:**
- Anki APKG format uses Anki's collection schema (respects Anki license)
- IPA chart audio subject to contributor attribution (see AUDIO_CREDITS.md)
- Swadesh list is public domain / CC0

## Configuration & Secrets Management

**No Configuration Required:**
- Application has no external API keys, tokens, or secret management
- All user data is local and encrypted by the OS filesystem

**Default Paths:**
- macOS: `~/Documents/conlang/`
- Linux: `~/.local/share/conlang/` (respects XDG standards via path_provider)
- Windows: `%APPDATA%\conlang\`

## Platform Integration

**Desktop Features:**
- Window management via `window_manager`: title bar, window size (1280x800), minimum size (900x600)
- Native file pickers per platform (select export destination)
- Material 3 theming via Flutter (respects system dark/light mode setting)

**IPA Audio:**
- Platform-specific audio backends:
  - macOS: native AVFoundation
  - Linux: media_kit with PulseAudio/ALSA
  - Windows: media_kit with DirectSound/WASAPI

---

*Integration audit: 2026-04-12*
