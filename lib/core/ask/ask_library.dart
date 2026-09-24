import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../hadith/hadith_repository.dart';
import '../quran/quran_repository.dart';
import 'ask_translation.dart';

class AskSource {
  const AskSource({
    required this.id,
    required this.title,
    required this.arabic,
    required this.english,
    required this.provenance,
    this.notes = '',
    this.sourceUrl = '',
    this.englishLabel = 'Published English',
  });
  final String id, title, arabic, english, provenance;
  final String notes, sourceUrl, englishLabel;
  factory AskSource.quran(QuranAyah ayah) => AskSource(
    id: 'quran:${ayah.surah}:${ayah.ayah}',
    title: 'Qur’an ${ayah.surah}:${ayah.ayah}',
    arabic: ayah.uthmani,
    english: ayah.words.map((w) => w.english).join(' '),
    provenance: 'Quran Foundation word-by-word English glosses; not a full verse translation or tafsir.',
  );
  factory AskSource.hadith(HadithRecord record, String collection) {
    if (record.english == null) {
      throw const FormatException('Published English unavailable');
    }
    final grades = record.grades
        .map((g) => '${g['name']}: ${g['grade']}')
        .join('; ');
    return AskSource(
      id: record.id,
      title: '$collection · ${record.number}',
      arabic: record.arabic ?? '',
      english: record.english!,
      provenance:
          'Hadith API source edition; book ${record.book}, entry ${record.bookNumber}. '
          '${grades.isEmpty ? 'No grade supplied.' : 'Reported grades: $grades.'} Not independently verified.',
    );
  }
}

const _stopWords =
    'a an the of to in on and or is are was were be been being it its this that those these for from with as at by who what when where why how do does did can could would should me my you your we our they their them he his she her have has had about tell explain please say says said islam quran hadith teaching teach teaches mean meaning learn';
List<String> askTerms(String text) {
  final stops = _stopWords.split(' ').toSet();
  return RegExp(r'[a-z0-9\u0621-\u063a\u0641-\u064a]+')
      .allMatches(normalizeHadith(text))
      .map((m) => m.group(0)!)
      .where((t) => !stops.contains(t))
      .map(
        (t) =>
            RegExp(r'^[a-z]+$').hasMatch(t) &&
                t.length > 4 &&
                t.endsWith('s') &&
                !t.endsWith('ss')
            ? t.substring(0, t.length - 1)
            : t,
      )
      .toList();
}

