import '../services/app_settings.dart';
import 'app_language.dart';

/// Scritte dell'interfaccia. [current] segue la lingua salvata in [AppSettings].
class S {
  final AppLanguage language;
  const S(this.language);

  static S get current => S(AppSettings.instance.language);

  String get settings => switch (language) {
        AppLanguage.it => 'Impostazioni',
        AppLanguage.en => 'Settings',
        AppLanguage.zh => '设置',
      };

  String get modelLanguage => switch (language) {
        AppLanguage.it => 'Lingua del modello',
        AppLanguage.en => 'Model language',
        AppLanguage.zh => '模型语言',
      };

  String get modelLanguageHelp => switch (language) {
        AppLanguage.it =>
          'Italiano usa Gemma 3 1B e non legge le immagini. Inglese e cinese usano MiniCPM-V, che legge anche le foto. Le scritte dell\'app seguono la stessa lingua. Se il modello di quella lingua non è sul telefono, va scaricato. Se c\'è già una conversazione, cambiarla la azzera.',
        AppLanguage.en =>
          'Italian uses Gemma 3 1B and cannot read images. English and Chinese use MiniCPM-V, which can also read photos. The app text follows the same language. If that model is not on the phone yet, it has to be downloaded. If a conversation is already open, switching clears it.',
        AppLanguage.zh =>
          '意大利语使用 Gemma 3 1B，不能看图片。英语和中文使用 MiniCPM-V，也可以看照片。应用里的文字会跟着变。如果手机上还没有该模型，就需要下载。如果已经有对话，切换语言会清空对话。',
      };

  String languageOptionSubtitle(AppLanguage option) => switch (language) {
        AppLanguage.it => switch (option) {
            AppLanguage.it => 'Gemma 3 1B, solo testo, circa 806 MB',
            AppLanguage.en => 'MiniCPM-V, testo e immagini, circa 1,6 GB',
            AppLanguage.zh => 'MiniCPM-V, testo e immagini, circa 1,6 GB',
          },
        AppLanguage.en => switch (option) {
            AppLanguage.it => 'Gemma 3 1B, text only, about 806 MB',
            AppLanguage.en => 'MiniCPM-V, text and images, about 1.6 GB',
            AppLanguage.zh => 'MiniCPM-V, text and images, about 1.6 GB',
          },
        AppLanguage.zh => switch (option) {
            AppLanguage.it => 'Gemma 3 1B，仅文字，约 806 MB',
            AppLanguage.en => 'MiniCPM-V，文字和图片，约 1.6 GB',
            AppLanguage.zh => 'MiniCPM-V，文字和图片，约 1.6 GB',
          },
      };

  String get changeLanguageTitle => switch (language) {
        AppLanguage.it => 'Cambiare lingua?',
        AppLanguage.en => 'Change language?',
        AppLanguage.zh => '要更改语言吗？',
      };

  String get changeLanguageBody => switch (language) {
        AppLanguage.it =>
          'La chat attuale viene cancellata. Se il modello di questa lingua non è ancora sul telefono, parte il download.',
        AppLanguage.en =>
          'The current chat will be cleared. If this language\'s model is not on the phone yet, the download starts.',
        AppLanguage.zh => '当前对话会被清空。如果手机上还没有这种语言的模型，就会开始下载。',
      };

  String get change => switch (language) {
        AppLanguage.it => 'Cambia',
        AppLanguage.en => 'Change',
        AppLanguage.zh => '更改',
      };

  String get cancel => switch (language) {
        AppLanguage.it => 'Annulla',
        AppLanguage.en => 'Cancel',
        AppLanguage.zh => '取消',
      };

  String get waitForReply => switch (language) {
        AppLanguage.it => 'Aspetta che finisca la risposta.',
        AppLanguage.en => 'Wait until the reply finishes.',
        AppLanguage.zh => '请等待回复结束。',
      };

  String get clearChat => switch (language) {
        AppLanguage.it => 'Pulisci chat',
        AppLanguage.en => 'Clear chat',
        AppLanguage.zh => '清空聊天',
      };

