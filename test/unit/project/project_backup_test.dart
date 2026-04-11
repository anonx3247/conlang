import 'dart:io';

import 'package:conlang_workbench/features/project/data/project_backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('conlang_backup_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<String> seedDb(int userVersion) async {
    final path = p.join(tmp.path, 'project.db');
    final raw = sqlite3.open(path);
    try {
      raw.execute('CREATE TABLE dummy (id INTEGER)');
      raw.execute('PRAGMA user_version = $userVersion');
    } finally {
      raw.dispose();
    }
    return path;
  }

  test('no-op when file does not exist', () async {
    final result =
        await backupProjectDbIfNeeded(p.join(tmp.path, 'missing.db'));
    expect(result, isFalse);
    expect(File(p.join(tmp.path, 'missing.db.v7.bak')).existsSync(), isFalse);
  });

  test('backs up a v7 project db', () async {
    final path = await seedDb(7);
    final result = await backupProjectDbIfNeeded(path);
    expect(result, isTrue);
    expect(File('$path.v7.bak').existsSync(), isTrue);
    expect(File('$path.v7.bak').lengthSync(),
        equals(File(path).lengthSync()));
  });

  test('backs up a pre-v7 project db (e.g. v5)', () async {
    final path = await seedDb(5);
    final result = await backupProjectDbIfNeeded(path);
    expect(result, isTrue);
    expect(File('$path.v7.bak').existsSync(), isTrue);
  });

  test('no-op when user_version >= 8', () async {
    final path = await seedDb(8);
    final result = await backupProjectDbIfNeeded(path);
    expect(result, isFalse);
    expect(File('$path.v7.bak').existsSync(), isFalse);
  });

  test('idempotent - does not overwrite existing backup', () async {
    final path = await seedDb(7);
    await File('$path.v7.bak').writeAsString('sentinel');
    final result = await backupProjectDbIfNeeded(path);
    expect(result, isFalse);
    expect(File('$path.v7.bak').readAsStringSync(), equals('sentinel'));
  });
}
