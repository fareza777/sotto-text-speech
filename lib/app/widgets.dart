import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';


import 'theme.dart';

class SottoWordmark extends StatelessWidget {
  const SottoWordmark({super.key, this.fontSize = 30, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          'Sotto',
          style: TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: fontSize,
            height: 1,
            letterSpacing: -0.6,
            color: color ?? tokens.ink,
          ),
        ),
        const SizedBox(width: 3),
        Container(
          width: 6,
          height: 6,
          margin: EdgeInsets.only(bottom: fontSize * 0.12),
          decoration: BoxDecoration(
            color: tokens.accent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: tokens.muted,
                    letterSpacing: 1.4,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.onTap,
    this.radius = 24,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tokens.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? tokens.hairline),
        boxShadow: tokens.isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF2A2118).withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class PrivacyPill extends StatelessWidget {
  const PrivacyPill({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 5 : 7),
      decoration: BoxDecoration(
        color: tokens.olive.withValues(alpha: tokens.isDark ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: compact ? 12 : 14, color: tokens.olive),
          const SizedBox(width: 6),
          Text(
            compact ? 'Offline' : 'On-device · nothing leaves this phone',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tokens.olive,
                  letterSpacing: 0.3,
                ),
          ),
        ],
      ),
    );
  }
}

class WaveBars extends StatelessWidget {
  const WaveBars({
    super.key,
    this.height = 36,
    this.bars = 26,
    this.progress = 0,
    this.color,
    this.seed = 7,
    this.awake = false,
    this.peaks,
  });

  final List<double>? peaks;
  final double height;
  final int bars;
  final double progress;
  final Color? color;
  final int seed;
  final bool awake;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _WavePainter(
          bars: bars,
          progress: progress,
          color: color ?? tokens.accent,
          idleColor: tokens.hairline,
          seed: seed,
          reveal: t,
          awake: awake,
          peaks: peaks,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.bars,
    required this.progress,
    required this.color,
    required this.idleColor,
    required this.seed,
    required this.reveal,
    required this.awake,
    this.peaks,
  });

  final int bars;
  final double progress;
  final Color color;
  final Color idleColor;
  final int seed;
  final double reveal;
  final bool awake;
  final List<double>? peaks;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final barWidth = size.width / (bars * 1.85);
    final gap = (size.width - barWidth * bars) / (bars - 1).clamp(1, 999);
    final playedIndex = (progress.clamp(0, 1) * bars).floor();
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < bars; i++) {
      final noise = (peaks != null && peaks!.isNotEmpty)
          ? peaks![(i * peaks!.length ~/ bars).clamp(0, peaks!.length - 1)]
          : 0.28 + random.nextDouble() * 0.72;
      final centerBias = 1 - ((i - bars / 2).abs() / (bars / 1.35)).clamp(0, 1) * 0.55;
      final h = size.height * noise * centerBias * reveal;
      final x = i * (barWidth + gap) + barWidth / 2;
      final active = i <= playedIndex;
      paint.color = active ? color.withValues(alpha: awake ? 0.95 : 0.65) : idleColor;
      paint.strokeWidth = barWidth;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.progress != progress ||
      old.reveal != reveal ||
      old.awake != awake ||
      old.peaks != peaks;
}

class CoverTile extends StatelessWidget {
  const CoverTile({
    super.key,
    required this.title,
    required this.seed,
    this.size = 92,
    this.progress,
    this.badge,
    this.coverPath,
    this.overlayTitle = false,
  });

  final String title;
  final int seed;
  final double size;
  final double? progress;
  final String? badge;
  final String? coverPath;
  final bool overlayTitle;

  static const _palettes = [
    [Color(0xFFB3542C), Color(0xFF6A2E14)],
    [Color(0xFF55604B), Color(0xFF2E3727)],
    [Color(0xFF6B5133), Color(0xFF3A2A18)],
    [Color(0xFF4C5A66), Color(0xFF2A343C)],
    [Color(0xFF7A4A52), Color(0xFF43262B)],
    [Color(0xFF84704E), Color(0xFF473B27)],
  ];

  @override
  Widget build(BuildContext context) {
    final palette = _palettes[seed.abs() % _palettes.length];
    final base = palette[0];
    final deep = palette[1];
    final initial = title.trim().isEmpty ? 'S' : title.trim().substring(0, 1).toUpperCase();
    final showTitle = size >= 70;
    final fallback = Container(
            width: size,
            height: size * 1.28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [base, deep],
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  initial,
                  style: TextStyle(
                    fontFamily: 'InstrumentSerif',
                    fontSize: size * 0.42,
                    height: 1,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (showTitle)
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: (size * 0.13).clamp(9.5, 11.0),
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          );

    final cover = coverPath == null
        ? fallback
        : ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(coverPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                ),
                if (overlayTitle)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(9, 22, 9, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: (size * 0.12).clamp(8.5, 10.5),
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );

    return SizedBox(
      width: size,
      height: size * 1.28,
      child: Stack(
        children: [
          cover,

          if (progress != null && progress! > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          if (badge != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tokens.accent, size: 26),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

class Dot extends StatelessWidget {
  const Dot({super.key, this.color, this.size = 4});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? SottoTokens.of(context).muted,
        shape: BoxShape.circle,
      ),
    );
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (minutes >= 60) {
    return '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
  }
  return '$minutes:$seconds';
}
