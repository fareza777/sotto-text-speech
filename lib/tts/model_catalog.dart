class ModelSpec {
  const ModelSpec({
    required this.id,
    required this.name,
    required this.tagline,
    required this.onnxFile,
    required this.onnxSha256,
    required this.onnxBytes,
    required this.voicesSha256,
    required this.voicesBytes,
    required this.repo,
    required this.bundled,
  });

  final String id;
  final String name;
  final String tagline;
  final String onnxFile;
  final String onnxSha256;
  final int onnxBytes;
  final String voicesSha256;
  final int voicesBytes;
  final String repo;
  final bool bundled;

  String get onnxUrl => 'https://huggingface.co/KittenML/$repo/resolve/main/$onnxFile';
  String get voicesUrl => 'https://huggingface.co/KittenML/$repo/resolve/main/voices.npz';
  int get downloadBytes => onnxBytes + voicesBytes;
  double get sizeMb => downloadBytes / (1024 * 1024);
}

const voicesFileName = 'voices.npz';

const modelCatalog = <ModelSpec>[
  ModelSpec(
    id: 'nano-int8',
    name: 'Nano',
    tagline: 'Fastest. Built for older phones.',
    onnxFile: 'kitten_tts_nano_v0_8.onnx',
    onnxSha256: 'f7b0afcbee92870b32b8e0276d855b954dc25470c9f051b376ac7eee537c76fc',
    onnxBytes: 24369971,
    voicesSha256: '8aa7cee235abb0739cb51e6559685f65a4dacd95568833d05699b1633f519b3f',
    voicesBytes: 3278902,
    repo: 'kitten-tts-nano-0.8-int8',
    bundled: true,
  ),
  ModelSpec(
    id: 'micro',
    name: 'Micro',
    tagline: 'Balanced warmth and speed.',
    onnxFile: 'kitten_tts_micro_v0_8.onnx',
    onnxSha256: '95481626fee1ba70ce683e69c534fc7cb38433c46ce42d3abbeafb4b9f1a4123',
    onnxBytes: 41384970,
    voicesSha256: '112710c1be8ad0e967c190fb0fd95cbe5848ec4791b93209f20b28b7da20dac1',
    voicesBytes: 3278902,
    repo: 'kitten-tts-micro-0.8',
    bundled: false,
  ),
  ModelSpec(
    id: 'mini',
    name: 'Mini',
    tagline: 'The most natural cadence.',
    onnxFile: 'kitten_tts_mini_v0_8.onnx',
    onnxSha256: '0f5bbae4fc4800c98dbc544a87ecfa79510de2fb8222db30d12e5bfe9177df91',
    onnxBytes: 78268016,
    voicesSha256: '40ad2638952b77b7b2f30127e2608e169fc69dd256b53bd8aaa3409a33193c42',
    voicesBytes: 3278902,
    repo: 'kitten-tts-mini-0.8',
    bundled: false,
  ),
];

ModelSpec modelSpec(String id) =>
    modelCatalog.firstWhere((m) => m.id == id, orElse: () => modelCatalog.first);