/// Runs off the UI isolate. Lexical retrieval is deliberately separate from AI.
List<Map<String, dynamic>> rankAskSources(Map<String, String> input) {
  final index = jsonDecode(input['index']!) as Map<String, dynamic>;
  if (index['version'] != 2 ||
      index['hadithRevision'] != HadithRepository.revision) {
    throw const FormatException('Unsupported source index');
  }
  final docs = List<Map<String, dynamic>>.from(index['documents'] as List);
  final query = input['query']!.replaceAllMapped(
    RegExp('[٠-٩]'),
    (m) => '${m[0]!.codeUnitAt(0) - 0x660}',
  );
  final filter = input['scope'] ?? 'all';
  bool allowed(Map<String, dynamic> d) =>
      filter == 'all' ||
      (filter == 'quran' ? d['surah'] != null : d['surah'] == null);
  List<Map<String, dynamic>> exactQuran(String id) =>
      docs.where((d) => d['id'] == id && allowed(d)).toList();
  final namedReference = RegExp(
    r'(?:surah|sura)\s*(\d{1,3})\s*(?:verse|ayah)\s*(\d{1,3})',
    caseSensitive: false,
  ).firstMatch(query);
  if (namedReference != null) {
    final id =
        'quran:${int.parse(namedReference[1]!)}:${int.parse(namedReference[2]!)}';
    return exactQuran(id);
  }
  final hadithReference = RegExp(
    r'\b(bukhari|muslim|abudawud|abu dawud|tirmidhi|nasai|ibnmajah|ibn majah|malik|nawawi|qudsi|dehlawi)\s*(?:hadith\s*)?#?\s*(\d+(?:\.\d+)?)\b',
    caseSensitive: false,
  ).firstMatch(query);
  if (hadithReference != null) {
    final prefix =
        '${hadithReference[1]!.toLowerCase().replaceAll(' ', '')}:${hadithReference[2]}|';
    return docs
        .where((d) => (d['id'] as String).startsWith(prefix) && allowed(d))
        .toList();
  }
  final direct = RegExp(
    r'(?:quran\s*)?(\d{1,3})\s*:\s*(\d{1,3})',
    caseSensitive: false,
  ).firstMatch(query);
  if (direct != null) {
    final id = 'quran:${int.parse(direct[1]!)}:${int.parse(direct[2]!)}';
    return exactQuran(id);
  }
  // Chapter-name references are resolved from the bundled Quran metadata.
  final namedQuery = normalizeHadith(query).replaceAll(RegExp(r"[’'`-]"), ' ');
  for (final c in (index['chapters'] as List? ?? [])) {
    final names = [
      normalizeHadith(c['name'] as String).replaceAll(RegExp(r"[’'`-]"), ' '),
      normalizeHadith(c['arabic'] as String),
    ];
    if (c['number'] == 1) names.addAll(['al fatiha', 'fatiha', 'fatihah']);
    for (final name in names) {
      final bare = name.startsWith('al ') ? name.substring(3) : name;
      final match = RegExp(
        '(?:^|\\s)(?:al\\s+)?${RegExp.escape(bare)}\\s*(?:verse|ayah|اية|:)?\\s*(\\d{1,3})(?:\\b|\$)',
        caseSensitive: false,
      ).firstMatch(namedQuery);
      if (match != null) {
        return exactQuran('quran:${c['number']}:${int.parse(match[1]!)}');
      }
    }
  }
  final terms = askTerms(query).toSet();
  if (terms.isEmpty) return [];
  final postings = index['postings'] as Map<String, dynamic>;
  final avg =
      docs.fold<double>(0, (sum, d) => sum + (d['length'] as int)) /
      docs.length;
  final scores = <int, double>{}, matches = <int, int>{};
  var searchableGroups = 0;
  for (final term in terms) {
    final groupScores = <int, double>{};
    final variants = askTermVariants(term);
    if (variants.any(postings.containsKey)) searchableGroups++;
    for (final variant in variants) {
      final rows = postings[variant] as List? ?? [];
      final df = rows.length / 2;
      final idf = log(1 + (docs.length - df + 0.5) / (df + 0.5));
      for (var n = 0; n < rows.length; n += 2) {
        final i = rows[n] as int, tf = rows[n + 1] as int;
        if (!allowed(docs[i])) continue;
        final score =
            (variant == term ? 1.0 : 0.65) *
            idf *
            tf *
            2.2 /
            (tf +
                1.2 * (0.25 + 0.75 * (docs[i]['length'] as int) / max(avg, 1)));
        groupScores[i] = max(groupScores[i] ?? 0, score);
      }
    }
    for (final entry in groupScores.entries) {
      scores[entry.key] = (scores[entry.key] ?? 0) + entry.value;
      matches[entry.key] = (matches[entry.key] ?? 0) + 1;
    }
  }
  final ranked =
      scores.keys.where((i) => matches[i]! >= min(2, searchableGroups)).toList()
        ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
  return ranked.take(12).map((i) => docs[i]).toList();
}

/// Retrieval hints only: related terms are NOT claims of religious equivalence.
Set<String> askTermVariants(String term) {
  const groups = [
    ['prayer', 'salah', 'salat', 'pray', 'praying'],
    ['charity', 'sadaqah', 'sadaqa', 'donation', 'alms'],
    ['zakat', 'zakah', 'alms'],
    ['fast', 'fasting', 'sawm', 'saum'],
    ['intention', 'niyyah', 'niyat', 'motive'],
    ['patience', 'patient', 'sabr'],
    ['forgive', 'forgiveness', 'repentance', 'tawbah'],
    ['kind', 'kindness', 'kindly', 'goodness'],
    ['parent', 'mother', 'father'],
    ['mercy', 'merciful', 'compassion', 'compassionate'],
    ['thankful', 'gratitude', 'grateful', 'thank'],
    ['backbiting', 'gossip', 'gheebah'],
    ['oneness', 'tawhid', 'tawheed', 'one'],
  ];
  return {
    term,
    for (final group in groups)
      if (group.contains(term)) ...group,
  };
}

class AskLibrary {
  AskLibrary(this.quran);
  final QuranRepository? quran;
  Future<AskTranslation>? _translation;
  Future<AskSource> enrich(AskSource source) async {
    if (!source.id.startsWith('quran:')) return source;
    late final AskTranslation translation;
    try {
      translation = await (_translation ??= AskTranslation.load());
    } catch (_) {
      _translation = null;
      rethrow;
    }
    final key = source.id.substring(6);
    final row = translation.ayah(key);
    return AskSource(
      id: source.id,
      title: source.title,
      arabic: source.arabic,
      english: row['translation'] as String,
      notes: row['footnotes'] as String? ?? '',
      englishLabel: 'Translation of the meanings',
      sourceUrl:
          'https://quranenc.com/en/browse/english_rwwad/${key.split(':')[0]}#${key.split(':')[1]}',
      provenance:
          '${translation.attribution}. Publisher notes are commentary, not Qur’anic text or AI output.',
    );
  }

