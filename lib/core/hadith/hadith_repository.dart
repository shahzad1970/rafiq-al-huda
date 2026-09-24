import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

String normalizeHadith(String text) => text
    .toLowerCase()
    .replaceAll(
      RegExp(r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed\u0640]'),
      '',
    )
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي');

class HadithBook {
  HadithBook(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = json['title'] as String,
      file = json['file'] as String,
      count = json['count'] as int,
      numbers = Set<String>.from(json['numbers'] as List);
  final String id, title, file;
  final int count;
  final Set<String> numbers;
}

class HadithCollection {
  HadithCollection(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = json['title'] as String,
      count = json['count'] as int,
      unavailableCount = json['unavailableCount'] as int,
      englishEdition = json['englishEdition'] as String,
      arabicEdition = json['arabicEdition'] as String,
      books = (json['books'] as List)
          .map((b) => HadithBook(b as Map<String, dynamic>))
          .toList();
  final String id, title, englishEdition, arabicEdition;
  final int count, unavailableCount;
  final List<HadithBook> books;
  List<HadithBook> search(String query) {
    final q = normalizeHadith(query.trim());
    return books
        .where(
          (b) =>
              q.isEmpty ||
              normalizeHadith(b.title).contains(q) ||
              b.numbers.contains(q),
        )
        .toList();
  }
}

class HadithRecord {
  HadithRecord(Map<String, dynamic> json)
    : id = json['id'] as String,
      number = json['number'] as String,
      book = json['book'] as String,
      bookNumber = json['bookNumber'] as String,
      arabic = json['arabic'] as String?,
      english = json['english'] as String?,
      aiEnglish = json['aiEnglish'] as String?,
      aiTranslationNote = json['aiTranslationNote'] as String?,
      grades = List<Map<String, dynamic>>.from(json['grades'] as List);
  final String id, number, book, bookNumber;
  final String? arabic, english, aiEnglish, aiTranslationNote;
  bool get usesAiTranslation =>
      english == null && arabic != null && aiEnglish != null;
  String? get displayEnglish => english ?? (arabic != null ? aiEnglish : null);
  static const aiTranslationLabel = 'AI translation — not scholar-reviewed';
  String get englishForCopy => usesAiTranslation
      ? '$aiTranslationLabel\n$aiEnglish${aiTranslationNote == null ? '' : '\n\nTranslation note: $aiTranslationNote'}'
      : (english ?? 'English translation unavailable.');
  final List<Map<String, dynamic>> grades;
  late final String searchText = normalizeHadith(
    '${displayEnglish ?? ''} ${arabic ?? ''}',
  );
  bool matches(String query) {
    final q = normalizeHadith(query.trim());
    if (q.isEmpty || q == number) return true;
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(q)) return false;
    return q.split(RegExp(r'\s+')).every(searchText.contains);
  }
}

List<HadithRecord> parseHadithBook(String source) =>
    (jsonDecode(source) as List)
        .map((h) => HadithRecord(h as Map<String, dynamic>))
        .toList();

class HadithRepository {
  HadithRepository({Future<String> Function(String)? loader})
    : _load = loader ?? ((path) => rootBundle.loadString(path));
  static const assetRoot = 'assets/data/hadith';
  static const revision = 'df57907be35291c91ad6a6691180e22ca9920784';
  final Future<String> Function(String) _load;
  Future<List<HadithCollection>>? _catalog;
  final _cache = <String, List<HadithRecord>>{};
  Future<List<HadithCollection>> collections() => _catalog ??= _readCatalog();
  Future<List<HadithCollection>> _readCatalog() async {
    try {
      final json = jsonDecode(
        await _load('$assetRoot/catalog.json'),
      ) as Map<String, dynamic>;
      if (json['version'] != 1 || json['commit'] != revision) {
        throw const FormatException('Unsupported catalog');
      }
      return (json['collections'] as List)
          .map((c) => HadithCollection(c as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _catalog = null;
      rethrow;
    }
  }

  Future<List<HadithRecord>> loadBook(HadithBook book) async {
    final cached = _cache.remove(book.file);
    if (cached != null) {
      _cache[book.file] = cached;
      return cached;
    }
    final records = await compute(
      parseHadithBook,
      await _load('$assetRoot/${book.file}'),
    );
    if (records.length != book.count) {
      throw const FormatException('Incomplete hadith book');
    }
    _cache[book.file] = records;
    while (_cache.length > 2) {
      _cache.remove(_cache.keys.first);
    }
    return records;
  }

  void clearCache() => _cache.clear();
}
