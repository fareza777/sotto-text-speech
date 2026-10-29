# Sotto — licence, security, and Play policy audit

Audited 28 October 2026 against the code in this repository.

## 1. Licence audit

| Component | Version | Licence | How it is used | Obligations | Verdict |
|---|---|---|---|---|---|
| KittenTTS Nano INT8 | v0.8 | Apache-2.0 | Bundled ONNX model | Keep NOTICE, state changes | OK |
| KittenTTS Micro / Mini | v0.8 | Apache-2.0 | Optional download | Same | OK |
| KittenTTS Flutter SDK | 0.1.1 | Apache-2.0 | Vendored in `packages/kittentts` | Keep LICENSE/NOTICE, mark modifications | OK (modified) |
| phonemize | 1.0.0 | MIT | English G2P | Keep copyright notice | OK |
| CMUdict-derived dictionary | via phonemize | BSD-2-Clause | English pronunciations | Keep notice | OK |
| LAME | 3.100 | LGPL-2.1 | MP3 encoding, separate `.so` | Source + licence, dynamic linking, replaceable | OK with notices |
| ONNX Runtime | via flutter_onnxruntime | MIT | Inference | Notice | OK |
| pdfrx / PDFium | 2.4.8 / bundled | MIT / BSD-3 | PDF text extraction | Notices | OK |
| just_audio / audio_service | 0.10.6 / 0.18.19 | MIT | Playback, media notification | Notices | OK |
| google_mobile_ads | 9.2.0 | Google APIs ToS | Advertising | Ads policy + disclosure | OK with test IDs |
| Manrope / Instrument Serif | — | OFL-1.1 | UI typography | Keep OFL | OK |
| Flutter / Dart | 3.44.6 / 3.12.2 | BSD-3 | Framework | Notice | OK |

### Findings that changed the build

1. **KittenTTS 2 is not usable commercially without a paid licence.** Its weights
   are under the Stellon Labs Community License (free only below a revenue
   threshold). Sotto therefore uses only the v0.8 Nano/Micro/Mini weights, which
   are Apache-2.0.
2. **The upstream Flutter SDK downloads espeak-ng rule files at runtime.**
   `dictsource/en_rules` and `en_list` are part of espeak-ng, which is GPLv3.
   Shipping or fetching them inside a closed-source app is a licence risk.
   Sotto removes that path and injects its own phonemizer built on `phonemize`
   (MIT) with a CMU-derived dictionary (BSD-2-Clause). No espeak-ng code or data
   is present.
3. **The upstream SDK ships an analytics client enabled by default**, posting to
   `https://kittenmlanalytics.com/v1/track` with a persistent anonymous ID. This
   contradicts the product's privacy promise and Play's Data Safety
   declarations. The entire `lib/src/analytics` directory and all call sites were
   deleted from the vendored copy. The endpoint string does not exist in the
   final binary.
4. **MP3 export was a stub** that threw `UnsupportedError`. Sotto compiles LAME
   3.100 from unmodified source into `libsotto_mp3.so` and links it dynamically
   through Dart FFI. LGPL-2.1 compliance: the library is a separate shared
   object, the complete corresponding source is included at
   `android/app/src/main/cpp/lame-3.100`, and the licence is shown in-app.
5. **The phonemizer C++ is original Apache-2.0 work**, not derived from espeak's
   GPL source (confirmed in the source header). It is no longer used by Sotto,
   but remains in the vendored SDK for API compatibility.

## 2. Security audit

