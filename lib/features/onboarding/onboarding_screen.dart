import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../state/settings_controller.dart';
import '../../tts/voice_catalog.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  void _finish() {
    context.read<SettingsController>().onboarded = true;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (value) => setState(() => _index = value),
                children: const [
                  _OnboardPage(
                    visual: _OfflineVisual(),
                    title: 'Studio voice.\nZero cloud.',
                    body:
                        'Every word is synthesised on this phone. No account, no upload, no server listening in.',
                  ),
                  _OnboardPage(
                    visual: _VoicesVisual(),
                    title: 'Eight voices,\nyour pace.',
                    body:
                        'Audition neural voices, choose a narrator per book, and change speed without regenerating a single word.',
                  ),
                  _OnboardPage(
                    visual: _LibraryVisual(),
                    title: 'Books, links,\nand clips.',
                    body:
                        'Import PDF, EPUB, or TXT, fetch an article once, and turn any passage into a shareable audio clip.',
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _index ? tokens.accent : tokens.hairline,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_index == 2) {
                      _finish();
                    } else {
                      _pages.nextPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  child: Text(_index == 2 ? 'Start listening' : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    required this.visual,
    required this.title,
    required this.body,
  });

  final Widget visual;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Center(child: visual)),
          Text(title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 14),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: tokens.muted,
                  height: 1.55,
                ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _OfflineVisual extends StatelessWidget {
  const _OfflineVisual();

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 3; i >= 1; i--)
            Container(
              width: 90.0 + i * 55,
              height: 90.0 + i * 55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: tokens.accent.withValues(alpha: 0.10 + i * 0.05),
                ),
              ),
            ),
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              color: tokens.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: tokens.accent.withValues(alpha: 0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'S',
                style: TextStyle(
                  fontFamily: 'InstrumentSerif',
                  fontSize: 72,
                  height: 1,
                  color: tokens.accentInk,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 26,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: tokens.hairline),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: tokens.olive),
                  const SizedBox(width: 6),
                  Text(
                    'ON DEVICE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                          color: tokens.olive,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoicesVisual extends StatelessWidget {
  const _VoicesVisual();

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        for (final voice in voiceCatalog.take(8))
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: voice.tint,
              shape: BoxShape.circle,
              border: Border.all(
                color: tokens.paper,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: voice.tint.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                voice.initial,
                style: const TextStyle(
                  fontFamily: 'InstrumentSerif',
                  fontSize: 28,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LibraryVisual extends StatelessWidget {
  const _LibraryVisual();

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return SizedBox(
      width: 280,
      height: 230,
      child: Stack(
        children: [
          Positioned(
            left: 20,
            top: 10,
            child: Transform.rotate(
              angle: -0.08,
              child: CoverTile(title: 'The Long Winter', seed: 1, size: 96),
            ),
          ),
          Positioned(
            left: 96,
            top: 26,
            child: Transform.rotate(
              angle: 0.05,
              child: CoverTile(title: 'A Room of Paper', seed: 3, size: 96),
            ),
          ),
          Positioned(
            right: 6,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tokens.hairline),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2A2118).withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.content_cut_rounded, size: 16, color: tokens.accent),
                  const SizedBox(width: 8),
                  Text('Clip', style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tokens.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, size: 18, color: tokens.muted),
                    const SizedBox(width: 10),
                    Icon(Icons.menu_book_rounded, size: 18, color: tokens.muted),
                    const SizedBox(width: 10),
                    Icon(Icons.link_rounded, size: 18, color: tokens.muted),
                    const SizedBox(width: 10),
                    Icon(Icons.graphic_eq_rounded, size: 18, color: tokens.accent),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
