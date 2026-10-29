# Sotto — device QA report

Tested on real hardware, not an emulator.

## Device

| | |
|---|---|
| Model | Redmi Note 11 (2201117TY) |
| SoC | Qualcomm Snapdragon 680, 8 cores |
| RAM | 5.7 GB total |
| OS | Android 13 (SDK 33), MIUI |
| ABI | arm64-v8a |
| Display | 1080 × 2400, 440 dpi |
| Build tested on device | debug APK + release APK (arm64) |
| Release artifacts | Split APKs (arm64 / v7a / x86_64), signed, 16 KB-aligned, release smoke-tested |

## Engine benchmark (on-device integration test)

`flutter test integration_test/engine_test.dart -d 69f664ea`

| Metric | Result |
|---|---|
| Nano INT8 model load | 5.2 s (cold) |
| Synthesis | 13.1 s for 12.57 s of audio |
| Real-time factor | **1.05×** (synthesis ≈ playback speed) |
| Output | 24 kHz mono, RMS 0.079, peak 0.60 |
| Word timings | 18 for two sentences |
| WAV | 603,644 bytes (valid RIFF, 16-bit PCM) |
| MP3 | 202,368 bytes at 128 kbps (matches duration × 16 KB/s) |

The MP3 output was also pulled from the device and parsed frame-by-frame:
valid MPEG-2 Layer III, 24 kHz, mono, 128 kbps, 548 frames.

## Feature results

| Feature | Result | Evidence |
|---|---|---|
| First launch, splash, Desk | Pass | Screenshots 02, 18, 26 |
| Bundled Nano loads offline | Pass | "warm" state, audio generated |
| Speech synthesis | Pass | 10.5 s WAV, RMS 0.09, AudioTrack 24 kHz |
| Eight voices, audition UI | Pass | Voice sheet renders all eight |
| Speed control | Pass | 0.5–2.0× slider, applied at synthesis |
| WAV export | Pass | File pulled and parsed on host |
| MP3 export (LAME) | Pass | File pulled and parsed on host |
| Studio save + replay | Pass | Audio track in Library, mini player |
| Library audio playback | Pass | MP3 decoded by Android `c2.android.mp3.decoder` |
| TXT import + chapters | Pass | "The Lantern Keeper" reader |
| EPUB import + metadata | Pass | Title, author, chapter headings |
| PDF text extraction | Pass | 2-page PDF read into blocks |
| Word highlighting | Pass | Active word highlighted; persists through word gaps |
| Resume from bookmark | Pass | 90% bookmark resumes at the last paragraph, not the start |
| Release APK startup | Pass | R8 WorkManager crash found and fixed; release launches clean |
| Release TTS / MP3 / PDF / background | Pass | Re-tested on the release build after the R8 fix |
| Sentence highlighting | Pass | Warm background follows narration |
| Auto-advance across chunks | Pass | Log shows chunk 2 starting at t=0 |
| Background narration | Pass | AudioTrack continues after Home |
| Media notification + FGS | Pass | `isForeground=true`, transport notification, Pause action |
| Batch conversion | Pass | 2 documents → 2 MP3 files (1.0 + 1.1 MB) |
| Model download (Micro) | Pass | 41,384,970 + 3,278,902 bytes, SHA-256 verified, model loads |
| Offline Mode | Pass | Banner disappears from Desk and Library; Ads card updates |
| AdMob banner (test IDs) | Pass | Google test creative rendered on Desk |
| Privacy audit | Pass | No analytics client; no `kittenmlanalytics.com` in source |

## Bugs found and fixed during device testing

1. **Playback blocked the UI.** `just_audio`'s `play()` future completes when a
   track ends, and the audio handler awaited it. Studio stayed on
   "Synthesising…" for the entire playback, and narration could not prefetch.
   Fixed with `unawaited`.
2. **Crash when narration started.** `super.stop()` in the audio handler wrote to
   the playback-state subject while the event pipe was adding to it:
   `Bad state: You cannot add items while items are being added from addStream`.
   Removed the super call; the player's idle event updates state correctly.
3. **Cover tiles overflowed by 5.7 px** with long titles. Cover typography now
   scales with tile size and hides the title on small covers.
4. **Grey status-bar scrim** from the Android theme. Switched to edge-to-edge
   with an `AnnotatedRegion`, cream splash in both system themes.
5. **`file_picker` 13 broke the build** (Kotlin incremental cache close failure
   in its federated Android module). Replaced with Flutter's `file_selector`
   (SAF) — fewer dependencies, same UX.
6. **First passage took ~30 s** on a long PDF paragraph. The first narration
   chunk is now a single sentence, the engine warms as soon as the reader opens,
   and the transport shows a preparing spinner.
7. **Duplicate document title** in TXT files. The parser now consumes the title
   line instead of repeating it as body text.

## Known limitations (not fixed in v1)

- **Synthesis is roughly real-time on this SoC (RTF 1.05×).** Prefetch keeps
  playback seamless after the first passage, but the very first sentence takes
  ~10–15 s including model load. A flagship phone is several times faster.
