import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the notices that are not provided by pub packages to Flutter's
/// licence registry, so Settings → Open-source licences shows them alongside
/// everything else.
Future<void> registerThirdPartyLicenses() async {
  final apache = await rootBundle.loadString('assets/licenses/Apache-2.0.txt');
  final lgpl = await rootBundle.loadString('assets/licenses/LGPL-2.1.txt');
  final cmu = await rootBundle.loadString('assets/licenses/CMUdict-BSD.txt');

  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const ['KittenTTS models (Nano, Micro, Mini)'], apache);
    yield LicenseEntryWithLineBreaks(
      const ['KittenTTS Flutter SDK (vendored, modified)'],
      apache,
    );
    yield LicenseEntryWithLineBreaks(const ['LAME MP3 encoder'], lgpl);
    yield LicenseEntryWithLineBreaks(
      const ['CMU Pronouncing Dictionary (via phonemize)'],
      cmu,
    );
  });
}