  Future<List<AskSource>> search(
    String question, {
    AskSource? selected,
    String scope = 'all',
  }) async {
    if (selected != null) return [await enrich(selected)];
    final ranked = await compute(rankAskSources, {
      'index': await rootBundle.loadString(
        'assets/data/ask_index.json',
        cache: false,
      ),
      'query': question,
      'scope': scope,
    });
    final result = <AskSource>[];
    final seen = <String>{};
    for (final meta in ranked) {
      AskSource source;
      if (meta['surah'] != null) {
        source = AskSource.quran(
          quran!.getAyah(meta['surah'] as int, meta['ayah'] as int),
        );
      } else {
        final records = await compute(
          parseHadithBook,
          await rootBundle.loadString(
            'assets/data/hadith/${meta['file']}',
            cache: false,
          ),
        );
        final record = records.firstWhere((r) => r.id == meta['id']);
        source = AskSource.hadith(record, meta['collection'] as String);
      }
      // Similar editions/duplicate narrations must not crowd out all other evidence.
      source = await enrich(source);
      if (seen.add(normalizeHadith(source.english))) result.add(source);
      if (result.length == 4) break;
    }
    return result;
  }
}

class AskClaim {
  const AskClaim(this.text, this.citations);
  final String text;
  final List<int> citations;
}

class AskCitationException extends FormatException {
  const AskCitationException() : super('Unverifiable citation');
}

class AskAnswer {
  const AskAnswer(this.claims);
  final List<AskClaim> claims;

  /// This checks citation identity/shape, NOT semantic correctness or entailment.
  factory AskAnswer.parse(String response, int sourceCount) {
    final parsed = jsonDecode(response.trim());
    if (parsed is! Map || parsed['claims'] is! List) {
      throw const FormatException('Invalid answer');
    }
    final raw = parsed['claims'] as List;
    if (raw.length > 6) throw const FormatException('Answer too long');
    final claims = <AskClaim>[];
    for (final item in raw) {
      if (item is! Map || item['text'] is! String || item['sources'] is! List) {
        throw const FormatException('Invalid claim');
      }
      final text = (item['text'] as String).trim();
      final refs = item['sources'] as List;
      if (text.isEmpty || text.length > 1400) {
        throw const FormatException('Invalid claim text');
      }
      if (refs.isEmpty ||
          refs.any((v) => v is! int || v < 1 || v > sourceCount)) {
        throw const AskCitationException();
      }
      claims.add(AskClaim(text, refs.cast<int>().toSet().toList()));
    }
    return AskAnswer(claims);
  }
}

String askPrompt(String question, List<AskSource> sources) {
  String excerpt(String text, int limit) => text.length <= limit
      ? text
      : '${text.substring(0, limit)} [excerpt ends]';
  return jsonEncode({
    'question': question,
    'passages': [
      for (var i = 0; i < sources.length; i++)
        {
          'source': i + 1,
          'reference': sources[i].title,
          'english': askRelevantExcerpt(
            sources[i].english,
            question,
            sources.length == 1 ? 1800 : 1000,
          ),
          'arabic': excerpt(sources[i].arabic, 220),
          if (sources[i].notes.isNotEmpty)
            'publisherNotes': askRelevantExcerpt(
              sources[i].notes,
              question,
              sources.length == 1 ? 1200 : 400,
            ),
          'provenance': sources[i].provenance,
        },
    ],
  });
}

/// Keep a contiguous source window around relevant words, rather than always
/// throwing away the end of long narrations. Full text remains in the reader.
String askRelevantExcerpt(String text, String question, int limit) {
  if (text.length <= limit) return text;
  final terms = askTerms(question).expand(askTermVariants).toSet();
  var bestStart = 0, bestScore = 0;
  for (var start = 0; start < text.length; start += max(1, limit ~/ 3)) {
    final end = min(text.length, start + limit);
    final score = askTerms(text.substring(start, end))
        .toSet()
        .intersection(terms)
        .length;
    if (score > bestScore) {
      bestScore = score;
      bestStart = start;
    }
  }
  // Move inward to word boundaries, never rewriting the source window.
  if (bestStart > 0) {
    final space = text.indexOf(' ', bestStart);
    if (space >= 0) bestStart = space + 1;
  }
  var end = min(text.length, bestStart + limit);
  if (end < text.length) {
    final space = text.lastIndexOf(' ', end);
    if (space > bestStart) end = space;
  }
  return '${bestStart > 0 ? '[excerpt begins] ' : ''}${text.substring(bestStart, end)}${end < text.length ? ' [excerpt ends]' : ''}';
}
