import 'package:flutter_test/flutter_test.dart';
import 'package:sotto/features/import/parsed_document.dart';
import 'package:sotto/features/reader/reader_content.dart';

void main() {
  group('sentence splitting', () {
    test('keeps abbreviations intact', () {
      final spans = splitSentencesWithOffsets(
        'Dr. Smith met Mrs. Hale at 5 p.m. They talked for an hour.',
      );
      expect(spans.length, 2);
      expect(spans.first.text, contains('Dr. Smith'));
      expect(spans.first.text, contains('p.m.'));
      expect(spans.last.text, 'They talked for an hour.');
    });

    test('handles initials and quotes', () {
      final spans = splitSentencesWithOffsets(
        '“Wait!” she said. J. K. Rowling agreed.',
      );
      expect(spans.length, 2);
      expect(spans.first.text, '“Wait!” she said.');
      expect(spans.last.text, contains('J. K. Rowling'));
    });

    test('maps offsets back into the source text', () {
      const text = 'One sentence. Two sentences. Three.';
      final spans = splitSentencesWithOffsets(text);
      expect(spans.length, 3);
      for (final span in spans) {
        expect(text.substring(span.start, span.end), span.text);
      }
    });
  });

  group('reader content', () {
    test('builds paragraphs, chapters, and sentence offsets', () {
      final content = ReaderContent.fromDocument(
        const ParsedDocument(
          title: 'Test',
          chapters: [
            ParsedChapter(
              title: 'One',
              blocks: [
                DocBlock('Chapter One', headingLevel: 1),
                DocBlock('The first line. The second line.'),
              ],
            ),
            ParsedChapter(
              title: 'Two',
              blocks: [DocBlock('A later thought.')],
            ),
          ],
        ),
      );
      expect(content.paragraphs.length, 3);
      expect(content.chapters.length, 2);
      expect(content.sentences.length, 4);
      expect(content.paragraphIndexAt(content.chapters[1].start), 2);
      expect(content.chapterIndexAt(content.chapters[1].start), 1);
    });
  });
}
