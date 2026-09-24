import 'dart:convert';

import 'package:flutter/services.dart';

class QuranChapter {
  const QuranChapter({
    required this.number,
    required this.name,
    required this.simpleName,
    required this.arabicName,
    required this.translatedName,
    required this.versesCount,
    required this.revelationPlace,
  });

  final int number;
  final String name;
  final String simpleName;
  final String arabicName;
  final String translatedName;
  final int versesCount;
  final String revelationPlace;

  factory QuranChapter.fromJson(Map<String, dynamic> json) => QuranChapter(
    number: json['number'] as int,
    name: json['number'] == 1 ? 'Al-Fātiḥah' : json['name'] as String,
    simpleName: json['simpleName'] as String,
    arabicName: json['arabicName'] as String,
    translatedName: json['translatedName'] as String,
    versesCount: json['versesCount'] as int,
    revelationPlace: json['revelationPlace'] as String,
  );
}

class QuranWord {
  const QuranWord({
    required this.index,
    required this.text,
    required this.english,
    this.indopakText,
    this.phonemes,
    this.letterSpans,
  });
  final int index;
  final String text;
  final String english;
  final String? indopakText;
  String get displayText => indopakText ?? text;
  final List<String>? phonemes;
  final List<LetterPhonemeSpan>? letterSpans;
}

class QuranAudioSegment {
  const QuranAudioSegment(this.startMilliseconds, this.endMilliseconds);
  final int startMilliseconds;
  final int endMilliseconds;
}

class QuranReferenceAudio {
  const QuranReferenceAudio({
    required this.remoteUrl,
    required this.cacheKey,
    required this.durationMilliseconds,
    required this.wordSegments,
    this.asset,
  });
  final String? asset;
  final String remoteUrl;
  final String cacheKey;
  final int durationMilliseconds;
  final List<QuranAudioSegment> wordSegments;
}

class LetterPhonemeSpan {
  const LetterPhonemeSpan(
    this.displayStart,
    this.displayEnd,
    this.phonemeStart,
    this.phonemeEnd,
  );
  final int displayStart, displayEnd, phonemeStart, phonemeEnd;
}

/// A source-provenance span. Joined sounds may belong to multiple written
/// words, which are reviewed together instead of blaming an arbitrary word.
class QuranPronunciationGroup {
  const QuranPronunciationGroup(
    this.wordStart,
    this.wordEnd,
    this.tokenStart,
    this.tokenEnd,
  );
  final int wordStart, wordEnd, tokenStart, tokenEnd;
}

class QuranAyah {
  const QuranAyah({
    required this.surah,
    required this.ayah,
    required this.uthmani,
    required this.words,
    this.expectedPhonemes,
    this.referenceAudio,
    this.exactWordMapping = true,
    this.pronunciationGroups = const [],
    this.hasRecommendedStop = false,
    this.sajdahNumber,
    this.tajwidAnnotations = const [],
  });
  final int surah, ayah;
  final String uthmani;
  final List<QuranWord> words;
  final List<String>? expectedPhonemes;
  final QuranReferenceAudio? referenceAudio;

  /// False when Quran-Lab joins acoustic units across visible word boundaries.
  /// The full ayah sequence remains canonical; only per-word spans are estimated.
  /// Legacy follow/display spans only. Grading uses supportsPronunciation and
  /// the independently validated pronunciationGroups instead.
  final bool exactWordMapping;
  final List<QuranPronunciationGroup> pronunciationGroups;
  bool get supportsPronunciation =>
      pronunciationGroups.isNotEmpty || exactWordMapping;

  QuranPronunciationGroup? groupForWord(int index) {
    for (final group in pronunciationGroups) {
      if (index >= group.wordStart && index < group.wordEnd) return group;
    }
    return null;
  }

  QuranWord pronunciationWord(int index) {
    final group = groupForWord(index);
    if (group == null) return words[index];
    final members = words.sublist(group.wordStart, group.wordEnd);
    return QuranWord(
      index: group.wordStart,
      text: members.map((w) => w.text).join(' '),
      indopakText: members.map((w) => w.displayText).join(' '),
      english: members.map((w) => w.english).join(' '),
      phonemes: expectedPhonemes!.sublist(group.tokenStart, group.tokenEnd),
    );
  }

  QuranAyah get scoringReference => pronunciationGroups.isEmpty
      ? this
      : QuranAyah(
          surah: surah,
          ayah: ayah,
          uthmani: uthmani,
          words: [
            for (final group in pronunciationGroups)
              pronunciationWord(group.wordStart),
          ],
          expectedPhonemes: expectedPhonemes,
        );
  final bool hasRecommendedStop;
  final int? sajdahNumber;
  final List<Map<String, Object?>> tajwidAnnotations;
}

abstract interface class QuranRepository {
  List<QuranChapter> get chapters;
  QuranChapter getChapter(int surah);
  List<QuranAyah> getSurah(int surah);
  QuranAyah getAyah(int surah, int ayah);
}

extension QuranOpening on QuranRepository {
  // Verse zero is an app learning prelude, never a renumbered canonical ayah.
  bool needsOpening(int surah) {
    if (surah == 1 || surah == 9) return false;
    String letters(String text) => text
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\sـ]'), '')
        .replaceAll('ٱ', 'ا');
    return !letters(getAyah(surah, 1).uthmani)
        .startsWith(letters(getAyah(1, 1).uthmani));
  }

  int firstLessonAyah(int surah) => needsOpening(surah) ? 0 : 1;
}