  String get chatCleared => switch (language) {
        AppLanguage.it => 'Chat pulita. Come posso aiutarti?',
        AppLanguage.en => 'Chat cleared. How can I help?',
        AppLanguage.zh => '聊天已清空。需要我做什么？',
      };

  String get deleteModel => switch (language) {
        AppLanguage.it => 'Elimina modello',
        AppLanguage.en => 'Delete model',
        AppLanguage.zh => '删除模型',
      };

  String get deleteModelTitle => switch (language) {
        AppLanguage.it => 'Elimina modello?',
        AppLanguage.en => 'Delete model?',
        AppLanguage.zh => '删除模型？',
      };

  String get deleteModelBody => switch (language) {
        AppLanguage.it => 'Dovrai riscaricare circa 806 MB.',
        AppLanguage.en => 'You will have to download 1.6 GB again.',
        AppLanguage.zh => '需要重新下载 1.6 GB。',
      };

  String get delete => switch (language) {
        AppLanguage.it => 'Elimina',
        AppLanguage.en => 'Delete',
        AppLanguage.zh => '删除',
      };

  String get modelDeleted => switch (language) {
        AppLanguage.it => 'Modello eliminato, riavvia l\'app',
        AppLanguage.en => 'Model deleted. Restart the app',
        AppLanguage.zh => '模型已删除，请重启应用',
      };

  String visionSubtitle(bool on) => switch (language) {
        AppLanguage.it => 'Gemma 3 1B • Solo testo',
        AppLanguage.en => on ? 'MiniCPM-V 4.6 • Vision ON' : 'MiniCPM-V 4.6 • Offline',
        AppLanguage.zh => on ? 'MiniCPM-V 4.6 • 视觉开启' : 'MiniCPM-V 4.6 • 离线',
      };

  String welcome({required bool vision}) {
    if (language == AppLanguage.it) {
      return 'Ciao! Sono Gemma 3, offline sul telefono. Rispondo in italiano. Le immagini non sono disponibili in italiano.';
    }
    final extra = vision ? visionReady : visionMissing;
    if (language == AppLanguage.en) {
      return 'Hi! I am MiniCPM-V 4.6 offline. I reply in English. $extra';
    }
    return '你好！我是离线的 MiniCPM-V 4.6。我会用中文回答。$extra';
  }

  String get visionReady => switch (language) {
        AppLanguage.it => 'Visione attiva: puoi inviare immagini.',
        AppLanguage.en => 'Vision is on: you can send images.',
        AppLanguage.zh => '视觉已开启：可以发送图片。',
      };

  String get visionMissing => switch (language) {
        AppLanguage.it => 'Modalità solo testo (modulo visione non caricato).',
        AppLanguage.en => 'Text only (vision module not loaded).',
        AppLanguage.zh => '仅文字模式（视觉模块未加载）。',
      };

  String get initializing => switch (language) {
        AppLanguage.it => 'Inizializzazione...',
        AppLanguage.en => 'Starting...',
        AppLanguage.zh => '正在启动...',
      };

  String get checkingModel => switch (language) {
        AppLanguage.it => 'Verifica modello...',
        AppLanguage.en => 'Checking model...',
        AppLanguage.zh => '正在检查模型...',
      };

  String initFailed(Object error) => switch (language) {
        AppLanguage.it => 'Errore inizializzazione: $error',
        AppLanguage.en => 'Startup error: $error',
        AppLanguage.zh => '初始化错误：$error',
      };

  String get initFailedShort => switch (language) {
        AppLanguage.it => 'Errore',
        AppLanguage.en => 'Error',
        AppLanguage.zh => '错误',
      };

  String pickFailed(Object error) => switch (language) {
        AppLanguage.it => 'Errore immagine: $error',
        AppLanguage.en => 'Image error: $error',
        AppLanguage.zh => '图片错误：$error',
      };

  String get gallery => switch (language) {
        AppLanguage.it => 'Galleria',
        AppLanguage.en => 'Gallery',
        AppLanguage.zh => '相册',
      };

