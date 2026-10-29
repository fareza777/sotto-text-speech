import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';

Future<void> showTrackMenu(BuildContext context, AudioTrack track) async {
  final library = context.read<LibraryController>();
  final player = context.read<PlayerController>();
  final subtitleFile = File(p.setExtension(track.path, '.srt'));
  final hasSubtitles = await subtitleFile.exists();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SingleChildScrollView(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('Play now'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  player.playTrack(track);
                },
              ),
              ListTile(
                leading: Icon(
                  track.favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                title: Text(
                  track.favorite
                      ? 'Remove from favourites'
                      : 'Add to favourites',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  library.toggleFavorite(track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Add to playlist'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await showAddToPlaylist(context, track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline_rounded),
                title: const Text('Rename'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _renameTrack(context, track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Share audio'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final file = File(track.path);
                  if (!await file.exists()) return;
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(track.path)],
                      text: track.title,
                      subject: track.title,
                    ),
                  );
                },
              ),
              if (hasSubtitles)
                ListTile(
                  leading: const Icon(Icons.subtitles_outlined),
                  title: const Text('Share subtitles (.srt)'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(subtitleFile.path)],
                        text: '${track.title} — subtitles',
                        subject: track.title,
                      ),
                    );
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: SottoTokens.of(context).danger,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(color: SottoTokens.of(context).danger),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _confirmDelete(context, track);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _renameTrack(BuildContext context, AudioTrack track) async {
  final controller = TextEditingController(text: track.title);
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Rename audio'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Title'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (value == null || value.isEmpty || !context.mounted) return;
  await context.read<LibraryController>().renameTrack(track, value);
}

Future<void> _confirmDelete(BuildContext context, AudioTrack track) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete this audio?'),
      content: Text('“${track.title}” will be removed from your device.'),
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
  if (confirmed != true || !context.mounted) return;
  await context.read<LibraryController>().deleteTrack(track);
}

Future<void> showAddToPlaylist(BuildContext context, AudioTrack track) async {
  final library = context.read<LibraryController>();
  await library.refresh();
  if (!context.mounted) return;
  final playlists = library.playlists;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => SingleChildScrollView(
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('New playlist'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final name = await _askPlaylistName(context);
                if (name == null || !context.mounted) return;
                final playlist = await library.createPlaylist(name);
                if (track.id != null) {
                  await library.addTrackToPlaylist(playlist.id!, track.id!);
                }
              },
            ),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No playlists yet.'),
              ),
            for (final playlist in playlists)
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: Text(playlist.name),
                subtitle: Text('${playlist.trackCount} tracks'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (track.id != null) {
                    await library.addTrackToPlaylist(playlist.id!, track.id!);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added to ${playlist.name}')),
                    );
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

Future<String?> askPlaylistName(BuildContext context) =>
    _askPlaylistName(context);

Future<String?> _askPlaylistName(BuildContext context) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New playlist'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Evening chapters'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  return (value == null || value.isEmpty) ? null : value;
}
