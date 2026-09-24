import '../scoring/pronunciation_error.dart';

abstract interface class TeacherFeedbackEngine {
  /// Explanations consume deterministic errors, never decide correctness.
  String explain(PronunciationError detectedError);
}

/// Explains an already-detected mismatch; never infers a new acoustic error.
class DeterministicTeacherFeedbackEngine implements TeacherFeedbackEngine {
  const DeterministicTeacherFeedbackEngine();

  @override
  String explain(PronunciationError error) {
    final expected = error.expectedPhoneme;
    final heard = error.detectedPhoneme;
    final evidence = error.evidenceStatus == EvidenceStatus.confirmed
        ? 'The recognized sound differed from the reference.'
        : 'Possible issue — the recording is not conclusive.';
    return switch (error.type) {
      PronunciationErrorType.substitution =>
        'Sound mismatch\n$evidence\n\nExpected sound: ${expected ?? "not available"}\nHeard closer to: ${heard ?? "not clear"}\n\nTry this: listen to the reference and focus on the expected sound above, then tap Listen from here and repeat it.',
      PronunciationErrorType.deletion || PronunciationErrorType.skippedWord =>
        'Sound not recognized\nExpected: ${expected ?? error.word}\nHeard: no clear matching sound. This may be a missed sound, quiet audio, or an unfinished attempt.\n\nTry this: recite the whole word clearly, including its ending, and continue. This is not a confirmed omission.',
      PronunciationErrorType.insertion =>
        'Possible extra sound\nHeard: ${heard ?? "an additional sound"}\n\nTry this: listen to the reference, then repeat the word without adding that sound. The app may have misheard it.',
      PronunciationErrorType.repeatedPhoneme ||
      PronunciationErrorType.repeatedWord =>
        'Possible repetition\nHeard again: ${heard ?? error.word}\n\nTry this: say the word once and continue. If you intentionally restarted, tap the word to begin a fresh attempt there.',
    };
  }
}
