import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/ad_widgets.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../batch/batch_screen.dart';
import '../import/import_actions.dart';
import '../reader/reader_screen.dart';
import 'library_actions.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final tokens = SottoTokens.of(context);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Library', style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 4),
                      Text(
                        '${library.docs.length} documents · ${library.tracks.length} audio · ${formatBytes(library.audioBytes)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Batch studio',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BatchScreen()),
                  ),
                  icon: const Icon(Icons.dynamic_feed_rounded),
                ),
                IconButton(
                  tooltip: 'Import',
                  onPressed: () => pickAndImportDocuments(context),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: tokens.surfaceRaised,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _segment = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _segment == i ? tokens.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Center(
                            child: Text(
                              ['Documents', 'Audio', 'Playlists'][i],
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: _segment == i ? tokens.ink : tokens.muted,
                                    letterSpacing: 0.3,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_segment) {
                0 => _DocsList(key: const ValueKey(0), docs: library.docs),
                1 => _TracksList(key: const ValueKey(1), tracks: library.tracks),
                _ => _PlaylistsList(key: const ValueKey(2)),
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: AdBannerSlot(),
          ),
        ],
      ),
    );
  }
}

class _DocsList extends StatelessWidget {
  const _DocsList({super.key, required this.docs});

  final List<Doc> docs;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    if (docs.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_rounded,
        title: 'No documents yet',
        body: 'Import a PDF, EPUB, or TXT file and Sotto will read it aloud — offline.',
        action: FilledButton(
          onPressed: () => pickAndImportDocuments(context),
          child: const Text('Import a document'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: docs.length,
      separatorBuilder: (_, __) => Divider(color: tokens.hairline, height: 18),
      itemBuilder: (context, index) {
        final doc = docs[index];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ReaderScreen(doc: doc)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CoverTile(
                  title: doc.title,
                  seed: doc.coverSeed,
                  size: 54,
                  progress: doc.progress,
                  coverPath: doc.coverPath,
                  overlayTitle: doc.kind == DocKind.pdf,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          doc.kind.name.toUpperCase(),
                          if (doc.author?.isNotEmpty == true) doc.author!,
                          '${(doc.progress * 100).round()}%',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: tokens.muted, size: 20),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      final library = context.read<LibraryController>();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Remove this document?'),
                          content: Text('“${doc.title}” will be removed from your library.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext, false),
                              child: const Text('Keep'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dialogContext, true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) await library.deleteDoc(doc);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('Remove from library')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TracksList extends StatelessWidget {
  const _TracksList({super.key, required this.tracks});

  final List<AudioTrack> tracks;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    final player = context.watch<PlayerController>();
    if (tracks.isEmpty) {
      return const EmptyState(
        icon: Icons.multitrack_audio_rounded,
        title: 'No audio yet',
        body: 'Anything you generate in Studio or export from the Reader lands here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: tracks.length,
      separatorBuilder: (_, __) => Divider(color: tokens.hairline, height: 18),
      itemBuilder: (context, index) {
        final track = tracks[index];
        final active = player.current?.id == track.id;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => player.playTrack(track),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: active ? tokens.accent : tokens.accentWash,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    active && player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: active ? tokens.accentInk : tokens.accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${track.durationLabel} · ${track.voice} · ${track.format.toUpperCase()} · ${formatBytes(track.sizeBytes)}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                if (track.favorite)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.favorite_rounded, size: 16, color: tokens.accent),
                  ),
                IconButton(
                  onPressed: () => showTrackMenu(context, track),
                  icon: Icon(Icons.more_vert_rounded, color: tokens.muted, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlaylistsList extends StatelessWidget {
  const _PlaylistsList({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final player = context.read<PlayerController>();
    final tokens = SottoTokens.of(context);
    final playlists = library.playlists;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        PaperCard(
          onTap: () async {
            final name = await askPlaylistName(context);
            if (name != null) await library.createPlaylist(name);
          },
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.accentWash,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.add_rounded, color: tokens.accent),
              ),
              const SizedBox(width: 14),
              Text('New playlist', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (playlists.isEmpty)
          const EmptyState(
            icon: Icons.queue_music_rounded,
            title: 'Playlists live here',
            body: 'Group exported audio into chapters, commutes, or bedtime queues.',
          ),
        for (final playlist in playlists)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PaperCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tokens.surfaceRaised,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.queue_music_rounded, color: tokens.muted),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(playlist.name, style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          '${playlist.trackCount} tracks',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final tracks = await library.playlistTracks(playlist.id!);
                      if (tracks.isNotEmpty) await player.playQueue(tracks);
                    },
                    icon: Icon(Icons.play_circle_fill_rounded, color: tokens.accent, size: 30),
                  ),
                  IconButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Delete playlist?'),
                          content: const Text('The audio files themselves are kept.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext, false),
                              child: const Text('Keep'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dialogContext, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) await library.deletePlaylist(playlist.id!);
                    },
                    icon: Icon(Icons.delete_outline_rounded, color: tokens.muted, size: 20),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