  String get camera => switch (language) {
        AppLanguage.it => 'Fotocamera',
        AppLanguage.en => 'Camera',
        AppLanguage.zh => '相机',
      };

  String get removeImage => switch (language) {
        AppLanguage.it => 'Rimuovi immagine',
        AppLanguage.en => 'Remove image',
        AppLanguage.zh => '移除图片',
      };

  String get imagePlaceholder => switch (language) {
        AppLanguage.it => '(immagine)',
        AppLanguage.en => '(image)',
        AppLanguage.zh => '（图片）',
      };

  String replyFailed(Object error) => switch (language) {
        AppLanguage.it => 'Errore: $error',
        AppLanguage.en => 'Error: $error',
        AppLanguage.zh => '错误：$error',
      };

  String get imageReady => switch (language) {
        AppLanguage.it => 'Immagine pronta da inviare',
        AppLanguage.en => 'Image ready to send',
        AppLanguage.zh => '图片已准备好发送',
      };

  String get sendImage => switch (language) {
        AppLanguage.it => 'Invia immagine',
        AppLanguage.en => 'Send image',
        AppLanguage.zh => '发送图片',
      };

  String get visionUnavailable => switch (language) {
        AppLanguage.it => 'Visione non disponibile',
        AppLanguage.en => 'Vision unavailable',
        AppLanguage.zh => '视觉不可用',
      };

  String get hintWithImage => switch (language) {
        AppLanguage.it => 'Messaggio + immagine opzionale...',
        AppLanguage.en => 'Message + optional image...',
        AppLanguage.zh => '消息，可附带图片...',
      };

  String get hintTextOnly => switch (language) {
        AppLanguage.it => 'Messaggio...',
        AppLanguage.en => 'Message...',
        AppLanguage.zh => '消息...',
      };

  String get tagline => switch (language) {
        AppLanguage.it => 'Gemma 3 1B  •  Offline •  Solo testo',
        AppLanguage.en => 'MiniCPM-V 4.6  •  Offline •  Multimodal',
        AppLanguage.zh => 'MiniCPM-V 4.6  •  离线  •  多模态',
      };

  String get capabilities => switch (language) {
        AppLanguage.it => 'Testo in italiano  •  ~806 MB',
        AppLanguage.en => 'Images + text  •  Video (frames)  •  ~1.6 GB',
        AppLanguage.zh => '图片 + 文字  •  视频（帧）  •  约 1.6 GB',
      };

  String get total => switch (language) {
        AppLanguage.it => 'totale',
        AppLanguage.en => 'total',
        AppLanguage.zh => '总计',
      };

  String get modelFileLabel => switch (language) {
        AppLanguage.it => 'Gemma 3 1B Q4_K_M (806 MB)',
        AppLanguage.en => 'Q4_0 model (501 MB)',
        AppLanguage.zh => 'Q4_0 模型（501 MB）',
      };

  String get visionFileLabel => switch (language) {
        AppLanguage.it => 'Mmproj visione (1.11 GB)',
        AppLanguage.en => 'Vision mmproj (1.11 GB)',
        AppLanguage.zh => '视觉投影 mmproj（1.11 GB）',
      };

  String get retry => switch (language) {
        AppLanguage.it => 'Riprova',
        AppLanguage.en => 'Retry',
        AppLanguage.zh => '重试',
      };

  String get downloadWarning => switch (language) {
        AppLanguage.it =>
          'Non chiudere l\'app durante il download.\nAvviene una sola volta, poi tutto offline.',
        AppLanguage.en =>
          'Do not close the app during the download.\nIt happens once, then everything works offline.',
        AppLanguage.zh => '下载时请不要关闭应用。\n只需下载一次，之后即可完全离线使用。',
      };

  String get details => switch (language) {
        AppLanguage.it => 'Dettagli',
        AppLanguage.en => 'Details',
        AppLanguage.zh => '详情',
      };

  String get modelStatus => switch (language) {
        AppLanguage.it => 'Stato modello',
        AppLanguage.en => 'Model status',
        AppLanguage.zh => '模型状态',
      };

