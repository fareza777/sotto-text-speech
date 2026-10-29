import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/ad_service.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/document_renderer.dart';
import '../../data/models.dart';
import '../../features/reader/reader_content.dart';
import '../../state/library_controller.dart';
import '../../state/settings_controller.dart';
import '../../tts/model_catalog.dart';
import '../../tts/tts_service.dart';
import '../studio/model_sheet.dart';
import '../studio/voice_sheet.dart';

class BatchScreen extends StatefulWidget {
  const BatchScreen({super.key});

  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  final Set<int> _selected = {};
  bool _running = false;
  bool _cancelRequested = false;
  double _overall = 0;
  String _stage = '';
  int _done = 0;
  int _failed = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selected.isEmpty) {
      final docs = context.read<LibraryController>().docs;
      for (final doc in docs.take(3)) {
        if (doc.id != null) _selected.add(doc.id!);
      }
    }
  }

  Future<void> _start(List<Doc> docs) async {
    final settings = context.read<SettingsController>();
    final library = context.read<LibraryController>();
    final tts = context.read<TtsService>();
    final ads = context.read<AdService>();
    final targets = docs.where((d) => _selected.contains(d.id)).toList();
    if (targets.isEmpty) return;
    setState(() {
      _running = true;
      _cancelRequested = false;
      _overall = 0;
      _done = 0;
      _failed = 0;
    });
    try {
      for (var i = 0; i < targets.length; i++) {
        if (_cancelRequested) break;
        final doc = targets[i];
        try {
          setState(() => _stage = 'Reading ${doc.title}');
          final parsed = await library.importer.loadContent(doc);
          final content = ReaderContent.fromDocument(parsed);
          final track = await renderDocument(
            doc: doc,
            content: content,
            tts: tts,
            voice: settings.voice,
            speed: settings.speed,
            modelId: settings.modelId,
            format: settings.exportFormat,
            bitRate: settings.mp3Bitrate,
            isCancelled: () => _cancelRequested,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _overall = (i + progress.fraction) / targets.length;
                _stage = progress.label;
              });
            },
          );
          await library.addTrack(track);
          _done += 1;
        } catch (error) {
          if (isRenderCancelled(error)) break;
          _failed += 1;
          debugPrint('[Sotto] batch failed for ${doc.title}: $error');
        }
        if (mounted) setState(() => _overall = (i + 1) / targets.length);
      }
      if (mounted) {
        setState(() => _stage = _cancelRequested ? 'Cancelled' : 'Finished');
      }
      if (!_cancelRequested && _done > 0) {
        await ads.maybeShowInterstitial();
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final settings = context.watch<SettingsController>();
    final tokens = SottoTokens.of(context);
    final docs = library.docs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch studio'),
        leading: IconButton(
          onPressed: () {
            if (_running) {
              setState(() => _cancelRequested = true);
            } else {
              Navigator.of(context).pop();
            }
          },
          icon: Icon(_running ? Icons.close_rounded : Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Turn a shelf into audio.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Documents are rendered one sentence at a time so your phone stays responsive.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          PaperCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.record_voice_over_outlined, color: tokens.accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${settings.voice} · ${settings.speed.toStringAsFixed(2)}×', style: Theme.of(context).textTheme.titleSmall)),
                    TextButton(onPressed: () => showVoiceSheet(context), child: const Text('Voice')),
                  ],
                ),
                const Divider(height: 18),
                Row(
                  children: [
                    Icon(Icons.memory_rounded, color: tokens.accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${modelSpec(settings.modelId).name} model', style: Theme.of(context).textTheme.titleSmall)),
                    TextButton(onPressed: () => showModelSheet(context), child: const Text('Model')),
                  ],
                ),
                const Divider(height: 18),
                Row(
                  children: [
                    Icon(Icons.audio_file_outlined, color: tokens.accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${settings.exportFormat.label} · ${settings.exportFormat.name == 'mp3' ? '${settings.mp3Bitrate} kbps' : 'lossless'}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      'Set in Studio',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionLabel(
            'Documents',
            trailing: TextButton(
              onPressed: _running || docs.isEmpty
                  ? null
                  : () => setState(() {
                        if (_selected.length == docs.length) {
                          _selected.clear();
                        } else {
                          _selected
                            ..clear()
                            ..addAll(docs.map((d) => d.id).whereType<int>());
                        }
                      }),
              child: Text(_selected.length == docs.length ? 'Clear' : 'Select all'),
            ),
          ),
          if (docs.isEmpty)
            const EmptyState(
              icon: Icons.menu_book_rounded,
              title: 'Nothing to convert',
              body: 'Import documents first, then return here.',
            ),
          for (final doc in docs)
            CheckboxListTile(
              value: _selected.contains(doc.id),
              onChanged: _running
                  ? null
                  : (value) => setState(() {
                        if (value == true) {
                          _selected.add(doc.id!);
                        } else {
                          _selected.remove(doc.id);
                        }
                      }),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${doc.kind.name.toUpperCase()} · ${(doc.charCount / 1000).toStringAsFixed(0)}k characters',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          const SizedBox(height: 16),
          if (_running || _overall > 0) ...[
            PaperCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_stage, style: Theme.of(context).textTheme.titleSmall),
                      ),
                      Text('${(_overall * 100).round()}%', style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(value: _overall, minHeight: 6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_done complete${_failed > 0 ? ' · $_failed failed' : ''}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          FilledButton(
            onPressed: _running || _selected.isEmpty ? null : () => _start(docs),
            child: Text(_running ? 'Rendering…' : 'Start batch'),
          ),
          if (_running) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _cancelRequested = true),
              child: const Text('Cancel after this sentence'),
            ),
          ],
        ],
      ),
    );
  }
}
