// Generates the app's offline Quran index from canonical, model-compatible data.
//
// Sources:
// - Quran-Lab ordered_quran_phonemes.json and tokens.txt (local authorized copy)
// - Quran.com Content API v4 chapter/verse data
//
// Run from the repository root with:
//   dart run tool/generate_quran_data.dart
import 'dart:convert';
import 'dart:io';

const _api = 'https://api.quran.com/api/v4';

Future<Map<String, dynamic>> _getJson(String url) async {
  Object? lastError;
  for (var attempt = 1; attempt <= 4; attempt++) {
    final client = HttpClient()
      ..userAgent = 'Quran Teacher AI local data builder';
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 QuranTeacherAI/0.1',
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != 200) {
        throw HttpException(
          'HTTP ${response.statusCode}: $body',
          uri: Uri.parse(url),
        );
      }
      return Map<String, dynamic>.from(jsonDecode(body) as Map);
    } catch (error) {
      lastError = error;
      if (attempt < 4) await Future<void>.delayed(Duration(seconds: attempt));
    } finally {
      client.close(force: true);
    }
  }
  throw StateError('Could not fetch $url: $lastError');
}

List<String> _tokenize(String value, List<String> tokens) {
  final best = List<List<String>?>.filled(value.length + 1, null);
  best[value.length] = const [];
  for (var offset = value.length - 1; offset >= 0; offset--) {
    for (final token in tokens) {
      if (value.startsWith(token, offset) &&
          best[offset + token.length] != null) {
        best[offset] = [token, ...best[offset + token.length]!];
        break;
      }
    }
  }
  return best[0] ??
      (throw FormatException('Cannot tokenize Quran-Lab value: $value'));
}

String _plainEnglish(Object? value) => (value?.toString() ?? '')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .trim();

List<List<String>> _partitionPhonemes(
  List<String> modelWords,
  List<Map<String, dynamic>> displayWords,
  List<String> tokens,
) {
  final flat = modelWords.expand((word) => _tokenize(word, tokens)).toList();
  if (displayWords.length == 1) return [flat];
  final weights = displayWords
      .map(
        (word) => (word['text_uthmani'] as String)
            .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06EDـ\s]'), '')
            .length
            .clamp(1, 1000),
      )
      .toList();
  final totalWeight = weights.fold<int>(0, (sum, value) => sum + value);
  final result = <List<String>>[];
  var tokenOffset = 0;
  var weightOffset = 0;
  for (var i = 0; i < displayWords.length; i++) {
    weightOffset += weights[i];
    final remainingWords = displayWords.length - i - 1;
    final desiredEnd = i == displayWords.length - 1
        ? flat.length
        : (flat.length * weightOffset / totalWeight).round();
    final end = desiredEnd.clamp(tokenOffset + 1, flat.length - remainingWords);
    result.add(flat.sublist(tokenOffset, end));
    tokenOffset = end;
  }
  return result;
}

List<List<int>> _partitionAudio(
  List<List<int>> source,
  List<Map<String, dynamic>> displayWords,
) {
  if (source.isEmpty) return const [];
  final start = source.first[0];
  final end = source.last[1];
  final weights = displayWords
      .map(
        (word) => (word['text_uthmani'] as String)
            .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06EDـ\s]'), '')
            .length
            .clamp(1, 1000),
      )
      .toList();
  final totalWeight = weights.fold<int>(0, (sum, value) => sum + value);
  var weightOffset = 0;
  var previous = start;
  return [
    for (var i = 0; i < displayWords.length; i++)
      () {
        weightOffset += weights[i];
        final next = i == displayWords.length - 1
            ? end
            : start + ((end - start) * weightOffset / totalWeight).round();
        final segment = [previous, next];
        previous = next;
        return segment;
      }(),
  ];
}

