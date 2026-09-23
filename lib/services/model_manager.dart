import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import 'app_settings.dart';

/// Due modelli, scelti dalla lingua prima del download.
/// Italiano: Dante 2B, solo testo. Inglese e cinese: MiniCPM-V 4.6 + mmproj.
class ModelManager {
  static const String danteUrl =
      'https://www.dropbox.com/scl/fi/pvda2zh4831rwlavs6mhy/dante-2b-ita-instruct-Q4_K_M.gguf?rlkey=t1dij8u00r33pzd3gur0s9moq&st=av5hzlnq&dl=1';
  static const String danteFileName = 'dante-2b-ita-instruct-Q4_K_M.gguf';
  // Dimensione reale del file su Dropbox (settembre 2026).
  static const int danteExpectedBytes = 1289746592;
  static const int danteMinBytes = danteExpectedBytes - 4 * 1024 * 1024;

  static const String minicpmUrl =
      'https://huggingface.co/openbmb/MiniCPM-V-4.6-gguf/resolve/main/MiniCPM-V-4_6-Q4_0.gguf';
  static const String mmprojUrl =
      'https://huggingface.co/openbmb/MiniCPM-V-4.6-gguf/resolve/main/mmproj-model-f16.gguf';

  static const String minicpmFileName = 'MiniCPM-V-4_6-Q4_0.gguf';
  static const String mmprojFileName = 'mmproj-model-f16.gguf';

  static const int minicpmExpectedBytes = 501 * 1024 * 1024;
  static const int mmprojExpectedBytes = 1130 * 1024 * 1024;
  static const int minicpmMinBytes = 400 * 1024 * 1024;
  static const int mmprojMinBytes = 1000 * 1024 * 1024;

  /// Italiano usa Dante. Inglese e cinese usano MiniCPM-V, che ha la visione.
  bool get usesVision => AppSettings.instance.language != AppLanguage.it;

