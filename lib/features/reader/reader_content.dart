import '../import/parsed_document.dart';

class SentenceSpan {
  const SentenceSpan({
    required this.text,
    required this.start,
    required this.end,
    required this.chapterIndex,
  });

  final String text;
  final int start;
  final int end;
  final int chapterIndex;
}

class ReaderParagraph {
  const ReaderParagraph({
    required this.text,
    required this.headingLevel,
    required this.start,
    required this.end,
    required this.chapterIndex,
  });

  final String text;
  final int headingLevel;
  final int start;
  final int end;
  final int chapterIndex;
}

class ChapterMarker {
  const ChapterMarker({
    required this.title,
    required this.start,
    required this.index,
    required this.charCount,
  });

  final String title;
  final int start;
  final int index;
  final int charCount;
}

class ReaderContent {
  ReaderContent._({
    required this.title,
    required this.author,
    required this.text,
    required this.paragraphs,
    required this.sentences,
    required this.chapters,
  });

  final String title;
  final String? author;
  final String text;
  final List<ReaderParagraph> paragraphs;
  final List<SentenceSpan> sentences;
  final List<ChapterMarker> chapters;

  int get charCount => text.length;

  factory ReaderContent.fromDocument(ParsedDocument document) {
    final buffer = StringBuffer();
    final paragraphs = <ReaderParagraph>[];
    final sentences = <SentenceSpan>[];
    final chapters = <ChapterMarker>[];

    for (var chapterIndex = 0; chapterIndex < document.chapters.length; chapterIndex++) {
      final chapter = document.chapters[chapterIndex];
      chapters.add(ChapterMarker(
        title: chapter.title,
        start: buffer.length,
        index: chapterIndex,
        charCount: chapter.charCount,
      ));
      for (final block in chapter.blocks) {
        if (buffer.isNotEmpty) buffer.write('\n\n');
        final start = buffer.length;
        buffer.write(block.text);
        final end = buffer.length;
        paragraphs.add(ReaderParagraph(
          text: block.text,
          headingLevel: block.headingLevel,
          start: start,
          end: end,
          chapterIndex: chapterIndex,
        ));
        sentences.addAll(
          splitSentencesWithOffsets(
            block.text,
            baseOffset: start,
            chapterIndex: chapterIndex,
          ),
        );
      }
    }

    return ReaderContent._(
      title: document.title,
      author: document.author,
      text: buffer.toString(),
      paragraphs: paragraphs,
      sentences: sentences,
      chapters: chapters,
    );
  }

