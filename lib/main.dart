import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ad_service.dart';
import 'app/app.dart';
import 'audio/audio_handler.dart';
import 'data/app_database.dart';
import 'features/import/document_importer.dart';
import 'legal/third_party_licenses.dart';
import 'state/library_controller.dart';
import 'state/narration_session.dart';
import 'state/purchase_controller.dart';
import 'state/player_controller.dart';
import 'state/settings_controller.dart';
import 'tts/model_repository.dart';
import 'tts/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await pdfrxFlutterInitialize();
  await registerThirdPartyLicenses();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(prefs);
  final database = await AppDatabase.open();
  final library = LibraryController(database, DocumentImporter(database));
  await library.refresh();

  SottoAudioHandler handler;
  try {
    handler = await AudioService.init(
      builder: () => SottoAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.sottovoice.sotto.playback',
        androidNotificationChannelName: 'Sotto playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (error) {
    debugPrint('[Sotto] audio service unavailable: $error');
    handler = SottoAudioHandler();
  }

  final models = ModelRepository();
  final tts = TtsService(models);
  final player = PlayerController(handler);
  final narration = NarrationSession(
    tts: tts,
    handler: handler,
    settings: settings,
    library: library,
    player: player,
  );
  player.onBeforePlay = narration.stop;
  final ads = AdService(settings);
  final purchase = PurchaseController(settings);

  runApp(
    SottoApp(
      settings: settings,
      library: library,
      tts: tts,
      player: player,
      narration: narration,
      ads: ads,
      purchase: purchase,
      handler: handler,
      models: models,
      database: database,
    ),
  );

  Future<void>.delayed(const Duration(milliseconds: 1200), ads.initialize);
  Future<void>.delayed(const Duration(milliseconds: 1600), purchase.init);
}
