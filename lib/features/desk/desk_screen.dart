import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/ad_widgets.dart';
import '../../app/shell_navigation.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../../tts/voice_catalog.dart';
import '../import/import_actions.dart';
import '../library/library_actions.dart';
import '../reader/reader_screen.dart';
import '../studio/voice_sheet.dart';

class DeskScreen extends StatelessWidget {
  const DeskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final tokens = SottoTokens.of(context);
    final docs = library.docs;
    final continueDoc = docs.where((d) => d.progress > 0.001).isNotEmpty
        ? docs.firstWhere((d) => d.progress > 0.001)
        : (docs.isNotEmpty ? docs.first : null);
    final hasProgress = (continueDoc?.progress ?? 0) > 0.001;
    final recentTracks = library.tracks.take(6).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SottoWordmark(fontSize: 32),
              const Spacer(),
              IconButton(
                tooltip: 'Voices',
                onPressed: () => showVoiceSheet(context),
                icon: const Icon(Icons.record_voice_over_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_greeting(), style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your listening desk. All on-device.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 10),
              const PrivacyPill(compact: true),
            ],
          ),
          const SizedBox(height: 18),
          if (continueDoc != null) ...[
            SectionLabel(
              hasProgress ? 'Pick up where you left off' : 'From your library',
            ),
            _ContinueCard(
              title: continueDoc.title,
              author: continueDoc.author,
              progress: continueDoc.progress,
              seed: continueDoc.coverSeed,
              coverPath: continueDoc.coverPath,
              overlayTitle: continueDoc.kind == DocKind.pdf,
              onOpen: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReaderScreen(doc: continueDoc),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          const SectionLabel('Start something'),
          PaperCard(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Expanded(
                  child: _QuickItem(
                    icon: Icons.graphic_eq_rounded,
                    label: 'Speak',
                    onTap: () => ShellNavigation.of(context).goTo(1),
                  ),
                ),
                const _QuickDivider(),
                Expanded(
                  child: _QuickItem(
                    icon: Icons.menu_book_rounded,
                    label: 'Import',
                    onTap: () => pickAndImportDocuments(context),
                  ),
                ),
                const _QuickDivider(),
                Expanded(
                  child: _QuickItem(
                    icon: Icons.link_rounded,
                    label: 'Read link',
                    onTap: () => importArticleFlow(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionLabel(
            'Recent audio',
            trailing: recentTracks.isEmpty
                ? null
                : TextButton(
                    onPressed: () => ShellNavigation.of(context).goTo(2),
                    child: const Text('All'),
                  ),
          ),
          if (recentTracks.isEmpty)
            PaperCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              child: Row(
                children: [
                  Icon(Icons.multitrack_audio_rounded, color: tokens.accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Generated audio will appear here, ready to replay or export.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 122,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentTracks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final track = recentTracks[index];
                  return _RecentAudioCard(track: track);
                },
              ),
            ),
          const SizedBox(height: 12),
          const AdBannerSlot(),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning.';
    if (hour < 18) return 'Good afternoon.';
    return 'Good evening.';
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.title,
    required this.author,
    required this.progress,
    required this.seed,
    required this.onOpen,
    this.coverPath,
    this.overlayTitle = false,
  });

  final String title;
  final String? author;
  final double progress;
  final int seed;
  final VoidCallback onOpen;
  final String? coverPath;
  final bool overlayTitle;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return PaperCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CoverTile(
            title: title,
            seed: seed,
            size: 76,
            progress: progress,
            coverPath: coverPath,
            overlayTitle: overlayTitle,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  author?.isNotEmpty == true ? author! : 'In your library',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (progress > 0.001)
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0, 1),
                            minHeight: 4,
                            backgroundColor: tokens.hairline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(progress * 100).round()}%',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  )
                else
                  Text(
                    'Not started',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tokens.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: tokens.accentInk,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickItem extends StatelessWidget {
  const _QuickItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tokens.accent, size: 22),
            const SizedBox(height: 7),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _QuickDivider extends StatelessWidget {
  const _QuickDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: SottoTokens.of(context).hairline,
    );
  }
}

class _RecentAudioCard extends StatelessWidget {
  const _RecentAudioCard({required this.track});

  final AudioTrack track;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    final player = context.read<PlayerController>();
    final voice = voiceSpec(track.voice);
    return SizedBox(
      width: 198,
      child: PaperCard(
        radius: 18,
        padding: const EdgeInsets.all(12),
        onTap: () => player.playTrack(track),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: voice.tint,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      voice.initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'InstrumentSerif',
                        fontSize: 14,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => showTrackMenu(context, track),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: tokens.muted,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              track.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${track.durationLabel} · ${track.format.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: tokens.accent,
                  size: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
