# Third-party notices

Sotto bundles or links the following components. Full licence texts are shown
inside the app under **Settings → About → Open-source licences**.

## Models

**KittenTTS Nano / Micro / Mini v0.8** — Apache License 2.0.
Copyright KittenML. Source: <https://huggingface.co/KittenML>.
Nano INT8 ships inside the APK; Micro and Mini are downloaded on demand.
KittenTTS 2 (Stellon Labs Community License) is deliberately **not** used.

## Speech engine

**KittenTTS Flutter SDK 0.1.1** — Apache License 2.0, KittenML.
Vendored at `packages/kittentts` with these modifications:
- the analytics/telemetry client was deleted (all references removed);
- the default phonemizer was changed from the espeak-ng rule downloader to the
  bundled rule-based implementation; Sotto injects its own MIT phonemizer;
- the web asset and examples were removed;
- the MP3 encoder stub is replaced by Sotto's LAME FFI encoder.

**ONNX Runtime** — MIT License, Microsoft Corporation, via
`flutter_onnxruntime` (MIT, MASLAB-UM).

## Phonemization

**phonemize 1.0.0** — MIT License. Pure-Dart grapheme-to-phoneme engine.
Its English dictionary is derived from **CMUdict**, Copyright Carnegie Mellon
University, BSD-2-Clause.

**number_to_words_english 3.0.4** — MIT License.

## MP3 encoding

**LAME 3.100** — GNU Lesser General Public License, version 2.1.
Copyright the LAME project authors.
Sotto compiles LAME from the unmodified source in
`android/app/src/main/cpp/lame-3.100` into a separate shared library
(`libsotto_mp3.so`). It is dynamically linked and can be replaced by the user;
the complete corresponding source is included in this repository.
LAME is only used when you choose MP3 export.

## Documents and media

**pdfrx 2.4.8** — MIT License. **PDFium** — BSD-3-Clause, The Chromium Authors.
**archive**, **xml**, **html** — MIT / BSD-style licences.

**just_audio**, **audio_service**, **audio_session** — MIT License, Ryan Heise.
**flutter_onnxruntime** — MIT License.

## Ads

**Google Mobile Ads SDK** — governed by the Google APIs Terms of Service and the
Google Mobile Ads SDK policies. This build ships Google's sample/test ad unit
IDs; a publisher replacing them must also update this notice and the privacy
policy.

## UI

**Manrope** — Copyright 2019 The Manrope Project Authors, SIL Open Font
License 1.1.
**Instrument Serif** — Copyright 2022 The Instrument Serif Project Authors,
SIL Open Font License 1.1.

## Flutter and Dart

Flutter, the Flutter engine, and the Dart SDK — BSD-3-Clause, Google LLC.

## Everything else

All remaining Dart packages (provider, sqflite, shared_preferences, path,
path_provider, crypto, intl, http, file_picker, share_plus, wakelock_plus,
url_launcher, scrollable_positioned_list, flutter_launcher_icons) use
MIT, BSD, or Apache-2.0 licences. Their full texts are available through the
in-app licence page.
