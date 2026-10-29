import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/audio_format.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs);

  final SharedPreferences _prefs;

  static const _kTheme = 'theme_mode';
  static const _kVoice = 'voice';
  static const _kSpeed = 'speed';
  static const _kModel = 'model';
  static const _kOffline = 'offline_mode';
  static const _kKeepAwake = 'keep_awake';
  static const _kReaderScale = 'reader_scale';
  static const _kStudioPass = 'studio_pass_until';
  static const _kOnboarded = 'onboarded';
  static const _kFormat = 'export_format';
  static const _kBitrate = 'mp3_bitrate';
  static const _kPlaybackSpeed = 'playback_speed';
  static const _kFocusMode = 'focus_mode';
  static const _kAdsRemoved = 'ads_removed';

  ThemeMode get themeMode {
    switch (_prefs.getString(_kTheme) ?? 'light') {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  set themeMode(ThemeMode mode) {
    _prefs.setString(_kTheme, switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    });
    notifyListeners();
  }

  String get voice => _prefs.getString(_kVoice) ?? 'bella';
  set voice(String value) {
    _prefs.setString(_kVoice, value);
    notifyListeners();
  }

  double get speed => (_prefs.getDouble(_kSpeed) ?? 1.0).clamp(0.5, 2.0);
  set speed(double value) {
    _prefs.setDouble(_kSpeed, value.clamp(0.5, 2.0));
    notifyListeners();
  }

  String get modelId => _prefs.getString(_kModel) ?? 'nano-int8';
  set modelId(String value) {
    _prefs.setString(_kModel, value);
    notifyListeners();
  }

  /// When true every ad SDK call is skipped and the app stays fully functional.
  bool get offlineMode => _prefs.getBool(_kOffline) ?? false;
  set offlineMode(bool value) {
    _prefs.setBool(_kOffline, value);
    notifyListeners();
  }

  bool get keepAwake => _prefs.getBool(_kKeepAwake) ?? false;
  set keepAwake(bool value) {
    _prefs.setBool(_kKeepAwake, value);
    notifyListeners();
  }

  double get readerScale => (_prefs.getDouble(_kReaderScale) ?? 1.0).clamp(0.8, 1.6);
  set readerScale(double value) {
    _prefs.setDouble(_kReaderScale, value.clamp(0.8, 1.6));
    notifyListeners();
  }

  AudioFormat get exportFormat => AudioFormat.fromName(_prefs.getString(_kFormat));
  set exportFormat(AudioFormat value) {
    _prefs.setString(_kFormat, value.name);
    notifyListeners();
  }

  int get mp3Bitrate => _prefs.getInt(_kBitrate) ?? 128;
  set mp3Bitrate(int value) {
    _prefs.setInt(_kBitrate, value.clamp(64, 160));
    notifyListeners();
  }

  double get playbackSpeed =>
      (_prefs.getDouble(_kPlaybackSpeed) ?? 1.0).clamp(0.75, 1.75);
  set playbackSpeed(double value) {
    _prefs.setDouble(_kPlaybackSpeed, value.clamp(0.75, 1.75));
    notifyListeners();
  }

  bool get focusMode => _prefs.getBool(_kFocusMode) ?? true;
  set focusMode(bool value) {
    _prefs.setBool(_kFocusMode, value);
    notifyListeners();
  }

  bool get adsRemoved => _prefs.getBool(_kAdsRemoved) ?? false;

  Future<void> setAdsRemoved(bool value) async {
    await _prefs.setBool(_kAdsRemoved, value);
    notifyListeners();
  }

  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;
  set onboarded(bool value) {
    _prefs.setBool(_kOnboarded, value);
    notifyListeners();
  }

  DateTime? get studioPassUntil {
    final raw = _prefs.getString(_kStudioPass);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  bool get hasStudioPass {
    final until = studioPassUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  Future<void> grantStudioPass(Duration duration) async {
    final now = DateTime.now();
    final current = studioPassUntil;
    final base = current != null && current.isAfter(now) ? current : now;
    await _prefs.setString(_kStudioPass, base.add(duration).toIso8601String());
    notifyListeners();
  }

  Future<void> clearStudioPass() async {
    await _prefs.remove(_kStudioPass);
    notifyListeners();
  }
}
