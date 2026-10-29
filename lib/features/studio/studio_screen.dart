import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/audio_export.dart';
import '../../core/audio_format.dart';
import '../../core/mp3_encoder.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
import '../../tts/model_catalog.dart';
import '../../tts/tts_service.dart';
import '../../tts/voice_catalog.dart';
import 'model_sheet.dart';
import 'voice_sheet.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  final _controller = TextEditingController();
  bool _generating = false;
  AudioTrack? _last;
  String? _error;

  static const _samples = {
    'Welcome': 'Welcome to Sotto. Everything you hear is generated on this phone, not on a server.',
    'Product note': 'Meet the new field notebook. Linen cover, lay-flat binding, and paper thick enough for ink.',
    'Story intro': 'The house had been empty for eleven years. Nobody in town could agree on why.',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write or paste something to read.');
      return;
    }
    if (text.length > 6000) {
      setState(() => _error = 'Studio handles up to 6,000 characters. Use the Reader for full books.');
      return;
    }
    final settings = context.read<SettingsController>();
    final tts = context.read<TtsService>();
    final library = context.read<LibraryController>();
    final player = context.read<PlayerController>();
    FocusScope.of(context).unfocus();
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final result = await tts.generate(
        text,
        voice: settings.voice,
        speed: settings.speed,
        modelId: settings.modelId,
      );
      final title = text.length > 46 ? '${text.substring(0, 46)}…' : text;
      final track = await saveAudioToLibrary(
        samples: result.samples,
        sampleRate: result.sampleRate,
        title: title,
        voice: settings.voice,
        modelId: settings.modelId,
        speed: settings.speed,
        format: settings.exportFormat,
        bitRate: settings.mp3Bitrate,
        excerpt: text,
      );
      await library.addTrack(track);
      final saved = library.tracks.firstWhere((t) => t.path == track.path, orElse: () => track);
      await player.playTrack(saved);
      if (!mounted) return;
      setState(() => _last = saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error is TtsException ? error.message : 'Could not generate audio.');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final tts = context.watch<TtsService>();
    final player = context.watch<PlayerController>();
    final tokens = SottoTokens.of(context);
    final voice = voiceSpec(settings.voice);
    final model = modelSpec(settings.modelId);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Text('Studio', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 4),
          Text(
            'Type it. Hear it. Keep it.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 20),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  minLines: 6,
                  maxLines: 12,
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Paste an article, a chapter, or a thought worth hearing…',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) => Text(
                        '${value.text.length} / 6000',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) => TextButton(
                        onPressed: value.text.isEmpty ? null : () => _controller.clear(),
                        child: const Text('Clear'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _samples.entries)
                ActionChip(
                  label: Text(entry.key),
                  onPressed: () => _controller.text = entry.value,
                ),
            ],
          ),
          const SizedBox(height: 22),
          SectionLabel('Voice'),
          PaperCard(
            onTap: () => showVoiceSheet(context),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: voice.tint, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      voice.initial,
                      style: const TextStyle(
                        fontFamily: 'InstrumentSerif',
                        fontSize: 22,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(voice.name, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        '${voice.gender} · English',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                Text('Change', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tokens.accent)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionLabel('Pace'),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('${settings.speed.toStringAsFixed(2)}×', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      settings.speed < 0.9
                          ? 'Unhurried'
                          : settings.speed > 1.25
                              ? 'Brisk'
                              : 'Natural',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                Slider(
                  value: settings.speed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 30,
                  onChanged: (value) => settings.speed = value,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0.5×', style: Theme.of(context).textTheme.labelSmall),
                    Text('2.0×', style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionLabel('Engine'),
          PaperCard(
            onTap: () => showModelSheet(context),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.memory_rounded, color: tokens.accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${model.name} model', style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        '${model.sizeMb.toStringAsFixed(0)} MB · ${tts.loadedModelId == model.id ? 'warm' : 'cold start'}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                Text('Manage', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tokens.accent)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionLabel('Output'),
          PaperCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<AudioFormat>(
                        segments: [
                          const ButtonSegment(value: AudioFormat.wav, label: Text('WAV')),
                          ButtonSegment(
                            value: AudioFormat.mp3,
                            label: Text(Mp3FileWriter.isAvailable ? 'MP3' : 'MP3 (n/a)'),
                          ),
                        ],
                        selected: {settings.exportFormat},
                        onSelectionChanged: Mp3FileWriter.isAvailable
                            ? (value) => settings.exportFormat = value.first
                            : null,
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelSmall),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (settings.exportFormat == AudioFormat.mp3)
                      Text(
                        '${settings.mp3Bitrate} kbps',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
                if (settings.exportFormat == AudioFormat.mp3) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final rate in [96, 128, 160])
                        ChoiceChip(
                          label: Text('$rate kbps'),
                          selected: settings.mp3Bitrate == rate,
                          labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: settings.mp3Bitrate == rate ? tokens.accent : tokens.ink,
                                letterSpacing: 0.2,
                              ),
                          onSelected: (_) => settings.mp3Bitrate = rate,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  settings.exportFormat == AudioFormat.wav
                      ? 'Lossless, larger files. Ideal for editing.'
                      : 'Compact MP3 via LAME, ideal for sharing. Still 24 kHz mono.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.danger)),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _generating ? null : _generate,
            child: _generating
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(tts.isLoading ? tts.loadStatus : 'Synthesising…'),
                    ],
                  )
                : const Text('Generate voice'),
          ),
          if (_generating && tts.isLoading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: tts.loadProgress, minHeight: 4),
            ),
          ],
          if (_last != null) ...[
            const SizedBox(height: 24),
            SectionLabel('Latest render'),
            PaperCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _last!.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: player.toggle,
                        icon: Icon(
                          player.isPlaying && player.current?.path == _last!.path
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_fill_rounded,
                          color: tokens.accent,
                          size: 38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_last!.durationLabel} · ${_last!.voice} · ${formatBytes(_last!.sizeBytes)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(files: [XFile(_last!.path)], text: _last!.title),
                        ),
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text('Share'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
