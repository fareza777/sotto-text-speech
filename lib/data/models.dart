import '../core/audio_peaks.dart';

enum DocKind { txt, epub, pdf, article }

DocKind docKindFromName(String name) {
  switch (name) {
    case 'epub':
      return DocKind.epub;
    case 'pdf':
      return DocKind.pdf;
    case 'article':
      return DocKind.article;
    default:
      return DocKind.txt;
  }
}

class Doc {
  const Doc({
    this.id,
    required this.title,
    this.author,
    required this.kind,
    required this.path,
    this.sourceUrl,
    required this.charCount,
    this.progress = 0,
    this.lastOffset = 0,
    this.addedAt,
    this.openedAt,
    this.coverSeed = 0,
    this.coverPath,
  });

  final int? id;
  final String title;
  final String? author;
  final DocKind kind;
  final String path;
  final String? sourceUrl;
  final int charCount;
  final double progress;
  final int lastOffset;
  final DateTime? addedAt;
  final DateTime? openedAt;
  final int coverSeed;
  final String? coverPath;

  Doc copyWith({
    int? id,
    String? title,
    String? author,
    DocKind? kind,
    String? path,
    String? sourceUrl,
    int? charCount,
    double? progress,
    int? lastOffset,
    DateTime? addedAt,
    DateTime? openedAt,
    int? coverSeed,
    String? coverPath,
  }) {
    return Doc(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      kind: kind ?? this.kind,
      path: path ?? this.path,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      charCount: charCount ?? this.charCount,
      progress: progress ?? this.progress,
      lastOffset: lastOffset ?? this.lastOffset,
      addedAt: addedAt ?? this.addedAt,
      openedAt: openedAt ?? this.openedAt,
      coverSeed: coverSeed ?? this.coverSeed,
      coverPath: coverPath ?? this.coverPath,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'author': author,
        'kind': kind.name,
        'path': path,
        'source_url': sourceUrl,
        'char_count': charCount,
        'progress': progress,
        'last_offset': lastOffset,
        'added_at': (addedAt ?? DateTime.now()).toIso8601String(),
        'opened_at': openedAt?.toIso8601String(),
        'cover_seed': coverSeed,
        'cover_path': coverPath,
      };

  static Doc fromMap(Map<String, Object?> map) => Doc(
        id: map['id'] as int?,
        title: map['title'] as String? ?? 'Untitled',
        author: map['author'] as String?,
        kind: docKindFromName(map['kind'] as String? ?? 'txt'),
        path: map['path'] as String? ?? '',
        sourceUrl: map['source_url'] as String?,
        charCount: map['char_count'] as int? ?? 0,
        progress: (map['progress'] as num?)?.toDouble() ?? 0,
        lastOffset: map['last_offset'] as int? ?? 0,
        addedAt: DateTime.tryParse(map['added_at'] as String? ?? ''),
        openedAt: DateTime.tryParse(map['opened_at'] as String? ?? ''),
        coverSeed: map['cover_seed'] as int? ?? 0,
        coverPath: map['cover_path'] as String?,
      );
}

class AudioTrack {
  const AudioTrack({
    this.id,
    required this.title,
    required this.path,
    required this.format,
    required this.voice,
    required this.model,
    required this.speed,
    required this.durationMs,
    required this.sizeBytes,
    this.docId,
    this.excerpt,
    this.favorite = false,
    this.createdAt,
    this.peaks,
  });

  final int? id;
  final String title;
  final String path;
  final String format;
  final String voice;
  final String model;
  final double speed;
  final int durationMs;
  final int sizeBytes;
  final int? docId;
  final String? excerpt;
  final bool favorite;
  final DateTime? createdAt;
  final String? peaks;

  List<double> get peakValues => decodePeaks(peaks);

  String get durationLabel {
    final total = Duration(milliseconds: durationMs);
    final m = total.inMinutes;
    final s = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (m >= 60) {
      final h = m ~/ 60;
      return '${h}h ${(m % 60).toString().padLeft(2, '0')}m';
    }
    return '$m:$s';
  }

  AudioTrack copyWith({
    int? id,
    String? title,
    String? path,
    String? format,
    String? voice,
    String? model,
    double? speed,
    int? durationMs,
    int? sizeBytes,
    int? docId,
    String? excerpt,
    bool? favorite,
    DateTime? createdAt,
    String? peaks,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      format: format ?? this.format,
      voice: voice ?? this.voice,
      model: model ?? this.model,
      speed: speed ?? this.speed,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      docId: docId ?? this.docId,
      excerpt: excerpt ?? this.excerpt,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt ?? this.createdAt,
      peaks: peaks ?? this.peaks,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'path': path,
        'format': format,
        'voice': voice,
        'model': model,
        'speed': speed,
        'duration_ms': durationMs,
        'size_bytes': sizeBytes,
        'doc_id': docId,
        'excerpt': excerpt,
        'favorite': favorite ? 1 : 0,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'peaks': peaks,
      };

  static AudioTrack fromMap(Map<String, Object?> map) => AudioTrack(
        id: map['id'] as int?,
        title: map['title'] as String? ?? 'Untitled audio',
        path: map['path'] as String? ?? '',
        format: map['format'] as String? ?? 'wav',
        voice: map['voice'] as String? ?? 'bella',
        model: map['model'] as String? ?? 'nano-int8',
        speed: (map['speed'] as num?)?.toDouble() ?? 1,
        durationMs: map['duration_ms'] as int? ?? 0,
        sizeBytes: map['size_bytes'] as int? ?? 0,
        docId: map['doc_id'] as int?,
        excerpt: map['excerpt'] as String?,
        favorite: (map['favorite'] as int? ?? 0) == 1,
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
        peaks: map['peaks'] as String?,
      );
}

class Playlist {
  const Playlist({
    this.id,
    required this.name,
    this.createdAt,
    this.trackCount = 0,
  });

  final int? id;
  final String name;
  final DateTime? createdAt;
  final int trackCount;

  Playlist copyWith({int? id, String? name, DateTime? createdAt, int? trackCount}) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      trackCount: trackCount ?? this.trackCount,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  static Playlist fromMap(Map<String, Object?> map) => Playlist(
        id: map['id'] as int?,
        name: map['name'] as String? ?? 'Playlist',
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
        trackCount: map['track_count'] as int? ?? 0,
      );
}

class DocBookmark {
  const DocBookmark({
    this.id,
    required this.docId,
    required this.offset,
    required this.snippet,
    this.createdAt,
  });

  final int? id;
  final int docId;
  final int offset;
  final String snippet;
  final DateTime? createdAt;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'doc_id': docId,
        'offset': offset,
        'snippet': snippet,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  static DocBookmark fromMap(Map<String, Object?> map) => DocBookmark(
        id: map['id'] as int?,
        docId: map['doc_id'] as int? ?? 0,
        offset: map['offset'] as int? ?? 0,
        snippet: map['snippet'] as String? ?? '',
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
      );
}
