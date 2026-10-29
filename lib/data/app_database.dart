import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static Future<AppDatabase> open() async {
    final path = p.join(await getDatabasesPath(), 'sotto.db');
    final db = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE docs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            author TEXT,
            kind TEXT NOT NULL,
            path TEXT NOT NULL,
            source_url TEXT,
            char_count INTEGER NOT NULL DEFAULT 0,
            progress REAL NOT NULL DEFAULT 0,
            last_offset INTEGER NOT NULL DEFAULT 0,
            added_at TEXT NOT NULL,
            opened_at TEXT,
            cover_seed INTEGER NOT NULL DEFAULT 0,
            cover_path TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE tracks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            path TEXT NOT NULL,
            format TEXT NOT NULL,
            voice TEXT NOT NULL,
            model TEXT NOT NULL,
            speed REAL NOT NULL DEFAULT 1,
            duration_ms INTEGER NOT NULL DEFAULT 0,
            size_bytes INTEGER NOT NULL DEFAULT 0,
            doc_id INTEGER REFERENCES docs(id) ON DELETE SET NULL,
            excerpt TEXT,
            favorite INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            peaks TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE playlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE playlist_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
            track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
            position INTEGER NOT NULL,
            UNIQUE(playlist_id, track_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            doc_id INTEGER NOT NULL REFERENCES docs(id) ON DELETE CASCADE,
            offset INTEGER NOT NULL,
            snippet TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_docs_opened ON docs(opened_at DESC)');
        await db.execute('CREATE INDEX idx_tracks_created ON tracks(created_at DESC)');
        await db.execute('CREATE INDEX idx_bookmarks_doc ON bookmarks(doc_id, offset)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE docs ADD COLUMN cover_path TEXT');
          await db.execute('ALTER TABLE tracks ADD COLUMN peaks TEXT');
        }
      },
    );
    return AppDatabase._(db);
  }

  Future<List<Doc>> docs({bool includeArchived = false}) async {
    final rows = await _db.query('docs', orderBy: 'COALESCE(opened_at, added_at) DESC');
    return rows.map(Doc.fromMap).toList();
  }

  Future<Doc?> doc(int id) async {
    final rows = await _db.query('docs', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Doc.fromMap(rows.first);
  }

  Future<int> insertDoc(Doc doc) => _db.insert('docs', doc.toMap());

  Future<void> updateDocProgress(int id, double progress, int offset) async {
    await _db.update(
      'docs',
      {
        'progress': progress.clamp(0, 1),
        'last_offset': offset,
        'opened_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> touchDoc(int id) async {
    await _db.update(
      'docs',
      {'opened_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> renameDoc(int id, String title) async {
    await _db.update('docs', {'title': title}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteDoc(int id) async {
    await _db.delete('docs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AudioTrack>> tracks({bool favoritesOnly = false}) async {
    final rows = await _db.query(
      'tracks',
      where: favoritesOnly ? 'favorite = 1' : null,
      orderBy: 'created_at DESC',
    );
    return rows.map(AudioTrack.fromMap).toList();
  }

  Future<AudioTrack?> track(int id) async {
    final rows = await _db.query('tracks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return AudioTrack.fromMap(rows.first);
  }

  Future<int> insertTrack(AudioTrack track) => _db.insert('tracks', track.toMap());

  Future<void> renameTrack(int id, String title) async {
    await _db.update('tracks', {'title': title}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setFavorite(int id, bool value) async {
    await _db.update('tracks', {'favorite': value ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTrack(int id) async {
    await _db.delete('tracks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Playlist>> playlists() async {
    final rows = await _db.rawQuery('''
      SELECT p.*, (SELECT COUNT(*) FROM playlist_items i WHERE i.playlist_id = p.id) AS track_count
      FROM playlists p ORDER BY p.created_at DESC
    ''');
    return rows.map(Playlist.fromMap).toList();
  }

  Future<int> insertPlaylist(Playlist playlist) => _db.insert('playlists', playlist.toMap());

  Future<void> deletePlaylist(int id) async {
    await _db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addToPlaylist(int playlistId, int trackId) async {
    final next = Sqflite.firstIntValue(await _db.rawQuery(
          'SELECT COALESCE(MAX(position), 0) + 1 FROM playlist_items WHERE playlist_id = ?',
          [playlistId],
        )) ??
        1;
    await _db.insert(
      'playlist_items',
      {'playlist_id': playlistId, 'track_id': trackId, 'position': next},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeFromPlaylist(int playlistId, int trackId) async {
    await _db.delete(
      'playlist_items',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, trackId],
    );
  }

  Future<List<AudioTrack>> playlistTracks(int playlistId) async {
    final rows = await _db.rawQuery('''
      SELECT t.* FROM playlist_items i
      JOIN tracks t ON t.id = i.track_id
      WHERE i.playlist_id = ?
      ORDER BY i.position ASC
    ''', [playlistId]);
    return rows.map(AudioTrack.fromMap).toList();
  }

  Future<List<DocBookmark>> bookmarks(int docId) async {
    final rows = await _db.query(
      'bookmarks',
      where: 'doc_id = ?',
      whereArgs: [docId],
      orderBy: 'offset ASC',
    );
    return rows.map(DocBookmark.fromMap).toList();
  }

  Future<int> insertBookmark(DocBookmark bookmark) => _db.insert('bookmarks', bookmark.toMap());

  Future<void> deleteBookmark(int id) async {
    await _db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> totalAudioBytes() async {
    final value = await _db.rawQuery('SELECT COALESCE(SUM(size_bytes), 0) AS total FROM tracks');
    return (value.first['total'] as int?) ?? 0;
  }

  Future<void> close() => _db.close();
}
