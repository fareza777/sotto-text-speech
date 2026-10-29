import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/ad_service.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../state/library_controller.dart';
import '../../state/purchase_controller.dart';
import '../../state/settings_controller.dart';
import '../../tts/model_catalog.dart';
import '../../tts/model_repository.dart';
import '../../tts/voice_catalog.dart';
import '../studio/model_sheet.dart';
import '../studio/voice_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final library = context.watch<LibraryController>();
    final ads = context.watch<AdService>();
    final purchase = context.watch<PurchaseController>();
    final tokens = SottoTokens.of(context);
    final voice = voiceSpec(settings.voice);
    final model = modelSpec(settings.modelId);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 4),
          Text(
            'Tuned for quiet, privacy, and long reads.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Appearance'),
          PaperCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.phone_android_rounded, size: 16),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (value) =>
                      settings.themeMode = value.first,
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(
                      Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sotto opens in light mode by design. Dark is one tap away.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Reading'),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.format_size_rounded, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Text size',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      '${(settings.readerScale * 100).round()}%',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                Slider(
                  value: settings.readerScale,
                  min: 0.8,
                  max: 1.6,
                  divisions: 8,
                  onChanged: (value) => settings.readerScale = value,
                ),
                const Divider(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.brightness_high_rounded,
                    size: 20,
                  ),
                  title: Text(
                    'Keep screen awake',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subtitle: Text(
                    'Only while narration is playing.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  value: settings.keepAwake,
                  onChanged: (value) => settings.keepAwake = value,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Voice and engine'),
          PaperCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: voice.tint,
                    child: Text(
                      voice.initial,
                      style: const TextStyle(
                        fontFamily: 'InstrumentSerif',
                        color: Colors.white,
                      ),
                    ),
                  ),
                  title: Text('Default voice'),
                  subtitle: Text('${voice.name} · ${voice.gender} · English'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showVoiceSheet(context),
                ),
                ListTile(
                  leading: const Icon(Icons.memory_rounded),
                  title: Text('${model.name} model'),
                  subtitle: Text(
                    '${model.sizeMb.toStringAsFixed(0)} MB · ${model.tagline}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showModelSheet(context),
                ),
                ListTile(
                  leading: const Icon(Icons.speed_rounded),
                  title: const Text('Voice pace (synthesis)'),
                  subtitle: Text(
                    '${settings.speed.toStringAsFixed(2)}× · baked into audio',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showPaceSheet(context, settings),
                ),
                ListTile(
                  leading: const Icon(Icons.play_circle_outline_rounded),
                  title: const Text('Playback speed'),
                  subtitle: Text(
                    '${settings.playbackSpeed.toStringAsFixed(2)}× · instant',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showPlaybackSpeedSheet(context, settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Privacy'),
          PaperCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tokens.olive.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: tokens.olive,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'On-device by default',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            'No account, no upload, no voice data.',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Offline Mode',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subtitle: Text(
                    'Turns off every ad request and network call except model downloads you start yourself.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  value: settings.offlineMode,
                  onChanged: (value) async {
                    settings.offlineMode = value;
                    await context.read<AdService>().onSettingsChanged();
                    if (value) await settings.clearStudioPass();
                  },
                ),
                TextButton.icon(
                  onPressed: () => _showPrivacyLedger(context),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('What leaves this device'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Ads'),
          PaperCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      settings.adsRemoved || settings.hasStudioPass
                          ? Icons.verified_rounded
                          : Icons.wb_sunny_outlined,
                      color: settings.adsRemoved || settings.hasStudioPass
                          ? tokens.olive
                          : tokens.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        settings.adsRemoved
                            ? 'Ads removed'
                            : settings.hasStudioPass
                            ? 'Studio Pass active'
                            : 'Free with light ads',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  settings.offlineMode
                      ? 'Offline Mode is on, so no ads are requested at all.'
                      : settings.adsRemoved
                      ? 'Thank you. No banners or interstitials, permanently.'
                      : settings.hasStudioPass
                      ? 'No banners or interstitials until ${_passLabel(settings)}.'
                      : 'A banner on the Desk and Library, and one interstitial after a batch render. Never while reading or listening.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (!settings.offlineMode && !settings.adsRemoved) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: purchase.productReady && !purchase.busy
                          ? purchase.buyRemoveAds
                          : null,
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: Text(
                        purchase.busy
                            ? 'Opening Google Play…'
                            : 'Remove ads · ${purchase.price}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    purchase.productReady
                        ? 'One-time purchase via Google Play. Restorable on this account.'
                        : purchase.available
                        ? 'The Play product is not configured yet (sotto_remove_ads).'
                        : 'Purchases are available in the Play Store build.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (!settings.hasStudioPass) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: ads.adsAllowed
                          ? () => _watchForPass(context, ads, settings)
                          : null,
                      icon: const Icon(
                        Icons.play_circle_outline_rounded,
                        size: 18,
                      ),
                      label: Text(
                        ads.adsAllowed
                            ? 'Watch an ad for 24h ad-free'
                            : 'Ad unavailable right now',
                      ),
                    ),
                  ],
                  if (purchase.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      purchase.error!,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: tokens.danger),
                    ),
                  ],
                  TextButton(
                    onPressed: purchase.available ? purchase.restore : null,
                    child: const Text('Restore purchases'),
                  ),
                ],
                if (settings.hasStudioPass && !settings.adsRemoved)
                  TextButton(
                    onPressed: () async {
                      await settings.clearStudioPass();
                      if (context.mounted) {
                        await context.read<AdService>().onSettingsChanged();
                      }
                    },
                    child: const Text('End Studio Pass early'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Storage'),
          PaperCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _StorageRow(
                  label: 'Generated audio',
                  value: formatBytes(library.audioBytes),
                  detail: '${library.tracks.length} files',
                ),
                const Divider(height: 18),
                FutureBuilder<int>(
                  future: context.read<ModelRepository>().installedBytes(),
                  builder: (context, snapshot) => _StorageRow(
                    label: 'Downloaded models',
                    value: formatBytes(snapshot.data ?? 0),
                    detail: 'Nano is built in',
                  ),
                ),
                const Divider(height: 18),
                _StorageRow(
                  label: 'Library documents',
                  value: '${library.docs.length}',
                  detail: library.docs.isEmpty ? 'None yet' : 'Stored locally',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('About'),
          PaperCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About Sotto'),
                  subtitle: const Text(
                    'Version 1.0.0 · offline neural narration',
                  ),
                  onTap: () => _showAbout(context),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Open-source licences'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Sotto',
                    applicationVersion: '1.0.0',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.gavel_rounded),
                  title: const Text('Third-party notices'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showNotices(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                const SottoWordmark(fontSize: 24),
                const SizedBox(height: 6),
                Text(
                  'Made for ears, not servers.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _passLabel(SettingsController settings) {
    final until = settings.studioPassUntil;
    if (until == null) return 'later';
    final local = until.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _watchForPass(
    BuildContext context,
    AdService ads,
    SettingsController settings,
  ) async {
    final earned = await ads.showRewardedForStudioPass();
    if (!context.mounted) return;
    if (earned) {
      await settings.grantStudioPass(const Duration(hours: 24));
      await ads.onSettingsChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Studio Pass active for 24 hours.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No reward this time. Try again when online.'),
        ),
      );
    }
  }

  Future<void> _showPaceSheet(
    BuildContext context,
    SettingsController settings,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Default pace',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              StatefulBuilder(
                builder: (context, setSheetState) => Column(
                  children: [
                    Text(
                      '${settings.speed.toStringAsFixed(2)}×',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    Slider(
                      value: settings.speed,
                      min: 0.5,
                      max: 2.0,
                      divisions: 30,
                      onChanged: (value) {
                        settings.speed = value;
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPlaybackSpeedSheet(
    BuildContext context,
    SettingsController settings,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Playback speed',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Changes audio immediately, without re-synthesising.',
                style: Theme.of(sheetContext).textTheme.labelSmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in [0.75, 0.9, 1.0, 1.15, 1.3, 1.5, 1.75])
                    ChoiceChip(
                      label: Text('${value.toStringAsFixed(2)}×'),
                      selected: (settings.playbackSpeed - value).abs() < 0.01,
                      onSelected: (_) {
                        settings.playbackSpeed = value;
                        Navigator.pop(sheetContext);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPrivacyLedger(BuildContext context) async {
    final tokens = SottoTokens.of(context);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.82,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          children: [
            Text(
              'Privacy ledger',
              style: Theme.of(sheetContext).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'A plain-language inventory of every network path in Sotto.',
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            _LedgerRow(
              icon: Icons.cloud_off_rounded,
              title: 'Speech synthesis',
              body:
                  'Runs in ONNX Runtime on this device. No text, audio, or voice samples are uploaded. Ever.',
            ),
            _LedgerRow(
              icon: Icons.analytics_outlined,
              title: 'Telemetry',
              body:
                  'The upstream SDK shipped an analytics client. It has been removed from this build: zero analytics code, zero analytics endpoints.',
            ),
            _LedgerRow(
              icon: Icons.download_rounded,
              title: 'Model downloads',
              body:
                  'Only when you tap Download for Micro or Mini. Files come from Hugging Face, then are checked against a SHA-256 hash baked into the app.',
            ),
            _LedgerRow(
              icon: Icons.link_rounded,
              title: 'Article import',
              body:
                  'Only when you paste a link. Sotto requests that page once, keeps the readable text locally, and never fetches it again.',
            ),
            _LedgerRow(
              icon: Icons.campaign_outlined,
              title: 'Ads',
              body:
                  'Play-services-ads requests banner, interstitial, or rewarded inventory. Offline Mode blocks every request. Readers and the player never show ads.',
            ),
            _LedgerRow(
              icon: Icons.person_off_outlined,
              title: 'Accounts',
              body: 'None. There is no sign-in, no cloud sync, and no profile.',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tokens.accentWash,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'If you want a build with zero network capability, enable Offline Mode and use Nano. After install, Sotto will read forever without a connection.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAbout(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sotto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Studio-grade narration, entirely offline.'),
            SizedBox(height: 12),
            Text('Voices: KittenTTS Nano, Micro, and Mini (Apache-2.0).'),
            SizedBox(height: 6),
            Text(
              'Phonemizer: phonemize (MIT) with a CMU-derived English dictionary.',
            ),
            SizedBox(height: 6),
            Text('PDF text engine: pdfrx / PDFium (MIT / BSD).'),
            SizedBox(height: 6),
            Text(
              'Ad unit IDs in this build are Google test units. Replace them with your own AdMob units before publishing.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotices(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Third-party notices'),
        content: const SingleChildScrollView(
          child: Text(
            'KittenTTS models — Apache License 2.0, KittenML.\n\n'
            'KittenTTS Flutter SDK — Apache License 2.0, KittenML. Modified: analytics removed, '
            'bundled phonemizer disabled, MP3 encoder added.\n\n'
            'phonemize — MIT License. English dictionary derived from CMUdict (BSD-2-Clause).\n\n'
            'flutter_onnxruntime / ONNX Runtime — MIT License, Microsoft.\n\n'
            'pdfrx / PDFium — MIT License / BSD-3-Clause.\n\n'
            'Manrope and Instrument Serif — SIL Open Font License 1.1.\n\n'
            'Audio playback: just_audio and audio_service — MIT License.\n\n'
            'Ads: Google Mobile Ads SDK — Google APIs Terms of Service.\n\n'
            'The full licence texts are available in Settings → Open-source licences.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              Text(detail, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = SottoTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: tokens.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
