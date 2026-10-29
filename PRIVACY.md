# Sotto Privacy Policy

**Last updated: 28 October 2026**

Sotto is an offline text-to-speech app. This policy describes exactly what the app
does with data, including the narrow cases where it uses the network.

> Publisher contact: `REPLACE_WITH_YOUR_SUPPORT_EMAIL` — this must be replaced
> with a monitored address before publishing to Google Play. Play also requires
> this policy to be hosted at a public HTTPS URL.

## The short version

- There is no account, no sign-in, and no cloud sync.
- Speech is generated on your device. Your text, documents, and audio are never
  uploaded to us.
- Sotto contains **no analytics, no crash reporting, and no telemetry**. The
  upstream SDK's analytics client was removed from the source.
- The app only uses the network in three situations: downloading a voice model
  you asked for, fetching an article link you pasted, and serving ads (unless you
  enable Offline Mode or hold a Studio Pass).

## What is processed on your device

| Data | Where it lives | Purpose |
|---|---|---|
| Text you type in Studio | Memory; saved only if you generate audio | Speech synthesis |
| Imported documents (PDF/EPUB/TXT) | App-private storage | Reading aloud |
| Extracted article text | App-private storage | Reading aloud |
| Generated audio (WAV/MP3) | App-private storage | Playback, export, sharing |
| Bookmarks, playlists, progress | Local database | Resume and organisation |
| Voice, speed, model, theme settings | Local preferences | App behaviour |

None of this leaves the device unless **you** explicitly share an exported audio
file using the system share sheet.

## Network activity

1. **Voice model downloads.** Sotto ships with the Nano INT8 model inside the
   app. Micro and Mini are optional downloads from Hugging Face
   (`huggingface.co/KittenML/...`) and are started only when you tap Download.
   Each file is verified against a SHA-256 hash baked into the app.
2. **Article import.** When you paste a link into "Read a link", Sotto requests
   that page once, extracts the readable text, stores it locally, and does not
   request it again. The request goes directly to the publisher's server; no
   proxy is involved.
3. **Advertising (Google AdMob).** Unless Offline Mode is enabled or a Studio
   Pass is active, the app loads banner, interstitial, and rewarded ads through
   the Google Mobile Ads SDK. Google may collect device identifiers (including
   the advertising ID), IP address, and ad interaction data as described in
   Google's own privacy policy: <https://policies.google.com/technologies/partner-sites>.
   Ads are never shown on reading screens, during narration, or during playback.
   Enabling **Settings → Privacy → Offline Mode** blocks every ad request.

Sotto has no servers of its own. There is no endpoint that receives your text,
audio, documents, or usage.

## Permissions

| Permission | Why |
|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE` | Optional model downloads, article import, ads |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Keep narration and exported audio playing with a media notification |
| `POST_NOTIFICATIONS` | Show the playback notification on Android 13+ |
| `WAKE_LOCK` | Keep playback alive while the screen is off |

Sotto does **not** request storage permissions. File imports use the Android
system file picker, and exports stay in app-private storage until you share them.

## Purchases

Remove Ads is a one-time in-app purchase processed entirely by Google Play.
Sotto never sees or stores payment details. After a successful purchase the app
stores a local "ads removed" flag and asks Google Play to restore it on future
installs. Purchase history is handled by Google under its own privacy policy.

## Data retention and deletion

All app data is stored in the app's private sandbox. You can delete individual
documents, audio files, bookmarks, and playlists inside the app. Uninstalling
Sotto removes every file and the database. Because there is no account and no
server copy, deletion is immediate and complete.

Android's automatic backup is disabled for Sotto (`allowBackup="false"`), so app
data is not copied to Google Drive.

## Children

Sotto is a general-audience reading tool and is not directed to children under
13. It does not knowingly collect personal information from anyone, including
children.

## Changes

If this policy changes, the "last updated" date above changes and the new text
ships in the next app release.

## Contact

`REPLACE_WITH_YOUR_SUPPORT_EMAIL`
