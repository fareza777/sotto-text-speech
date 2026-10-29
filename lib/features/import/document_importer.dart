import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/app_database.dart';
import '../../data/models.dart';
import 'article_parser.dart';
import 'parsed_document.dart';
import 'pdf_parser.dart';
import 'text_parsers.dart';

class DocumentImporter {
  DocumentImporter(this._db);

  final AppDatabase _db;

  Future<Directory> _libraryRoot() async {
    final dir = await getApplicationDocumentsDirectory();
    final library = Directory(p.join(dir.path, 'library'));
    await library.create(recursive: true);
    return library;
  }

  Future<Doc> importFile(
    String sourcePath, {
    void Function(double progress, String stage)? onProgress,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FormatException('That file could not be opened.');
    }
    final extension = p.extension(sourcePath).toLowerCase();
    final kind = switch (extension) {
      '.epub' => DocKind.epub,
      '.pdf' => DocKind.pdf,
      _ => DocKind.txt,
    };
    final fallbackTitle = p.basenameWithoutExtension(sourcePath).replaceAll('_', ' ').trim();
    final size = await source.length();
    if (size > 80 * 1024 * 1024) {
      throw const FormatException('Documents larger than 80 MB are not supported.');
    }

    final root = await _libraryRoot();
    final folder = Directory(
      p.join(root.path, 'doc_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}'),
    );
    await folder.create(recursive: true);

    try {
      onProgress?.call(0.05, 'Copying document');
      final sourceCopy = File(p.join(folder.path, 'source$extension'));
      await source.copy(sourceCopy.path);

      ParsedDocument parsed;
      switch (kind) {
        case DocKind.pdf:
          onProgress?.call(0.12, 'Reading PDF');
          parsed = await parsePdfFile(
            sourceCopy,
            fallbackTitle: fallbackTitle,
            onProgress: (value) => onProgress?.call(0.12 + value * 0.78, 'Reading PDF'),
          );
        case DocKind.epub:
          onProgress?.call(0.2, 'Reading EPUB');
          parsed = await parseEpubFile(sourceCopy, fallbackTitle: fallbackTitle);
        case DocKind.txt:
        case DocKind.article:
          onProgress?.call(0.2, 'Reading text');
          parsed = await parseTextFile(sourceCopy, fallbackTitle: fallbackTitle);
      }

      onProgress?.call(0.94, 'Preparing pages');
      final content = File(p.join(folder.path, 'content.json'));
      await content.writeAsString(parsed.toJsonString(), flush: true);

      String? coverPath;
      if (parsed.coverBytes != null && parsed.coverBytes!.isNotEmpty) {
        final extension = parsed.coverExtension ?? 'png';
        final coverFile = File(p.join(folder.path, 'cover.$extension'));
        await coverFile.writeAsBytes(parsed.coverBytes!, flush: true);
        coverPath = coverFile.path;
      }

      final doc = Doc(
        title: parsed.title.trim().isEmpty ? fallbackTitle : parsed.title.trim(),
        author: parsed.author,
        kind: kind,
        path: content.path,
        charCount: parsed.charCount,
        coverSeed: parsed.title.hashCode.abs() % 360,
        coverPath: coverPath,
      );
      final id = await _db.insertDoc(doc);
      onProgress?.call(1, 'Ready');
      return doc.copyWith(id: id);
    } catch (_) {
      if (await folder.exists()) await folder.delete(recursive: true);
      rethrow;
    }
  }

  Future<Doc> importArticle(
    String url, {
    void Function(double progress, String stage)? onProgress,
  }) async {
    onProgress?.call(0.1, 'Fetching article');
    final parsed = await parseArticleUrl(url);
    onProgress?.call(0.8, 'Preparing pages');
    final root = await _libraryRoot();
    final folder = Directory(
      p.join(root.path, 'doc_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}'),
    );
    await folder.create(recursive: true);
    try {
      final content = File(p.join(folder.path, 'content.json'));
      await content.writeAsString(parsed.toJsonString(), flush: true);
      final doc = Doc(
        title: parsed.title,
        author: parsed.author,
        kind: DocKind.article,
        path: content.path,
        sourceUrl: url,
        charCount: parsed.charCount,
        coverSeed: parsed.title.hashCode.abs() % 360,
      );
      final id = await _db.insertDoc(doc);
      onProgress?.call(1, 'Ready');
      return doc.copyWith(id: id);
    } catch (_) {
      if (await folder.exists()) await folder.delete(recursive: true);
      rethrow;
    }
  }

  Future<ParsedDocument> loadContent(Doc doc) async {
    final file = File(doc.path);
    if (!await file.exists()) {
      throw const FormatException('This document file is missing.');
    }
    return ParsedDocument.fromJsonString(await file.readAsString());
  }
}
