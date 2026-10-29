import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:kittentts/kittentts.dart' show KittenTTSModelFiles;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'model_catalog.dart';

class ModelDownloadProgress {
  const ModelDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.label,
  });

  final int receivedBytes;
  final int totalBytes;
  final String label;

  double get fraction =>
      totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0, 1);
}

class ModelRepository {
  ModelRepository();

  Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'models'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> modelDir(String id) async {
    final dir = Directory(p.join((await _root()).path, id));
    await dir.create(recursive: true);
    return dir;
  }

  Future<String> _copyAsset(String asset, File target) async {
    final data = await rootBundle.load(asset);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final digest = sha256.convert(bytes).toString();
    await target.writeAsBytes(bytes, flush: true);
    return digest;
  }

  /// Materializes the bundled Nano INT8 model into app storage.
  Future<KittenTTSModelFiles> ensureBundled() async {
    final spec = modelSpec('nano-int8');
    final dir = await modelDir(spec.id);
    final onnx = File(p.join(dir.path, spec.onnxFile));
    final voices = File(p.join(dir.path, voicesFileName));

    if (!await onnx.exists() || await onnx.length() != spec.onnxBytes) {
      final temp = File('${onnx.path}.tmp');
      final digest = await _copyAsset(
        'assets/models/${spec.onnxFile}',
        temp,
      );
      if (digest != spec.onnxSha256) {
        await temp.delete();
        throw StateError('Bundled Nano model failed integrity check.');
      }
      await temp.rename(onnx.path);
    }
    if (!await voices.exists() || await voices.length() != spec.voicesBytes) {
      final temp = File('${voices.path}.tmp');
      final digest = await _copyAsset('assets/models/$voicesFileName', temp);
      if (digest != spec.voicesSha256) {
        await temp.delete();
        throw StateError('Bundled voice bank failed integrity check.');
      }
      await temp.rename(voices.path);
    }
    return KittenTTSModelFiles(onnxPath: onnx.path, voicesPath: voices.path);
  }

  Future<KittenTTSModelFiles> filesIfPresent(String id) async {
    final spec = modelSpec(id);
    if (spec.bundled) return ensureBundled();
    final dir = await modelDir(spec.id);
    final onnx = File(p.join(dir.path, spec.onnxFile));
    final voices = File(p.join(dir.path, voicesFileName));
    if (!await onnx.exists() || !await voices.exists()) {
      throw StateError('${spec.name} is not downloaded yet.');
    }
    return KittenTTSModelFiles(onnxPath: onnx.path, voicesPath: voices.path);
  }

  Future<bool> isInstalled(String id) async {
    final spec = modelSpec(id);
    if (spec.bundled) return true;
    final dir = await modelDir(spec.id);
    final onnx = File(p.join(dir.path, spec.onnxFile));
    final voices = File(p.join(dir.path, voicesFileName));
    return await onnx.exists() &&
        await voices.exists() &&
        await onnx.length() == spec.onnxBytes &&
        await voices.length() == spec.voicesBytes;
  }

  Future<void> delete(String id) async {
    final spec = modelSpec(id);
    if (spec.bundled) return;
    final dir = await modelDir(spec.id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<KittenTTSModelFiles> download(
    String id, {
    void Function(ModelDownloadProgress)? onProgress,
  }) async {
    final spec = modelSpec(id);
    final dir = await modelDir(id);
    final client = http.Client();
    try {
      await _downloadFile(
        client,
        spec.onnxUrl,
        File(p.join(dir.path, spec.onnxFile)),
        spec.onnxSha256,
        spec.onnxBytes,
        spec.name,
        onProgress,
        0,
        spec.downloadBytes,
      );
      await _downloadFile(
        client,
        spec.voicesUrl,
        File(p.join(dir.path, voicesFileName)),
        spec.voicesSha256,
        spec.voicesBytes,
        spec.name,
        onProgress,
        spec.onnxBytes,
        spec.downloadBytes,
      );
    } finally {
      client.close();
    }
    return KittenTTSModelFiles(
      onnxPath: p.join(dir.path, spec.onnxFile),
      voicesPath: p.join(dir.path, voicesFileName),
    );
  }

  Future<void> _downloadFile(
    http.Client client,
    String url,
    File target,
    String expectedSha,
    int expectedBytes,
    String label,
    void Function(ModelDownloadProgress)? onProgress,
    int baseBytes,
    int totalBytes,
  ) async {
    final temp = File('${target.path}.part');
    final request = http.Request('GET', Uri.parse(url));
    final response = await client.send(request);
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} while downloading $url');
    }
    final sink = temp.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(
          ModelDownloadProgress(
            receivedBytes: baseBytes + received,
            totalBytes: totalBytes,
            label: label,
          ),
        );
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    if (received != expectedBytes) {
      await temp.delete();
      throw StateError('$label download incomplete ($received bytes).');
    }
    final digest = await sha256.bind(temp.openRead()).first;
    if (digest.toString() != expectedSha) {
      await temp.delete();
      throw StateError('$label failed integrity verification.');
    }
    if (await target.exists()) await target.delete();
    await temp.rename(target.path);
  }

  Future<int> installedBytes() async {
    var total = 0;
    for (final spec in modelCatalog) {
      if (spec.bundled || !await isInstalled(spec.id)) continue;
      total += spec.downloadBytes;
    }
    return total;
  }
}
