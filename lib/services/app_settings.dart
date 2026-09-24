import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_language.dart';

/// Lingua scelta per il modello e per le scritte dell'app. Persistita in
/// Documents, fuori dalla cartella dei pesi, così cancellare il modello non
/// resetta la preferenza.
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const _fileName = 'airplane_ai_settings.json';

  AppLanguage language = AppLanguage.it;

  /// Ricerca online facoltativa dal feed RSS personale. Spenta di default:
  /// l'app resta offline, se accesa aggiunge contesto dalle ultime 24h.
  bool onlineSearch = false;

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is Map && raw['language'] is String) {
        language = AppLanguage.fromCode(raw['language'] as String);
      }
      if (raw is Map && raw['onlineSearch'] is bool) {
        onlineSearch = raw['onlineSearch'] as bool;
      }
    } catch (e) {
      debugPrint('AppSettings load: $e');
    }
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      await file.writeAsString(
          jsonEncode({'language': language.code, 'onlineSearch': onlineSearch}));
    } catch (e) {
      debugPrint('AppSettings save: $e');
    }
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (value == language) return;
    language = value;
    notifyListeners();
    await _save();
  }

  Future<void> setOnlineSearch(bool value) async {
    if (value == onlineSearch) return;
    onlineSearch = value;
    notifyListeners();
    await _save();
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }
}
