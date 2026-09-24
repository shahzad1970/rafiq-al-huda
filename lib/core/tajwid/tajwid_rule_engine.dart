import '../alignment/quran_alignment_engine.dart';
import '../quran/quran_repository.dart';
import '../speech/quran_speech_engine.dart';

enum TajwidRuleType { shaddah, madd }

enum TajwidAssessment { correct, needsPractice, measuredOnly, uncertain }

/// Deterministic acoustic evidence. This is teaching feedback, not a ruling.
class TajwidFinding {
  const TajwidFinding({
    required this.rule,
    required this.assessment,
    required this.wordIndex,
    required this.word,
    required this.expectedPhoneme,
    required this.detectedPhoneme,
    required this.confidence,
    required this.measuredDuration,
    this.expectedMaddUnits,
    this.start,
    this.end,
    this.wordEnd,
  });

  final TajwidRuleType rule;
  final TajwidAssessment assessment;
  final int wordIndex;
  final String word;
  final String expectedPhoneme;
  final String? detectedPhoneme;
  final double confidence;
  final Duration? measuredDuration;
  final int? expectedMaddUnits;

  /// CTC emission timestamps, not forced-aligned acoustic sound boundaries.
  final Duration? start;
  final Duration? end;
  final int? wordEnd;

  String get guidance => rule == TajwidRuleType.shaddah
      ? 'The doubled sound may have sounded single. Listen and try the word or phrase again.'
      : 'Madd is present in the reference. Length is not graded yet; CTC timing is not a reliable sound duration.';
}

abstract interface class TajwidRuleEngine {
  List<TajwidFinding> evaluate({
    required QuranAyah expected,
    required List<PhonemeRecognitionResult> detected,
    required List<PhonemeAlignment> alignment,
    required bool utteranceFinalized,
  });
}

class DeterministicTajwidRuleEngine implements TajwidRuleEngine {
  const DeterministicTajwidRuleEngine({
    this.minimumConfidence = .90,
    this.minimumMarginPeak = .60,
  });

  final double minimumConfidence;
  final double minimumMarginPeak;

  static Set<TajwidRuleType> rulesForWord(QuranWord word) => {
    for (final phoneme in word.phonemes ?? const <String>[])
      if (_isGeminated(phoneme)) TajwidRuleType.shaddah,
    for (final phoneme in word.phonemes ?? const <String>[])
      if (_maddUnits(phoneme) != null) TajwidRuleType.madd,
  };

  @override
  List<TajwidFinding> evaluate({
    required QuranAyah expected,
    required List<PhonemeRecognitionResult> detected,
    required List<PhonemeAlignment> alignment,
    required bool utteranceFinalized,
  }) {
    if (expected.pronunciationGroups.isNotEmpty) {
      return evaluate(
            expected: expected.scoringReference,
            detected: detected,
            alignment: alignment,
            utteranceFinalized: utteranceFinalized,
          )
          .map((finding) {
            final group = expected.groupForWord(finding.wordIndex)!;
            return TajwidFinding(
              rule: finding.rule,
              assessment: finding.assessment,
              wordIndex: finding.wordIndex,
              wordEnd: group.wordEnd,
              word: finding.word,
              expectedPhoneme: finding.expectedPhoneme,
              detectedPhoneme: finding.detectedPhoneme,
              confidence: finding.confidence,
              measuredDuration: finding.measuredDuration,
              expectedMaddUnits: finding.expectedMaddUnits,
              start: finding.start,
              end: finding.end,
            );
          })
          .toList(growable: false);
    }
    final expectedPhonemes = expected.expectedPhonemes;
    if (!utteranceFinalized || expectedPhonemes == null) return const [];
    final ranges = _wordRanges(expected);
    final findings = <TajwidFinding>[];

    for (final item in alignment) {
      final expectedIndex = item.expectedIndex;
      final detectedIndex = item.detectedIndex;
      if (expectedIndex == null ||
          detectedIndex == null ||
          expectedIndex < 0 ||
          expectedIndex >= expectedPhonemes.length ||
          detectedIndex < 0 ||
          detectedIndex >= detected.length) {
        continue;
      }
      final wordIndex = _wordForExpectedIndex(expectedIndex, ranges);
      if (wordIndex == null) continue;
      final expectedToken = expectedPhonemes[expectedIndex];
      final recognized = detected[detectedIndex];
      if (!_strongEnough(recognized)) continue;
      final word = expected.words[wordIndex];

      if (_isGeminated(expectedToken)) {
        final assessment = item.kind == AlignmentKind.correct
            ? TajwidAssessment.correct
            : recognized.decodedPhoneme == _singleVersion(expectedToken)
            ? TajwidAssessment.needsPractice
            : TajwidAssessment.uncertain;
        findings.add(
          TajwidFinding(
            rule: TajwidRuleType.shaddah,
            assessment: assessment,
            wordIndex: word.index,
            word: word.text,
            expectedPhoneme: expectedToken,
            detectedPhoneme: recognized.decodedPhoneme,
            confidence: recognized.confidence,
            measuredDuration: recognized.end - recognized.start,
            start: recognized.start,
            end: recognized.end,
          ),
        );
      }

      final maddUnits = _maddUnits(expectedToken);
      if (maddUnits != null) {
        // Record CTC timing, but do not grade short/long until real recitations
        // establish reliable, tempo-aware ranges for this model.
        findings.add(
          TajwidFinding(
            rule: TajwidRuleType.madd,
            assessment: item.kind == AlignmentKind.correct
                ? TajwidAssessment.measuredOnly
                : TajwidAssessment.uncertain,
            wordIndex: word.index,
            word: word.text,
            expectedPhoneme: expectedToken,
            detectedPhoneme: recognized.decodedPhoneme,
            confidence: recognized.confidence,
            measuredDuration: recognized.end - recognized.start,
            expectedMaddUnits: maddUnits,
            start: recognized.start,
            end: recognized.end,
          ),
        );
      }
    }
    return findings;
  }

  bool _strongEnough(PhonemeRecognitionResult result) =>
      result.streamingStatus == StreamingStatus.finalized &&
      result.end > result.start &&
      result.confidence >= minimumConfidence &&
      result.marginPeak >= minimumMarginPeak;

  static bool _isGeminated(String token) {
    final runes = token.runes.toList(growable: false);
    return _maddUnits(token) == null &&
        runes.length >= 2 &&
        'ءبتثجحخدذرزسشصضطظعغفقكلمنهوي'.runes.contains(runes[0]) &&
        runes[0] == runes[1];
  }

  static String _singleVersion(String token) =>
      String.fromCharCodes(token.runes.skip(1));

  static int? _maddUnits(String token) {
    final runes = token.runes.toList(growable: false);
    if (runes.length < 2) return null;
    const maddCharacters = {0x0627, 0x06e6, 0x06e5};
    return runes.every(maddCharacters.contains) ? runes.length : null;
  }

  List<({int start, int end})> _wordRanges(QuranAyah ayah) {
    var start = 0;
    return [
      for (final word in ayah.words)
        (start: start, end: start += word.phonemes?.length ?? 0),
    ];
  }

  int? _wordForExpectedIndex(
    int expectedIndex,
    List<({int start, int end})> ranges,
  ) {
    final result = ranges.indexWhere(
      (range) => expectedIndex >= range.start && expectedIndex < range.end,
    );
    return result < 0 ? null : result;
  }
}
