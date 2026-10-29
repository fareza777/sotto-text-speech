import 'package:flutter/material.dart';

class VoiceSpec {
  const VoiceSpec({
    required this.id,
    required this.name,
    required this.gender,
    required this.tint,
    required this.sampleLine,
  });

  final String id;
  final String name;

  /// Derived from the model's voice embedding key (expr-voice-N-f/m).
  final String gender;
  final Color tint;
  final String sampleLine;

  String get initial => name.substring(0, 1);
}

const voiceCatalog = <VoiceSpec>[
  VoiceSpec(
    id: 'bella',
    name: 'Bella',
    gender: 'Female',
    tint: Color(0xFFB3542C),
    sampleLine: 'Some stories are better heard than read.',
  ),
  VoiceSpec(
    id: 'jasper',
    name: 'Jasper',
    gender: 'Male',
    tint: Color(0xFF4F5B48),
    sampleLine: 'Let me walk you through the quiet parts.',
  ),
  VoiceSpec(
    id: 'luna',
    name: 'Luna',
    gender: 'Female',
    tint: Color(0xFF5B5470),
    sampleLine: 'The evening light settled over the page.',
  ),
  VoiceSpec(
    id: 'bruno',
    name: 'Bruno',
    gender: 'Male',
    tint: Color(0xFF3F4A52),
    sampleLine: 'Chapter one. The house had been empty for years.',
  ),
  VoiceSpec(
    id: 'rosie',
    name: 'Rosie',
    gender: 'Female',
    tint: Color(0xFF9A4F58),
    sampleLine: 'Here is something worth slowing down for.',
  ),
  VoiceSpec(
    id: 'hugo',
    name: 'Hugo',
    gender: 'Male',
    tint: Color(0xFF6B5A3E),
    sampleLine: 'Read it once for the facts, twice for the feeling.',
  ),
  VoiceSpec(
    id: 'kiki',
    name: 'Kiki',
    gender: 'Female',
    tint: Color(0xFF7A6234),
    sampleLine: 'This is where the story starts to move.',
  ),
  VoiceSpec(
    id: 'leo',
    name: 'Leo',
    gender: 'Male',
    tint: Color(0xFF4C5063),
    sampleLine: 'Turn the page. I will keep reading.',
  ),
];

VoiceSpec voiceSpec(String id) =>
    voiceCatalog.firstWhere((v) => v.id == id, orElse: () => voiceCatalog.first);
