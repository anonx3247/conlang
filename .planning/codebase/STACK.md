# Technology Stack

**Analysis Date:** 2026-04-12

## Languages

**Primary:**
- Dart 3.10.4+ - Application logic, UI, database layer, and test code

**Secondary:**
- Swift - macOS platform integration (`macos/Runner/MainFlutterWindow.swift`)
- C/C++ - Linux and Windows platform support via CMake

## Runtime

**Environment:**
- Flutter SDK (cross-platform framework)
- Dart Virtual Machine

**Platform Support:**
- macOS (desktop)
- Linux (desktop)
- Windows (desktop)

## Frameworks

**Core UI:**
- Flutter (Material 3 design system)
- go_router 17.2.0 - Navigation and routing with StatefulShellRoute architecture

**State Management:**
- flutter_riverpod 3.0.3 - Reactive state management and dependency injection
- riverpod_annotation 3.0.3 - Code generation for Riverpod providers

**Database:**
- drift 2.30.0 - Type-safe SQLite ORM with code generation
- drift_flutter 0.2.8 - Flutter-specific SQLite integration
- sqlite3 2.4.6 - Low-level SQLite bindings
- sqlite3_flutter_libs 0.5.23 - Pre-built SQLite libraries for Flutter

**Audio:**
- just_audio 0.10.5 - Audio playback framework
- just_audio_media_kit 2.1.0 - Media Kit backend for cross-platform audio
- media_kit_libs_linux - Linux audio library bindings
- media_kit_libs_windows_audio - Windows audio library bindings
- audio_session - Audio session management (transitive)

**Parser:**
- petitparser 7.0.2 - PEG parser combinator library for DSL parsing

**File Operations:**
- path_provider 2.1.5 - Platform-specific documents/cache directory access
- path 1.9.1 - Cross-platform path manipulation
- file_selector_platform_interface 2.7.0 - Abstract file picker interface
- file_selector_macos 0.9.5 - macOS file picker implementation
- file_selector_linux 0.9.4 - Linux file picker implementation
- file_selector_windows 0.9.3+5 - Windows file picker implementation

**Window Management:**
- window_manager 0.5.1 - Desktop window control (size, position, title bar)

**Export/Archive:**
- archive 3.6.1 - ZIP archive creation and manipulation for Anki export

**Testing:**
- flutter_test - Unit and widget test framework (included with Flutter SDK)

## Key Dependencies

**Critical:**
- drift 2.30.0 - Provides type-safe database schema, migrations, and queries. Required for project persistence. Code generation via drift_dev.
- flutter_riverpod 3.0.3 - Core reactive architecture. Used for all provider-based state management and DAOs.
- go_router 17.2.0 - Enables multi-level nested routing with proper state preservation during navigation.
- just_audio 0.10.5 - Audio playback for IPA chart pronunciation. Requires just_audio_media_kit initialization before use.

**Infrastructure:**
- archive 3.6.1 - Anki deck (.apkg) export requires ZIP encoding with in-memory SQLite
- sqlite3 2.4.6 - Direct SQLite access for Anki exporter and project backup utilities
- petitparser 7.0.2 - Parses phonotactic DSL, morphology DSL, rewrite rules (SPE notation)

## Configuration

**Environment:**
- No external environment variables required
- Application configuration stored in SQLite database
- Platform-specific settings handled by OS (window size, theme mode)

**Build Configuration:**
- `pubspec.yaml` - Package manifest and build targets
- `build.yaml` - Code generation ordering (drift_dev runs before riverpod_generator)
- `analysis_options.yaml` - Dart linter rules (prefer_single_quotes, const constructors)
- `.metadata` - Flutter project metadata
- `conlang_workbench.iml` - IntelliJ IDEA project configuration

**Platform Build Configs:**
- `macos/Runner/Configs/AppInfo.xcconfig` - macOS app version and bundle identifier
- `windows/CMakeLists.txt` and `linux/CMakeLists.txt` - Cross-platform compilation
- `linux/runner/CMakeLists.txt`, `windows/runner/CMakeLists.txt` - Platform runners

## Platform Requirements

**Development:**
- Flutter SDK 3.10.4 or higher
- Dart 3.10.4 or higher
- macOS 11.0+ (for macOS development)
- Xcode 14+ (for macOS builds)
- CMake 3.10+ (for Linux/Windows builds)
- Visual Studio 2019+ (for Windows builds)

**Production:**
- macOS 11.0+ with native arm64 or x86_64 support
- Linux distributions with glibc 2.27+ (for media kit libraries)
- Windows 10 Build 19041+
- 200MB+ disk space for project files and audio assets

## Code Generation

**Generators:**
- drift_dev 2.30.1 - Generates DAOs and migration code from `@DataClassName` and custom SQL queries
- riverpod_generator 3.0.3 - Generates Riverpod provider implementations from annotated functions

**Generated Files:**
- `*.g.dart` - TypeScript-style generated files for drift queries and Riverpod providers
- `app_database.g.dart` - Complete Drift database implementation

## Assets and Resources

**Bundled Assets:**
- `assets/ipa_audio/` - IPA pronunciation audio files (MP3)
- `assets/AUDIO_CREDITS.md` - Attribution for IPA audio sources
- `assets/swadesh_list.json` - Swadesh wordlist reference data
- `assets/conlangers_thesaurus.json` - Thesaurus for linguistic terminology
- `assets/glossary.json` - Application glossary

**Uses Material 3 design tokens:**
- Dark theme seed color: 0xFF5B8DEF (professional blue)
- Light theme seed color: 0xFF1A56DB (darker blue)

---

*Stack analysis: 2026-04-12*
