import 'dart:io';
import 'dart:typed_data';

/// Minimal PNG encoder for PDFium's BGRA output, so PDF covers can be stored
/// without pulling in an image package.
Uint8List encodePngBgra(Uint8List bgra, int width, int height) {
  final raw = Uint8List((width * 4 + 1) * height);
  var offset = 0;
  for (var y = 0; y < height; y++) {
    raw[offset++] = 0;
    var i = y * width * 4;
    for (var x = 0; x < width; x++) {
      final b = bgra[i];
      final g = bgra[i + 1];
      final r = bgra[i + 2];
      final a = bgra[i + 3];
      raw[offset++] = r;
      raw[offset++] = g;
      raw[offset++] = b;
      raw[offset++] = a;
      i += 4;
    }
  }

  final compressed = ZLibEncoder().convert(raw);
  final out = BytesBuilder(copy: false);
  out.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  void chunk(String type, List<int> data) {
    out.add(_be32(data.length));
    final typeBytes = type.codeUnits;
    out.add(typeBytes);
    out.add(data);
    out.add(_be32(_crc32(typeBytes, data)));
  }

  chunk('IHDR', [
    ..._be32(width),
    ..._be32(height),
    8,
    6,
    0,
    0,
    0,
  ]);
  chunk('IDAT', compressed);
  chunk('IEND', const []);
  return out.takeBytes();
}

List<int> _be32(int value) => [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> type, List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final byte in type) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  for (final byte in data) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