  int sentenceIndexAt(int offset) {
    if (sentences.isEmpty) return 0;
    var low = 0;
    var high = sentences.length - 1;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (sentences[mid].end <= offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  int paragraphIndexAt(int offset) {
    if (paragraphs.isEmpty) return 0;
    var low = 0;
    var high = paragraphs.length - 1;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (paragraphs[mid].end <= offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  int chapterIndexAt(int offset) {
    if (chapters.isEmpty) return 0;
    var result = 0;
    for (final chapter in chapters) {
      if (chapter.start <= offset) {
        result = chapter.index;
      } else {
        break;
      }
    }
    return result;
  }

  ChapterMarker chapterAt(int offset) =>
      chapters[chapterIndexAt(offset).clamp(0, chapters.length - 1)];
}

const _abbreviations = {
  'mr', 'mrs', 'ms', 'dr', 'prof', 'sr', 'jr', 'st', 'vs', 'etc', 'eg', 'ie',
  'no', 'fig', 'al', 'inc', 'ltd', 'co', 'jan', 'feb', 'mar', 'apr', 'jun',
  'jul', 'aug', 'sep', 'sept', 'oct', 'nov', 'dec', 'mt', 'ave', 'blvd', 'rd',
  'apt', 'dept', 'est', 'min', 'max', 'approx', 'cf', 'vol', 'pp', 'ch',
  'sec', 'art', 'para', 'ed', 'eds', 'rev', 'gen', 'gov', 'sen', 'rep',
  'col', 'capt', 'lt', 'sgt', 'hon', 'pres', 'u.s', 'u.k', 'a.m', 'p.m',
};

List<SentenceSpan> splitSentencesWithOffsets(
  String text, {
  int baseOffset = 0,
  int chapterIndex = 0,
  int maxLength = 320,
}) {
  final spans = <SentenceSpan>[];
  if (text.trim().isEmpty) return spans;

  var start = 0;
  final length = text.length;
  for (var i = 0; i < length; i++) {
    final char = text[i];
    if (char != '.' && char != '!' && char != '?') continue;

    var end = i + 1;
    while (end < length && '"\u2019\u201D)]}'.contains(text[end])) {
      end++;
    }
    if (end < length && !_isBreakSpace(text[end])) continue;

    final nextNonSpace = _nextNonSpace(text, end);
    if (nextNonSpace != null && _isLowerAscii(text[nextNonSpace])) {
      // Dialogue tags and continuations ("Stop!" she said) stay in one span.
      continue;
    }
    if (char == '.' && _isAbbreviation(text, i)) continue;
    if (char == '.' && _isInitial(text, i)) continue;

    final raw = text.substring(start, end).trim();
    if (raw.isNotEmpty) {
      spans.addAll(_splitLong(raw, start, baseOffset, chapterIndex, maxLength));
    }
    start = end;
    while (start < length && _isBreakSpace(text[start])) {
      start++;
    }
    i = start - 1;
  }
  if (start < length) {
    final raw = text.substring(start).trim();
    if (raw.isNotEmpty) {
      spans.addAll(_splitLong(raw, start, baseOffset, chapterIndex, maxLength));
    }
  }
  return spans
      .map((s) => SentenceSpan(
            text: s.text.trim(),
            start: s.start,
            end: s.end,
            chapterIndex: chapterIndex,
          ))
      .where((s) => s.text.isNotEmpty)
      .toList();
}

bool _isBreakSpace(String c) => c == ' ' || c == '\n' || c == '\t' || c == '\r';

bool _isLowerAscii(String c) {
  final code = c.codeUnitAt(0);
  return code >= 97 && code <= 122;
}

int? _nextNonSpace(String text, int from) {
  for (var i = from; i < text.length; i++) {
    if (!_isBreakSpace(text[i])) return i;
  }
  return null;
}

bool _isAbbreviation(String text, int periodIndex) {
  var start = periodIndex - 1;
  while (start >= 0 && RegExp(r'[A-Za-z.]').hasMatch(text[start])) {
    start--;
  }
  final token = text
      .substring(start + 1, periodIndex)
      .toLowerCase()
      .replaceAll('.', '');
  return _abbreviations.contains(token);
}

bool _isInitial(String text, int periodIndex) {
  var start = periodIndex - 1;
  while (start >= 0 && _isBreakSpace(text[start])) {
    start--;
  }
  if (start < 0) return false;
  final char = text[start];
  if (!RegExp(r'[A-Z]').hasMatch(char)) return false;
  final before = start - 1;
  return before < 0 || _isBreakSpace(text[before]) || text[before] == '.';
}

List<SentenceSpan> _splitLong(
  String raw,
  int rawStart,
  int baseOffset,
  int chapterIndex,
  int maxLength,
) {
  if (raw.length <= maxLength) {
    return [
      SentenceSpan(
        text: raw,
        start: baseOffset + rawStart,
        end: baseOffset + rawStart + raw.length,
        chapterIndex: chapterIndex,
      ),
    ];
  }
  final result = <SentenceSpan>[];
  var cursor = 0;
  while (cursor < raw.length) {
    var take = (cursor + maxLength).clamp(0, raw.length);
    if (take < raw.length) {
      final window = raw.substring(cursor, take);
      final breakAt = [
        window.lastIndexOf(', '),
        window.lastIndexOf('; '),
        window.lastIndexOf(' '),
      ].reduce((a, b) => a > b ? a : b);
      if (breakAt > maxLength ~/ 3) take = cursor + breakAt + 1;
    }
    final piece = raw.substring(cursor, take).trim();
    if (piece.isNotEmpty) {
      final leading = raw.substring(cursor, take).indexOf(piece);
      result.add(SentenceSpan(
        text: piece,
        start: baseOffset + rawStart + cursor + (leading < 0 ? 0 : leading),
        end: baseOffset + rawStart + cursor + (leading < 0 ? 0 : leading) + piece.length,
        chapterIndex: chapterIndex,
      ));
    }
    cursor = take;
    while (cursor < raw.length && _isBreakSpace(raw[cursor])) {
      cursor++;
    }
  }
  return result;
}
