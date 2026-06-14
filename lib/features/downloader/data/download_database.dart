import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/download_task.dart';

/// sqflite-backed persistence for the download queue.
class DownloadDatabase {
  DownloadDatabase._(this._db);

  final Database _db;
  static const _table = 'download_tasks';

  static Future<DownloadDatabase> open() async {
    final path = p.join(await getDatabasesPath(), 'tubedl.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            videoId TEXT NOT NULL,
            title TEXT NOT NULL,
            author TEXT,
            thumbnailUrl TEXT NOT NULL,
            filePath TEXT NOT NULL,
            status INTEGER NOT NULL,
            progress INTEGER NOT NULL,
            createdAt INTEGER NOT NULL,
            isAudio INTEGER NOT NULL,
            convertToMp3 INTEGER NOT NULL,
            quality TEXT,
            container TEXT
          )
        ''');
      },
    );
    return DownloadDatabase._(db);
  }

  Future<List<DownloadTask>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'createdAt DESC');
    return rows.map(DownloadTask.fromMap).toList();
  }

  Future<void> insert(DownloadTask task) =>
      _db.insert(_table, task.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> update(DownloadTask task) =>
      _db.update(_table, task.toMap(), where: 'id = ?', whereArgs: [task.id]);

  Future<void> updateId(String oldId, String newId) => _db.update(
        _table,
        {'id': newId},
        where: 'id = ?',
        whereArgs: [oldId],
      );

  Future<void> delete(String id) =>
      _db.delete(_table, where: 'id = ?', whereArgs: [id]);
}
