import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../ads/ad_service.dart';
import '../audio/audio_handler.dart';
import '../data/app_database.dart';
import '../state/library_controller.dart';
import '../state/narration_session.dart';
import '../state/purchase_controller.dart';
import '../state/player_controller.dart';
import '../state/settings_controller.dart';
import '../tts/model_repository.dart';
import '../tts/tts_service.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'shell.dart';
import 'theme.dart';

class SottoApp extends StatelessWidget {
  const SottoApp({
    super.key,
    required this.settings,
    required this.library,
    required this.tts,
    required this.player,
    required this.narration,
    required this.ads,
    required this.purchase,
    required this.handler,
    required this.models,
    required this.database,
  });

  final SettingsController settings;
  final LibraryController library;
  final TtsService tts;
  final PlayerController player;
  final NarrationSession narration;
  final AdService ads;
  final PurchaseController purchase;
  final SottoAudioHandler handler;
  final ModelRepository models;
  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(value: tts),
        ChangeNotifierProvider.value(value: player),
        ChangeNotifierProvider.value(value: narration),
        ChangeNotifierProvider.value(value: ads),
        ChangeNotifierProvider.value(value: purchase),
        Provider.value(value: handler),
        Provider.value(value: models),
        Provider.value(value: database),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Sotto',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: settings.themeMode,
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: isDark
                      ? Brightness.dark
                      : Brightness.light,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarDividerColor: Colors.transparent,
                  systemNavigationBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: settings.onboarded
                ? const SottoShell()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}
