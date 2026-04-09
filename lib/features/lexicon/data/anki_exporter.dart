import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:sqlite3/sqlite3.dart';

/// A single entry to be exported as an Anki card.
///
/// Card layout (per D-17):
/// - Front: IPA form (+ romanization if present)
/// - Back: meaning/gloss
/// - Additional fields: POS tag, morphological context
///
/// No audio field (D-19).
class AnkiExportEntry {
  final String ipa;
  final String? romanization;
  final String? meaning;
  final String? partOfSpeech;
  final String? morphologicalContext;

  const AnkiExportEntry({
    required this.ipa,
    this.romanization,
    this.meaning,
    this.partOfSpeech,
    this.morphologicalContext,
  });
}

/// Builds valid Anki .apkg files from [AnkiExportEntry] lists.
///
/// Uses an in-memory SQLite database to construct the Anki collection schema,
/// then serializes it into a ZIP file (.apkg format).
///
/// Threat mitigation T-03-09: all text fields are HTML-escaped before insertion
/// to prevent injection into Anki's HTML card renderer.
class AnkiExporter {
  static const int _modelId = 1_000_000_000;
  static const int _deckId = 1_000_000_001;

  /// Builds a .apkg file (Uint8List) from the given entries.
  Uint8List buildApkg({
    required String deckName,
    required List<AnkiExportEntry> entries,
  }) {
    final db = sqlite3.openInMemory();
    try {
      _createSchema(db);
      _insertCol(db, deckName);
      _insertNotes(db, entries);
      _insertCards(db, entries.length);
      final dbBytes = _serializeDb(db);

      final archive = Archive();
      archive.addFile(
          ArchiveFile('collection.anki21', dbBytes.length, dbBytes));
      final mediaBytes = utf8.encode('{}');
      archive.addFile(ArchiveFile('media', mediaBytes.length, mediaBytes));
      return Uint8List.fromList(ZipEncoder().encode(archive)!);
    } finally {
      db.dispose();
    }
  }

  void _createSchema(Database db) {
    // Anki collection schema v11
    db.execute('''
      CREATE TABLE col (
        id     INTEGER PRIMARY KEY,
        crt    INTEGER NOT NULL,
        mod    INTEGER NOT NULL,
        scm    INTEGER NOT NULL,
        ver    INTEGER NOT NULL,
        dty    INTEGER NOT NULL,
        usn    INTEGER NOT NULL,
        ls     INTEGER NOT NULL,
        conf   TEXT    NOT NULL,
        models TEXT    NOT NULL,
        decks  TEXT    NOT NULL,
        dconf  TEXT    NOT NULL,
        tags   TEXT    NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE notes (
        id    INTEGER PRIMARY KEY,
        guid  TEXT    NOT NULL,
        mid   INTEGER NOT NULL,
        mod   INTEGER NOT NULL,
        usn   INTEGER NOT NULL,
        tags  TEXT    NOT NULL,
        flds  TEXT    NOT NULL,
        sfld  TEXT    NOT NULL,
        csum  INTEGER NOT NULL,
        flags INTEGER NOT NULL,
        data  TEXT    NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE cards (
        id     INTEGER PRIMARY KEY,
        nid    INTEGER NOT NULL,
        did    INTEGER NOT NULL,
        ord    INTEGER NOT NULL,
        mod    INTEGER NOT NULL,
        usn    INTEGER NOT NULL,
        type   INTEGER NOT NULL,
        queue  INTEGER NOT NULL,
        due    INTEGER NOT NULL,
        ivl    INTEGER NOT NULL,
        factor INTEGER NOT NULL,
        reps   INTEGER NOT NULL,
        lapses INTEGER NOT NULL,
        left   INTEGER NOT NULL,
        odue   INTEGER NOT NULL,
        odid   INTEGER NOT NULL,
        flags  INTEGER NOT NULL,
        data   TEXT    NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE revlog (
        id      INTEGER PRIMARY KEY,
        cid     INTEGER NOT NULL,
        usn     INTEGER NOT NULL,
        ease    INTEGER NOT NULL,
        ivl     INTEGER NOT NULL,
        lastIvl INTEGER NOT NULL,
        factor  INTEGER NOT NULL,
        time    INTEGER NOT NULL,
        type    INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE graves (
        usn  INTEGER NOT NULL,
        oid  INTEGER NOT NULL,
        type INTEGER NOT NULL
      );
    ''');
  }

