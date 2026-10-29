enum AudioFormat {
  wav,
  mp3;

  String get extension => name;
  String get label => this == AudioFormat.wav ? 'WAV' : 'MP3';

  static AudioFormat fromName(String? value) =>
      value == 'mp3' ? AudioFormat.mp3 : AudioFormat.wav;
}
