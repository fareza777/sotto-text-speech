import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import 'ad_service.dart';

/// Reserved, collapsible banner slot. It renders nothing until an ad is
/// actually ready, so the layout never shows an empty hole.
class AdBannerSlot extends StatefulWidget {
  const AdBannerSlot({super.key, this.margin = const EdgeInsets.only(top: 8)});

  final EdgeInsets margin;

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends State<AdBannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;
  double _height = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  Future<void> _maybeLoad() async {
    if (_requested) return;
    final ads = context.read<AdService>();
    if (!ads.adsAllowed) return;
    _requested = true;
    final width = (MediaQuery.sizeOf(context).width - 40).truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!mounted) return;
    if (size == null) {
      _requested = false;
      return;
    }
    _height = size.height.toDouble();
    final ad = ads.createBanner(
      size: size,
      onLoaded: () {
        if (!mounted) return;
        setState(() => _loaded = true);
      },
      onFailed: () {
        if (!mounted) return;
        setState(() => _loaded = false);
      },
    );
    ad.load();
    _ad = ad;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ads = context.watch<AdService>();
    if (!ads.adsAllowed) return const SizedBox.shrink();
    _maybeLoad();
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Container(
      margin: widget.margin,
      alignment: Alignment.center,
      height: _height > 0 ? _height : 56,
      decoration: BoxDecoration(
        color: SottoTokens.of(context).surfaceRaised,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: AdWidget(ad: _ad!),
    );
  }
}
