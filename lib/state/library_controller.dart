import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/models.dart';
import '../features/import/document_importer.dart';

class LibraryController extends ChangeNotifier {
  LibraryController(this.db, this.importer);

  final AppDatabase db;
  final DocumentImporter importer;

  List<Doc> _docs = const [];
  List<AudioTrack> _tracks = const [];
  List<Playlist> _playlists = const [];
  bool _loading = true;
  int _audioBytes = 0;

  List<Doc> get docs => _docs;
  List<AudioTrack> get tracks => _tracks;
  List<Playlist> get playlists => _playlists;
  List<AudioTrack> get favorites => _tracks.where((t) => t.favorite).toList();
  bool get loading => _loading;
  int get audioBytes => _audioBytes;

  Future<void> refresh() async {
    _docs = await db.docs();
    _tracks = await db.tracks();
    _playlists = await db.playlists();
    _audioBytes = await db.totalAudioBytes();
    _loading = false;
    notifyListeners();
  }

  Future<void> refreshTracks() async {
    _tracks = await db.tracks();
    _audioBytes = await db.totalAudioBytes();
    notifyListeners();
  }

  Future<void> refreshDocs() async {
    _docs = await db.docs();
    notifyListeners();
  }

  Future<Doc> importFile(String path, {void Function(double, String)? onProgress}) async {
    final doc = await importer.importFile(path, onProgress: onProgress);
    await refreshDocs();
    return doc;
  }

  Future<Doc> importArticle(String url, {void Function(double, String)? onProgress}) async {
    final doc = await importer.importArticle(url, onProgress: onProgress);
    await refreshDocs();
    return doc;
  }

  Future<void> saveDocProgress(int docId, double progress, int offset) async {
    await db.updateDocProgress(docId, progress, offset);
    final index = _docs.indexWhere((d) => d.id == docId);
    if (index >= 0) {
      _docs[index] = _docs[index].copyWith(
        progress: progress,
        lastOffset: offset,
        openedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  Future<void> deleteDoc(Doc doc) async {
    await db.deleteDoc(doc.id!);
    final file = File(doc.path);
    final dir = file.parent;
    if (await dir.exists()) await dir.delete(recursive: true);
    await refreshDocs();
  }

  Future<void> addTrack(AudioTrack track) async {
    final id = await db.insertTrack(track);
    _tracks = [track.copyWith(id: id), ..._tracks];
    _audioBytes += track.sizeBytes;
    notifyListeners();
  }

  Future<void> deleteTrack(AudioTrack track) async {
    if (track.id != null) await db.deleteTrack(track.id!);
    final file = File(track.path);
    if (await file.exists()) await file.delete();
    _tracks = _tracks.where((t) => t.id != track.id).toList();
    _audioBytes = (_audioBytes - track.sizeBytes).clamp(0, 1 << 62);
    notifyListeners();
  }

  Future<void> toggleFavorite(AudioTrack track) async {
    if (track.id == null) return;
    final value = !track.favorite;
    await db.setFavorite(track.id!, value);
    _tracks = _tracks
        .map((t) => t.id == track.id ? t.copyWith(favorite: value) : t)
        .toList();
    notifyListeners();
  }

  Future<void> renameTrack(AudioTrack track, String title) async {
    if (track.id == null) return;
    await db.renameTrack(track.id!, title);
    _tracks = _tracks.map((t) => t.id == track.id ? t.copyWith(title: title) : t).toList();
    notifyListeners();
  }

  Future<List<DocBookmark>> bookmarks(int docId) => db.bookmarks(docId);

  Future<void> addBookmark(int docId, int offset, String snippet) async {
    await db.insertBookmark(
      DocBookmark(docId: docId, offset: offset, snippet: snippet),
    );
  }

  Future<void> removeBookmark(int id) => db.deleteBookmark(id);

  Future<Playlist> createPlaylist(String name) async {
    final playlist = Playlist(name: name);
    final id = await db.insertPlaylist(playlist);
    await refresh();
    return playlist.copyWith(id: id);
  }

  Future<void> deletePlaylist(int id) async {
    await db.deletePlaylist(id);
    await refresh();
  }

  Future<void> addTrackToPlaylist(int playlistId, int trackId) async {
    await db.addToPlaylist(playlistId, trackId);
    await refresh();
  }

  Future<void> removeTrackFromPlaylist(int playlistId, int trackId) async {
    await db.removeFromPlaylist(playlistId, trackId);
    await refresh();
  }

  Future<List<AudioTrack>> playlistTracks(int playlistId) => db.playlistTracks(playlistId);
}