- Narration stops when you leave the reader; exported audio keeps playing in the
  background through the media service.
- PDF support requires selectable text. Scanned pages need OCR, which is not
  bundled.
- English only. The model has no validated other-language behaviour.
- Ads ship with Google test unit IDs. Real IDs must be added before publishing.
- Only Android 13 / MIUI was tested. API 24–32, tablets, foldables, and other
  OEM skins are untested.
- The app installs as debug or release-signed APK; Play Console upload and the
  Data Safety form remain the publisher's responsibility.

## Reproduce

```bash
flutter test integration_test/engine_test.dart -d <device-id>
adb install -r dist/sotto-1.0.0-arm64-v8a.apk
```

The release APK was installed and smoke-tested on hardware: Studio TTS, MP3
export, PDF import, narration with sentence/word highlighting, and background
playback with the media notification all passed. Two release-only defects were
found and fixed in the process (R8 WorkManager crash, resume position).

Test fixtures live in `qa/` (TXT, EPUB, PDF) and were pushed to
`/sdcard/Download`.

## v1.1 update (29 October 2026)

### Verified on device

| Feature | Result | Evidence |
|---|---|---|
| Three-card onboarding | Pass | Screenshots 95–98 |
| Narration survives leaving the reader | Pass | Mini player shows the book + "Preparing…" on Desk and Library (101, 102) |
| Instant playback speed | Pass | 1.50x applied without regeneration (105) |
| Editorial drop caps | Pass | Large terracotta capitals at chapter openings (103) |
| Focus mode | Pass | Non-active passages dim while speaking (103) |
| Real PDF cover | Pass | Rendered first page shown as the book cover (109) |
| DB v1 to v2 migration | Pass | Existing library and 90% bookmark survived the update |
| Model + voice data intact | Pass | Micro model still installed after migration |

### Verified on the final build (29 Oct, 20:07–20:12)

| Feature | Result | Evidence |
|---|---|---|
| PDF cover title overlay | Pass | Gradient + title over the rendered page (112) |
| Softer focus dim (0.46) | Pass | Non-active passages readable but de-emphasised (113) |
| Narration across screens (final build) | Pass | Mini player with pause + "Preparing…" on Library (114) |
| Bookmark creation | Pass | Sheet lists the saved snippet (119) |
| Bookmark-to-clip export | Pass | "Clip saved to your library" + Share action (120) |
| Clip in library | Pass | Clip · The Lantern Keeper, 0:05, MP3 91 KB (121) |
| SRT sidecar | Pass | "Share subtitles (.srt)" appears in the track menu (122) |
| Sleep timer | Pass | 15-minute timer, chip shows "Sleep 14:59" (125) |
| Real waveform | Pass | Waveform follows the stored peaks of the clip (123) |
| Playback speed persistence | Pass | 1.50x survives navigation and relaunch |

### Fixed and re-checked on the final build

- The reader's overflow menu never showed "Create a clip from here"; the
  handler existed but the menu item was missing. Added and verified (126).
- Rendering a clip while narration was synthesising could run two ONNX
  inferences on one session. `TtsService` now serialises generation and
  streaming behind a lock; a clip created during narration completed without a
  crash (127).

### Desk density and system insets (29 Oct, 20:31)

| Change | Result | Evidence |
|---|---|---|
| Compact Desk | Greeting, privacy pill, continue card, quick bar, recent audio and ad slot fit on one screen without scrolling | 128, 131 |
| Quick action bar | Speak / Import / Read link as a single compact card | 128 |
| Recent audio cards | Smaller cards with a dedicated menu button and play affordance | 128–129 |
| Track menu | Safe-area applied; Delete sits fully above the Android navigation bar | 129 |
| Player sheet | Options button clears the navigation bar | 130 |

### Behaviour-level notes (no numeric assertion)

- Cached voice auditions: the second preview plays from a cached WAV.
- Narration chunks are 3 sentences / 240 characters; on this Snapdragon 680 the
  synthesis is roughly real-time, so long PDF paragraphs still show an
  occasional "Preparing…" between chunks.

### Deferred

- Playlist drag-reorder.
- Wi-Fi-only / pause-resume model downloads.
- OCR for scanned PDFs (ML Kit size and licensing).
- Remove-ads IAP (needs Play Console).

### Monetisation (29 Oct, 22:54)

| Item | Status |
|---|---|
| AdMob banner / interstitial / rewarded | Implemented and tested with Google test unit IDs |
| Real AdMob IDs | Not set — replace the four values listed in `lib/ads/ad_config.dart` |
| Remove ads (US$4.99) | Implemented via Play Billing, product ID `sotto_remove_ads`; UI verified on a sideloaded build (button disabled, "product not configured") |
| Entitlement persistence | Unit tested (`test/purchase_entitlement_test.dart`) |
| Purchase / restore on device | Not testable without the Play product and a license tester |

