import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/wav_writer.dart';
import '../../state/settings_controller.dart';
import '../../tts/tts_service.dart';
import '../../tts/voice_catalog.dart';

Future<void> showVoiceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.86,
      child: VoiceSheet(),
    ),
  );
}

class VoiceSheet extends StatefulWidget {
  const VoiceSheet({super.key});

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<VoiceSheet> {
  final _player = AudioPlayer();
  String? _previewing;
  String? _error;

  Future<void> _preview(VoiceSpec voice) async {
    final tts = context.read<TtsService>();
    final settings = context.read<SettingsController>();
    setState(() {
      _previewing = voice.id;
      _error = null;
    });
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(dir.path, 'audition_${voice.id}_${settings.modelId}.wav'),
      );
      final cached = await file.exists() && await file.length() > 1000;
      if (!cached) {
        final result = await tts.generate(
          voice.sampleLine,
          voice: voice.id,
          speed: 1.0,
          modelId: settings.modelId,
        );
        await file.writeAsBytes(
          encodeWav(result.samples, result.sampleRate),
          flush: true,
        );
      }
      await _player.setFilePath(file.path);
      await _player.play();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is TtsException ? error.message : 'Preview failed.');
      }
    } finally {
      if (mounted) setState(() => _previewing = null);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final tokens = SottoTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose a voice', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Eight neural voices, rendered on this phone. Audition one before you commit.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.danger)),
          ],
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: voiceCatalog.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final voice = voiceCatalog[index];
                final selected = settings.voice == voice.id;
                final previewing = _previewing == voice.id;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      settings.voice = voice.id;
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected ? tokens.accentWash : tokens.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected ? tokens.accent : tokens.hairline,
                          width: selected ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(color: voice.tint, shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                voice.initial,
                                style: const TextStyle(
                                  fontFamily: 'InstrumentSerif',
                                  fontSize: 24,
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
                          IconButton(
                            tooltip: 'Audition ${voice.name}',
                            onPressed: previewing ? null : () => _preview(voice),
                            icon: previewing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(
                                    Icons.play_circle_outline_rounded,
                                    color: selected ? tokens.accent : tokens.muted,
                                  ),
                          ),
                          if (selected)
                            Icon(Icons.check_circle_rounded, color: tokens.accent),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
