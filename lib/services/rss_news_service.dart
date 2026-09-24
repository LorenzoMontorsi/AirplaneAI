import 'package:http/http.dart' as http;

import '../l10n/app_language.dart';

/// Ricerca facoltativa di notizie online dal FreshRSS personale.
///
/// Il modello resta offline: quando il toggle è acceso, la domanda viene
/// usata per filtrare gli ultimi item RSS (ultime 24h) e i migliori vengono
/// iniettati nel prompt come contesto. Se la rete manca o il feed non
/// risponde, si torna alla chat puramente offline senza errori bloccanti.
class RssNewsItem {
  final String title;
  final String description;
  final String link;
  final String pubDate;
  const RssNewsItem({
    required this.title,
    required this.description,
    required this.link,
    required this.pubDate,
  });
}

class RssNewsService {
  RssNewsService._();
  static final RssNewsService instance = RssNewsService._();

  static const String feedUrl =
      'http://freshrss-e112psvrz8z65q783ld40orm.157.173.124.193.sslip.io/i/?a=rss&hours=24&nb=1000&state=3';

  static const Duration _timeout = Duration(seconds: 8);
  static const int maxItems = 5;
  static const int maxCharsPerItem = 400;

  List<RssNewsItem>? _cache;
  DateTime? _cacheAt;
  static const Duration _cacheTtl = Duration(minutes: 10);

  /// Scarica il feed e restituisce al massimo [maxItems] rilevanti per [query].
  /// Ritorna lista vuota (mai eccezione) se offline o senza match.
  Future<List<RssNewsItem>> search(String query, {int limit = maxItems}) async {
    try {
      final items = await _loadItems();
      final keywords = _keywords(query);
      if (items.isEmpty) return const [];
      if (keywords.isEmpty) return items.take(limit).toList();
      final scored = <({RssNewsItem item, int score})>[];
      for (final item in items) {
        final haystack = '${item.title} ${item.description}'.toLowerCase();
        var score = 0;
        for (final k in keywords) {
          if (haystack.contains(k)) score += k.length >= 5 ? 2 : 1;
        }
        if (score > 0) scored.add((item: item, score: score));
      }
      scored.sort((a, b) => b.score.compareTo(a.score));
      return scored.take(limit).map((e) => e.item).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Blocco di testo da accodare al prompt utente, già nella lingua dell'app.
  /// Ritorna stringa vuota se niente di rilevante (il modello va avanti offline).
  Future<String> buildContextBlock(String query, AppLanguage language) async {
    final hits = await search(query);
    if (hits.isEmpty) return '';
    final header = switch (language) {
      AppLanguage.it =>
        'Notizie recenti (ultime 24h, dal mio feed). Usale solo se pertinenti alla domanda, senza inventare altro:',
      AppLanguage.en =>
        'Recent news (last 24h, from my feed). Use them only if relevant to the question, do not invent anything else:',
      AppLanguage.zh => '最近24小时的新闻（来自我的订阅）。仅在与问题相关时使用，不要编造其他内容：',
    };
    final buf = StringBuffer(header);
    for (final item in hits) {
      var desc = item.description.trim();
      if (desc.length > maxCharsPerItem) {
        desc = '${desc.substring(0, maxCharsPerItem)}…';
      }
      buf.writeln();
      buf.write('- ${item.title.trim()}');
      if (desc.isNotEmpty) buf.write(' — $desc');
      if (item.pubDate.isNotEmpty) buf.write(' (${item.pubDate.trim()})');
    }
    return buf.toString();
  }

  Future<List<RssNewsItem>> _loadItems() async {
    if (_cache != null &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      return _cache!;
    }
    final resp = await http
        .get(Uri.parse(feedUrl), headers: {'User-Agent': 'AirplaneAI/1.0'})
        .timeout(_timeout);
    if (resp.statusCode != 200) return const [];
    final items = _parse(resp.body);
    _cache = items;
    _cacheAt = DateTime.now();
    return items;
  }

  /// Parsing leggero senza dipendenze: il feed è RSS 2.0 semplice.
  List<RssNewsItem> _parse(String xml) {
    final items = <RssNewsItem>[];
    final itemRe = RegExp(r'<item>(.*?)</item>', dotAll: true);
    for (final m in itemRe.allMatches(xml)) {
      final block = m.group(1) ?? '';
      final title = _field(block, 'title');
      final link = _field(block, 'link');
      final pubDate = _field(block, 'pubDate');
      var desc = _field(block, 'description');
      desc = _stripHtml(desc);
      if (title.isEmpty) continue;
      items.add(RssNewsItem(
        title: title.trim(),
        description: desc.trim(),
        link: link.trim(),
        pubDate: pubDate.trim(),
      ));
      if (items.length >= 1000) break;
    }
    return items;
  }

  String _field(String block, String tag) {
    final re = RegExp('<$tag.*?>(.*?)</$tag>', dotAll: true);
    final m = re.firstMatch(block);
    if (m == null) return '';
    var v = (m.group(1) ?? '').trim();
    if (v.startsWith('<![CDATA[') && v.endsWith(']]>')) {
      v = v.substring(9, v.length - 3);
    }
    return v.trim();
  }

  String _stripHtml(String s) {
    var v = s.replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '');
    v = v.replaceAll(RegExp(r'<[^>]*>'), ' ');
    v = v
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    return v.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Parole significative della domanda (minuscole, senza stopword e punteggiatura).
  Set<String> _keywords(String query) {
    const stop = {
      'che', 'cosa', 'come', 'quando', 'dove', 'perche', 'perché', 'chi',
      'quale', 'quali', 'quanto', 'quanti', 'della', 'dello', 'delle', 'degli',
      'nella', 'nello', 'sulla', 'sullo', 'dalla', 'dallo', 'con',
      'senza', 'questo', 'questa', 'questi', 'queste', 'quello', 'quella',
      'sono', 'sei', 'siamo', 'siete', 'stato', 'stata', 'fare', 'dire',
      'the', 'what', 'when', 'where', 'which', 'that', 'this',
      'with', 'from', 'have', 'has', 'are', 'was', 'were', 'about',
      'nel', 'sul', 'al', 'del', 'la', 'il', 'lo', 'di', 'a',
      'da', 'in', 'su', 'per', 'tra', 'fra', 'ed', 'and', 'for',
      'notizie', 'news', 'ultime', 'ultima', 'recenti', 'dimmi', 'raccontami',
      'parlami', 'fammi', 'sapere', 'oggi', 'ieri', 'successo',
    };
    return query
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-zà-ÿ\u4e00-\u9fff0-9\s]"), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !stop.contains(w))
        .take(8)
        .toSet();
  }
}
