import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:xml/xml.dart';

import 'parsed_document.dart';

String decodeTextBytes(List<int> bytes) {
  try {
    final decoded = utf8.decode(bytes);
    if (!decoded.contains('\uFFFD')) return decoded;
  } catch (_) {
    // Fall through to a permissive decode.
  }
  return utf8.decode(bytes, allowMalformed: true);
}

final _chapterHeading = RegExp(
  r'^(chapter|part|book|section|prologue|epilogue|introduction|preface|contents)\b',
  caseSensitive: false,
);

bool _looksLikeHeading(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.length > 90) return false;
  if (_chapterHeading.hasMatch(trimmed)) return true;
  if (RegExp(r'^\d{1,4}[\.\s]').hasMatch(trimmed) && trimmed.length < 60) return true;
  final letters = trimmed.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.length >= 4 && letters == letters.toUpperCase()) return true;
  return false;
}

ParsedDocument parsePlainText(String text, {required String fallbackTitle}) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final rawParagraphs = normalized
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  var title = fallbackTitle;
  final firstLines = normalized.split('\n').where((l) => l.trim().isNotEmpty).take(3).toList();
  if (firstLines.isNotEmpty &&
      firstLines.first.trim().length <= 80 &&
      !firstLines.first.trim().endsWith('.')) {
    title = firstLines.first.trim();
  }

  final chapters = <ParsedChapter>[];
  var currentTitle = title;
  var blocks = <DocBlock>[];
  final headingPattern = RegExp(r'^(chapter|part|book|section)\b', caseSensitive: false);

  void flush() {
    if (blocks.isEmpty) return;
    chapters.add(ParsedChapter(title: currentTitle, blocks: blocks));
    blocks = <DocBlock>[];
  }

  var skippedTitle = false;
  for (final paragraph in rawParagraphs) {
    if (!skippedTitle && paragraph.trim() == title) {
      skippedTitle = true;
      continue;
    }
    final lines = paragraph.split('\n');
    if (lines.length == 1 && _looksLikeHeading(paragraph) && headingPattern.hasMatch(paragraph)) {
      flush();
      currentTitle = paragraph.trim();
      blocks.add(DocBlock(paragraph.trim(), headingLevel: 1));
      continue;
    }
    if (lines.length == 1 && _looksLikeHeading(paragraph) && blocks.length > 20) {
      flush();
      currentTitle = paragraph.trim();
      blocks.add(DocBlock(paragraph.trim(), headingLevel: 1));
      continue;
    }
    blocks.add(DocBlock(paragraph.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim()));
  }
  flush();

  if (chapters.isEmpty) {
    chapters.add(ParsedChapter(
      title: title,
      blocks: [DocBlock(normalized.trim())],
    ));
  }
  return ParsedDocument(title: title, chapters: chapters);
}

ParsedDocument parseEpubBytes(List<int> bytes, {required String fallbackTitle}) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: false);
  final byName = {for (final file in archive) file.name: file};

  final container = byName['META-INF/container.xml'];
  if (container == null) {
    throw const FormatException('This EPUB is missing its container file.');
  }
  final containerXml = XmlDocument.parse(decodeTextBytes(container.content as List<int>));
  final rootPath = containerXml
      .findAllElements('rootfile', namespace: '*')
      .map((e) => e.getAttribute('full-path'))
      .whereType<String>()
      .firstOrNull;
  if (rootPath == null) {
    throw const FormatException('This EPUB has no package document.');
  }
  final opfFile = byName[rootPath];
  if (opfFile == null) {
    throw const FormatException('This EPUB package document is missing.');
  }
  final opf = XmlDocument.parse(decodeTextBytes(opfFile.content as List<int>));
  final baseDir = rootPath.contains('/') ? rootPath.substring(0, rootPath.lastIndexOf('/') + 1) : '';

  final title = opf
          .findAllElements('title', namespace: '*')
          .map((e) => e.innerText.trim())
          .where((t) => t.isNotEmpty)
          .firstOrNull ??
      fallbackTitle;
  final author = opf
      .findAllElements('creator', namespace: '*')
      .map((e) => e.innerText.trim())
      .where((t) => t.isNotEmpty)
      .firstOrNull;

  final manifest = <String, String>{};
  final manifestTypes = <String, String>{};
  final coverProperties = <String>{};
  for (final item in opf.findAllElements('item', namespace: '*')) {
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id != null && href != null) {
      manifest[id] = href;
      manifestTypes[id] = item.getAttribute('media-type') ?? '';
      if ((item.getAttribute('properties') ?? '').contains('cover-image')) {
        coverProperties.add(id);
      }
    }
  }

  String? coverId;
  for (final meta in opf.findAllElements('meta', namespace: '*')) {
    if (meta.getAttribute('name') == 'cover') {
      coverId = meta.getAttribute('content');
    }
  }
  coverId ??= coverProperties.isNotEmpty ? coverProperties.first : null;
  Uint8List? coverBytes;
  String? coverExtension;
  if (coverId != null && manifest[coverId] != null) {
    final coverHref = _resolvePath(baseDir, manifest[coverId]!);
    final entry = byName[coverHref] ?? byName[Uri.decodeFull(coverHref)];
    final mediaType = manifestTypes[coverId] ?? '';
    if (entry != null) {
      coverBytes = Uint8List.fromList(entry.content as List<int>);
      coverExtension = switch (mediaType) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/gif' => 'gif',
        'image/svg+xml' => 'svg',
        _ => 'jpg',
      };
    }
  }

  final chapters = <ParsedChapter>[];
  var index = 0;
  for (final itemref in opf.findAllElements('itemref', namespace: '*')) {
    final idref = itemref.getAttribute('idref');
    if (idref == null) continue;
    final href = manifest[idref];
    if (href == null) continue;
    final path = _resolvePath(baseDir, href);
    final entry = byName[path] ?? byName[Uri.decodeFull(path)];
    if (entry == null) continue;
    final markup = decodeTextBytes(entry.content as List<int>);
    final chapter = _parseXhtmlChapter(markup, index + 1);
    if (chapter == null || chapter.blocks.isEmpty) continue;
    chapters.add(chapter);
    index += 1;
  }

  if (chapters.isEmpty) {
    throw const FormatException('No readable chapters were found in this EPUB.');
  }
  return ParsedDocument(
      title: title,
      author: author,
      chapters: chapters,
      coverBytes: coverBytes,
      coverExtension: coverExtension,
    );
}

