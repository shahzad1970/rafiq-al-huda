import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../alignment/word_feedback_engine.dart';
import '../scoring/pronunciation_error.dart';

class PracticeRecord {
  const PracticeRecord({
    required this.surah,
    required this.ayah,
    required this.wordIndex,
    required this.word,
    required this.status,
    required this.meanConfidence,
    required this.practicedAt,
    required this.findings,
  });

  final int surah;
  final int ayah;
  final int wordIndex;
  final String word;
  final WordFeedbackStatus status;
  final double? meanConfidence;
  final DateTime practicedAt;
  final List<Map<String, Object?>> findings;

  Map<String, Object?> toJson() => {
    'surah': surah,
    'ayah': ayah,
    'wordIndex': wordIndex,
    'word': word,
    'status': status.name,
    'meanConfidence': meanConfidence,
    'practicedAt': practicedAt.toUtc().toIso8601String(),
    'findings': findings,
  };

  factory PracticeRecord.fromJson(Map<String, Object?> json) => PracticeRecord(
    surah: json['surah']! as int,
    ayah: json['ayah']! as int,
    wordIndex: json['wordIndex']! as int,
    word: json['word']! as String,
    status: WordFeedbackStatus.values.byName(json['status']! as String),
    meanConfidence: (json['meanConfidence'] as num?)?.toDouble(),
    practicedAt: DateTime.parse(json['practicedAt']! as String),
    findings: (json['findings']! as List)
        .map((item) => Map<String, Object?>.from(item as Map))
        .toList(growable: false),
  );
}

class WeakWordSummary {
  const WeakWordSummary({
    required this.surah,
    required this.ayah,
    required this.wordIndex,
    required this.word,
    required this.reviewCount,
  });

  final int surah;
  final int ayah;
  final int wordIndex;
  final String word;
  final int reviewCount;
}

abstract interface class ProgressStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> remove();
}

class PreferencesProgressStore implements ProgressStore {
  PreferencesProgressStore(this.preferences);

  static const key = 'practice_history_v1';
  final SharedPreferencesAsync preferences;

  @override
  Future<String?> read() => preferences.getString(key);

  @override
  Future<void> write(String value) => preferences.setString(key, value);

  @override
  Future<void> remove() => preferences.remove(key);
}

class LocalProgressRepository extends ChangeNotifier {
  LocalProgressRepository(this.store);

  static const maximumRecords = 200;
  final ProgressStore store;
  final List<PracticeRecord> _records = [];

  List<PracticeRecord> get records => List.unmodifiable(_records);
  int get totalAttempts => _records.length;
  int get acceptedAttempts => _records
      .where((record) => record.status == WordFeedbackStatus.accepted)
      .length;
  int get reviewAttempts => _records
      .where((record) => record.status == WordFeedbackStatus.needsReview)
      .length;

  Future<void> load() async {
    final encoded = await store.read();
    if (encoded == null) return;
    try {
      final values = jsonDecode(encoded) as List;
      _records
        ..clear()
        ..addAll(
          values.map(
            (item) =>
                PracticeRecord.fromJson(Map<String, Object?>.from(item as Map)),
          ),
        );
    } on FormatException {
      await store.remove();
      _records.clear();
    }
    notifyListeners();
  }

  Future<void> add({
    required int surah,
    required int ayah,
    required int wordIndex,
    required String word,
    required WordFeedbackStatus status,
    required double? meanConfidence,
    required List<PronunciationError> findings,
  }) async {
    _records.insert(
      0,
      PracticeRecord(
        surah: surah,
        ayah: ayah,
        wordIndex: wordIndex,
        word: word,
        status: status,
        meanConfidence: meanConfidence,
        practicedAt: DateTime.now().toUtc(),
        findings: findings.map((finding) => finding.toJson()).toList(),
      ),
    );
    if (_records.length > maximumRecords) {
      _records.removeRange(maximumRecords, _records.length);
    }
    notifyListeners();
    await _persist();
  }

  Map<String, int> get weakWords {
    final counts = <String, int>{};
    for (final record in _records.where(
      (record) => record.status == WordFeedbackStatus.needsReview,
    )) {
      final key =
          '${record.surah}:${record.ayah}:${record.wordIndex}:${record.word}';
      counts.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    return Map.fromEntries(
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  List<WeakWordSummary> get weakWordSummaries {
    final summaries = <String, WeakWordSummary>{};
    for (final record in _records.where(
      (record) => record.status == WordFeedbackStatus.needsReview,
    )) {
      final key = '${record.surah}:${record.ayah}:${record.wordIndex}';
      final existing = summaries[key];
      summaries[key] = WeakWordSummary(
        surah: record.surah,
        ayah: record.ayah,
        wordIndex: record.wordIndex,
        word: record.word,
        reviewCount: (existing?.reviewCount ?? 0) + 1,
      );
    }
    return summaries.values.toList()
      ..sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
  }

  Future<void> deleteAll() async {
    _records.clear();
    notifyListeners();
    await store.remove();
  }

  Future<void> _persist() => store.write(
    jsonEncode(_records.map((record) => record.toJson()).toList()),
  );
}