  String get ok => switch (language) {
        AppLanguage.it => 'OK',
        AppLanguage.en => 'OK',
        AppLanguage.zh => '确定',
      };

  String get modelAlreadyPresent => switch (language) {
        AppLanguage.it => 'Modello già presente ✓',
        AppLanguage.en => 'Model already on device ✓',
        AppLanguage.zh => '模型已在设备上 ✓',
      };

  String get downloadDone => switch (language) {
        AppLanguage.it => 'Download completato ✓',
        AppLanguage.en => 'Download complete ✓',
        AppLanguage.zh => '下载完成 ✓',
      };

  String get downloadError => switch (language) {
        AppLanguage.it => 'Errore download',
        AppLanguage.en => 'Download error',
        AppLanguage.zh => '下载出错',
      };

  String statusDetails({
    required String modelPath,
    required bool modelExists,
    required String modelSizeMb,
    required String mmprojPath,
    required bool mmprojExists,
    required String mmprojSizeMb,
    required bool vision,
  }) {
    if (!vision) {
      return switch (language) {
        AppLanguage.it =>
          'Modello: $modelPath\nPresente: $modelExists, $modelSizeMb MB\n\nSolo testo: Gemma 3 non ha il modulo visione.',
        AppLanguage.en =>
          'Model: $modelPath\nPresent: $modelExists, $modelSizeMb MB\n\nText only: Gemma 3 has no vision module.',
        AppLanguage.zh =>
          '模型：$modelPath\n已存在：$modelExists，$modelSizeMb MB\n\n仅文字：Gemma 3 没有视觉模块。',
      };
    }
    return switch (language) {
      AppLanguage.it =>
        'Modello: $modelPath\nPresente: $modelExists, $modelSizeMb MB\n\nVisione: $mmprojPath\nPresente: $mmprojExists, $mmprojSizeMb MB',
      AppLanguage.en =>
        'Model: $modelPath\nPresent: $modelExists, $modelSizeMb MB\n\nVision: $mmprojPath\nPresent: $mmprojExists, $mmprojSizeMb MB',
      AppLanguage.zh =>
        '模型：$modelPath\n已存在：$modelExists，$modelSizeMb MB\n\n视觉：$mmprojPath\n已存在：$mmprojExists，$mmprojSizeMb MB',
    };
  }

  String downloadFailed(int code) => switch (language) {
        AppLanguage.it => 'Download fallito (HTTP $code)',
        AppLanguage.en => 'Download failed (HTTP $code)',
        AppLanguage.zh => '下载失败（HTTP $code）',
      };

  String get modelAlreadyDownloaded => switch (language) {
        AppLanguage.it => 'Modello già scaricato',
        AppLanguage.en => 'Model already downloaded',
        AppLanguage.zh => '模型已下载',
      };

  String get downloadingModel => switch (language) {
        AppLanguage.it => 'Download Gemma 3 1B (806 MB)...',
        AppLanguage.en => 'Downloading Q4_0 model (501 MB)...',
        AppLanguage.zh => '正在下载 Q4_0 模型（501 MB）...',
      };

  String modelProgress(String received, String total) => switch (language) {
        AppLanguage.it => 'Gemma 3 1B: $received / $total MB',
        AppLanguage.en => 'Q4_0 model: $received / $total MB',
        AppLanguage.zh => 'Q4_0 模型：$received / $total MB',
      };

  String get downloadingVision => switch (language) {
        AppLanguage.it => 'Download mmproj (1.11 GB) per la visione...',
        AppLanguage.en => 'Downloading vision mmproj (1.11 GB)...',
        AppLanguage.zh => '正在下载视觉投影 mmproj（1.11 GB）...',
      };

  String visionProgress(String received, String total) => switch (language) {
        AppLanguage.it => 'Mmproj visione: $received / $total MB',
        AppLanguage.en => 'Vision mmproj: $received / $total MB',
        AppLanguage.zh => '视觉投影：$received / $total MB',
      };

  String get downloadComplete => switch (language) {
        AppLanguage.it => 'Download completato',
        AppLanguage.en => 'Download complete',
        AppLanguage.zh => '下载完成',
      };

