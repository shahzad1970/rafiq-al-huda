import '../quran/quran_repository.dart';
import '../speech/quran_speech_engine.dart';

class RecitationPosition {
  const RecitationPosition(this.verse, this.wordIndex, this.offset);
  final QuranAyah verse;
  final int? wordIndex;
  final int offset;
}

/// Conservative acoustic-symbol locator, not pronunciation grading or text
/// correction. Corpus storage is fixed; live evidence is capped at 24 symbols.
class RecitationPositionTracker {
  RecitationPositionTracker(QuranRepository repository) {
    for (final chapter in repository.chapters) {
      for (final verse in repository.getSurah(chapter.number)) {
        _verseStart[verse] = _symbols.length;
        _verseOrder[verse] = _verseOrder.length;
        var word = 0;
        var wordEnd = verse.words.isEmpty
            ? 0
            : (verse.words.first.phonemes?.length ?? 0);
        final symbols = verse.expectedPhonemes ?? const <String>[];
        // Approximate display spans support following, never grading.
        final hasWordSpans =
            verse.words.isNotEmpty &&
            verse.words.fold<int>(0, (n, w) => n + (w.phonemes?.length ?? 0)) ==
                symbols.length;
        for (var i = 0; i < symbols.length; i++) {
          while (word + 1 < verse.words.length && i >= wordEnd) {
            word++;
            wordEnd += verse.words[word].phonemes?.length ?? 0;
          }
          _symbols.add(symbols[i]);
          _positions.add(
            RecitationPosition(
              verse,
              hasWordSpans ? word : null,
              _positions.length,
            ),
          );
          if (_symbols.length >= 3) {
            final end = _symbols.length - 1;
            _index.putIfAbsent(_key(_symbols, end), () => []).add(end);
          }
        }
      }
    }
  }

  final List<String> _symbols = [];
  final List<RecitationPosition> _positions = [];
  final Map<QuranAyah, int> _verseOrder = {};
  final Map<QuranAyah, int> _verseStart = {};
  final Map<String, List<int>> _index = {};
  final List<PhonemeRecognitionResult> _recent = [];
  RecitationPosition? position;
  int? _pending;
  int _confirmations = 0;
  int? _transitionStart;
  int get bufferedSymbols => _recent.length;

  static String _key(List<String> symbols, int end) =>
      '${symbols[end - 2]}\u0000${symbols[end - 1]}\u0000${symbols[end]}';

  void reset() {
    _recent.clear();
    position = null;
    _pending = null;
    _confirmations = 0;
    _transitionStart = null;
  }

  RecitationPosition? add(PhonemeRecognitionResult result) {
    _recent.add(result);
    if (_recent.length > 24) _recent.removeAt(0);
    if (_recent.length < 8) return null;
    if (result.confidence < .45) {
      _pending = null;
      _confirmations = 0;
      return null;
    }
    final observed = _recent.map((r) => r.decodedPhoneme).toList();
    final candidates = <int>{};
    // An exact seed may precede a missed/extra sound at the tail. Project its
    // endpoint with a one-symbol allowance, then verify against real evidence.
    for (var tail = 0; tail <= 3; tail++) {
      final seed = observed.length - 1 - tail;
      for (final anchor in _index[_key(observed, seed)] ?? const <int>[]) {
        for (var shift = -1; shift <= 1; shift++) {
          final end = anchor + tail + shift;
          if (end >= 0 && end < _symbols.length) candidates.add(end);
        }
      }
    }
    final currentVerse = position == null ? null : _verseOrder[position!.verse];
    final nearby = currentVerse == null
        ? const <int>[]
        : candidates.where(
            (end) =>
                (_verseOrder[_positions[end].verse]! - currentVerse).abs() <= 2,
          );
    // Slightly lower mean-confidence requirement only within the five nearby
    // verses. Global acquisition/jumps retain the stricter threshold.
    final normalTarget =
        _chooseTarget(nearby, minConfidence: .60) ?? _chooseTarget(candidates);
    final bridge = normalTarget == null ? _nextVersePrefix() : null;
    final target = normalTarget ?? bridge?.$1;
    if (target == null) {
      _pending = null;
      _confirmations = 0;
      return null;
    }
    final continuous =
        position != null &&
        (bridge == null ||
            identical(position!.verse, _positions[target].verse)) &&
        target > position!.offset &&
        target <= position!.offset + 5;
    if (!continuous) {
      _confirmations =
          _pending != null && target > _pending! && target <= _pending! + 5
          ? _confirmations + 1
          : 1;
      _pending = target;
      if (_confirmations < 2) return null;
    }
    position = _positions[target];
    if (bridge != null) _transitionStart = bridge.$2;
    if (_transitionStart != null &&
        (target < _transitionStart! || target >= _transitionStart! + 16)) {
      _transitionStart = null;
    }
    _pending = null;
    _confirmations = 0;
    return position;
  }

