import 'dart:io';
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../../core/png.dart';

import 'parsed_document.dart';

const _pagesPerChapter = 10;

final _sentenceEnd = RegExp(r'[.!?]["”’)]?$');
final _chapterHeading = RegExp(
  r'^(chapter|part|book|prologue|epilogue|introduction|preface|contents)\b',
  caseSensitive: false,
);

Future<ParsedDocument> parsePdfFile(
  File file, {
  required String fallbackTitle,
  void Function(double progress)? onProgress,
}) async {
  await pdfrxFlutterInitialize();
  final document = await PdfDocument.openFile(file.path);
  try {
    final pages = document.pages;
    if (pages.isEmpty) {
      throw const FormatException('This PDF has no pages.');
    }
    var title = fallbackTitle;
    Uint8List? coverBytes;
    try {
      final rendered = await pages.first.render(width: 640);
      if (rendered != null) {
        coverBytes = encodePngBgra(rendered.pixels, rendered.width, rendered.height);
        rendered.dispose();
      }
    } catch (_) {
      // A cover is nice to have; never fail an import over it.
    }
    final chapters = <ParsedChapter>[];
    var blocks = <DocBlock>[];
    var chapterStart = 1;
    var extractedChars = 0;

    for (var i = 0; i < pages.length; i++) {
      onProgress?.call((i + 1) / pages.length);
      String text;
      try {
        final raw = await pages[i].loadText();
        text = raw?.fullText ?? '';
      } catch (_) {
        text = '';
      }
      extractedChars += text.trim().length;
      final pageBlocks = pdfBlocks(text);
      if (i == 0 && pageBlocks.isNotEmpty) {
        final first = pageBlocks.first;
        if (first.headingLevel > 0 &&
            first.text.length <= 90 &&
            !_sentenceEnd.hasMatch(first.text)) {
          title = first.text;
          pageBlocks.removeAt(0);
        }
      }
      blocks.addAll(pageBlocks);

      final isLast = i == pages.length - 1;
      if ((i + 1) % _pagesPerChapter == 0 || isLast) {
        if (blocks.isNotEmpty) {
          final end = i + 1;
          chapters.add(
            ParsedChapter(
              title: chapterStart == end
                  ? 'Page $chapterStart'
                  : 'Pages $chapterStart–$end',
              blocks: blocks,
            ),
          );
          blocks = <DocBlock>[];
        }
        chapterStart = i + 2;
      }
    }

    if (extractedChars < 80) {
      throw const FormatException(
        'This PDF has no selectable text. It is likely a scan, which needs OCR.',
      );
    }
    return ParsedDocument(
      title: title,
      chapters: chapters,
      coverBytes: coverBytes,
      coverExtension: coverBytes == null ? null : 'png',
    );
  } finally {
    await document.dispose();
  }
}

/// Groups raw PDF text into paragraphs and headings. PDF text streams only
/// contain line breaks, so headings are inferred from chapter keywords, line
/// length relative to the page median, and sentence punctuation.
List<DocBlock> pdfBlocks(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

  final lengths = lines.map((l) => l.trim().length).where((l) => l > 0).toList()
    ..sort();
  final median = lengths.isEmpty
      ? 0.0
      : lengths[lengths.length ~/ 2].toDouble();

  final blocks = <DocBlock>[];
  final buffer = <String>[];

  void flush() {
    if (buffer.isEmpty) return;
    final joined = buffer.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    buffer.clear();
    if (joined.isEmpty) return;
    for (final paragraph in splitLongText(joined)) {
      blocks.add(DocBlock(paragraph));
    }
  }

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flush();
      continue;
    }
    if (_chapterHeading.hasMatch(line) && line.length < 110) {
      flush();
      blocks.add(DocBlock(line, headingLevel: 1));
      continue;
    }
    final looksLikeHeading =
        median > 0 &&
        line.length <= median * 0.6 &&
        line.length < 70 &&
        !_sentenceEnd.hasMatch(line) &&
        !line.endsWith(',') &&
        !line.endsWith(';');
    if (looksLikeHeading && buffer.isEmpty) {
      blocks.add(DocBlock(line, headingLevel: 2));
      continue;
    }
    if (buffer.isNotEmpty) {
      final previous = buffer.last;
      if (previous.endsWith('-') && !previous.endsWith('--')) {
        buffer[buffer.length - 1] =
            previous.substring(0, previous.length - 1) + line;
        continue;
      }
      if (_sentenceEnd.hasMatch(previous) && previous.length < 70) {
        flush();
      }
    }
    buffer.add(line);
  }
  flush();
  return blocks;
}

/// Keeps paragraphs readable in the UI and narration chunks small.
List<String> splitLongText(String text, {int softLimit = 700}) {
  if (text.length <= softLimit) return [text];
  final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
  final result = <String>[];
  final buffer = StringBuffer();
  for (final sentence in sentences) {
    if (buffer.length > 0 && buffer.length + sentence.length > softLimit) {
      result.add(buffer.toString().trim());
      buffer.clear();
    }
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(sentence);
  }
  if (buffer.toString().trim().isNotEmpty) {
    result.add(buffer.toString().trim());
  }
  return result;
}
