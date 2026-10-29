import 'dart:convert';
import 'dart:typed_data';

class DocBlock {
  const DocBlock(this.text, {this.headingLevel = 0});

  final String text;

  /// 0 for body copy, 1-3 for heading levels.
  final int headingLevel;

  Map<String, Object?> toJson() => {'t': text, 'h': headingLevel};

  static DocBlock fromJson(Map<String, Object?> json) => DocBlock(
        json['t'] as String? ?? '',
        headingLevel: json['h'] as int? ?? 0,
      );
}

class ParsedChapter {
  const ParsedChapter({required this.title, required this.blocks});

  final String title;
  final List<DocBlock> blocks;

  int get charCount => blocks.fold(0, (sum, block) => sum + block.text.length);

  Map<String, Object?> toJson() => {
        'title': title,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  static ParsedChapter fromJson(Map<String, Object?> json) => ParsedChapter(
        title: json['title'] as String? ?? 'Chapter',
        blocks: (json['blocks'] as List? ?? const [])
            .whereType<Map>()
            .map((b) => DocBlock.fromJson(Map<String, Object?>.from(b)))
            .toList(),
      );
}

class ParsedDocument {
  const ParsedDocument({
    required this.title,
    this.author,
    required this.chapters,
    this.coverBytes,
    this.coverExtension,
  });

  final String title;
  final String? author;
  final List<ParsedChapter> chapters;
  final Uint8List? coverBytes;
  final String? coverExtension;

  int get charCount =>
      chapters.fold(0, (sum, chapter) => sum + chapter.charCount);

  String toJsonString() => jsonEncode({
        'title': title,
        'author': author,
        'chapters': chapters.map((c) => c.toJson()).toList(),
      });

  static ParsedDocument fromJsonString(String raw) {
    final json = jsonDecode(raw) as Map<String, Object?>;
    return ParsedDocument(
      title: json['title'] as String? ?? 'Untitled',
      author: json['author'] as String?,
      chapters: (json['chapters'] as List? ?? const [])
          .whereType<Map>()
          .map((c) => ParsedChapter.fromJson(Map<String, Object?>.from(c)))
          .toList(),
    );
  }
}