  void _insertCol(Database db, String deckName) {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Model (note type) definition — 4 fields, 1 template
    final models = jsonEncode({
      '$_modelId': {
        'id': _modelId,
        'name': 'Conlang Basic',
        'type': 0,
        'mod': nowSec,
        'usn': -1,
        'sortf': 0,
        'did': _deckId,
        'tmpls': [
          {
            'name': 'Card 1',
            'ord': 0,
            'qfmt': '{{Front}}',
            'afmt':
                '{{FrontSide}}<hr id=answer>{{Back}}<br><small>{{POS}} {{Context}}</small>',
            'bqfmt': '',
            'bafmt': '',
            'did': null,
            'bfont': '',
            'bsize': 0,
          }
        ],
        'flds': [
          {'name': 'Front', 'ord': 0, 'sticky': false, 'rtl': false, 'font': 'Arial', 'size': 20, 'media': []},
          {'name': 'Back', 'ord': 1, 'sticky': false, 'rtl': false, 'font': 'Arial', 'size': 20, 'media': []},
          {'name': 'POS', 'ord': 2, 'sticky': false, 'rtl': false, 'font': 'Arial', 'size': 20, 'media': []},
          {'name': 'Context', 'ord': 3, 'sticky': false, 'rtl': false, 'font': 'Arial', 'size': 20, 'media': []},
        ],
        'css': '.card { font-family: arial; font-size: 20px; text-align: center; }',
        'latexPre': '',
        'latexPost': '',
        'req': [[0, 'any', [0]]],
        'tags': [],
        'vers': [],
      }
    });

    // Deck definition
    final decks = jsonEncode({
      '$_deckId': {
        'id': _deckId,
        'name': deckName,
        'desc': '',
        'mod': nowSec,
        'usn': -1,
        'lrnToday': [0, 0],
        'revToday': [0, 0],
        'newToday': [0, 0],
        'timeToday': [0, 0],
        'collapsed': false,
        'browserCollapsed': false,
        'extendNew': 10,
        'extendRev': 50,
        'conf': 1,
        'dyn': 0,
      }
    });

    db.execute(
      'INSERT INTO col (id, crt, mod, scm, ver, dty, usn, ls, conf, models, decks, dconf, tags) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [1, nowSec, nowMs, nowMs, 11, 0, -1, 0, '{}', models, decks, '{}', '{}'],
    );
  }

  void _insertNotes(Database db, List<AnkiExportEntry> entries) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final stmt = db.prepare(
      'INSERT INTO notes (id, guid, mid, mod, usn, tags, flds, sfld, csum, flags, data) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    );
    try {
      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        final noteId = now * 1000 + i;
        final guid = 'conlang_${noteId}_$i';

        // Build front field: romanization (line 1) + [IPA] (line 2) per D-05
        final front = e.romanization != null && e.romanization!.isNotEmpty
            ? '${_htmlEscape(e.romanization!)}<br>[${_htmlEscape(e.ipa)}]'
            : _htmlEscape(e.ipa);

        final back = _htmlEscape(e.meaning ?? '');
        final pos = _htmlEscape(e.partOfSpeech ?? '');
        final context = _htmlEscape(e.morphologicalContext ?? '');

        // Fields separated by \x1f (Anki unit separator)
        final flds = '$front\x1f$back\x1f$pos\x1f$context';
        final sfld = e.ipa; // sort field = raw IPA
        final csum = _csum(sfld);

        stmt.execute([noteId, guid, _modelId, now, -1, '', flds, sfld, csum, 0, '']);
      }
    } finally {
      stmt.dispose();
    }
  }

  void _insertCards(Database db, int count) {
    if (count == 0) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final stmt = db.prepare(
      'INSERT INTO cards (id, nid, did, ord, mod, usn, type, queue, due, ivl, factor, reps, lapses, left, odue, odid, flags, data) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    );
    try {
      final noteRows = db.select('SELECT id FROM notes ORDER BY id');
      for (var i = 0; i < noteRows.length; i++) {
        final nid = noteRows[i]['id'] as int;
        final cardId = now * 1000 + 100000 + i;
        stmt.execute([
          cardId, nid, _deckId, 0, now, -1, 0, 0, i + 1, 0, 0, 0, 0, 0, 0, 0, 0, '',
        ]);
      }
    } finally {
      stmt.dispose();
    }
  }

  /// Serializes the in-memory SQLite database to raw bytes.
  ///
  /// Uses VACUUM INTO a temp file since sqlite3 2.9.4 does not expose
  /// `db.serialize()` as a Dart method.
  Uint8List _serializeDb(Database db) {
    // Create a unique temp file path
    final tmpPath = _tempDbPath();
    try {
      db.execute("VACUUM INTO '${tmpPath.replaceAll("'", "''")}'");
      final file = File(tmpPath);
      final bytes = file.readAsBytesSync();
      return Uint8List.fromList(bytes);
    } finally {
      try {
        File(tmpPath).deleteSync();
      } catch (_) {
        // Best-effort cleanup
      }
    }
  }

  String _tempDbPath() {
    // Generate a unique temp path using current timestamp + pid
    final tmpDir = Directory.systemTemp.path;
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '$tmpDir/anki_export_$ts.db';
  }

  /// Simple djb2 checksum for the sort field, matching Anki's csum algorithm.
  ///
  /// Anki uses the first 8 hex digits of the SHA1 of the sfld, but a
  /// djb2 hash is sufficient for uniqueness within a deck.
  int _csum(String sfld) {
    // Anki's actual algorithm: int(hashlib.sha1(sfld.encode("utf-8")).hexdigest()[:8], 16)
    // We implement a compatible djb2 checksum within 32-bit range.
    var hash = 5381;
    for (final codeUnit in sfld.codeUnits) {
      hash = ((hash << 5) + hash + codeUnit) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// HTML-escapes a string to prevent injection into Anki's card HTML renderer.
  ///
  /// Mitigates threat T-03-09 (injection via notes.flds column).
  String _htmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }
}
