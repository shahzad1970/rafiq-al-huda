import '../alignment/quran_alignment_engine.dart';
import '../quran/quran_repository.dart';
import '../speech/quran_speech_engine.dart';
import 'pronunciation_error.dart';

abstract interface class PronunciationScoringEngine {
  /// Only validated acoustic alignment may produce errors. Implement in Phase 7.
  List<PronunciationError> score({
    required QuranAyah expected,
    required List<PhonemeRecognitionResult> detected,
    required List<PhonemeAlignment> alignment,
    required bool utteranceFinalized,
  });
}

class DeterministicPronunciationScoringEngine
    implements PronunciationScoringEngine {
  const DeterministicPronunciationScoringEngine({
    this.minimumConfidence = 0.70,
    this.minimumMarginPeak = 0.35,
    this.confirmedConfidence = 0.90,
    this.confirmedMarginPeak = 0.60,
  });

  final double minimumConfidence;
  final double minimumMarginPeak;
  final double confirmedConfidence;
  final double confirmedMarginPeak;

  @override
  List<PronunciationError> score({
    required QuranAyah expected,
    required List<PhonemeRecognitionResult> detected,
    required List<PhonemeAlignment> alignment,
    required bool utteranceFinalized,
  }) {
    if (expected.pronunciationGroups.isNotEmpty) {
      return score(
        expected: expected.scoringReference,
        detected: detected,
        alignment: alignment,
        utteranceFinalized: utteranceFinalized,
      );
    }
    if (!utteranceFinalized || expected.expectedPhonemes == null) {
      return const [];
    }
    final ranges = _wordRanges(expected);
    final repeated = _repeatedWords(expected, detected, alignment);
    final repeatedDetectedIndices = repeated.repeatedDetectedIndices;
    final fullyDeletedWords = <int>{};
    for (var wordIndex = 0; wordIndex < ranges.length; wordIndex++) {
      final range = ranges[wordIndex];
      final items = alignment.where(
        (item) =>
            item.expectedIndex != null &&
            item.expectedIndex! >= range.start &&
            item.expectedIndex! < range.end,
      );
      if (items.length == range.end - range.start &&
          items.every((item) => item.kind == AlignmentKind.deletion)) {
        fullyDeletedWords.add(wordIndex);
      }
    }

    final errors = <PronunciationError>[...repeated.errors];
    for (final wordIndex in fullyDeletedWords) {
      final word = expected.words[wordIndex];
      errors.add(
        PronunciationError(
          surah: expected.surah,
          ayah: expected.ayah,
          wordIndex: word.index,
          word: word.text,
          expectedPhoneme: word.phonemes?.join(),
          detectedPhoneme: null,
          confidence: 0,
          type: PronunciationErrorType.skippedWord,
          severity: ErrorSeverity.low,
          evidenceStatus: EvidenceStatus.lowConfidenceSuggestion,
        ),
      );
    }

    for (
      var alignmentIndex = 0;
      alignmentIndex < alignment.length;
      alignmentIndex++
    ) {
      final item = alignment[alignmentIndex];
      final expectedIndex = item.expectedIndex;
      final mappedWord = _wordForExpectedIndex(
        expectedIndex ?? _nearestExpectedIndex(alignment, alignmentIndex),
        ranges,
      );
      if (mappedWord == null || fullyDeletedWords.contains(mappedWord)) {
        continue;
      }
      final word = expected.words[mappedWord];
      final recognized = item.detectedIndex == null
          ? null
          : detected[item.detectedIndex!];
      switch (item.kind) {
        case AlignmentKind.correct:
          break;
        case AlignmentKind.substitution:
          if (!_strongEnough(recognized)) break;
          errors.add(
            _error(
              ayah: expected,
              word: word,
              wordIndex: word.index,
              expectedPhoneme: expected.expectedPhonemes![expectedIndex!],
              detectedPhoneme: recognized!.decodedPhoneme,
              recognized: recognized,
              type: PronunciationErrorType.substitution,
              severity: ErrorSeverity.moderate,
            ),
          );
        case AlignmentKind.deletion:
          errors.add(
            PronunciationError(
              surah: expected.surah,
              ayah: expected.ayah,
              wordIndex: word.index,
              word: word.text,
              expectedPhoneme: expected.expectedPhonemes![expectedIndex!],
              detectedPhoneme: null,
              confidence: 0,
              type: PronunciationErrorType.deletion,
              severity: ErrorSeverity.low,
              evidenceStatus: EvidenceStatus.lowConfidenceSuggestion,
            ),
          );
        case AlignmentKind.insertion:
          if (item.detectedIndex != null &&
              repeatedDetectedIndices.contains(item.detectedIndex)) {
            break;
          }
          if (!_strongEnough(recognized)) break;
          final nearbyExpected = _nearestExpectedIndex(
            alignment,
            alignmentIndex,
          );
          final expectedSymbol = nearbyExpected == null
              ? null
              : expected.expectedPhonemes![nearbyExpected];
          final repeated = expectedSymbol == recognized!.decodedPhoneme;
          errors.add(
            _error(
              ayah: expected,
              word: word,
              wordIndex: word.index,
              expectedPhoneme: expectedSymbol,
              detectedPhoneme: recognized.decodedPhoneme,
              recognized: recognized,
              type: repeated
                  ? PronunciationErrorType.repeatedPhoneme
                  : PronunciationErrorType.insertion,
              severity: ErrorSeverity.low,
            ),
          );
      }
    }
    return errors;
  }

  ({List<PronunciationError> errors, Set<int> repeatedDetectedIndices})
  _repeatedWords(
    QuranAyah expected,
    List<PhonemeRecognitionResult> detected,
    List<PhonemeAlignment> alignment,
  ) {
    final inserted = alignment
        .where((item) => item.kind == AlignmentKind.insertion)
        .map((item) => item.detectedIndex)
        .toSet();
    final symbols = detected
        .map((item) => item.decodedPhoneme)
        .toList(growable: false);
    final errors = <PronunciationError>[];
    final repeatedIndices = <int>{};
    for (var wordIndex = 0; wordIndex < expected.words.length; wordIndex++) {
      final word = expected.words[wordIndex];
      final pattern = word.phonemes;
      if (pattern == null || pattern.length < 2) continue;
      for (
        var start = 0;
        start + pattern.length * 2 <= symbols.length;
        start++
      ) {
        if (!_matches(symbols, start, pattern) ||
            !_matches(symbols, start + pattern.length, pattern)) {
          continue;
        }
        final secondStart = start + pattern.length;
        // Repetition that belongs to the canonical verse is not an error.
        // Require one entire extra copy supported by insertion alignment.
        if (!List.generate(
              pattern.length,
              (i) => start + i,
            ).every(inserted.contains) &&
            !List.generate(
              pattern.length,
              (i) => secondStart + i,
            ).every(inserted.contains)) {
          continue;
        }
        final evidence = detected.sublist(
          secondStart,
          secondStart + pattern.length,
        );
        if (!evidence.every(_strongEnough)) continue;
        repeatedIndices.addAll(
          Iterable<int>.generate(pattern.length * 2, (index) => start + index),
        );
        final confidence = evidence
            .map((item) => item.confidence)
            .reduce((a, b) => a < b ? a : b);
        final margin = evidence
            .map((item) => item.marginPeak)
            .reduce((a, b) => a < b ? a : b);
        errors.add(
          PronunciationError(
            surah: expected.surah,
            ayah: expected.ayah,
            wordIndex: word.index,
            word: word.text,
            expectedPhoneme: pattern.join(),
            detectedPhoneme: [...pattern, ...pattern].join(),
            confidence: confidence,
            marginPeak: margin,
            type: PronunciationErrorType.repeatedWord,
            severity: ErrorSeverity.low,
            evidenceStatus:
                confidence >= confirmedConfidence &&
                    margin >= confirmedMarginPeak
                ? EvidenceStatus.confirmed
                : EvidenceStatus.lowConfidenceSuggestion,
          ),
        );
        break;
      }
    }
    return (errors: errors, repeatedDetectedIndices: repeatedIndices);
  }

  bool _matches(List<String> symbols, int start, List<String> pattern) {
    for (var index = 0; index < pattern.length; index++) {
      if (symbols[start + index] != pattern[index]) return false;
    }
    return true;
  }

  bool _strongEnough(PhonemeRecognitionResult? result) =>
      result != null &&
      result.confidence >= minimumConfidence &&
      result.marginPeak >= minimumMarginPeak;

  PronunciationError _error({
    required QuranAyah ayah,
    required QuranWord word,
    required int wordIndex,
    required String? expectedPhoneme,
    required String? detectedPhoneme,
    required PhonemeRecognitionResult recognized,
    required PronunciationErrorType type,
    required ErrorSeverity severity,
  }) => PronunciationError(
    surah: ayah.surah,
    ayah: ayah.ayah,
    wordIndex: wordIndex,
    word: word.text,
    expectedPhoneme: expectedPhoneme,
    detectedPhoneme: detectedPhoneme,
    confidence: recognized.confidence,
    marginPeak: recognized.marginPeak,
    type: type,
    severity: severity,
    evidenceStatus:
        recognized.confidence >= confirmedConfidence &&
            recognized.marginPeak >= confirmedMarginPeak
        ? EvidenceStatus.confirmed
        : EvidenceStatus.lowConfidenceSuggestion,
  );

  List<({int start, int end})> _wordRanges(QuranAyah ayah) {
    var start = 0;
    return [
      for (final word in ayah.words)
        (start: start, end: start += word.phonemes?.length ?? 0),
    ];
  }

  int? _wordForExpectedIndex(
    int? expectedIndex,
    List<({int start, int end})> ranges,
  ) {
    if (expectedIndex == null) return null;
    final result = ranges.indexWhere(
      (range) => expectedIndex >= range.start && expectedIndex < range.end,
    );
    return result < 0 ? null : result;
  }

  int? _nearestExpectedIndex(List<PhonemeAlignment> alignment, int index) {
    for (var offset = 1; offset < alignment.length; offset++) {
      final before = index - offset;
      if (before >= 0 && alignment[before].expectedIndex != null) {
        return alignment[before].expectedIndex;
      }
      final after = index + offset;
      if (after < alignment.length && alignment[after].expectedIndex != null) {
        return alignment[after].expectedIndex;
      }
    }
    return null;
  }
}