  String get modelAlreadyLoaded => switch (language) {
        AppLanguage.it => 'Modello già caricato',
        AppLanguage.en => 'Model already loaded',
        AppLanguage.zh => '模型已加载',
      };

  String modelMissing(String path) => switch (language) {
        AppLanguage.it => 'Modello non trovato: $path',
        AppLanguage.en => 'Model not found: $path',
        AppLanguage.zh => '未找到模型：$path',
      };

  String get startingEngine => switch (language) {
        AppLanguage.it => 'Inizializzazione engine llama.cpp...',
        AppLanguage.en => 'Starting llama.cpp engine...',
        AppLanguage.zh => '正在初始化 llama.cpp 引擎...',
      };

  String get loadingModel => switch (language) {
        AppLanguage.it => 'Caricamento Gemma 3 1B...',
        AppLanguage.en => 'Loading Q4_0 model...',
        AppLanguage.zh => '正在加载 Q4_0 模型...',
      };

  String get modelLoaded => switch (language) {
        AppLanguage.it => 'Modello caricato',
        AppLanguage.en => 'Model loaded',
        AppLanguage.zh => '模型已加载',
      };

  String get loadingVision => switch (language) {
        AppLanguage.it => 'Caricamento proiettore visione (mmproj)...',
        AppLanguage.en => 'Loading vision projector (mmproj)...',
        AppLanguage.zh => '正在加载视觉投影（mmproj）...',
      };

  String get visionEnabled => switch (language) {
        AppLanguage.it => 'Visione attivata ✓',
        AppLanguage.en => 'Vision enabled ✓',
        AppLanguage.zh => '视觉已启用 ✓',
      };

  String visionLoadWarning(Object error) => switch (language) {
        AppLanguage.it => 'Avviso mmproj: $error. Continuo senza visione.',
        AppLanguage.en => 'Vision warning: $error. Continuing without vision.',
        AppLanguage.zh => '视觉模块警告：$error。将继续以纯文字模式运行。',
      };

  String get visionFileMissing => switch (language) {
        AppLanguage.it => 'Mmproj non trovato, solo chat testuale',
        AppLanguage.en => 'Vision file missing, text chat only',
        AppLanguage.zh => '未找到视觉模块，仅可文字聊天',
      };

  String loadFailed(Object error) => switch (language) {
        AppLanguage.it => 'Errore caricamento: $error',
        AppLanguage.en => 'Load error: $error',
        AppLanguage.zh => '加载错误：$error',
      };

  String get engineNotReady => switch (language) {
        AppLanguage.it => 'Engine non inizializzato',
        AppLanguage.en => 'Engine is not ready',
        AppLanguage.zh => '引擎尚未初始化',
      };

  String get emptyMessage => switch (language) {
        AppLanguage.it => 'Messaggio vuoto',
        AppLanguage.en => 'Empty message',
        AppLanguage.zh => '消息为空',
      };

  String get pickLanguageTitle => switch (language) {
        AppLanguage.it => 'Prima del download',
        AppLanguage.en => 'Before the download',
        AppLanguage.zh => '下载之前',
      };

  String get pickLanguageHelp => switch (language) {
        AppLanguage.it =>
          'Italiano scarica Gemma 3 1B, solo testo. Inglese e cinese scaricano MiniCPM-V, che legge anche le immagini.',
        AppLanguage.en =>
          'Italian downloads Gemma 3 1B, text only. English and Chinese download MiniCPM-V, which can also read images.',
        AppLanguage.zh =>
          '意大利语会下载 Gemma 3 1B，仅文字。英语和中文会下载 MiniCPM-V，也可以看图片。',
      };

  String get startDownload => switch (language) {
        AppLanguage.it => 'Scarica',
        AppLanguage.en => 'Download',
        AppLanguage.zh => '下载',
      };

  String get continueChat => switch (language) {
        AppLanguage.it => 'Continua',
        AppLanguage.en => 'Continue',
        AppLanguage.zh => '继续',
      };
}
