import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:llamadart/llamadart.dart';
import '../l10n/app_strings.dart';
import '../services/app_settings.dart';
import '../services/chat_engine.dart';
import '../services/model_manager.dart';
import '../widgets/message_bubble.dart';
import 'settings_screen.dart';

class ChatMessageUI {
  final String text;
  final BubbleRole role;
  final String? imagePath;
  ChatMessageUI({required this.text, required this.role, this.imagePath});
}

class ChatScreen extends StatefulWidget {
  /// La lingua attiva non ha ancora i pesi sul telefono.
  final VoidCallback onModelMissing;

  const ChatScreen({super.key, required this.onModelMissing});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatEngine _engine = ChatEngine();
  final ModelManager _modelMgr = ModelManager();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();

  final List<ChatMessageUI> _uiMessages = [];
  final List<LlamaChatMessage> _llamaHistory = [];

  bool _isGenerating = false;
  bool _isInitializing = true;
  bool _applyingLanguage = false;
  String _initLog = S.current.initializing;
  String? _pendingImagePath;
  bool _visionEnabled = false;

  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_onLanguageChanged);
    _initEngine();
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onLanguageChanged);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// La lingua è cambiata. Inglese e cinese restano su MiniCPM-V e azzerano
  /// solo la chat. Italiano carica Dante, e se i pesi non ci sono si torna
  /// al download.
  void _onLanguageChanged() {
    _applyLanguageChange();
  }

  Future<void> _applyLanguageChange() async {
    if (!mounted || _applyingLanguage) return;
    _applyingLanguage = true;
    try {
      if (_isInitializing) {
        if (mounted) setState(() {});
        return;
      }
      final ready = await _modelMgr.isAllReady();
      if (!mounted) return;
      if (!ready) {
        final nav = Navigator.of(context);
        if (nav.canPop()) nav.pop();
        widget.onModelMissing();
        return;
      }
      final modelPath = await _modelMgr.getModelPath();
      if (!mounted) return;
      if (!_engine.isLoaded || _engine.loadedModelPath != modelPath) {
        setState(() {
          _uiMessages.clear();
          _pendingImagePath = null;
        });
        await _initEngine();
        return;
      }
      _resetConversation(S.current.welcome(vision: _visionEnabled));
    } finally {
      _applyingLanguage = false;
    }
  }

  Future<void> _initEngine() async {
    setState(() { _isInitializing = true; _initLog = S.current.checkingModel; });
    final vision = _modelMgr.usesVision;
    final modelPath = await _modelMgr.getModelPath();
    final mmprojPath = vision ? await _modelMgr.getMmprojPath() : null;
    try {
      await _engine.init(
        modelPath: modelPath,
        mmprojPath: mmprojPath,
        contextSize: _modelMgr.contextSize,
        onLog: (m) {
          if (mounted) setState(() => _initLog = m);
        },
      );
      final visionOn = await _engine.supportsVision;
      if (!mounted) return;
      setState(() {
        _visionEnabled = visionOn;
        _isInitializing = false;
      });
      _llamaHistory.clear();
      _llamaHistory.add(_engine.systemMessage);
      _addSystem(S.current.welcome(vision: _visionEnabled));
    } catch (e) {
      if (!mounted) return;
      setState(() { _isInitializing = false; _initLog = '${S.current.initFailedShort}: $e'; });
      _addSystem(S.current.initFailed(e));
    }
  }

  void _addSystem(String text) {
    setState(() => _uiMessages.add(ChatMessageUI(text: text, role: BubbleRole.system)));
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? x = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1024, maxHeight: 1024);
      if (x != null) {
        setState(() => _pendingImagePath = x.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.current.pickFailed(e))));
    }
  }

  void _showPickerSheet() {
    final s = S.current;
    showModalBottomSheet(context: context, builder: (sheetContext) => SafeArea(
      child: Wrap(children: [
        ListTile(leading: const Icon(Icons.photo_library), title: Text(s.gallery), onTap: () { Navigator.pop(sheetContext); _pickImage(ImageSource.gallery); }),
        ListTile(leading: const Icon(Icons.camera_alt), title: Text(s.camera), onTap: () { Navigator.pop(sheetContext); _pickImage(ImageSource.camera); }),
        if (_pendingImagePath != null)
          ListTile(leading: const Icon(Icons.clear, color: Colors.red), title: Text(s.removeImage), onTap: () { Navigator.pop(sheetContext); setState(() => _pendingImagePath = null); }),
      ]),
    ));
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _pendingImagePath == null) return;
    if (_isGenerating || _isInitializing) return;

    final imgPath = _pendingImagePath;
    // Add user bubble
    setState(() {
      _uiMessages.add(ChatMessageUI(text: text.isEmpty ? S.current.imagePlaceholder : text, role: BubbleRole.user, imagePath: imgPath));
      _isGenerating = true;
      _pendingImagePath = null;
    });
    _textCtrl.clear();
    _scrollToBottom();

    // Placeholder assistant streaming
    setState(() => _uiMessages.add(ChatMessageUI(text: '', role: BubbleRole.assistant)));
    _scrollToBottom();

    final historyCopy = List<LlamaChatMessage>.from(_llamaHistory);
    String accumulated = '';
    try {
      final stream = _engine.chatStream(history: historyCopy, userText: text, imagePath: imgPath);
      await for (final token in stream) {
        accumulated += token;
        setState(() => _uiMessages[_uiMessages.length - 1] = ChatMessageUI(text: accumulated, role: BubbleRole.assistant));
        // occasional scroll
      }
      // Commit to history
      final List<LlamaContentPart> content = [];
      if (imgPath != null) content.add(LlamaImageContent(path: imgPath));
      if (text.isNotEmpty) content.add(LlamaTextContent(text));
      final userMsg = LlamaChatMessage.withContent(role: LlamaChatRole.user, content: content);
      _llamaHistory.add(userMsg);
      _llamaHistory.add(LlamaChatMessage.withContent(role: LlamaChatRole.assistant, content: [LlamaTextContent(accumulated)]));
    } catch (e) {
      setState(() => _uiMessages[_uiMessages.length - 1] = ChatMessageUI(text: S.current.replyFailed(e), role: BubbleRole.assistant));
    } finally {
      setState(() => _isGenerating = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _resetConversation(String banner) {
    setState(() {
      _uiMessages.clear();
      _llamaHistory
        ..clear()
        ..add(_engine.systemMessage);
      _pendingImagePath = null;
    });
    _addSystem(banner);
  }

  void _clearChat() {
    _resetConversation(S.current.chatCleared);
  }

  Future<void> _openSettings() async {
    final s = S.current;
    if (_isGenerating || _isInitializing) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.waitForReply)));
      return;
    }
    final hasConversation = _uiMessages.any((m) => m.role != BubbleRole.system);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsScreen(hasConversation: hasConversation)),
    );
  }

  Future<void> _confirmDeleteModel() async {
    final s = S.current;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.deleteModelTitle),
        content: Text(s.deleteModelBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _modelMgr.deleteAll();
    await _engine.dispose();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.current.modelDeleted)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1D26),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AirplaneAI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(s.visionSubtitle(_visionEnabled), style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: s.clearChat, onPressed: _clearChat),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'settings') _openSettings();
              if (v == 'delete_model') _confirmDeleteModel();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'settings', child: Text(s.settings)),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'delete_model', child: Text(s.deleteModel)),
            ],
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF6F7F8),
      body: Column(
        children: [
          if (_isInitializing)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Expanded(child: Text(_initLog, style: const TextStyle(fontSize: 12))),
              ]),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _uiMessages.length,
              itemBuilder: (_, i) {
                final m = _uiMessages[i];
                final streaming = i == _uiMessages.length - 1 && _isGenerating && m.role == BubbleRole.assistant;
                return ChatBubble(text: m.text, role: m.role, imagePath: m.imagePath, isStreaming: streaming);
              },
            ),
          ),
          if (_pendingImagePath != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_pendingImagePath!), width: 60, height: 60, fit: BoxFit.cover)),
                const SizedBox(width: 8),
                Expanded(child: Text(s.imageReady, style: const TextStyle(fontSize: 12, color: Colors.black54))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _pendingImagePath = null)),
              ]),
            ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.add_a_photo, color: _visionEnabled ? const Color(0xFF0B1D26) : Colors.grey),
                  onPressed: _visionEnabled ? _showPickerSheet : null,
                  tooltip: _visionEnabled ? s.sendImage : s.visionUnavailable,
                ),
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: _visionEnabled ? s.hintWithImage : s.hintTextOnly,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF0F2F3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  backgroundColor: _isGenerating ? Colors.grey : const Color(0xFF0F7B6B),
                  child: IconButton(
                    icon: _isGenerating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _isGenerating ? null : _send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
