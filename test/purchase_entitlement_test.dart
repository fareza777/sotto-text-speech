import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotto/state/settings_controller.dart';

void main() {
  test('remove-ads entitlement survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = SettingsController(await SharedPreferences.getInstance());
    expect(first.adsRemoved, isFalse);

    await first.setAdsRemoved(true);

    final second = SettingsController(await SharedPreferences.getInstance());
    expect(second.adsRemoved, isTrue);

    await second.setAdsRemoved(false);
    final third = SettingsController(await SharedPreferences.getInstance());
    expect(third.adsRemoved, isFalse);
  });
}
