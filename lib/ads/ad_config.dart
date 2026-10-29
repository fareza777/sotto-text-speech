/// AdMob identifiers.
///
/// These are Google's official **test** units. Before publishing, replace all
/// four values with the IDs from your AdMob account:
///   * `bannerUnit`       — AdMob → Apps → Ad units → Banner
///   * `interstitialUnit` — AdMob → Apps → Ad units → Interstitial
///   * `rewardedUnit`     — AdMob → Apps → Ad units → Rewarded
///   * the app ID in `android/app/src/main/AndroidManifest.xml`
///     (`com.google.android.gms.ads.APPLICATION_ID`)
///
/// Test units never earn revenue and are safe for QA. Shipping them as-is is
/// invalid traffic, so this is a hard release blocker.
class AdConfig {
  AdConfig._();

  static const bool usingTestIds = true;

  static const bannerUnit = 'ca-app-pub-3940256099942544/6300978111';
  static const interstitialUnit = 'ca-app-pub-3940256099942544/1033173712';
  static const rewardedUnit = 'ca-app-pub-3940256099942544/5224354917';

  /// Set in the manifest, listed here so the four IDs stay together.
  static const manifestAppId = 'ca-app-pub-3940256099942544~3347511713';
}
