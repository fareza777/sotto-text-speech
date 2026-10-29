# Sotto — release checklist

Everything below is what remains before the build in `dist/` can go live.

## 1. Replace the ad IDs (required)

Google test IDs ship on purpose. Using them in production is invalid traffic.

- `lib/ads/ad_config.dart` — banner, interstitial, rewarded unit IDs
- `android/app/src/main/AndroidManifest.xml` — `com.google.android.gms.ads.APPLICATION_ID`

After replacing them, update the Data Safety form and `PRIVACY.md` if your
AdMob configuration differs from the defaults described there.

## 1b. Remove-ads product (Play Billing)

1. Play Console → Monetize → Products → In-app products → Create.
2. Product ID: `sotto_remove_ads` (must match `PurchaseController.removeAdsId`).
3. Type: one-time product. Price: **US$4.99** (Play converts to local prices).
4. Upload the AAB to internal testing, add your account as a license tester, then
   verify purchase, entitlement persistence, and "Restore purchases".
5. The button label uses the localized store price once the product loads; the
   `$4.99` fallback only shows when the product is unavailable.

## 2. Privacy policy and support contact

- Host `PRIVACY.md` at a public HTTPS URL.
- Replace `REPLACE_WITH_YOUR_SUPPORT_EMAIL` in `PRIVACY.md` and in the Play
  listing with a monitored address.
- Add the URL to the Play Console listing and the Data Safety form.

## 3. Play Console setup

| Field | Value |
|---|---|
| App name | Sotto |
| Package | `com.sottovoice.sotto` |
| Category | Books & Reference (or Tools) |
| Content rating | Everyone / PEGI 3 |
| Target audience | 13+ (not child-directed) |
| Ads | Yes, contains ads |
| Data safety | No account data, no analytics; ads collect device/ad identifiers |
| Foreground service | Media playback — declare in the console |
| Permissions | Internet, network state, notifications, wake lock, FGS media |
| Privacy policy | Required URL |
| App access | No login required |

Current delivery is APK-only (sideload). If you publish to Play later, build
`flutter build appbundle --release` and upload the `.aab`; Play re-signs with
the app signing key you register.

## 4. Signing material

- Upload keystore: `android/keystore/sotto-release.jks` (alias `sotto`).
- Passwords: `android/key.properties`.
- **Back both up offline.** Losing them means you cannot ship updates under the
  same listing.
- Both files are git-ignored. Never commit them.
- Consider Play App Signing: upload key = this keystore, app signing key = Google.

## 5. Verified before packaging

- [x] Target SDK 36, min SDK 24
- [x] 16 KB ELF alignment on every native library (`0x4000` or larger)
- [x] 16 KB ZIP alignment (`zipalign -c -P 16`)
- [x] Release APK signed (`apksigner verify`: CN=Sotto)
- [x] Bundled Nano model + voices present in the AAB
- [x] R8 mapping file retained (`build/app/outputs/mapping/release/mapping.txt`)
- [x] No analytics endpoint, no telemetry client
- [x] Offline Mode tested on device
- [x] Batch, readers, MP3, background playback tested on device

## 6. Still to do

- [x] Smoke-test the **release** APK on a physical phone (found and fixed an R8
      WorkManager crash; Studio, MP3, PDF, narration, background all pass).
- [ ] Replace ad IDs.
- [ ] Host the privacy policy and set the support email.
- [ ] Play Console data safety, content rating, ads declaration.
- [ ] Store listing: title, short description, full description, screenshots
      (8 phone screenshots), feature graphic 1024×500, icon 512×512.
- [ ] Test on at least one other Android version (API 24–32) and one other OEM.

## 7. Versioning

`pubspec.yaml` → `version: 1.0.0+1` maps to versionName 1.0.0 / versionCode 1.
Bump the build number for every Play upload.
