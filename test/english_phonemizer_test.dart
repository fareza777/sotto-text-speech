import 'package:flutter_test/flutter_test.dart';
import 'package:sotto/tts/english_phonemizer.dart';

const _ipaSymbols =
    r'ɑɐɒæɓʙβɔɕçɗɖðʤəɘɚɛɜɝɞɟʄɡɠɢʛɦɧħɥʜɨɪʝɭɬɫɮʟɱɯɰŋɳɲɴøɵɸθœɶʘɹɺɾɻʀʁɽʂʃʈʧʉʊʋⱱʌɣɤʍχʎʏʑʐʒʔʡʕʢǀǁǂǃˈˌːˑʼʴʰʱʲʷˠˤ˞↓↑→↗↘’̩‘ᵻ';
const _punctuation = ';:,.!?¡¿—…"«»“” ';

void main() {
  final phonemizer = EnglishPhonemizer();
  // The model tokenizer also maps plain ASCII letters, which IPA uses for
  // several English phonemes (h, s, d, j, o in oʊ, a in aɪ).
  final vocabulary = {
    ..._ipaSymbols.runes,
    ..._punctuation.runes,
    ...'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'.runes,
  };

  test('produces IPA inside the KittenTTS symbol table', () async {
    const samples = [
      'Hello. This is Sotto, running entirely on your device.',
      'The quick brown fox jumps over the lazy dog.',
      'She sells sea shells by the seashore.',
      'Dr. Smith arrived at 7:30 PM with 42 pages of notes.',
      'Sotto reads PDF, EPUB, and plain text without an internet connection.',
      'Though the weather was thoroughly thought through, the plough remained unploughed.',
    ];
    for (final sample in samples) {
      final ipa = await phonemizer.phonemize(sample);
      expect(ipa.trim(), isNotEmpty, reason: sample);
      final unknown = ipa.runes.where((r) => !vocabulary.contains(r)).toSet();
      expect(unknown, isEmpty, reason: 'Unknown runes for: $sample');
    }
  });

  test('moves stress onto the vowel nucleus like the training data', () async {
    final ipa = await phonemizer.phonemize('Hello world');
    expect(ipa, contains('ˈ'));
    final stressIndex = ipa.indexOf('ˈ');
    final afterStress = ipa.substring(stressIndex + 1);
    expect(
      RegExp(r'^[ɑɐɒæɛəɘɚɜɝɞɨɪɔœɵøʊʌɤɯᵻaeiou]').hasMatch(afterStress),
      isTrue,
      reason: 'Stress must sit immediately before a vowel: $ipa',
    );
  });

  test('expands numbers and abbreviations', () async {
    final ipa = await phonemizer.phonemize('Chapter 12 begins at 9.');
    expect(ipa, isNot(contains('12')));
    expect(ipa, isNot(contains('9')));
  });
}