  int get contextSize => usesVision ? 4096 : 2048;

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
    final name = usesVision ? minicpmFileName : danteFileName;
    return p.join(dir.path, name);
  }

  Future<String> getMmprojPath() async {
    final dir = await _getModelDir();
    return p.join(dir.path, mmprojFileName);
  }

  Future<bool> _isFileReady(String path, int minBytes) async {
    final f = File(path);
    if (!await f.exists()) return false;
    return await f.length() >= minBytes;
  }

  Future<bool> isModelExists() async {
    final minBytes = usesVision ? minicpmMinBytes : danteMinBytes;
    return _isFileReady(await getModelPath(), minBytes);
  }

  Future<bool> isMmprojExists() async {
    return _isFileReady(await getMmprojPath(), mmprojMinBytes);
  }

  /// Pronto per la lingua attiva: Dante da solo, oppure MiniCPM-V più mmproj.
  Future<bool> isAllReady() async {
    if (!await isModelExists()) return false;
    if (!usesVision) return true;
    return isMmprojExists();
  }

  /// Cancella solo i file della lingua attiva. L'altro modello, se c'è, resta.
  Future<void> deleteAll() async {
    final model = File(await getModelPath());
    if (await model.exists()) await model.delete();
    if (!usesVision) return;
    final mmproj = File(await getMmprojPath());
    if (await mmproj.exists()) await mmproj.delete();
  }

  /// Download con resume (Range) + progress 0..1.
  /// [minBytes] scarta una pagina HTML di errore salvata al posto del GGUF.
  Future<void> _downloadFile({
    required String url,
    required String savePath,
    required int expectedBytes,
    required int minBytes,
    required void Function(double progress, int received, int total) onProgress,
  }) async {
    final file = File(savePath);
    int existing = 0;
    if (await file.exists()) {
      existing = await file.length();
    }

    final client = http.Client();
    try {
      final headers = <String, String>{
        'User-Agent': 'AirplaneAI/1.0',
      };
      if (existing > 0) {
        headers['Range'] = 'bytes=$existing-';
      }

      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(headers);
      final response = await client.send(request);

      if (response.statusCode == 416) {
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
        total = expectedBytes;
        if (existing > total) total = existing;
      }

      final append = existing > 0 && response.statusCode == 206;
      if (response.statusCode == 200 && existing > 0) {
        existing = 0;
      }

      final sink = file.openWrite(mode: append ? FileMode.append : FileMode.write);
      int received = existing;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        final prog = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
        onProgress(prog, received, total);
      }
      await sink.flush();
      await sink.close();

      final saved = await file.length();
      if (saved < minBytes) {
        await file.delete();
        throw HttpException(S.current.downloadFailed(response.statusCode));
      }
    } finally {
      client.close();
    }
  }

  /// Scarica il modello della lingua attiva.
  /// onProgress: progress totale 0..1, messaggio, progress modello, progress mmproj.
  /// Per Dante il progress della visione resta a 0: non viene scaricata.
  Future<void> downloadAll({
    required void Function(
      double totalProgress,
      String status,
      double modelProgress,
      double mmprojProgress,
    ) onProgress,
  }) async {
    final vision = usesVision;
    final modelPath = await getModelPath();
    final modelUrl = vision ? minicpmUrl : danteUrl;
    final modelExpected = vision ? minicpmExpectedBytes : danteExpectedBytes;
    final modelMin = vision ? minicpmMinBytes : danteMinBytes;

    double modelProg = await _isFileReady(modelPath, modelMin) ? 1.0 : 0.0;
    double mmprojProg = vision && !await isMmprojExists() ? 0.0 : 1.0;

    double combined() => vision ? (modelProg + mmprojProg) / 2 : modelProg;

    if (modelProg == 1.0 && mmprojProg == 1.0) {
      onProgress(1.0, S.current.modelAlreadyDownloaded, 1.0, vision ? 1.0 : 0.0);
      return;
    }

    if (modelProg < 1.0) {
      onProgress(combined(), S.current.downloadingModel, modelProg, vision ? mmprojProg : 0.0);
      await _downloadFile(
        url: modelUrl,
        savePath: modelPath,
        expectedBytes: modelExpected,
        minBytes: modelMin,
        onProgress: (p, rec, tot) {
          modelProg = p;
          final mbRec = (rec / (1024 * 1024)).toStringAsFixed(1);
          final mbTot = (tot / (1024 * 1024)).toStringAsFixed(1);
          onProgress(combined(), S.current.modelProgress(mbRec, mbTot), modelProg, vision ? mmprojProg : 0.0);
        },
      );
      modelProg = 1.0;
    }

    if (vision && mmprojProg < 1.0) {
      final mmprojPath = await getMmprojPath();
      onProgress(combined(), S.current.downloadingVision, modelProg, mmprojProg);
      await _downloadFile(
        url: mmprojUrl,
        savePath: mmprojPath,
        expectedBytes: mmprojExpectedBytes,
        minBytes: mmprojMinBytes,
        onProgress: (p, rec, tot) {
          mmprojProg = p;
          final mbRec = (rec / (1024 * 1024)).toStringAsFixed(1);
          final mbTot = (tot / (1024 * 1024)).toStringAsFixed(1);
          onProgress(combined(), S.current.visionProgress(mbRec, mbTot), modelProg, mmprojProg);
        },
      );
    }

    onProgress(1.0, S.current.downloadComplete, 1.0, vision ? 1.0 : 0.0);
  }

  Future<Map<String, dynamic>> getStatus() async {
    final modelPath = await getModelPath();
    final mmprojPath = await getMmprojPath();
    final modelExists = await isModelExists();
    final mmprojExists = await isMmprojExists();
    final vision = usesVision;
    int modelSize = 0, mmprojSize = 0;
    if (await File(modelPath).exists()) modelSize = await File(modelPath).length();
    if (vision && await File(mmprojPath).exists()) mmprojSize = await File(mmprojPath).length();
    return {
      'modelPath': modelPath,
      'mmprojPath': mmprojPath,
      'modelExists': modelExists,
      'mmprojExists': mmprojExists,
      'modelSize': modelSize,
      'mmprojSize': mmprojSize,
      'usesVision': vision,
      'ready': modelExists && (!vision || mmprojExists),
    };
  }
}
