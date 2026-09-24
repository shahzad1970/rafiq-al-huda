enum PronunciationErrorType {
  substitution,
  deletion,
  insertion,
  repeatedPhoneme,
  skippedWord,
  repeatedWord,
}

enum ErrorSeverity { low, moderate, high }

enum EvidenceStatus { lowConfidenceSuggestion, confirmed }

/// Acoustic/alignment result. An LLM must never create this object.
class PronunciationError {
  const PronunciationError({
    required this.surah,
    required this.ayah,
    required this.wordIndex,
    required this.word,
    required this.expectedPhoneme,
    required this.detectedPhoneme,
    required this.confidence,
    required this.type,
    required this.severity,
    required this.evidenceStatus,
    this.letter,
    this.displayStart,
    this.displayEnd,
    this.marginPeak,
  });
  final int surah, ayah, wordIndex;
  final String word;
  final String? letter, expectedPhoneme, detectedPhoneme;
  final int? displayStart, displayEnd;
  final double confidence;
  final double? marginPeak;
  final PronunciationErrorType type;
  final ErrorSeverity severity;
  final EvidenceStatus evidenceStatus;

  Map<String, Object?> toJson() => {
    'surah': surah,
    'ayah': ayah,
    'wordIndex': wordIndex,
    'word': word,
    'letter': letter,
    'expectedPhoneme': expectedPhoneme,
    'detectedPhoneme': detectedPhoneme,
    'confidence': confidence,
    'marginPeak': marginPeak,
    'errorType': type.name,
    'severity': severity.name,
    'evidenceStatus': evidenceStatus.name,
    'displayStart': displayStart,
    'displayEnd': displayEnd,
  };
}
