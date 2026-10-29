# Sotto — name, ASO, and hook pack

Prepared 30 October 2026 for the Google Play listing.

## 1. Name

**Keep “Sotto”. Use the keyword title below.**

Why: the brand is already baked into the icon, typography, voice copy and the
“Made for ears, not servers” line. “Sotto” is short, premium, pronounceable in
English and Indonesian, and not another “TTS Reader” clone. Its weakness is
search — nobody types “sotto” — and the Play title solves that by pairing the
brand with the highest-intent query.

Do not rename to a generic keyword app (“Offline Text to Speech Reader”): it
wins a little search early and loses all brand equity, icon recognition and
word-of-mouth.

If a rebrand is ever required, the only two worth considering are **Inkvoice**
(ink + voice, distinctive, 8 letters) and **Narra** (narrate, warm). Both need a
USPTO/Play name search first; several “Narra” products already exist.

Trademark check before publishing: search “Sotto” in USPTO TESS, EUIPO and Play.
A restaurant/POS product with the same name is the realistic conflict to rule out.

## 2. Store listing

### App title — 30 characters max

**Primary (29):**
```
Sotto: Offline Text to Speech
```

Alternates:
```
Sotto: Read Aloud, Offline        (25)
Sotto: AI Voice Book Reader       (27)
```

### Short description — 80 characters max

**Primary (78):**
```
Natural offline text to speech. Read PDFs, EPUBs and articles aloud. No cloud.
```

Alternate (75):
```
8 natural AI voices, offline TTS, PDF/EPUB reader, MP3 export. Private.
```

### Full description — 4,000 characters max

```
Studio voice. Zero cloud.

Sotto reads your books, PDFs and articles aloud with natural neural voices — entirely on your phone. No account. No upload. No internet needed after install.

EIGHT VOICES, YOUR PACE
Choose from eight English neural voices, audition each one, and set the pace that suits you. Playback speed changes instantly, without re-rendering the audio.

READ WHAT YOU ACTUALLY READ
• PDF — text-based PDFs, with chapter detection
• EPUB — chapters, metadata and cover art
• TXT — plain text, scripts and notes
• Articles — paste a link once; Sotto keeps the text offline

LISTEN YOUR WAY
• Sentence and word highlighting, karaoke-style
• Narration keeps playing when you leave the reader
• Bookmarks, playlists and a sleep timer with fade-out
• Export WAV or MP3, plus SRT subtitles for creators
• Turn any bookmark into a shareable audio clip
• Batch-convert a whole shelf of documents

BUILT FOR OFFLINE AND PRIVATE
Speech runs in ONNX Runtime on your device. Sotto has no servers, no analytics and no account. Offline Mode blocks every network request, including ads. Your documents and audio stay in app-private storage.

SMALL PHONES WELCOME
Nano INT8 ships inside the app and starts instantly. Micro and Mini download once, are checksum-verified, then run offline. Models unload when idle to save RAM and battery.

HONEST NOTES
• English voices only — no other language is validated yet
• PDF reading requires selectable text; scanned pages need OCR, which is not included
• Narration speed depends on your device; older phones may pause briefly between long passages

Free to download with a small banner on the home and library screens. Remove ads with a one-time purchase, or watch a rewarded ad for 24 hours ad-free.

Made for ears, not servers.
```

### What’s new — 1.0.0

```
First release: eight neural voices, an offline PDF/EPUB/TXT reader, word-level highlighting, background narration, WAV/MP3 export, SRT subtitles, shareable bookmark clips, batch conversion, a sleep timer, and a fully on-device engine.
```

### Category and tags

- Category: **Books & Reference**
- Tags: **Text to Speech**, **Audiobooks**, **Reading**
- Content rating: Everyone / PEGI 3 (no user-generated content, no violence)
- Ads: **Yes, contains ads** (banner, interstitial, rewarded)
- In-app purchases: **Yes** (Remove ads, US$4.99)
- App access: no login required
- Data safety: no account data, no analytics; ads collect device/ad identifiers;
  purchases handled by Google Play (purchase history)

## 3. Screenshot copy (render this text on the images)

1. **Studio voice. Zero cloud.** — Desk screen
2. **Eight neural voices, on device.** — Voice sheet
3. **Your PDFs, read aloud.** — Reader with PDF open
4. **Word-by-word karaoke.** — Reader with active word highlighted
5. **WAV, MP3 and subtitles.** — Player sheet with waveform
6. **Batch a whole shelf.** — Batch studio at 100%
7. **Keeps reading when you leave.** — Mini player over Library
8. **No account. No cloud.** — Privacy card / Offline Mode

Feature graphic (1024×500): ivory background, serif “S” mark, headline
**“Studio voice. Zero cloud.”**, and three chips: `Offline · 8 voices · PDF/EPUB`.

Icon: keep the current terracotta serif S on ivory — it reads at 48 px and is
distinct from the blue/purple cloud-TTS competitors.

## 4. Keyword bank

Play has no keyword field; Google reads the title, short description, long
description and your store listing experiments. Use these phrases naturally
(never stuffed, never in the title twice):

offline text to speech, text to speech offline, TTS reader, read aloud, read
books aloud, PDF to speech, PDF reader aloud, EPUB reader, article reader,
audiobook maker, text to MP3, neural voice, natural voice, AI voice reader,
narration, screen-free listening, offline reader, private TTS, no internet TTS,
speech synthesis, study tool, commute listening.

Avoid: “best”, “#1”, “free” without qualifier, competitor names, medical or
dyslexia claims (accessibility features are not certified), and non-English
language claims.

## 5. Hook pack

**Brand hook (store, icon, video end card):**
> Studio voice. Zero cloud.

**Listing hook (first line of the description):**
> Your books, read aloud — even in airplane mode.

**15–30 s short-video hook (first 3 seconds):**
> “This phone reads a 300-page PDF out loud — with airplane mode on.”
> Show airplane mode → import PDF → word karaoke → exported MP3.

**Paid-ad hook (Meta/TikTok):**
> No subscription. No cloud. Your PDFs, narrated on-device.

**Contrast hook (against cloud TTS competitors):**
> Most voice apps upload your books. Sotto never leaves airplane mode.

## 6. Launch checklist for the listing

- [ ] Title, short and long description pasted exactly
- [ ] 8 phone screenshots (1080×1920 or 1440×2560) with the copy above
- [ ] Feature graphic 1024×500, icon 512×512
- [ ] Privacy policy hosted; support email replaced
- [ ] Data safety + ads + IAP declarations
- [ ] Real AdMob IDs in `lib/ads/ad_config.dart` and the manifest
- [ ] `sotto_remove_ads` product created at US$4.99
- [ ] Internal-testing purchase + restore verified with a license tester
