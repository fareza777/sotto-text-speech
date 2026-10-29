import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../state/settings_controller.dart';
import 'ad_config.dart';

/// AdMob integration.
///
/// Test unit IDs are shipped on purpose: real IDs belong to the publisher and
/// must be pasted into [_bannerUnit], [_interstitialUnit] and [_rewardedUnit]
/// before release. Every ad surface is skipped when the user enables Offline
/// Mode or holds a Studio Pass, so the core promise of the app never depends
/// on the ad SDK.
class AdService extends ChangeNotifier {
  AdService(this._settings) {
    _settings.addListener(_onSettingsChanged);
  }

  final SettingsController _settings;

  void _onSettingsChanged() {
    if (!adsAllowed || _settings.offlineMode || _settings.hasStudioPass) {
      _interstitial?.dispose();
      _interstitial = null;
      _rewarded?.dispose();
      _rewarded = null;
    }
    notifyListeners();
  }

  static const _bannerUnit = AdConfig.bannerUnit;
  static const _interstitialUnit = AdConfig.interstitialUnit;
  static const _rewardedUnit = AdConfig.rewardedUnit;

  bool _initialized = false;
  bool _canRequestAds = false;
  bool _consentAttempted = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  DateTime? _lastInterstitial;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;

  bool get initialized => _initialized;
  bool get adsAllowed =>
      !_settings.offlineMode &&
      !_settings.hasStudioPass &&
      !_settings.adsRemoved &&
      _initialized &&
      _canRequestAds;
  String get bannerUnitId => _bannerUnit;
  String get interstitialUnitId => _interstitialUnit;
  String get rewardedUnitId => _rewardedUnit;

  Future<void> initialize() async {
    if (_initialized || _settings.offlineMode || _settings.hasStudioPass || _settings.adsRemoved) return;
    try {
      if (!_consentAttempted) {
        _consentAttempted = true;
        await _requestConsent();
      }
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      if (!_canRequestAds) {
        notifyListeners();
        return;
      }
      await MobileAds.instance.initialize();
      _initialized = true;
      notifyListeners();
      _preloadInterstitial();
      _preloadRewarded();
    } catch (error) {
      debugPrint('[Sotto] ad init skipped: $error');
    }
  }

  Future<void> _requestConsent() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          final available = await ConsentInformation.instance.isConsentFormAvailable();
          if (available) {
            await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
              if (error != null) debugPrint('[Sotto] consent form: ${error.message}');
            });
          }
        } finally {
          completer.complete();
        }
      },
      (FormError error) {
        debugPrint('[Sotto] consent update failed: ${error.message}');
        completer.complete();
      },
    );
    await completer.future.timeout(const Duration(seconds: 12), onTimeout: () {});
  }

  Future<void> onSettingsChanged() async {
    if (_settings.offlineMode || _settings.hasStudioPass || _settings.adsRemoved) {
      _interstitial?.dispose();
      _interstitial = null;
      _rewarded?.dispose();
      _rewarded = null;
      notifyListeners();
      return;
    }
    if (!_initialized) {
      await initialize();
    } else {
      notifyListeners();
    }
  }

  BannerAd createBanner({
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
    AdSize size = AdSize.banner,
  }) {
    return BannerAd(
      adUnitId: _bannerUnit,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) {
          debugPrint('[Sotto] banner failed: ${error.message}');
          ad.dispose();
          onFailed();
        },
      ),
    );
  }

  void _preloadInterstitial() {
    if (!adsAllowed || _interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: _interstitialUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          debugPrint('[Sotto] interstitial failed: ${error.message}');
        },
      ),
    );
  }

  void _preloadRewarded() {
    if (!adsAllowed || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: _rewardedUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewarded = ad;
        },
        onAdFailedToLoad: (error) {
          _loadingRewarded = false;
          debugPrint('[Sotto] rewarded failed: ${error.message}');
        },
      ),
    );
  }

  /// Shows an interstitial after a heavy action, at most once every five
  /// minutes, and never on reading or playback surfaces.
  Future<void> maybeShowInterstitial() async {
    if (!adsAllowed) return;
    final now = DateTime.now();
    if (_lastInterstitial != null && now.difference(_lastInterstitial!).inMinutes < 5) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      _preloadInterstitial();
      return;
    }
    _interstitial = null;
    _lastInterstitial = now;
    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete();
        _preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete();
        _preloadInterstitial();
      },
    );
    await ad.show();
    await completer.future;
  }

  Future<bool> showRewardedForStudioPass() async {
    if (!adsAllowed) return false;
    var ad = _rewarded;
    if (ad == null) {
      final loaded = Completer<RewardedAd?>();
      RewardedAd.load(
        adUnitId: _rewardedUnit,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: loaded.complete,
          onAdFailedToLoad: (error) {
            debugPrint('[Sotto] rewarded failed: ${error.message}');
            loaded.complete(null);
          },
        ),
      );
      ad = await loaded.future;
    }
    if (ad == null) return false;
    _rewarded = null;
    var earned = false;
    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete(earned);
        _preloadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete(earned);
        _preloadRewarded();
      },
    );
    await ad.show(
      onUserEarnedReward: (ad, reward) {
        earned = true;
      },
    );
    return completer.future;
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _interstitial?.dispose();
    _rewarded?.dispose();
    super.dispose();
  }
}
