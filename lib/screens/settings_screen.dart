import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../services/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  /// True se in chat c'è già almeno un messaggio dell'utente o del modello.
  /// In quel caso cambiare lingua chiede conferma, perché la chat viene azzerata.
  final bool hasConversation;

  const SettingsScreen({super.key, required this.hasConversation});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _select(AppLanguage language) async {
    final settings = AppSettings.instance;
    if (language == settings.language) return;

    if (widget.hasConversation) {
      final s = S.current;
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(s.changeLanguageTitle),
          content: Text(s.changeLanguageBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(s.change),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    await settings.setLanguage(language);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final selected = AppSettings.instance.language;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1D26),
        foregroundColor: Colors.white,
        title: Text(s.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Row(
            children: [
              const Icon(Icons.translate, color: Color(0xFF0F7B6B)),
              const SizedBox(width: 8),
              Text(
                s.modelLanguage,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.modelLanguageHelp,
            style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: RadioGroup<AppLanguage>(
              groupValue: selected,
              onChanged: (value) {
                if (value != null) _select(value);
              },
              child: Column(
                children: [
                  for (var i = 0; i < AppLanguage.values.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    RadioListTile<AppLanguage>(
                      value: AppLanguage.values[i],
                      activeColor: const Color(0xFF0F7B6B),
                      title: Text(
                        AppLanguage.values[i].nativeName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(s.languageOptionSubtitle(AppLanguage.values[i])),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.cloud_outlined, color: Color(0xFF0F7B6B)),
              const SizedBox(width: 8),
              Text(
                s.onlineSearchTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.onlineSearchHelp,
            style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              activeThumbColor: const Color(0xFF0F7B6B),
              title: Text(
                s.onlineSearchTitle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(AppSettings.instance.onlineSearch
                  ? s.onlineSearchOn
                  : s.onlineSearchOff),
              value: AppSettings.instance.onlineSearch,
              onChanged: (value) =>
                  AppSettings.instance.setOnlineSearch(value),
            ),
          ),
        ],
      ),
    );
  }
}
