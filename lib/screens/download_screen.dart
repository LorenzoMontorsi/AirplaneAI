import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../services/app_settings.dart';
import '../services/model_manager.dart';

class DownloadScreen extends StatefulWidget {
  final VoidCallback onReady;
  const DownloadScreen({super.key, required this.onReady});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final ModelManager _mgr = ModelManager();
  double _total = 0;
  double _modelProg = 0;
  double _mmprojProg = 0;
  String _status = S.current.checkingModel;
  bool _downloading = false;
  bool _error = false;
  bool _targetReady = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_onLanguage);
    _refreshTarget();
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onLanguage);
    super.dispose();
  }

  void _onLanguage() {
    if (!mounted || _downloading) return;
    setState(() {});
    _refreshTarget();
  }

  Future<void> _refreshTarget() async {
    final ready = await _mgr.isAllReady();
    if (!mounted || _downloading) return;
    setState(() => _targetReady = ready);
  }

  Future<void> _selectLanguage(AppLanguage language) async {
    if (_downloading) return;
    await AppSettings.instance.setLanguage(language);
  }

  Future<void> _confirmAndDownload() async {
    if (_downloading) return;
    if (await _mgr.isAllReady()) {
      widget.onReady();
      return;
    }
    await _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _error = false;
      _errorMsg = '';
    });
    try {
      await _mgr.downloadAll(
        onProgress: (total, status, modelP, mmprojP) {
          if (!mounted) return;
          setState(() {
            _total = total;
            _status = status;
            _modelProg = modelP;
            _mmprojProg = mmprojP;
          });
        },
      );
      if (!mounted) return;
      setState(() => _status = S.current.downloadDone);
      await Future.delayed(const Duration(milliseconds: 800));
      widget.onReady();
    } catch (e) {
      setState(() {
        _error = true;
        _errorMsg = e.toString();
        _downloading = false;
        _status = S.current.downloadError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1D26),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
                const Icon(Icons.smart_toy, size: 72, color: Color(0xFF2EC4A5)),
                const SizedBox(height: 16),
                const Text('AirplaneAI', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(s.tagline, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                  child: Text(s.capabilities, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(s.pickLanguageTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Text(s.pickLanguageHelp, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
                const SizedBox(height: 12),
                _languagePicker(s),
                const SizedBox(height: 24),
                if (_downloading || _error) ...[
                  Align(alignment: Alignment.centerLeft, child: Text(_status, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.left)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: _total, minHeight: 10, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(Color(0xFF2EC4A5))),
                  ),
                  const SizedBox(height: 6),
                  Text('${(_total * 100).toStringAsFixed(1)} %  ${s.total}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 20),
                  _buildDetail(s.modelFileLabel, _modelProg),
                  if (_mgr.usesVision) ...[
                    const SizedBox(height: 10),
                    _buildDetail(s.visionFileLabel, _mmprojProg),
                  ],
                  const SizedBox(height: 30),
                ],
                if (_error) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade300)),
                    child: Text(_errorMsg, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _startDownload,
                    icon: const Icon(Icons.refresh),
                    label: Text(s.retry),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2EC4A5), foregroundColor: Colors.white),
                  ),
                ] else if (_downloading)
                  Text(s.downloadWarning, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12))
                else ...[
                  ElevatedButton.icon(
                    onPressed: _confirmAndDownload,
                    icon: Icon(_targetReady ? Icons.arrow_forward : Icons.download),
                    label: Text(_targetReady ? s.continueChat : s.startDownload),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2EC4A5), foregroundColor: Colors.white),
                  ),
                  if (!_targetReady) ...[
                    const SizedBox(height: 16),
                    Text(s.downloadWarning, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    final s = await _mgr.getStatus();
                    if (!context.mounted) return;
                    final strings = S.current;
                    showDialog(context: context, builder: (dialogContext) => AlertDialog(
                      title: Text(strings.modelStatus),
                      content: Text(strings.statusDetails(
                        modelPath: '${s['modelPath']}',
                        modelExists: s['modelExists'] == true,
                        modelSizeMb: ((s['modelSize'] as int) / 1024 / 1024).toStringAsFixed(1),
                        mmprojPath: '${s['mmprojPath']}',
                        mmprojExists: s['mmprojExists'] == true,
                        mmprojSizeMb: ((s['mmprojSize'] as int) / 1024 / 1024).toStringAsFixed(1),
                        vision: s['usesVision'] == true,
                      )),
                      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(strings.ok))],
                    ));
                  },
                  child: Text(s.details, style: const TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _languagePicker(S s) {
    final selected = AppSettings.instance.language;
    return Material(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: RadioGroup<AppLanguage>(
        groupValue: selected,
        onChanged: _downloading
            ? (_) {}
            : (value) {
                if (value != null) _selectLanguage(value);
              },
        child: Column(
          children: [
            for (var i = 0; i < AppLanguage.values.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Colors.white12),
              RadioListTile<AppLanguage>(
                value: AppLanguage.values[i],
                activeColor: const Color(0xFF2EC4A5),
                title: Text(
                  AppLanguage.values[i].nativeName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  s.languageOptionSubtitle(AppLanguage.values[i]),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(String label, double prog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text('${(prog * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: prog, minHeight: 6, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(Color(0xFF4DD0C8))),
        ),
      ],
    );
  }
}
