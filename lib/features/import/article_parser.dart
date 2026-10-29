import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'parsed_document.dart';
import 'pdf_parser.dart' show splitLongText;

const _userAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Mobile Safari/537.36 Sotto/1.0';

Future<ParsedDocument> parseArticleUrl(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
    throw const FormatException('Enter a valid http or https link.');
  }
  final response = await http
      .get(uri, headers: {'User-Agent': _userAgent, 'Accept': 'text/html,*/*'})
      .timeout(const Duration(seconds: 25));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw FormatException('The page returned HTTP ${response.statusCode}.');
  }
  final contentType = response.headers['content-type'] ?? '';
  if (!contentType.contains('html') && !contentType.contains('text')) {
    throw const FormatException('That link is not an article page.');
  }
  final charset = _charsetOf(contentType, response.bodyBytes);
  String body;
  try {
    body = utf8.decode(response.bodyBytes);
  } catch (_) {
    body = latin1.decode(response.bodyBytes);
  }
  if (charset != null &&
      charset.toLowerCase() != 'utf-8' &&
      charset.toLowerCase() != 'utf8') {
    try {
      body = latin1.decode(response.bodyBytes);
    } catch (_) {
      // Keep the utf-8 attempt.
    }
  }
  return parseArticleHtml(body, uri);
}

String? _charsetOf(String contentType, List<int> bytes) {
  final match = RegExp(r'charset=([\w-]+)').firstMatch(contentType);
  if (match != null) return match.group(1);
  final head = latin1.decode(bytes.take(2048).toList(), allowInvalid: true);
  final meta = RegExp('charset=["\']?([\\w-]+)', caseSensitive: false).firstMatch(head);
  return meta?.group(1);
}

ParsedDocument parseArticleHtml(String markup, Uri uri) {
  final document = html.parse(markup);
  for (final tag in [
    'script',
    'style',
    'nav',
    'header',
    'footer',
    'aside',
    'form',
    'svg',
    'noscript',
    'iframe',
  ]) {
    for (final node in document.querySelectorAll(tag)) {
      node.remove();
    }
  }

  final title = _meta(document, 'og:title') ??
      document.querySelector('title')?.text.trim() ??
      uri.host;

  final candidates = <dom.Element>[
    ...document.querySelectorAll('article'),
    ...document.querySelectorAll('main'),
    ...document.querySelectorAll('[role="main"]'),
    ...document.querySelectorAll('.post-content, .article-content, .entry-content'),
    if (document.body != null) document.body!,
  ];

  dom.Element? best;
  var bestScore = 0;
  for (final candidate in candidates) {
    var score = 0;
    for (final p in candidate.querySelectorAll('p')) {
      final length = p.text.trim().length;
      if (length > 40) score += length;
    }
    score += candidate.querySelectorAll('h2,h3').length * 40;
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }

  if (best == null || bestScore < 200) {
    throw const FormatException(
      'Sotto could not find readable article text on that page.',
    );
  }

  final blocks = <DocBlock>[];
  for (final element in best.querySelectorAll('h1,h2,h3,p,li,blockquote,pre')) {
    final text = element.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length < 12 && element.localName == 'p') continue;
    if (text.isEmpty) continue;
    final level = switch (element.localName) {
      'h1' => 1,
      'h2' => 2,
      'h3' => 3,
      _ => 0,
    };
    if (level > 0) {
      blocks.add(DocBlock(text, headingLevel: level));
    } else if (element.localName == 'li') {
      blocks.add(DocBlock('• $text'));
    } else {
      for (final part in splitLongText(text)) {
        blocks.add(DocBlock(part));
      }
    }
  }
  if (blocks.isEmpty) {
    throw const FormatException('That page has no readable paragraphs.');
  }
  final author = _meta(document, 'article:author') ??
      _meta(document, 'author') ??
      uri.host.replaceFirst('www.', '');

  return ParsedDocument(
    title: title,
    author: author,
    chapters: [ParsedChapter(title: 'Article', blocks: blocks)],
  );
}

String? _meta(dom.Document document, String property) {
  final element = document.querySelector('meta[property="$property"]') ??
      document.querySelector('meta[name="$property"]');
  final value = element?.attributes['content']?.trim();
  return (value == null || value.isEmpty) ? null : value;
}