String _resolvePath(String baseDir, String href) {
  final cleanHref = href.split('#').first;
  final segments = ('$baseDir$cleanHref').split('/');
  final resolved = <String>[];
  for (final segment in segments) {
    if (segment == '..') {
      if (resolved.isNotEmpty) resolved.removeLast();
    } else if (segment != '.' && segment.isNotEmpty) {
      resolved.add(segment);
    }
  }
  return resolved.join('/');
}

ParsedChapter? _parseXhtmlChapter(String markup, int number) {
  final document = html.parse(markup);
  final body = document.body;
  if (body == null) return null;

  for (final tag in ['script', 'style', 'nav', 'svg', 'figure']) {
    for (final node in body.querySelectorAll(tag)) {
      node.remove();
    }
  }

  final blocks = <DocBlock>[];
  var title = '';
  final selectors = 'h1,h2,h3,h4,p,li,blockquote,pre';
  final elements = body.querySelectorAll(selectors);
  if (elements.isEmpty) {
    final text = body.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return null;
    return ParsedChapter(title: 'Chapter $number', blocks: [DocBlock(text)]);
  }
  for (final element in elements) {
    final text = element.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) continue;
    switch (element.localName) {
      case 'h1':
        blocks.add(DocBlock(text, headingLevel: 1));
        if (title.isEmpty) title = text;
      case 'h2':
        blocks.add(DocBlock(text, headingLevel: 2));
        if (title.isEmpty) title = text;
      case 'h3':
      case 'h4':
        blocks.add(DocBlock(text, headingLevel: 3));
        if (title.isEmpty) title = text;
      case 'li':
        blocks.add(DocBlock('• $text'));
      default:
        blocks.add(DocBlock(text));
    }
  }
  if (blocks.isEmpty) return null;
  return ParsedChapter(title: title.isEmpty ? 'Chapter $number' : title, blocks: blocks);
}

List<DocBlock> blocksFromHtml(dom.Document document) {
  final body = document.body;
  if (body == null) return const [];
  for (final tag in ['script', 'style', 'nav', 'header', 'footer', 'aside', 'form', 'svg', 'noscript']) {
    for (final node in body.querySelectorAll(tag)) {
      node.remove();
    }
  }
  final blocks = <DocBlock>[];
  for (final element in body.querySelectorAll('h1,h2,h3,p,li,blockquote,pre')) {
    final text = element.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) continue;
    final level = switch (element.localName) {
      'h1' => 1,
      'h2' => 2,
      'h3' => 3,
      _ => 0,
    };
    blocks.add(DocBlock(level > 0 ? text : (element.localName == 'li' ? '• $text' : text),
        headingLevel: level));
  }
  return blocks;
}

Future<ParsedDocument> parseTextFile(File file, {required String fallbackTitle}) async {
  final text = decodeTextBytes(await file.readAsBytes());
  return parsePlainText(text, fallbackTitle: fallbackTitle);
}

Future<ParsedDocument> parseEpubFile(File file, {required String fallbackTitle}) async {
  return parseEpubBytes(await file.readAsBytes(), fallbackTitle: fallbackTitle);
}
