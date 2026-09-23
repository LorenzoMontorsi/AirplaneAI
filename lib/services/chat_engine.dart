import 'dart:async';
import 'dart:io';
import 'package:llamadart/llamadart.dart';

import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import 'app_settings.dart';

class ChatEngine {
  static final ChatEngine _instance = ChatEngine._internal();
  factory ChatEngine() => _instance;
  ChatEngine._internal();

  LlamaEngine? _engine;
  bool _isLoading = false;
  bool _isLoaded = false;
  bool _visionReady = false;
  String? _loadedModelPath;
  String? _loadedMmprojPath;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String? get loadedModelPath => _loadedModelPath;

  // Dante 2B è un instruct italiano: la regola va scritta in italiano.
  // MiniCPM-V 4.6 è addestrato su cinese e inglese, e segue la regola
  // solo se è scritta in inglese. Scriverla nella lingua di arrivo lo fa deragliare.
  static String systemPromptFor(AppLanguage language) => switch (language) {
        AppLanguage.it =>
          'Sei AirplaneAI. Rispondi solo in italiano. '
          'Usa un italiano corretto e semplice. '
          'Non usare caratteri cinesi. Non rispondere in inglese, '
          'tranne per nomi, codice o una parola che l\'utente chiede di lasciare così. '
          'Non mescolare le lingue nella stessa risposta. '
          'Se l\'utente scrive in un\'altra lingua, rispondi comunque in italiano, '
          'a meno che non chieda esplicitamente di tradurre o di usare un\'altra lingua. '
          'Sii conciso e cordiale.',
        AppLanguage.en =>
          'You are AirplaneAI. Answer in English only. '
          'Use correct, simple English. '
          'Do not use Chinese characters. Do not answer in Italian, '
          'except for names, code, or a word the user asked to keep. '
          'Do not mix languages in the same answer. '
          'If the user writes in another language, still answer in English, '
          'unless they explicitly ask you to translate or to use another language. '
          'Be concise and friendly. Describe images in English.',
        AppLanguage.zh =>
          'You are AirplaneAI. Answer in Simplified Chinese only. '
          'Use correct, natural Chinese. '
          'Do not answer in English or Italian, '
          'except for names, code, or a word the user asked to keep. '
          'Do not mix languages in the same answer. '
          'If the user writes in another language, still answer in Chinese, '
          'unless they explicitly ask you to translate or to use another language. '
          'Be concise and friendly. Describe images in Chinese.',
      };

  static String imageOnlyPromptFor(AppLanguage language) => switch (language) {
        AppLanguage.it => 'Descrivi questa immagine in italiano.',
        AppLanguage.en => 'Describe this image in English.',
        AppLanguage.zh => '请用中文描述这张图片。',
      };

  /// Parametri del cookbook ufficiale llama.cpp per MiniCPM-V 4.6.
  /// La penalty di default di llamadart (1.1) su un modello da 0.8B spinge
  /// i token fuori dall'italiano verso cinese e inglese.
  static const GenerationParams defaultParams = GenerationParams(
    maxTokens: 1024,
    temp: 0.7,
    topK: 100,
    topP: 0.8,
    minP: 0.0,
    penalty: 1.05,
  );

  LlamaChatMessage get systemMessage => LlamaChatMessage.fromText(
        role: LlamaChatRole.system,
        text: systemPromptFor(AppSettings.instance.language),
      );

  Future<bool> get supportsVision async {
    if (_engine == null) return false;
    try {
      return await _engine!.supportsVision;
    } catch (_) {
      return false;
    }
  }