Future<void> main() async {
  final mappingPython = Platform.environment['QURAN_MAPPING_PYTHON'];
  if (mappingPython == null) {
    throw StateError(
      'Set QURAN_MAPPING_PYTHON to the Python environment with the pinned quran-transcript dependency. See docs/QURAN_WORD_MAPPING.md.',
    );
  }
  final phonemeSource = Map<String, dynamic>.from(
    jsonDecode(
      await File('models/quran_lab/v3_1/ordered_quran_phonemes.json')
          .readAsString(),
    ) as Map,
  );
  final tokens =
      (await File('models/quran_lab/v3_1/tokens.txt').readAsLines())
          .map((line) => line.substring(0, line.lastIndexOf(' ')))
          .where((token) => token != '<blank>')
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));

  final chapterResponse = await _getJson('$_api/chapters?language=en');
  final chapters = (chapterResponse['chapters'] as List)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();

  final outputChapters = <Map<String, Object?>>[];
  final outputAyahs = <String, Object?>{};
  for (final chapter in chapters) {
    final number = chapter['id'] as int;
    stdout.writeln('Loading surah $number of 114…');
    final response = await _getJson(
      '$_api/verses/by_chapter/$number?language=en&words=true'
      '&word_fields=text_uthmani,text_indopak&audio=1&fields=text_uthmani&per_page=300',
    );
    final verses = (response['verses'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    if (verses.length != chapter['verses_count']) {
      throw StateError('Surah $number returned ${verses.length} verses');
    }
    outputChapters.add({
      'number': number,
      'name': chapter['name_complex'],
      'simpleName': chapter['name_simple'],
      'arabicName': chapter['name_arabic'],
      'translatedName': (chapter['translated_name'] as Map)['name'],
      'versesCount': chapter['verses_count'],
      'revelationPlace': chapter['revelation_place'],
    });
    for (final verse in verses) {
      final key = verse['verse_key'] as String;
      final canonical = Map<String, dynamic>.from(phonemeSource[key] as Map);
      final modelWords = (canonical['aya_phonemes_list'] as List)
          .cast<String>();
      final apiWords = (verse['words'] as List)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .where((word) => word['char_type_name'] == 'word')
          .toList();
      final exactWordMapping = modelWords.length == apiWords.length;
      final phonemesByDisplayWord = exactWordMapping
          ? modelWords.map((word) => _tokenize(word, tokens)).toList()
          : _partitionPhonemes(modelWords, apiWords, tokens);
      if (!exactWordMapping) {
        stdout.writeln(
          '  $key: canonical acoustic units=${modelWords.length}, display words=${apiWords.length}; preserving full sequence with approximate word spans',
        );
      }
      final audio = Map<String, dynamic>.from(verse['audio'] as Map);
      var segments = (audio['segments'] as List? ?? const [])
          .map(
            (value) =>
                (value as List).map((item) => int.parse('$item')).toList(),
          )
          .where((segment) => segment.length >= 4)
          .map((segment) => [segment[2], segment[3]])
          .toList();
      if (segments.length != apiWords.length) {
        if (key == '1:4') {
          segments = const [
            [800, 2800],
            [2800, 3800],
            [3800, 6600],
          ];
        } else {
          segments = _partitionAudio(segments, apiWords);
        }
      }
      outputAyahs[key] = {
        'uthmani': canonical['aya_text'],
        'exactWordMapping': exactWordMapping,
        'sajdahNumber': verse['sajdah_number'],
        'hasRecommendedStop': apiWords.any((word) {
          final text = word['text_indopak'] as String? ?? '';
          // U+06D7 = preferred pause and U+06D8 = necessary pause.
          // U+06DA (merely permissible), U+06D6 (preferred continuation),
          // and U+06D9 (do not pause) intentionally do not qualify.
          return text.contains('\u06D7') || text.contains('\u06D8');
        }),
        'words': [
          for (var i = 0; i < apiWords.length; i++)
            {
              'text': apiWords[i]['text_uthmani'],
              'indopak': apiWords[i]['text_indopak'],
              'english': _plainEnglish(
                (apiWords[i]['translation'] as Map?)?['text'],
              ),
              'phonemes': phonemesByDisplayWord[i],
            },
        ],
        'audio': {
          'url': 'https://verses.quran.foundation/${audio['url']}',
          'durationMs': segments
              .map((segment) => segment[1])
              .fold<int>(0, (a, b) => a > b ? a : b),
          'segments': segments,
        },
      };
    }
  }
  if (outputAyahs.length != 6236) {
    throw StateError('Expected 6236 ayahs, generated ${outputAyahs.length}');
  }
  final output = {
    'schemaVersion': 1,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'quranLabRevision': '506422c82a81c86e7ae74a5a2ab4641724bcd3b3',
    'quranLabPhonemeSha256':
        '4782e90e190a59207f5d74a909dd917a0cfead1959338d1fbc97fe55faf1c09c',
    'quranLabTokensSha256':
        '252c10687e442aa9291973065fae19fa39bcd681c4f5612ec496a647e20b43a1',
    'contentSource': 'Quran.com Content API v4',
    'chapters': outputChapters,
    'ayahs': outputAyahs,
  };
  final file = File('assets/data/quran_v1.json');
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(output), flush: true);
  final mapping = await Process.run(mappingPython, [
    'tool/build_quran_word_mapping.py',
    '--write',
  ]);
  stdout.write(mapping.stdout);
  if (mapping.exitCode != 0) {
    throw StateError(
      'Pronunciation mapping failed; do not ship this generated asset: ${mapping.stderr}',
    );
  }
  stdout.writeln(
    'Wrote ${file.path} (${await file.length()} bytes, ${outputAyahs.length} ayahs).',
  );
}