  /// A known verse ending provides context that an unrelated jump does not.
  /// Require a literal next-verse prefix, not just a few common nearby sounds.
  (int, int)? _nextVersePrefix() {
    final current = position;
    if (current == null) return null;
    final start = _verseStart[current.verse]!;
    final next = start + (current.verse.expectedPhonemes?.length ?? 0);
    final int prefixStart;
    if (_transitionStart == start && current.offset < start + 16) {
      prefixStart = start;
    } else {
      if (next - current.offset > 3 || next >= _positions.length) return null;
      final nextVerse = _positions[next].verse;
      if (nextVerse.surah != current.verse.surah ||
          nextVerse.ayah != current.verse.ayah + 1) {
        return null;
      }
      prefixStart = next;
    }
    final length = _positions[prefixStart].verse.expectedPhonemes!.length;
    for (var count = 16; count >= 4; count--) {
      if (count > _recent.length || count > length) continue;
      var confidence = 0.0;
      var matches = true;
      for (var i = 0; i < count; i++) {
        final heard = _recent[_recent.length - count + i];
        if (heard.decodedPhoneme != _symbols[prefixStart + i] ||
            heard.confidence < .45) {
          matches = false;
          break;
        }
        confidence += heard.confidence;
      }
      if (matches && confidence / count >= .60) {
        final target = prefixStart + count - 1;
        if (target > current.offset) return (target, prefixStart);
      }
    }
    return null;
  }

  int? _chooseTarget(Iterable<int> candidates, {double minConfidence = .65}) {
    if (candidates.length > 4096) return null;
    var bestScore = 0;
    var secondScore = 0;
    final best = <int>[];
    for (final end in candidates) {
      final score = _suffixScore(end, minConfidence: minConfidence);
      if (score > bestScore) {
        secondScore = bestScore;
        bestScore = score;
        best
          ..clear()
          ..add(end);
      } else if (score == bestScore && score > 0) {
        best.add(end);
      } else if (score > secondScore) {
        secondScore = score;
      }
    }
    if (best.isEmpty) {
      return null;
    }
    // A known, steadily advancing position can disambiguate repeated phrases.
    // Otherwise require a unique location, never guess a distant verse.
    final local = position == null
        ? <int>[]
        : best
              .where((p) => p > position!.offset && p <= position!.offset + 5)
              .toList();
    if (local.length == 1) {
      return local.single;
    } else if (best.length == 1 && bestScore >= secondScore + 3) {
      return best.single;
    }
    return null;
  }

  /// Bounded one-edit suffix alignment: substitution, inserted observation or
  /// omitted observation. Never edits the recognized output or grades a voice.
  int _suffixScore(
    int end, {
    int minMatches = 8,
    int maxEdits = 1,
    double minConfidence = .65,
  }) {
    // The display endpoint must itself have acoustic support. An extra tail
    // sound is handled by the UI hold until a subsequent sound anchors it.
    if (_recent.last.decodedPhoneme != _symbols[end]) return 0;
    var best = 0;
    void walk(
      int heard,
      int expected,
      int matches,
      int edits,
      double confidence,
      int count,
    ) {
      if (matches >= minMatches &&
          count > 0 &&
          confidence / count >= minConfidence) {
        final score = matches - edits * 3;
        if (score > best) best = score;
      }
      if (heard < 0 || expected < 0) return;
      final sample = _recent[heard];
      if (sample.decodedPhoneme == _symbols[expected]) {
        walk(
          heard - 1,
          expected - 1,
          matches + 1,
          edits,
          confidence + sample.confidence,
          count + 1,
        );
      } else if (edits < maxEdits) {
        walk(
          heard - 1,
          expected - 1,
          matches,
          edits + 1,
          confidence + sample.confidence,
          count + 1,
        );
        walk(
          heard - 1,
          expected,
          matches,
          edits + 1,
          confidence + sample.confidence,
          count + 1,
        );
        // Do not advance the display past the last acoustically matched sound.
        if (heard != _recent.length - 1) {
          walk(heard, expected - 1, matches, edits + 1, confidence, count);
        }
      }
    }

    walk(_recent.length - 1, end, 0, 0, 0, 0);
    return best;
  }
}
