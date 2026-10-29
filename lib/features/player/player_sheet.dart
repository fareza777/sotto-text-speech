import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
import '../library/library_actions.dart';

Future<void> showPlayerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        const FractionallySizedBox(heightFactor: 0.92, child: PlayerSheet()),
  );
}

Future<void> _showSleepSheet(BuildContext context, PlayerController player) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(
            'Sleep timer',
            style: Theme.of(sheetContext).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Audio fades out and pauses.',
            style: Theme.of(sheetContext).textTheme.labelSmall,
          ),
          const SizedBox(height: 10),
          for (final minutes in [0, 15, 30, 45, 60])
            ListTile(
              title: Text(minutes == 0 ? 'Off' : '$minutes minutes'),
              trailing:
                  player.sleepRemaining != null &&
                      minutes > 0 &&
                      player.sleepRemaining!.inMinutes <= minutes &&
                      player.sleepRemaining!.inMinutes > minutes - 15
                  ? Icon(
                      Icons.check_rounded,
                      color: SottoTokens.of(context).accent,
                    )
                  : null,
              onTap: () {
                player.setSleepTimer(
                  minutes == 0 ? null : Duration(minutes: minutes),
                );
                Navigator.pop(sheetContext);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class PlayerSheet extends StatelessWidget {
  const PlayerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final tokens = SottoTokens.of(context);
    final track = player.current;
    if (track == null) {
      return const SizedBox.shrink();
    }
    final duration = player.duration;
    final position = player.position;
    final maxValue = duration.inMilliseconds < 1
        ? 1.0
        : duration.inMilliseconds.toDouble();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            tokens.accent.withValues(alpha: 0.92),
                            tokens.isDark
                                ? const Color(0xFF2B211C)
                                : const Color(0xFF6A3218),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.graphic_eq_rounded,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              track.voice.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      track.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${track.voice} · ${track.model} · ${track.format.toUpperCase()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 22),
                    WaveBars(
                      height: 44,
                      bars: 44,
                      progress: player.progress,
                      awake: player.isPlaying,
                      seed: (track.path.hashCode & 0x7fffffff) % 360,
                      peaks: track.peakValues.isEmpty ? null : track.peakValues,
                    ),
                    Slider(
                      value: position.inMilliseconds
                          .toDouble()
                          .clamp(0.0, maxValue)
                          .toDouble(),
                      max: maxValue,
                      onChanged: (value) =>
                          player.seek(Duration(milliseconds: value.round())),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatDuration(position),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            formatDuration(duration),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 30,
                          onPressed: player.previous,
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          iconSize: 26,
                          onPressed: () {
                            final target =
                                position - const Duration(seconds: 15);
                            player.seek(
                              target < Duration.zero ? Duration.zero : target,
                            );
                          },
                          icon: const Icon(Icons.replay_10_rounded),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: tokens.accent,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 38,
                            color: tokens.accentInk,
                            onPressed: player.toggle,
                            icon: Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          iconSize: 26,
                          onPressed: () => player.seek(
                            position + const Duration(seconds: 30),
                          ),
                          icon: const Icon(Icons.forward_30_rounded),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          iconSize: 30,
                          onPressed: player.next,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const SectionLabel('Playback'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final value in [0.75, 1.0, 1.25, 1.5])
                          ChoiceChip(
                            label: Text('${value.toStringAsFixed(2)}×'),
                            selected:
                                (context
                                            .watch<SettingsController>()
                                            .playbackSpeed -
                                        value)
                                    .abs() <
                                0.01,
                            onSelected: (_) {
                              context.read<SettingsController>().playbackSpeed =
                                  value;
                              player.setPlaybackSpeed(value);
                            },
                          ),
                        ChoiceChip(
                          label: Text(
                            player.sleepRemaining == null
                                ? 'Sleep timer'
                                : 'Sleep ${formatDuration(player.sleepRemaining!)}',
                          ),
                          selected: player.sleepRemaining != null,
                          onSelected: (_) => _showSleepSheet(context, player),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => showTrackMenu(context, track),
                          icon: const Icon(Icons.more_horiz_rounded, size: 18),
                          label: const Text('Options'),
                        ),
                      ],
                    ),
                    if (player.queue.length > 1) ...[
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SectionLabel('Up next'),
                      ),
                      for (var i = 0; i < player.queue.length; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Text(
                            '${i + 1}'.padLeft(2, '0'),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          title: Text(
                            player.queue[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          trailing: player.queue[i].id == track.id
                              ? Icon(
                                  Icons.equalizer_rounded,
                                  color: tokens.accent,
                                  size: 18,
                                )
                              : null,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
