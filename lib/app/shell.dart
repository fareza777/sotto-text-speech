import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/desk/desk_screen.dart';
import '../features/library/library_screen.dart';
import '../features/player/player_sheet.dart';
import '../features/settings/settings_screen.dart';
import '../features/studio/studio_screen.dart';
import '../features/reader/reader_screen.dart';
import '../state/narration_session.dart';
import '../state/player_controller.dart';
import 'shell_navigation.dart';
import 'theme.dart';
import 'widgets.dart';

class SottoShell extends StatefulWidget {
  const SottoShell({super.key});

  @override
  State<SottoShell> createState() => _SottoShellState();
}

class _SottoShellState extends State<SottoShell> {
  int _index = 0;

  static const _pages = [
    DeskScreen(),
    StudioScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return Scaffold(
      body: ShellNavigation(
        goTo: (index) => setState(() => _index = index),
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.hairline)),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.auto_stories_outlined),
                    selectedIcon: Icon(Icons.auto_stories_rounded),
                    label: 'Desk',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.graphic_eq_rounded),
                    selectedIcon: Icon(Icons.graphic_eq_rounded),
                    label: 'Studio',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.library_music_outlined),
                    selectedIcon: Icon(Icons.library_music_rounded),
                    label: 'Library',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.tune_rounded),
                    selectedIcon: Icon(Icons.tune_rounded),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final session = context.watch<NarrationSession>();
    final tokens = SottoTokens.of(context);
    final track = player.current;

    if (track != null) {
      return _MiniShell(
        onTap: () => showPlayerSheet(context),
        leading: Icon(Icons.multitrack_audio_rounded, color: tokens.accent, size: 20),
        title: track.title,
        subtitle:
            '${formatDuration(player.position)} · ${track.voice.toUpperCase()}',
        trailing: IconButton(
          onPressed: player.toggle,
          icon: Icon(
            player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 28,
          ),
        ),
      );
    }

    final doc = session.doc;
    final controller = session.controller;
    if (doc == null || controller == null || !session.isActive) {
      return const SizedBox.shrink();
    }
    final chapter = session.chapterTitle ?? 'Reading';
    return _MiniShell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReaderScreen(doc: doc)),
      ),
      leading: Icon(Icons.auto_stories_rounded, color: tokens.accent, size: 20),
      title: doc.title,
      subtitle: controller.isPreparing
          ? 'Preparing the next passage…'
          : '$chapter · ${(session.progress * 100).round()}%',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: session.toggle,
            icon: Icon(
              controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 28,
            ),
          ),
          IconButton(
            onPressed: session.stop,
            icon: Icon(Icons.close_rounded, size: 20, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class _MiniShell extends StatelessWidget {
  const _MiniShell({
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return Material(
      color: tokens.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: tokens.hairline)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tokens.accentWash,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: leading),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