| Area | Finding | Status |
|---|---|---|
| Telemetry | Upstream analytics removed, no endpoint or ID file remains | Fixed |
| Cleartext traffic | `android:usesCleartextTraffic="false"` | Fixed |
| Model integrity | Every downloaded model and the bundled model are checked with a hard-coded SHA-256 before use | Fixed |
| File handling | Imports are copied into app-private storage; 80 MB cap; parsers never execute content | OK |
| HTML parsing | `package:html` is a pure parser; scripts are stripped, never executed; no WebView in app code | OK |
| Backups | `allowBackup="false"`, `fullBackupContent="false"` | Fixed |
| Permissions | Only INTERNET, network state, foreground media, notifications, wake lock. No storage, camera, contacts, location | OK |
| Exported components | Only the launcher activity, the media browser service, and the media button receiver (all required by `audio_service`) | Reviewed |
| Ads isolation | Ads are skipped in Offline Mode and with a Studio Pass; ad surfaces never overlap reading or playback | Fixed |
| Secrets | No API keys, tokens, or signing material in the repository. `android/key.properties` is git-ignored | OK |
| Input validation | URLs restricted to http/https with timeouts; document size/type checks; empty-text guards | OK |
| Dependency provenance | All Dart packages resolve from pub.dev; the vendored SDK is pinned in-repo and diffable | OK |

### Residual risks

- **AdMob test IDs are shipped.** This is intentional: publishing with someone
  else's real unit IDs would be invalid traffic. Replace them before release.
- **LAME is LGPL.** Compliant as configured, but removing the MP3 feature would
  simplify the licence surface if that matters more than the feature.
- **Article fetch is SSRF-free by design** (the app is the client, no server),
  but it will happily download very large pages; the 25-second timeout and text
  scoring limit the impact.
- **Model downloads from Hugging Face** are integrity-checked but not
  signature-checked; a compromised HF account could serve a different file, and
  the hash check would reject it.

## 3. Google Play policy checklist

| Requirement | Status |
|---|---|
| Target SDK 36 (2026 requirement) | Set |
| 16 KB page size for native libraries | NDK r28 used; see verification log |
| Android App Bundle for production | Build command documented |
| Data Safety form | Guidance in `PRIVACY.md`; ads must be declared when enabled |
| Ads policy (no disruptive ads, no ads on reading surfaces) | Enforced in layout |
| Families policy | App is not child-directed; content rating to be set accordingly |
| Foreground service type declared | `mediaPlayback` |
| POST_NOTIFICATIONS runtime request | Requested by `audio_service` / ads SDK flow; verify on device |
| Privacy policy URL | `PRIVACY.md` must be hosted; support email must be replaced |
| Account deletion | No accounts exist |
| Permissions justified | See table above |
| No impersonation, no misleading claims | English-only claim is accurate; no “AI voice cloning” claims |
| Ads SDK consent (EEA/UK) | UMP consent flow implemented before ads initialise |

## 4. Verification log

Verified on a Redmi Note 11 (Android 13, arm64, 5.7 GB RAM). Full details and
screenshots: `QA_REPORT.md` and `qa/`.

- [x] App installs and launches on physical hardware
- [x] Bundled Nano model loads without network
- [x] Speech generates non-silent audio (RMS 0.08, peak 0.6, 24 kHz)
- [x] Word timings drive highlighting (verified in the reader)
- [x] WAV and MP3 exports are valid and playable (files pulled and parsed)
- [x] PDF/EPUB/TXT import works
- [x] Narration continues across chunks and in the background
- [x] Media notification and foreground service appear for playback
- [x] No analytics endpoint or client exists in the source
- [x] Offline Mode removes every ad surface
- [x] Model download verifies SHA-256 before use (Micro installed)
- [x] `libsotto_mp3.so` and `libkittentts_cephonemizer.so` are 16 KB aligned
- [x] Release APKs build and are signed (`apksigner verify`, CN=Sotto)

The release APK was installed on the Redmi Note 11 and smoke-tested end to end
(Studio TTS, MP3 export, PDF import, narration/highlighting, background media
notification). That test caught a release-only R8 crash in WorkManager/Room,
now fixed with keep rules.

Not verified: other Android versions (24-32), other OEM skins, tablets,
foldables, and Play Console upload itself.