  Future<void> init({
    required String modelPath,
    String? mmprojPath,
    int contextSize = 4096,
    void Function(String msg)? onLog,
  }) async {
    if (_isLoading) return;
    if (_isLoaded && _loadedModelPath == modelPath && _loadedMmprojPath == mmprojPath) {
      onLog?.call(S.current.modelAlreadyLoaded);
      return;
    }

    _isLoading = true;
    try {
      // Dispose precedente
      if (_engine != null) {
        try { await _engine!.dispose(); } catch (_) {}
        _engine = null;
      }
      _visionReady = false;

      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        throw Exception(S.current.modelMissing(modelPath));
      }

      onLog?.call(S.current.startingEngine);
      _engine = LlamaEngine(LlamaBackend());

      onLog?.call(S.current.loadingModel);
      // Usa ModelParams per contesto e gpu
      await _engine!.loadModel(
        modelPath,
        modelParams: ModelParams(
          // Dante è stato addestrato a 2048 token. MiniCPM-V resta a 4096.
          contextSize: contextSize,
          gpuLayers: 0, // CPU sicuro; imposta 99 per GPU se dispositivo supporta Vulkan
        ),
      );
      onLog?.call(S.current.modelLoaded);

      final projector = mmprojPath;
      if (projector != null && await File(projector).exists()) {
        try {
          onLog?.call(S.current.loadingVision);
          await _engine!.loadMultimodalProjector(projector);
          _visionReady = true;
          onLog?.call(S.current.visionEnabled);
        } catch (e) {
          onLog?.call(S.current.visionLoadWarning(e));
        }
      } else if (projector != null) {
        onLog?.call(S.current.visionFileMissing);
      }

      _isLoaded = true;
      _loadedModelPath = modelPath;
      _loadedMmprojPath = mmprojPath;
    } catch (e, st) {
      _isLoaded = false;
      _visionReady = false;
      onLog?.call(S.current.loadFailed(e));
      print('ChatEngine init error: $e\n$st');
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// Chat streaming: supporta testo + opzionale immagine
  Stream<String> chatStream({
    required List<LlamaChatMessage> history,
    required String userText,
    String? imagePath,
    GenerationParams params = defaultParams,
  }) async* {
    if (_engine == null || !_isLoaded) {
      throw Exception(S.current.engineNotReady);
    }

    final List<LlamaContentPart> content = [];
    final image = imagePath;
    if (_visionReady && image != null && image.isNotEmpty) {
      final f = File(image);
      if (await f.exists()) {
        content.add(LlamaImageContent(path: image));
      }
    }
    // Senza testo il modello descrive l'immagine nella sua lingua di default.
    final language = AppSettings.instance.language;
    final promptText = userText.trim().isEmpty && content.isNotEmpty
        ? imageOnlyPromptFor(language)
        : userText.trim();
    if (promptText.isNotEmpty) {
      content.add(LlamaTextContent(promptText));
    }
    if (content.isEmpty) {
      throw Exception(S.current.emptyMessage);
    }

    final userMsg = LlamaChatMessage.withContent(
      role: LlamaChatRole.user,
      content: content,
    );

    // Sostituisce sempre il system prompt: la history della chat può averne
    // uno vecchio, creato prima di questa regola.
    final List<LlamaChatMessage> effectiveHistory;
    if (history.isNotEmpty && history.first.role == LlamaChatRole.system) {
      effectiveHistory = [systemMessage, ...history.skip(1)];
    } else {
      effectiveHistory = [systemMessage, ...history];
    }
    final messages = [...effectiveHistory, userMsg];

    // Il template di MiniCPM-V 4.6 Instruct apre <think> se enable_thinking
    // non è false. Il checkpoint Instruct non sa chiudere quel blocco e
    // sputa il ragionamento in cinese/inglese insieme alla risposta.
    // Cookbook ufficiale: reasoning off / enable_thinking false.
    await for (final chunk in _engine!.create(
      messages,
      params: params,
      enableThinking: false,
    )) {
      final first = chunk.choices.isNotEmpty ? chunk.choices.first : null;
      final text = first?.delta.content;
      if (text != null && text.isNotEmpty) {
        yield text;
      }
    }
  }

  /// Versione che gestisce history locale
  Stream<String> sendWithHistory({
    required List<LlamaChatMessage> history,
    required String text,
    String? imagePath,
  }) {
    return chatStream(history: history, userText: text, imagePath: imagePath);
  }

  Future<void> dispose() async {
    if (_engine != null) {
      try { await _engine!.dispose(); } catch (_) {}
      _engine = null;
    }
    _isLoaded = false;
    _isLoading = false;
    _visionReady = false;
  }
}
