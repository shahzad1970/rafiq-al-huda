import '../quran/quran_repository.dart';
import '../speech/quran_speech_engine.dart';
import 'quran_alignment_engine.dart';

enum WordFeedbackStatus { unread, current, accepted, needsReview, uncertain }

class WordFeedback {
  const WordFeedback({
    required this.word,
    required this.status,
    required this.meanConfidence,
  });

  final QuranWord word;
  final WordFeedbackStatus status;
  final double? meanConfidence;
}

/// Maps deterministic phoneme alignment to conservative word-level UI state.
/// It does not diagnose tajwid or create pronunciation errors.
class WordFeedbackEngine {
  const WordFeedbackEngine({
    this.acceptedConfidence = 0.45,
    this.reviewConfidence = 0.70,
    this.acceptedMarginPeak = 0.20,
    this.reviewMarginPeak = 0.35,
  });

  final double acceptedConfidence;
  final double reviewConfidence;
  final double acceptedMarginPeak;
  final double reviewMarginPeak;

  List<WordFeedback> evaluate({
    required QuranAyah ayah,
    required List<PhonemeRecognitionResult> detected,
    required List<PhonemeAlignment> alignment,
    required bool utteranceFinalized,
  }) {
    if (ayah.pronunciationGroups.isNotEmpty) {
      final grouped = evaluate(
        ayah: ayah.scoringReference,
        detected: detected,
        alignment: alignment,
        utteranceFinalized: utteranceFinalized,
      );
      return [
        for (var i = 0; i < ayah.pronunciationGroups.length; i++)
          for (
            var word = ayah.pronunciationGroups[i].wordStart;
            word < ayah.pronunciationGroups[i].wordEnd;
            word++
          )
            WordFeedback(
              word: ayah.words[word],
              status: grouped[i].status,
              meanConfidence: grouped[i].meanConfidence,
            ),
      ];
    }
    if (detected.isEmpty) {
      return [
        for (final word in ayah.words)
          WordFeedback(
            word: word,
            status: WordFeedbackStatus.unread,
            meanConfidence: null,
          ),
      ];
    }

    final lastObserved = alignment.lastIndexWhere(
      (item) => item.detectedIndex != null,
    );
    final observed = utteranceFinalized
        ? alignment
        : lastObserved < 0
        ? const <PhonemeAlignment>[]
        : alignment.sublist(0, lastObserved + 1);
    final furthestExpected = observed
        .where((item) => item.expectedIndex != null)
        .fold<int>(
          -1,
          (value, item) =>
              value > item.expectedIndex! ? value : item.expectedIndex!,
        );
    final ranges = _ranges(ayah.words);
    final currentWordIndex = ranges.indexWhere(
      (range) =>
          furthestExpected >= range.start && furthestExpected < range.end,
    );

    final feedback = [
      for (var wordIndex = 0; wordIndex < ayah.words.length; wordIndex++)
        _evaluateWord(
          word: ayah.words[wordIndex],
          range: ranges[wordIndex],
          wordIndex: wordIndex,
          currentWordIndex: currentWordIndex,
          observed: observed,
          detected: detected,
          utteranceFinalized: utteranceFinalized,
        ),
    ];
    if (ayah.exactWordMapping) return feedback;
    return [
      for (final item in feedback)
        WordFeedback(
          word: item.word,
          status: item.status == WordFeedbackStatus.current
              ? WordFeedbackStatus.current
              : item.status == WordFeedbackStatus.unread
              ? WordFeedbackStatus.unread
              : WordFeedbackStatus.uncertain,
          meanConfidence: item.meanConfidence,
        ),
    ];
  }

  WordFeedback _evaluateWord({
    required QuranWord word,
    required ({int start, int end}) range,
    required int wordIndex,
    required int currentWordIndex,
    required List<PhonemeAlignment> observed,
    required List<PhonemeRecognitionResult> detected,
    required bool utteranceFinalized,
  }) {
    if (wordIndex > currentWordIndex && !utteranceFinalized) {
      return WordFeedback(
        word: word,
        status: WordFeedbackStatus.unread,
        meanConfidence: null,
      );
    }
    if (wordIndex == currentWordIndex && !utteranceFinalized) {
      return WordFeedback(
        word: word,
        status: WordFeedbackStatus.current,
        meanConfidence: _meanConfidence(range, observed, detected),
      );
    }

    final items = observed.where(
      (item) =>
          item.expectedIndex != null &&
          item.expectedIndex! >= range.start &&
          item.expectedIndex! < range.end,
    );
    final itemList = items.toList();
    final confidence = _meanConfidence(range, itemList, detected);
    final marginPeak = _meanMarginPeak(range, itemList, detected);
    final expectedCount = range.end - range.start;
    final correctCount = itemList
        .where((item) => item.kind == AlignmentKind.correct)
        .length;
    // A missing CTC token has no acoustic confidence of its own. Do not turn a
    // single deletion into learner-facing review feedback. A whole word may be
    // treated as skipped only when later phonemes were actually observed.
    final hasObservedLaterPhoneme = observed.any(
      (item) =>
          item.expectedIndex != null &&
          item.expectedIndex! >= range.end &&
          item.detectedIndex != null,
    );
    final hasSupportedWordSkip =
        itemList.isNotEmpty &&
        itemList.every((item) => item.kind == AlignmentKind.deletion) &&
        hasObservedLaterPhoneme;
    final hasConfidentMismatch = itemList.any(
      (item) =>
          item.kind == AlignmentKind.substitution &&
          item.detectedIndex != null &&
          detected[item.detectedIndex!].confidence >= reviewConfidence &&
          detected[item.detectedIndex!].marginPeak >= reviewMarginPeak,
    );

    final status =
        correctCount == expectedCount &&
            confidence != null &&
            confidence >= acceptedConfidence &&
            marginPeak != null &&
            marginPeak >= acceptedMarginPeak
        ? WordFeedbackStatus.accepted
        : (hasSupportedWordSkip || hasConfidentMismatch)
        ? WordFeedbackStatus.needsReview
        : WordFeedbackStatus.uncertain;
    return WordFeedback(word: word, status: status, meanConfidence: confidence);
  }

  double? _meanConfidence(
    ({int start, int end}) range,
    Iterable<PhonemeAlignment> alignment,
    List<PhonemeRecognitionResult> detected,
  ) {
    final values = alignment
        .where(
          (item) =>
              item.expectedIndex != null &&
              item.expectedIndex! >= range.start &&
              item.expectedIndex! < range.end &&
              item.detectedIndex != null,
        )
        .map((item) => detected[item.detectedIndex!].confidence)
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? _meanMarginPeak(
    ({int start, int end}) range,
    Iterable<PhonemeAlignment> alignment,
    List<PhonemeRecognitionResult> detected,
  ) {
    final values = alignment
        .where(
          (item) =>
              item.expectedIndex != null &&
              item.expectedIndex! >= range.start &&
              item.expectedIndex! < range.end &&
              item.detectedIndex != null,
        )
        .map((item) => detected[item.detectedIndex!].marginPeak)
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  List<({int start, int end})> _ranges(List<QuranWord> words) {
    var start = 0;
    return [
      for (final word in words)
        (start: start, end: start += word.phonemes?.length ?? 0),
    ];
  }
}
