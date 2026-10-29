import 'package:kittentts/kittentts.dart';
import 'package:number_to_words_english/number_to_words_english.dart';
import 'package:phonemize/phonemize.dart' as g2p;

/// English G2P for Sotto.
///
/// The upstream KittenTTS Flutter SDK downloads espeak-ng rule files at runtime.
/// Those files are GPLv3, which cannot ship inside a closed-source Play Store
/// app. This implementation uses the MIT-licensed `phonemize` package instead:
/// a CMUdict-backed dictionary plus letter-to-sound rules for out-of-vocabulary
/// words, running fully offline with no downloaded data.
///
/// KittenTTS was trained on espeak-ng IPA, which places the stress mark directly
/// before the vowel nucleus (`həlˈoʊ`). `phonemize` places it before the
/// syllable onset (`həˈloʊ`). [_repositionStress] rewrites the mark to match the
/// training convention, which keeps prosody closer to the model's expectation.
class EnglishPhonemizer implements KittenPhonemizerProtocol {
  EnglishPhonemizer();

  @override
  Future<void> downloadIfNeeded(
    String storageDirectory, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(1);
  }

  @override
  Future<String> phonemize(String text) async {
    final ipa = g2p.phonemize(_expandNumbers(text), language: 'en-US');
    return _repositionStress(ipa);
  }

  @override
  Future<void> dispose() async {}
}

const _stressMarks = {'ˈ', 'ˌ'};
const _vowels = {
  'a', 'e', 'i', 'o', 'u', 'y', //
  'ɑ', 'ɐ', 'ɒ', 'æ', 'ɛ', 'ə', 'ɘ', 'ɚ', 'ɜ', 'ɝ', 'ɞ', 'ɨ', 'ɪ',
  'ɔ', 'œ', 'ɵ', 'ø', 'ʊ', 'ʌ', 'ɤ', 'ɯ', 'ᵻ',
};
const _wordBreakers = {' ', '\n', '\t', ',', '.', '!', '?', ';', ':', '—', '…', '"', '“', '”', '«', '»'};

/// Replaces digit runs with words before G2P. The bundled tokenizer expands
/// years defensively and repeats the century ("2026" -> "twenty twenty-six"
/// became "twenty twenty-six" with a duplicated "twenty"), so we take control
/// of number expansion here.
String _expandNumbers(String text) {
  return text.replaceAllMapped(RegExp(r'\d[\d,]*(?:\.\d+)?'), (match) {
    final raw = match.group(0)!.replaceAll(',', '');
    if (raw.contains('.')) {
      return NumberToWords.convertDecimal('en', raw).replaceAll('-', ' ');
    }
    final value = int.tryParse(raw);
    if (value == null) return match.group(0)!;
    return NumberToWords.convert('en', value).replaceAll('-', ' ');
  });
}

String _repositionStress(String ipa) {
  final chars = ipa.runes.map(String.fromCharCode).toList();
  for (var i = 0; i < chars.length; i++) {
    if (!_stressMarks.contains(chars[i])) continue;
    var j = i + 1;
    while (j < chars.length &&
        !_wordBreakers.contains(chars[j]) &&
        !_vowels.contains(chars[j]) &&
        !_stressMarks.contains(chars[j])) {
      j++;
    }
    if (j >= chars.length || !_vowels.contains(chars[j]) || j == i + 1) {
      continue;
    }
    final mark = chars.removeAt(i);
    chars.insert(j - 1, mark);
  }
  return chars.join();
}