class LocalQuranRepository implements QuranRepository {
  LocalQuranRepository._(this._chapters, this._ayahs);

  static const assetPath = 'assets/data/quran_v1.json';
  final List<QuranChapter> _chapters;
  final Map<String, QuranAyah> _ayahs;

  static Future<LocalQuranRepository> load() async =>
      fromJsonString(await rootBundle.loadString(assetPath));

  static LocalQuranRepository fromJsonString(String source) {
    final root = Map<String, dynamic>.from(jsonDecode(source) as Map);
    if (root['schemaVersion'] != 1) {
      throw const FormatException('Unsupported Quran data schema');
    }
    final chapters = (root['chapters'] as List)
        .map(
          (value) =>
              QuranChapter.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(growable: false);
    final ayahs = <String, QuranAyah>{};
    for (final entry in Map<String, dynamic>.from(
      root['ayahs'] as Map,
    ).entries) {
      final parts = entry.key.split(':');
      final surah = int.parse(parts[0]);
      final ayah = int.parse(parts[1]);
      final value = Map<String, dynamic>.from(entry.value as Map);
      final wordsJson = (value['words'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final words = [
        for (var index = 0; index < wordsJson.length; index++)
          QuranWord(
            index: index,
            text: wordsJson[index]['text'] as String,
            indopakText: wordsJson[index]['indopak'] as String?,
            english: wordsJson[index]['english'] as String,
            phonemes: (wordsJson[index]['phonemes'] as List).cast<String>(),
          ),
      ];
      final audioJson = Map<String, dynamic>.from(value['audio'] as Map);
      final segments = (audioJson['segments'] as List)
          .map((item) {
            final segment = (item as List).cast<int>();
            return QuranAudioSegment(segment[0], segment[1]);
          })
          .toList(growable: false);
      final paddedSurah = surah.toString().padLeft(3, '0');
      final paddedAyah = ayah.toString().padLeft(3, '0');
      final groups = <QuranPronunciationGroup>[];
      var nextWord = 0, nextToken = 0;
      final tokenCount = words.fold<int>(0, (n, w) => n + w.phonemes!.length);
      for (final raw in value['pronunciationGroups'] as List? ?? const []) {
        final span = (raw as List).cast<int>();
        if (span.length != 4 ||
            span[0] != nextWord ||
            span[2] != nextToken ||
            span[1] <= span[0] ||
            span[3] <= span[2] ||
            span[1] > words.length ||
            span[3] > tokenCount) {
          throw FormatException('Invalid pronunciation mapping: ${entry.key}');
        }
        groups.add(QuranPronunciationGroup(span[0], span[1], span[2], span[3]));
        nextWord = span[1];
        nextToken = span[3];
      }
      if (value.containsKey('pronunciationGroups') &&
          (groups.isEmpty ||
              nextWord != words.length ||
              nextToken != tokenCount)) {
        throw FormatException('Incomplete pronunciation mapping: ${entry.key}');
      }
      ayahs[entry.key] = QuranAyah(
        surah: surah,
        ayah: ayah,
        uthmani: value['uthmani'] as String,
        words: words,
        expectedPhonemes: words
            .expand((word) => word.phonemes!)
            .toList(growable: false),
        exactWordMapping: value['exactWordMapping'] as bool? ?? true,
        pronunciationGroups: groups,
        hasRecommendedStop: value['hasRecommendedStop'] as bool? ?? false,
        sajdahNumber: value['sajdahNumber'] as int?,
        referenceAudio: QuranReferenceAudio(
          asset: surah == 1
              ? 'assets/audio/abdulbaset_mujawwad/$paddedSurah$paddedAyah.mp3'
              : null,
          remoteUrl: audioJson['url'] as String,
          cacheKey: '$paddedSurah$paddedAyah.mp3',
          durationMilliseconds: audioJson['durationMs'] as int,
          wordSegments: segments,
        ),
      );
    }
    if (chapters.length != 114 || ayahs.length != 6236) {
      throw FormatException(
        'Incomplete Quran data: ${chapters.length} surahs, '
        '${ayahs.length} ayahs',
      );
    }
    return LocalQuranRepository._(chapters, ayahs);
  }

  @override
  List<QuranChapter> get chapters => _chapters;

  @override
  QuranChapter getChapter(int surah) => _chapters.firstWhere(
    (chapter) => chapter.number == surah,
    orElse: () => throw StateError('Surah not installed: $surah'),
  );

  @override
  List<QuranAyah> getSurah(int surah) => [
    for (var ayah = 1; ayah <= getChapter(surah).versesCount; ayah++)
      getAyah(surah, ayah),
  ];

  @override
  QuranAyah getAyah(int surah, int ayah) {
    getChapter(surah);
    if (ayah == 0 && needsOpening(surah)) {
      final source = _ayahs['1:1']!;
      return QuranAyah(
        surah: surah,
        ayah: 0,
        uthmani: source.uthmani,
        words: source.words,
        expectedPhonemes: source.expectedPhonemes,
        referenceAudio: source.referenceAudio,
        exactWordMapping: source.exactWordMapping,
        pronunciationGroups: source.pronunciationGroups,
      );
    }
    return _ayahs['$surah:$ayah'] ??
        (throw StateError('Ayah not installed: $surah:$ayah'));
  }
}
