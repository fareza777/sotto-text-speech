import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/document_renderer.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/narration_session.dart';
import '../../state/settings_controller.dart';
import '../../tts/tts_service.dart';
import '../../tts/voice_catalog.dart';
import 'narration_controller.dart';
import 'reader_content.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.doc});

  final Doc doc;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  ReaderContent? _content;
  NarrationController? _narration;
  String? _error;
  bool _loading = true;
  int _lastParagraph = -1;
  DateTime _lastUserScroll = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final library = context.read<LibraryController>();
      final parsed = await library.importer.loadContent(widget.doc);
      final content = ReaderContent.fromDocument(parsed);
      final settings = context.read<SettingsController>();
      // Warm the engine while the first page is being read.
      unawaited(context.read<TtsService>().load(modelId: settings.modelId));
      final session = context.read<NarrationSession>();
      final narration = session.open(
        widget.doc,
        content,
        startOffset: widget.doc.lastOffset,
      );
      narration.addListener(_onNarrationChanged);
      unawaited(narration.prewarm());
      if (!mounted) {
        narration.removeListener(_onNarrationChanged);
        return;
      }
      setState(() {
        _content = content;
        _narration = narration;
        _loading = false;
      });
      final startOffset = narration.currentChunk != null
          ? narration.currentOffset
          : widget.doc.lastOffset;
      final startParagraph = content.paragraphIndexAt(startOffset);
      _lastParagraph = startParagraph;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.isAttached && startParagraph < content.paragraphs.length) {
          _scroll.jumpTo(index: startParagraph, alignment: 0.05);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('FormatException: ', '');
        _loading = false;
      });
    }
  }

  void _onNarrationChanged() {
    final narration = _narration;
    if (narration == null) return;
    if (narration.isPlaying) {
      final sinceScroll = DateTime.now().difference(_lastUserScroll).inSeconds;
      if (sinceScroll > 5) {
        final paragraph = narration.currentSentence == null
            ? _lastParagraph
            : _content!.paragraphIndexAt(narration.currentSentence!.start);
        if (paragraph != _lastParagraph && _scroll.isAttached) {
          _lastParagraph = paragraph;
          _scroll.jumpTo(index: paragraph, alignment: 0.25);
        }
      }
    }
    if (_saveTimer?.isActive != true) {
      _saveTimer = Timer(const Duration(seconds: 4), () {
        final offset = narration.currentOffset;
        if (widget.doc.id != null &&
            _content != null &&
            _content!.charCount > 0) {
          context.read<LibraryController>().saveDocProgress(
            widget.doc.id!,
            (offset / _content!.charCount).clamp(0, 1),
            offset,
          );
        }
      });
    }
    setState(() {});
    _syncWakelock();
  }

  void _syncWakelock() {
    final settings = context.read<SettingsController>();
    final playing = _narration?.isPlaying ?? false;
    if (settings.keepAwake && playing) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    WakelockPlus.disable();
    _narration?.removeListener(_onNarrationChanged);
    super.dispose();
  }

  Future<void> _saveNow() async {
    final narration = _narration;
    final content = _content;
    if (narration == null || content == null || widget.doc.id == null) return;
    final offset = narration.currentOffset;
    await context.read<LibraryController>().saveDocProgress(
      widget.doc.id!,
      content.charCount == 0 ? 0 : (offset / content.charCount).clamp(0, 1),
      offset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    final content = _content;
    final narration = _narration;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || content == null || narration == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not open this document',
          body: _error ?? 'Unknown error',
          action: FilledButton(
            onPressed: _load,
            child: const Text('Try again'),
          ),
        ),
      );
    }

    final paragraphCount = content.paragraphs.length;
    final progress = content.charCount == 0
        ? 0.0
        : (narration.currentOffset / content.charCount).clamp(0.0, 1.0);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveNow();
      },
      child: Scaffold(
        backgroundColor: tokens.paper,
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                content.chapterAt(narration.currentOffset).title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Bookmarks',
              onPressed: _showBookmarks,
              icon: const Icon(Icons.bookmark_border_rounded),
            ),
            IconButton(
              tooltip: 'Chapters',
              onPressed: _showChapters,
              icon: const Icon(Icons.format_list_bulleted_rounded),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'export') _exportChapter();
                if (value == 'clip') {
                  _exportClipAt(_narration?.currentOffset ?? 0);
                }
                if (value == 'type') _showTypeSettings();
                if (value == 'voice') _showVoiceQuick();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'type', child: Text('Text size')),
                PopupMenuItem(value: 'voice', child: Text('Voice and pace')),
                PopupMenuItem(value: 'clip', child: Text('Create a clip from here')),
                PopupMenuItem(
                  value: 'export',
                  child: Text('Export this chapter'),
                ),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: tokens.hairline,
            ),
          ),
        ),
        body: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification &&
                notification.dragDetails != null) {
              _lastUserScroll = DateTime.now();
            }
            return false;
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ScrollablePositionedList.builder(
                itemScrollController: _scroll,
                itemPositionsListener: _positions,
                itemCount: paragraphCount,
                padding: EdgeInsets.fromLTRB(24, 8, 24, 40),
                itemBuilder: (context, index) {
                  final paragraph = content.paragraphs[index];
                  final previous =
                      index == 0 ? null : content.paragraphs[index - 1];
                  final settings = context.watch<SettingsController>();
                  final startsChapter = paragraph.headingLevel == 0 &&
                      (previous == null ||
                          previous.headingLevel > 0 ||
                          previous.chapterIndex != paragraph.chapterIndex);
                  return _ParagraphView(
                    key: ValueKey(index),
                    paragraph: paragraph,
                    narration: narration,
                    scale: settings.readerScale,
                    focusMode: settings.focusMode,
                    dropCap: startsChapter,
                    onTap: () => narration.startAt(paragraph.start),
                  );
                },
              ),
            ),
          ),
        ),
        bottomNavigationBar: _ReaderControls(
          narration: narration,
          onBookmark: _addBookmark,
          onSpeed: _showSpeedSheet,
        ),
      ),
    );
  }

  Future<void> _showSpeedSheet() async {
    final settings = context.read<SettingsController>();
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reading pace',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in [0.75, 0.9, 1.0, 1.15, 1.3, 1.5, 1.75])
                    ChoiceChip(
                      label: Text('${value.toStringAsFixed(2)}×'),
                      selected: (settings.playbackSpeed - value).abs() < 0.01,
                      onSelected: (_) {
                        settings.playbackSpeed = value;
                        _narration?.setPlaybackSpeed(value);
                        Navigator.pop(sheetContext);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showVoiceQuick() async {
    final settings = context.read<SettingsController>();
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voice for this session',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Changes apply from the next passage.',
                style: Theme.of(sheetContext).textTheme.labelSmall,
              ),
              const SizedBox(height: 12),
              for (final voice in voiceCatalog)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: voice.tint,
                    child: Text(
                      voice.initial,
                      style: const TextStyle(
                        fontFamily: 'InstrumentSerif',
                        color: Colors.white,
                      ),
                    ),
                  ),
                  title: Text(voice.name),
                  subtitle: Text('${voice.gender} · English'),
                  trailing: settings.voice == voice.id
                      ? Icon(
                          Icons.check_rounded,
                          color: SottoTokens.of(context).accent,
                        )
                      : null,
                  onTap: () {
                    settings.voice = voice.id;
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChapters() async {
    final content = _content;
    final narration = _narration;
    if (content == null || narration == null) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.8,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Chapters',
              style: Theme.of(sheetContext).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            for (final chapter in content.chapters)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  '${chapter.index + 1}'.padLeft(2, '0'),
                  style: Theme.of(sheetContext).textTheme.labelSmall,
                ),
                title: Text(chapter.title),
                subtitle: Text(
                  '${(chapter.charCount / 1000).toStringAsFixed(1)}k characters',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  final index = content.paragraphIndexAt(chapter.start);
                  if (_scroll.isAttached)
                    _scroll.jumpTo(index: index, alignment: 0.05);
                  narration.startAt(chapter.start);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBookmarks() async {
    final library = context.read<LibraryController>();
    final narration = _narration;
    final content = _content;
    if (narration == null || content == null || widget.doc.id == null) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.7,
        child: FutureBuilder<List<DocBookmark>>(
          future: library.bookmarks(widget.doc.id!),
          builder: (context, snapshot) {
            final bookmarks = snapshot.data ?? const <DocBookmark>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'Bookmarks',
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await library.addBookmark(
                      widget.doc.id!,
                      narration.currentOffset,
                      content.text.substring(
                        narration.currentOffset,
                        (narration.currentOffset + 120).clamp(
                          0,
                          content.text.length,
                        ),
                      ),
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    if (mounted) _showBookmarks();
                  },
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Bookmark this sentence'),
                ),
                const SizedBox(height: 16),
                if (bookmarks.isEmpty)
                  const EmptyState(
                    icon: Icons.bookmark_border_rounded,
                    title: 'No bookmarks',
                    body: 'Save a place and come back to it later.',
                  ),
                for (final bookmark in bookmarks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      bookmark.snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Create clip',
                          icon: const Icon(Icons.content_cut_rounded, size: 18),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _exportClipAt(bookmark.offset);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          onPressed: () async {
                            await library.removeBookmark(bookmark.id!);
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                            if (mounted) _showBookmarks();
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      final index = content.paragraphIndexAt(bookmark.offset);
                      if (_scroll.isAttached)
                        _scroll.jumpTo(index: index, alignment: 0.1);
                      narration.startAt(bookmark.offset);
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addBookmark() async {
    final content = _content;
    final narration = _narration;
    if (content == null || narration == null || widget.doc.id == null) return;
    final offset = narration.currentOffset;
    final snippet = content.text.substring(
      offset,
      (offset + 120).clamp(0, content.text.length),
    );
    await context.read<LibraryController>().addBookmark(
      widget.doc.id!,
      offset,
      snippet,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bookmark saved')));
  }

  Future<void> _showTypeSettings() async {
    final settings = context.read<SettingsController>();
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Text size',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setSheetState) => Column(
                  children: [
                    Slider(
                      value: settings.readerScale,
                      min: 0.8,
                      max: 1.6,
                      divisions: 8,
                      label: '${(settings.readerScale * 100).round()}%',
                      onChanged: (value) {
                        settings.readerScale = value;
                        setSheetState(() {});
                        setState(() {});
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Focus while playing'),
                      subtitle: const Text('Dim everything but the current passage'),
                      value: settings.focusMode,
                      onChanged: (value) {
                        settings.focusMode = value;
                        setState(() {});
                        setSheetState(() {});
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Keep screen awake while reading'),
                      value: settings.keepAwake,
                      onChanged: (value) {
                        settings.keepAwake = value;
                        _syncWakelock();
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportClipAt(int offset) async {
    final content = _content;
    if (content == null) return;
    final settings = context.read<SettingsController>();
    final tts = context.read<TtsService>();
    final library = context.read<LibraryController>();
    final startIndex = content.sentenceIndexAt(offset);
    final sentences = content.sentences.skip(startIndex).take(2).toList();
    if (sentences.isEmpty) return;
    final progress = ValueNotifier<(double, String)>((0, 'Preparing clip'));
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: ValueListenableBuilder<(double, String)>(
          valueListenable: progress,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Creating a shareable clip', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: value.$1, minHeight: 6),
              ),
              const SizedBox(height: 10),
              Text(
                '${(value.$1 * 100).round()}% · ${value.$2}',
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
    try {
      final track = await renderSentences(
        doc: widget.doc.copyWith(title: 'Clip · ${content.title}'),
        sentences: sentences,
        tts: tts,
        voice: settings.voice,
        speed: settings.speed,
        modelId: settings.modelId,
        format: settings.exportFormat,
        bitRate: settings.mp3Bitrate,
        onProgress: (value) => progress.value = (value.fraction, value.label),
      );
      await library.addTrack(track);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Clip saved to your library.'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => SharePlus.instance.share(
              ShareParams(files: [XFile(track.path)], text: track.title),
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create the clip. $error')),
      );
    } finally {
      progress.dispose();
    }
  }

  Future<void> _exportChapter() async {
    final content = _content;
    if (content == null) return;
    final settings = context.read<SettingsController>();
    final tts = context.read<TtsService>();
    final library = context.read<LibraryController>();
    final chapterIndex = content.chapterIndexAt(_narration?.currentOffset ?? 0);
    final chapter = content.chapters[chapterIndex];
    final nextStart = chapterIndex + 1 < content.chapters.length
        ? content.chapters[chapterIndex + 1].start
        : content.charCount;
    final sentences = content.sentences
        .where((s) => s.start >= chapter.start && s.start < nextStart)
        .toList();
    final progress = ValueNotifier<(double, String)>((0, 'Preparing'));
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: ValueListenableBuilder<(double, String)>(
          valueListenable: progress,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Exporting ${chapter.title}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: value.$1, minHeight: 6),
              ),
              const SizedBox(height: 10),
              Text(
                '${(value.$1 * 100).round()}% · ${value.$2}',
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
    try {
      final track = await renderSentences(
        doc: widget.doc.copyWith(title: chapter.title),
        sentences: sentences,
        tts: tts,
        voice: settings.voice,
        speed: settings.speed,
        modelId: settings.modelId,
        format: settings.exportFormat,
        bitRate: settings.mp3Bitrate,
        onProgress: (value) {
          progress.value = (value.fraction, value.label);
        },
      );
      await library.addTrack(track);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${chapter.title} saved to your library.')),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed. $error')));
    } finally {
      progress.dispose();
    }
  }
}

class _ParagraphView extends StatelessWidget {
  const _ParagraphView({
    super.key,
    required this.paragraph,
    required this.narration,
    required this.scale,
    required this.onTap,
    this.focusMode = true,
    this.dropCap = false,
  });

  final ReaderParagraph paragraph;
  final NarrationController narration;
  final double scale;
  final VoidCallback onTap;
  final bool focusMode;
  final bool dropCap;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    final base = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontSize: 17 * scale,
      height: 1.72,
      letterSpacing: 0.05,
      color: tokens.ink,
    );
    final style = switch (paragraph.headingLevel) {
      1 => Theme.of(
        context,
      ).textTheme.headlineMedium!.copyWith(fontSize: 26 * scale),
      2 => Theme.of(
        context,
      ).textTheme.headlineSmall!.copyWith(fontSize: 22 * scale),
      3 => Theme.of(
        context,
      ).textTheme.titleLarge!.copyWith(fontSize: 19 * scale),
      _ => base,
    };
    final isHeading = paragraph.headingLevel > 0;

    final spans = <InlineSpan>[];
    final sentence = narration.currentSentence;
    final word = narration.currentWord;
    final hasHighlight =
        !isHeading &&
        sentence != null &&
        word != null &&
        word.start >= paragraph.start &&
        word.end <= paragraph.end;

    final activeSentence = sentence != null &&
        sentence.start >= paragraph.start &&
        sentence.start < paragraph.end;
    final dimmed = focusMode &&
        narration.isPlaying &&
        narration.currentWord != null &&
        !activeSentence &&
        !isHeading;

    if (!hasHighlight) {
      if (dropCap && paragraph.text.isNotEmpty) {
        spans.add(
          TextSpan(
            text: paragraph.text.substring(0, 1),
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: (style.fontSize ?? 17) * 2.5,
              height: 0.86,
              color: tokens.accent,
            ),
          ),
        );
        spans.add(TextSpan(text: paragraph.text.substring(1)));
      } else {
        spans.add(TextSpan(text: paragraph.text));
      }
    } else {
      final sentenceStart = (sentence.start - paragraph.start).clamp(
        0,
        paragraph.text.length,
      );
      final sentenceEnd = (sentence.end - paragraph.start).clamp(
        0,
        paragraph.text.length,
      );
      final wordStart = (word.start - paragraph.start).clamp(
        sentenceStart,
        sentenceEnd,
      );
      final wordEnd = (word.end - paragraph.start).clamp(
        wordStart,
        sentenceEnd,
      );
      if (sentenceStart > 0) {
        spans.add(TextSpan(text: paragraph.text.substring(0, sentenceStart)));
      }
      spans.add(
        TextSpan(
          text: paragraph.text.substring(sentenceStart, wordStart),
          style: TextStyle(
            backgroundColor: tokens.accentWash.withValues(alpha: 0.75),
          ),
        ),
      );
      spans.add(
        TextSpan(
          text: paragraph.text.substring(wordStart, wordEnd),
          style: TextStyle(
            backgroundColor: tokens.accent,
            color: tokens.accentInk,
          ),
        ),
      );
      spans.add(
        TextSpan(
          text: paragraph.text.substring(wordEnd, sentenceEnd),
          style: TextStyle(
            backgroundColor: tokens.accentWash.withValues(alpha: 0.75),
          ),
        ),
      );
      if (sentenceEnd < paragraph.text.length) {
        spans.add(TextSpan(text: paragraph.text.substring(sentenceEnd)));
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: dimmed ? 0.46 : 1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: Padding(
          padding: EdgeInsets.only(
            top: isHeading ? 22 : 10,
            bottom: isHeading ? 8 : 10,
          ),
          child: Text.rich(TextSpan(children: spans), style: style),
        ),
      ),
    );
  }
}

class _ReaderControls extends StatelessWidget {
  const _ReaderControls({
    required this.narration,
    required this.onBookmark,
    required this.onSpeed,
  });

  final NarrationController narration;
  final VoidCallback onBookmark;
  final VoidCallback onSpeed;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    final settings = context.watch<SettingsController>();
    final playing = narration.isPlaying;
    final preparing = narration.isPreparing;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: tokens.hairline),
          boxShadow: tokens.isDark
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF2A2118).withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (preparing)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Preparing the next passage…',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            if (narration.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  narration.error!,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: tokens.danger),
                ),
              ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Bookmark',
                  onPressed: onBookmark,
                  icon: Icon(Icons.bookmark_add_outlined, color: tokens.muted),
                ),
                IconButton(
                  tooltip: 'Previous sentence',
                  onPressed: narration.previousSentence,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    shape: BoxShape.circle,
                  ),
                  child: preparing && !playing
                      ? Padding(
                          padding: const EdgeInsets.all(17),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: tokens.accentInk,
                          ),
                        )
                      : IconButton(
                          onPressed: narration.toggle,
                          color: tokens.accentInk,
                          iconSize: 28,
                          icon: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Next sentence',
                  onPressed: narration.nextSentence,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onSpeed,
                  child: Text(
                    '${settings.playbackSpeed.toStringAsFixed(2)}×',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: tokens.accent),
                  ),
                ),
                IconButton(
                  tooltip: 'Stop',
                  onPressed: narration.stop,
                  icon: Icon(Icons.stop_circle_outlined, color: tokens.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
