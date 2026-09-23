import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_strings.dart';

/// Gestisce download automatico di MiniCPM-V-4.6 Q4_0 + mmproj (multimodale)
class ModelManager {
  static const String modelUrl =
      'https://huggingface.co/openbmb/MiniCPM-V-4.6-gguf/resolve/main/MiniCPM-V-4_6-Q4_0.gguf';
  static const String mmprojUrl =
      'https://huggingface.co/openbmb/MiniCPM-V-4.6-gguf/resolve/main/mmproj-model-f16.gguf';

  static const String modelFileName = 'MiniCPM-V-4_6-Q4_0.gguf';
  static const String mmprojFileName = 'mmproj-model-f16.gguf';

  // Size hint per progress UI (bytes) - usati se server non manda content-length
  static const int modelExpectedBytes = 501 * 1024 * 1024; // ~501 MB
  static const int mmprojExpectedBytes = 1130 * 1024 * 1024; // ~1.11 GB

  Future<Directory> _getModelDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'airplane_ai_models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> getModelPath() async {
    final dir = await _getModelDir();
    return p.join(dir.path, modelFileName);
  }

  Future<String> getMmprojPath() async {
    final dir = await _getModelDir();
    return p.join(dir.path, mmprojFileName);
  }

  Future<bool> isModelExists() async {
    final path = await getModelPath();
    final f = File(path);
    if (!await f.exists()) return false;
    // verifica dimensione > 400MB
    final len = await f.length();
    return len > 400 * 1024 * 1024;
  }

  Future<bool> isMmprojExists() async {
    final path = await getMmprojPath();
    final f = File(path);
    if (!await f.exists()) return false;
    final len = await f.length();
    return len > 1000 * 1024 * 1024; // ~1GB
  }

  Future<bool> isAllReady() async {
    return await isModelExists() && await isMmprojExists();
  }

  Future<void> deleteAll() async {
    for (final path in [await getModelPath(), await getMmprojPath()]) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
  }

  /// Download con resume (Range) + progress 0..1
  Future<void> _downloadFile({
    required String url,
    required String savePath,
    required void Function(double progress, int received, int total) onProgress,
  }) async {
    final file = File(savePath);
    int existing = 0;
    if (await file.exists()) {
      existing = await file.length();
    }

    final client = http.Client();
    try {
      final headers = <String, String>{};
      if (existing > 0) {
        headers['Range'] = 'bytes=$existing-';
      }

      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(headers);
      final response = await client.send(request);

      if (response.statusCode == 416) {
        // Già completo
        onProgress(1.0, existing, existing);
        return;
      }

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException(S.current.downloadFailed(response.statusCode));
      }

      int total = existing;
      final contentLength = response.contentLength ?? 0;
      if (contentLength > 0) {
        total = existing + contentLength;
      } else {
        // Se non abbiamo header, usa expected (per UI)
        if (savePath.endsWith(modelFileName)) {
          total = modelExpectedBytes;
        } else {
          total = mmprojExpectedBytes;
        }
        if (existing > total) total = existing;
      }

      // se 200 e file esiste parziale, dobbiamo sovrascrivere (server non supporta Range)
      // Per hf.co supporta Range, ma nel caso sovrascriviamo
      final sink = file.openWrite(mode: existing > 0 && response.statusCode == 206 ? FileMode.append : FileMode.write);
      // se 200 e avevamo dati, tronchiamo
      if (response.statusCode == 200 && existing > 0) {
        existing = 0;
      }

      int received = existing;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        final prog = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
        onProgress(prog, received, total);
      }
      await sink.flush();
      await sink.close();
    } finally {
      client.close();
    }
  }

  /// Scarica entrambi i file sequenzialmente.
  /// onProgress: progress totale 0..1, messaggio, progress modello, progress mmproj
  Future<void> downloadAll({
    required void Function(
      double totalProgress,
      String status,
      double modelProgress,
      double mmprojProgress,
    ) onProgress,
  }) async {
    final modelPath = await getModelPath();
    final mmprojPath = await getMmprojPath();

    double modelProg = await isModelExists() ? 1.0 : 0.0;
    double mmprojProg = await isMmprojExists() ? 1.0 : 0.0;

    // Se già completi, notifica
    if (modelProg == 1.0 && mmprojProg == 1.0) {
      onProgress(1.0, S.current.modelAlreadyDownloaded, 1.0, 1.0);
      return;
    }

    // Download modello principale
    if (modelProg < 1.0) {
      onProgress(0.0, S.current.downloadingModel, modelProg, mmprojProg);
      await _downloadFile(
        url: modelUrl,
        savePath: modelPath,
        onProgress: (p, rec, tot) {
          modelProg = p;
          final total = (modelProg + mmprojProg) / 2;
          final mbRec = (rec / (1024 * 1024)).toStringAsFixed(1);
          final mbTot = (tot / (1024 * 1024)).toStringAsFixed(1);
          onProgress(total, S.current.modelProgress(mbRec, mbTot), modelProg, mmprojProg);
        },
      );
    }

    // Download mmproj per visione
    if (mmprojProg < 1.0) {
      // ricalcola se mmproj esiste già parzialmente
      final f = File(mmprojPath);
      if (await f.exists() && await f.length() > 1000 * 1024 * 1024) {
        mmprojProg = 1.0;
      } else {
        onProgress(0.5, S.current.downloadingVision, modelProg, mmprojProg);
        await _downloadFile(
          url: mmprojUrl,
          savePath: mmprojPath,
          onProgress: (p, rec, tot) {
            mmprojProg = p;
            final total = (modelProg + mmprojProg) / 2;
            final mbRec = (rec / (1024 * 1024)).toStringAsFixed(1);
            final mbTot = (tot / (1024 * 1024)).toStringAsFixed(1);
            onProgress(total, S.current.visionProgress(mbRec, mbTot), modelProg, mmprojProg);
          },
        );
      }
    }

    onProgress(1.0, S.current.downloadComplete, 1.0, 1.0);
  }

  Future<Map<String, dynamic>> getStatus() async {
    final modelPath = await getModelPath();
    final mmprojPath = await getMmprojPath();
    final modelExists = await isModelExists();
    final mmprojExists = await isMmprojExists();
    int modelSize = 0, mmprojSize = 0;
    if (await File(modelPath).exists()) modelSize = await File(modelPath).length();
    if (await File(mmprojPath).exists()) mmprojSize = await File(mmprojPath).length();
    return {
      'modelPath': modelPath,
      'mmprojPath': mmprojPath,
      'modelExists': modelExists,
      'mmprojExists': mmprojExists,
      'modelSize': modelSize,
      'mmprojSize': mmprojSize,
      'ready': modelExists && mmprojExists,
    };
  }
}
