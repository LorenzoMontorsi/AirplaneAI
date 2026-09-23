import 'package:flutter/material.dart';
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
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_onLanguage);
    _checkAndDownload();
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onLanguage);
    super.dispose();
  }

  void _onLanguage() {
    if (mounted) setState(() {});
  }

  Future<void> _checkAndDownload() async {
    final ready = await _mgr.isAllReady();
    if (ready) {
      _status = S.current.modelAlreadyPresent;
      setState(() {
        _total = 1;
        _modelProg = 1;
        _mmprojProg = 1;
      });
      await Future.delayed(const Duration(milliseconds: 600));
      widget.onReady();
      return;
    }
    _startDownload();
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(height: 36),
                // Totale
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
                const SizedBox(height: 10),
                _buildDetail(s.visionFileLabel, _mmprojProg),
                const SizedBox(height: 30),
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
                  Text(s.downloadWarning, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
