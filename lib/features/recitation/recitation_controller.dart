import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/alignment/quran_alignment_engine.dart';
import '../../core/alignment/recitation_position_tracker.dart';
import '../../core/alignment/word_feedback_engine.dart';
import '../../core/audio/audio_capture.dart';
import '../../core/calibration/calibration_repository.dart';
import '../../core/progress/progress_repository.dart';
import '../../core/quran/quran_repository.dart';
import '../../core/scoring/pronunciation_error.dart';
import '../../core/scoring/pronunciation_scoring_engine.dart';
import '../../core/speech/quran_speech_engine.dart';
import '../../core/tajwid/tajwid_rule_engine.dart';

class PracticeAttemptSummary {
  const PracticeAttemptSummary({
    required this.number,
    required this.status,
    required this.meanConfidence,
  });

  final int number;
  final WordFeedbackStatus status;
  final double? meanConfidence;
}

typedef _PendingCalibration = ({
  Uint8List audio,
  int surah,
  int ayah,
  Map<String, Object?> recognitionMetadata,
});

class RecitationController extends ChangeNotifier {
  RecitationController({
    required this.audio,
    required this.engine,
    this.progress,
    this.calibration,
  });
  final AudioCapture audio;
  final QuranSpeechEngine engine;
  final LocalProgressRepository? progress;
  final LocalCalibrationRepository? calibration;
  StreamSubscription<AudioChunk>? _subscription;
  StreamSubscription<PhonemeRecognitionResult>? _recognitionSubscription;
  bool listening = false, busy = false;
  bool recognitionActive = false;
  String? error;
  String? recognitionError;
  AudioChunk? latest;
  final List<PhonemeRecognitionResult> recognitionResults = [];
  RecitationPositionTracker? _positionTracker;
  bool followRecitation = false;
  RecitationPosition? get followedPosition => _positionTracker?.position;
  bool followPositionConfirmed = false;
  bool followPositionHeld = false;
  bool get followPositionVisible =>
      followPositionConfirmed || followPositionHeld;
  Timer? _followHoldTimer;
  bool _followHoldExpired = false;

  void _clearFollowHold() {
    _followHoldTimer?.cancel();
    _followHoldTimer = null;
    _followHoldExpired = false;
    followPositionHeld = false;
  }

  void setFollowRecitation(bool enabled, QuranRepository repository) {
    if (listening || busy) return;
    followRecitation = enabled;
    if (enabled) {
      _positionTracker ??= RecitationPositionTracker(repository);
    }
    _positionTracker?.reset();
    followPositionConfirmed = false;
    clearSession();
  }

  QuranAyah? expectedAyah;
  final QuranAlignmentEngine _alignmentEngine = QuranAlignmentEngine();
  final WordFeedbackEngine _wordFeedbackEngine = const WordFeedbackEngine();
  final PronunciationScoringEngine _scoringEngine =
      const DeterministicPronunciationScoringEngine();
  final TajwidRuleEngine _tajwidEngine = const DeterministicTajwidRuleEngine();
  bool utteranceFinalized = false;
  int? practiceWordIndex;
  QuranAyah? _listeningSuffix;
  List<WordFeedback> _prefixFeedback = const [];
  List<PronunciationError> _prefixErrors = const [];
  List<TajwidFinding> _prefixTajwid = const [];
  int? get listeningFromWord => _listeningSuffix?.words.first.index;

  /// Keep the verse on screen while aligning only the selected phrase onward.
  /// Shared phonemes require starting at their canonical phrase boundary.
  void prepareListeningFromWord(int wordIndex) {
    final ayah = expectedAyah;
    if (ayah == null ||
        listening ||
        busy ||
        !ayah.supportsPronunciation ||
        wordIndex < 0 ||
        wordIndex >= ayah.words.length) {
      return;
    }
    final previous = wordFeedback;
    final start = ayah.groupForWord(wordIndex)?.wordStart ?? wordIndex;
    final earlierErrors = pronunciationErrors
        .where((f) => f.wordIndex < start)
        .toList();
    final earlierTajwid = tajwidFindings
        .where((f) => f.wordIndex < start)
        .toList();
    final words = ayah.scoringReference.words
        .where((w) => w.index >= start)
        .toList();
    _listeningSuffix = QuranAyah(
      surah: ayah.surah,
      ayah: ayah.ayah,
      uthmani: words.map((w) => w.text).join(' '),
      words: words,
      expectedPhonemes: [for (final word in words) ...word.phonemes!],
    );
    _prefixFeedback = [
      for (final item in previous.where((w) => w.word.index < start))
        if (item.status == WordFeedbackStatus.current)
          WordFeedback(
            word: item.word,
            status: WordFeedbackStatus.unread,
            meanConfidence: null,
          )
        else
          item,
    ];
    _prefixErrors = earlierErrors;
    _prefixTajwid = earlierTajwid;
    practiceWordIndex = null;
    followRecitation = false;
    recognitionResults.clear();
    _correctedWords.clear();
    utteranceFinalized = false;
    _notify();
  }

  ({
    List<PhonemeRecognitionResult> results,
    bool finalized,
    Map<int, double?> corrected,
  })?
  _repairSnapshot;
  final Map<int, double?> _correctedWords = {};

  /// Separate successful practice attempts, never a rewritten model transcript.
  final Map<int, List<PhonemeRecognitionResult>> repairEvidence = {};
  bool get repairingWrongPart => _repairSnapshot != null;
  final List<PracticeAttemptSummary> practiceAttempts = [];
  int chunkCount = 0, frameCount = 0;
  int? _lastSequence;
  int _generation = 0;
  bool _disposed = false;
  bool _stopping = false;
  bool _calibrationMode = false;
  BytesBuilder? _calibrationBytes;
  _PendingCalibration? _pendingCalibration;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  List<double> waveform = [];

  bool get hasPendingCalibrationAudio =>
      _pendingCalibration?.audio.isNotEmpty ?? false;
  bool get calibrationRecording => _calibrationMode;
  Duration get pendingCalibrationDuration => Duration(
    milliseconds:
        (_pendingCalibration?.audio.length ?? 0) *
        1000 ~/
        (LocalCalibrationRepository.sampleRate * 2),
  );

  List<PhonemeAlignment> get alignment {
    final expected = expectedSequence;
    if (expected == null) return const [];
    final detected = recognitionResults
        .map((result) => result.decodedPhoneme)
        .toList();
    return utteranceFinalized
        ? _alignmentEngine.align(expected, detected)
        : _alignmentEngine.alignStreamingPrefix(expected, detected);
  }

  List<String>? get expectedSequence {
    final ayah = expectedAyah;
    if (ayah == null) return null;
    final wordIndex = practiceWordIndex;
    return wordIndex == null
        ? (_listeningSuffix ?? ayah).expectedPhonemes
        : ayah.pronunciationWord(wordIndex).phonemes;
  }

  /// True only after streaming alignment has reached the final expected
  /// phoneme with enough observed context to avoid treating a short fragment
  /// as a completed verse.
  bool get reachedEndOfExpectedSequence {
    final expected = expectedSequence;
    if (expected == null ||
        expected.isEmpty ||
        recognitionResults.isEmpty ||
        recognitionResults.length * 5 < expected.length * 3) {
      return false;
    }
    final finalIndex = expected.length - 1;
    return alignment.any(
      (item) => item.expectedIndex == finalIndex && item.detectedIndex != null,
    );
  }

  /// Change only the reference, not the microphone, CTC decoder or model cache.
  bool get needsVerseRetry {
    final ayah = expectedAyah;
    if (followRecitation ||
        ayah == null ||
        !ayah.supportsPronunciation ||
        practiceWordIndex != null) {
      return false;
    }
    return wordFeedback.any(
      (word) => word.status == WordFeedbackStatus.needsReview,
    );
  }

  /// Change only the reference, not the microphone, CTC decoder or model cache.
  /// Symbols already heard after the aligned ending belong to the next verse.
  bool continueWithAyah(QuranAyah ayah) {
    if (!listening ||
        practiceWordIndex != null ||
        calibrationRecording ||
        hasPendingCalibrationAudio ||
        !reachedEndOfExpectedSequence ||
        needsVerseRetry) {
      return false;
    }
    final last = expectedSequence!.length - 1;
    final boundary = alignment
        .firstWhere(
          (item) => item.expectedIndex == last && item.detectedIndex != null,
        )
        .detectedIndex!;
    recognitionResults.removeRange(0, boundary + 1);
    _listeningSuffix = null;
    _prefixFeedback = const [];
    _prefixErrors = const [];
    _prefixTajwid = const [];
    _correctedWords.clear();
    repairEvidence.clear();
    expectedAyah = ayah;
    utteranceFinalized = false;
    _notify();
    return true;
  }

  WordFeedback? get practiceFeedback {
    final ayah = expectedAyah;
    final wordIndex = practiceWordIndex;
    final expected = expectedSequence;
    if (ayah == null || wordIndex == null || expected == null) return null;
    final word = ayah.pronunciationWord(wordIndex);
    final practiceAyah = QuranAyah(
      surah: ayah.surah,
      ayah: ayah.ayah,
      uthmani: word.text,
      words: [word],
      expectedPhonemes: expected,
    );
    final feedback = _wordFeedbackEngine
        .evaluate(
          ayah: practiceAyah,
          detected: recognitionResults,
          alignment: alignment,
          utteranceFinalized: utteranceFinalized,
        )
        .single;
    if (utteranceFinalized &&
        (tajwidFindings.any(
              (f) => f.assessment == TajwidAssessment.needsPractice,
            ) ||
            pronunciationErrors.any(
              (item) => item.type == PronunciationErrorType.repeatedWord,
            ))) {
      return WordFeedback(
        word: word,
        status: WordFeedbackStatus.needsReview,
        meanConfidence: feedback.meanConfidence,
      );
    }
    return feedback;
  }

  List<PronunciationError> get pronunciationErrors {
    if (followRecitation) return const [];
    final ayah = expectedAyah;
    final expected = expectedSequence;
    if (ayah == null || expected == null) return const [];
    if (!ayah.supportsPronunciation) return const [];
    final wordIndex = practiceWordIndex;
    final scoringAyah = wordIndex == null
        ? (_listeningSuffix ?? ayah)
        : QuranAyah(
            surah: ayah.surah,
            ayah: ayah.ayah,
            uthmani: ayah.pronunciationWord(wordIndex).text,
            words: [ayah.pronunciationWord(wordIndex)],
            expectedPhonemes: expected,
          );
    return [
      if (wordIndex == null && _listeningSuffix != null) ..._prefixErrors,
      ..._scoringEngine
          .score(
            expected: scoringAyah,
            detected: recognitionResults,
            alignment: alignment,
            utteranceFinalized: utteranceFinalized,
          )
          .where(
            (finding) =>
                wordIndex != null ||
                !_correctedWords.containsKey(finding.wordIndex),
        ),
    ];
  }

  List<TajwidFinding> get tajwidFindings {
    if (followRecitation) return const [];
    final ayah = expectedAyah;
    final expected = expectedSequence;
    if (ayah == null || expected == null) return const [];
    if (!ayah.supportsPronunciation) return const [];
    final wordIndex = practiceWordIndex;
    final scoringAyah = wordIndex == null
        ? (_listeningSuffix ?? ayah)
        : QuranAyah(
            surah: ayah.surah,
            ayah: ayah.ayah,
            uthmani: ayah.pronunciationWord(wordIndex).text,
            words: [ayah.pronunciationWord(wordIndex)],
            expectedPhonemes: expected,
          );
    return [
      if (wordIndex == null && _listeningSuffix != null) ..._prefixTajwid,
      ..._tajwidEngine
          .evaluate(
            expected: scoringAyah,
            detected: recognitionResults,
            alignment: alignment,
            utteranceFinalized:
                utteranceFinalized ||
                (wordIndex == null && reachedEndOfExpectedSequence),
          )
          .where(
            (finding) =>
                wordIndex != null ||
                !_correctedWords.containsKey(finding.wordIndex),
        ),
    ];
  }

  List<WordFeedback> get wordFeedback {
    final ayah = expectedAyah;
    if (ayah == null) return const [];
    if (followRecitation) {
      return [
        for (final word in ayah.words)
          WordFeedback(
            word: word,
            status:
                followPositionVisible &&
                    followedPosition?.wordIndex == word.index
                ? WordFeedbackStatus.current
                : WordFeedbackStatus.unread,
            meanConfidence: null,
          ),
      ];
    }
    if (practiceWordIndex != null) {
      return [
        for (final word in ayah.words)
          WordFeedback(
            word: word,
            status: WordFeedbackStatus.unread,
            meanConfidence: null,
          ),
      ];
    }
    final scored = _wordFeedbackEngine.evaluate(
      ayah: _listeningSuffix ?? ayah,
      detected: recognitionResults,
      alignment: alignment,
      utteranceFinalized: utteranceFinalized || reachedEndOfExpectedSequence,
    );
    final feedback = _listeningSuffix == null
        ? scored
        : <WordFeedback>[
            ..._prefixFeedback,
            for (final item in scored)
              for (
                var index = item.word.index;
                index <
                    (ayah.groupForWord(item.word.index)?.wordEnd ??
                        item.word.index + 1);
                index++
              )
                WordFeedback(
                  word: ayah.words[index],
                  status: item.status,
                  meanConfidence: item.meanConfidence,
                ),
          ];
    final reviews = tajwidFindings.where(
      (finding) => finding.assessment == TajwidAssessment.needsPractice,
    );
    return [
      for (final item in feedback)
        if (_correctedWords.containsKey(item.word.index))
          WordFeedback(
            word: item.word,
            status: WordFeedbackStatus.accepted,
            meanConfidence: _correctedWords[item.word.index],
          )
        else if (reviews.any(
          (f) =>
              item.word.index >= f.wordIndex &&
              item.word.index <
                  (f.wordEnd ??
                      ayah.groupForWord(f.wordIndex)?.wordEnd ??
                      f.wordIndex + 1),
        ))
          WordFeedback(
            word: item.word,
            status: WordFeedbackStatus.needsReview,
            meanConfidence: item.meanConfidence,
          )
        else
          item,
    ];
  }

  void selectAyah(QuranAyah ayah) {
    if (expectedAyah?.surah == ayah.surah && expectedAyah?.ayah == ayah.ayah) {
      return;
    }
    expectedAyah = ayah;
    _correctedWords.clear();
    repairEvidence.clear();
    clearSession();
  }

  /// Manual navigation changes the reference, not the microphone or model
  /// streaming state. Old alignment must not mark words in the new verse.
  bool navigateWhileListening(QuranAyah ayah) {
    if (!listening ||
        busy ||
        practiceWordIndex != null ||
        calibrationRecording ||
        hasPendingCalibrationAudio) {
      return false;
    }
    expectedAyah = ayah;
    recognitionResults.clear();
    _listeningSuffix = null;
    _prefixFeedback = const [];
    _prefixErrors = const [];
    _prefixTajwid = const [];
    _correctedWords.clear();
    repairEvidence.clear();
    utteranceFinalized = false;
    _positionTracker?.reset();
    followPositionConfirmed = false;
    _clearFollowHold();
    _notify();
    return true;
  }

  void beginWordPractice(int wordIndex) {
    final ayah = expectedAyah;
    if (ayah == null || wordIndex < 0 || wordIndex >= ayah.words.length) {
      throw RangeError.index(wordIndex, ayah?.words ?? const []);
    }
    followRecitation = false;
    _positionTracker?.reset();
    practiceWordIndex = ayah.groupForWord(wordIndex)?.wordStart ?? wordIndex;
    practiceAttempts.clear();
    clearSession();
  }

  void beginWrongPartPractice(int wordIndex) {
    if (listening || busy || practiceWordIndex != null) return;
    final snapshot = (
      results: List<PhonemeRecognitionResult>.of(recognitionResults),
      finalized: utteranceFinalized,
      corrected: Map<int, double?>.of(_correctedWords),
    );
    final previousEvidence = Map<int, List<PhonemeRecognitionResult>>.of(
      repairEvidence,
    );
    beginWordPractice(wordIndex);
    _repairSnapshot = snapshot;
    repairEvidence.addAll(previousEvidence);
  }

  void endWrongPartPractice() {
    final snapshot = _repairSnapshot;
    final index = practiceWordIndex;
    if (snapshot == null || index == null || listening || busy) return;
    final feedback = utteranceFinalized ? practiceFeedback : null;
    final corrected = Map<int, double?>.of(snapshot.corrected);
    final evidence = Map<int, List<PhonemeRecognitionResult>>.of(
      repairEvidence,
    );
    if (feedback?.status == WordFeedbackStatus.accepted) {
      final group = expectedAyah!.groupForWord(index);
      for (
        var i = group?.wordStart ?? index;
        i < (group?.wordEnd ?? index + 1);
        i++
      ) {
        corrected[i] = feedback!.meanConfidence;
      }
      evidence[index] = List<PhonemeRecognitionResult>.of(recognitionResults);
    }
    practiceWordIndex = null;
    practiceAttempts.clear();
    _repairSnapshot = null;
    recognitionResults
      ..clear()
      ..addAll(snapshot.results);
    utteranceFinalized = snapshot.finalized;
    _correctedWords
      ..clear()
      ..addAll(corrected);
    repairEvidence
      ..clear()
      ..addAll(evidence);
    _notify();
  }

  void endWordPractice() {
    practiceWordIndex = null;
    practiceAttempts.clear();
    clearSession();
  }

  Future<void> startMicrophone() async {
    if (busy || listening || _disposed) return;
    final generation = ++_generation;
    if (practiceWordIndex == null) {
      _correctedWords.clear();
      repairEvidence.clear();
    }
    busy = true;
    error = null;
    recognitionError = null;
    latest = null;
    chunkCount = 0;
    frameCount = 0;
    _lastSequence = null;
    waveform = [];
    recognitionResults.clear();
    _positionTracker?.reset();
    followPositionConfirmed = false;
    _clearFollowHold();
    utteranceFinalized = false;
    _notify();
    await _recognitionSubscription?.cancel();
    _recognitionSubscription = engine.results.listen(
      (result) {
        if (_disposed || generation != _generation) return;
        if (followRecitation &&
            practiceWordIndex == null &&
            !_calibrationMode) {
          final match = _positionTracker!.add(result);
          followPositionConfirmed = match != null;
          if (match != null) {
            _clearFollowHold();
            expectedAyah = match.verse;
          } else {
            // Time-based grace, not a token count: fast uncertain sounds must
            // not cut it short. New misses never extend the same deadline.
            followPositionHeld =
                followedPosition != null && !_followHoldExpired;
            if (followPositionHeld) {
              _followHoldTimer ??= Timer(
                const Duration(milliseconds: 1500),
                () {
                  _followHoldTimer = null;
                  followPositionHeld = false;
                  _followHoldExpired = true;
                  _notify();
                },
              );
            }
          }
          recognitionResults.add(result);
          if (recognitionResults.length > 24) recognitionResults.removeAt(0);
          _notify();
          return;
        }
        // Bound unsuccessful/repeated attempts as well as successful verses.
        if (recognitionResults.length >= 4096) {
          recognitionError =
              'This attempt is too long. Restart listening to try again.';
          if (recognitionActive) {
            recognitionActive = false;
            unawaited(stopMicrophone());
          }
          return;
        }
        recognitionResults.add(result);
        _notify();
      },
      onError: (Object e) {
        if (_disposed || generation != _generation) return;
        recognitionActive = false;
        recognitionError = e.toString();
        unawaited(stopMicrophone());
        _notify();
      },
    );
    try {
      await engine.initialize();
      await engine.startListening();
      recognitionActive = true;
    } catch (e) {
      recognitionActive = false;
      recognitionError = e.toString();
    }
    await _subscription?.cancel();
    _subscription = audio.chunks.listen(
      (chunk) {
        if (_disposed || generation != _generation) return;
        if (chunk.startSample != frameCount ||
            (_lastSequence != null && chunk.sequence != _lastSequence! + 1)) {
          error = 'Audio discontinuity detected. Restart the microphone.';
          unawaited(stopMicrophone());
          return;
        }
        _lastSequence = chunk.sequence;
        latest = chunk;
        chunkCount++;
        frameCount += chunk.frameCount;
        final calibrationBytes = _calibrationBytes;
        if (calibrationBytes != null) {
          if (calibrationBytes.length + chunk.pcm.length >
              LocalCalibrationRepository.sampleRate *
                  2 *
                  LocalCalibrationRepository.maximumSeconds) {
            error = 'Calibration recording reached the two-minute limit.';
            unawaited(stopMicrophone());
            return;
          }
          calibrationBytes.add(chunk.pcm);
        }
        final values = chunk.samples;
        waveform = [for (var i = 0; i < values.length; i += 16) values[i]];
        _notify();
      },
      onError: (Object e) {
        if (_disposed || generation != _generation) return;
        error = e.toString();
        unawaited(stopMicrophone());
      },
    );
    try {
      await audio.start();
      if (_disposed || generation != _generation) {
        await audio.stop();
      } else {
        listening = true;
      }
    } catch (e) {
      if (generation == _generation) error = e.toString();
      if (recognitionActive) await engine.stopListening();
      recognitionActive = false;
      await _subscription?.cancel();
      _subscription = null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> startCalibrationMicrophone() async {
    if (busy || listening || _disposed) return;
    followRecitation = false;
    discardPendingCalibration();
    _calibrationMode = true;
    _calibrationBytes = BytesBuilder(copy: false);
    await startMicrophone();
    if (!listening) {
      _calibrationMode = false;
      _calibrationBytes = null;
    }
  }

  Future<void> stopMicrophone() async {
    if (_stopping) return;
    _stopping = true;
    _clearFollowHold();
    final generation = _generation;
    final shouldFinalize =
        !utteranceFinalized &&
        (listening || recognitionActive || recognitionResults.isNotEmpty);
    try {
      await audio.stop();
    } catch (e) {
      error = e.toString();
    }
    try {
      await engine.stopListening();
    } catch (e) {
      recognitionError = e.toString();
    }
    if (generation == _generation) utteranceFinalized = true;
    final feedback = practiceFeedback;
    if (shouldFinalize && practiceWordIndex != null && feedback != null) {
      practiceAttempts.add(
        PracticeAttemptSummary(
          number: practiceAttempts.length + 1,
          status: feedback.status,
          meanConfidence: feedback.meanConfidence,
        ),
      );
      final ayah = expectedAyah!;
      final word = ayah.pronunciationWord(practiceWordIndex!);
      unawaited(
        progress?.add(
          surah: ayah.surah,
          ayah: ayah.ayah,
          wordIndex: word.index,
          word: word.text,
          status: feedback.status,
          meanConfidence: feedback.meanConfidence,
          findings: pronunciationErrors,
        ),
      );
    }
    await _subscription?.cancel();
    _subscription = null;
    await _recognitionSubscription?.cancel();
    _recognitionSubscription = null;
    if (_calibrationMode) {
      final bytes = _calibrationBytes?.takeBytes();
      final ayah = expectedAyah;
      if (bytes != null && bytes.isNotEmpty && ayah != null) {
        _pendingCalibration = (
          audio: bytes,
          surah: ayah.surah,
          ayah: ayah.ayah,
          recognitionMetadata: _calibrationRecognitionMetadata(),
        );
      }
      _calibrationBytes = null;
      _calibrationMode = false;
    }
    listening = false;
    recognitionActive = false;
    _clearFollowHold();
    _generation++;
    _stopping = false;
    _notify();
  }

  Future<CalibrationRecord> savePendingCalibration({
    required CalibrationLabel label,
    String? note,
  }) async {
    final repository = calibration;
    final pending = _pendingCalibration;
    if (repository == null || pending == null || pending.audio.isEmpty) {
      throw StateError('No completed calibration recording is available.');
    }
    final record = await repository.save(
      surah: pending.surah,
      ayah: pending.ayah,
      label: label,
      pcm16le: pending.audio,
      note: note,
      recognitionMetadata: pending.recognitionMetadata,
    );
    _pendingCalibration = null;
    _notify();
    return record;
  }

  Map<String, Object?> _calibrationRecognitionMetadata() {
    final detected = List<PhonemeRecognitionResult>.of(recognitionResults);
    final meanConfidence = detected.isEmpty
        ? null
        : detected.fold<double>(0, (sum, item) => sum + item.confidence) /
              detected.length;
    return {
      'model': 'Quran-Lab/zipformer_p-arabic-v3.1.float8',
      'meanConfidence': meanConfidence,
      'expectedPhonemes': expectedSequence,
      'detected': [
        for (final item in detected)
          {
            'tokenId': item.token,
            'phoneme': item.decodedPhoneme,
            'confidence': item.confidence,
            'marginPeak': item.marginPeak,
            'startMicros': item.start.inMicroseconds,
            'endMicros': item.end.inMicroseconds,
            'sequencePosition': item.sequencePosition,
          },
      ],
      'alignment': [
        for (final item in alignment)
          {
            'kind': item.kind.name,
            'expectedIndex': item.expectedIndex,
            'detectedIndex': item.detectedIndex,
          },
      ],
      'findings': [for (final item in pronunciationErrors) item.toJson()],
      'inputSampleRate': latest?.inputSampleRate,
      'chunkCount': chunkCount,
      'pcmFrameCount': frameCount,
    };
  }

  void discardPendingCalibration() {
    _calibrationBytes = null;
    _pendingCalibration = null;
    _calibrationMode = false;
    _notify();
  }

  void clearSession() {
    _listeningSuffix = null;
    _prefixFeedback = const [];
    _prefixErrors = const [];
    _prefixTajwid = const [];
    _correctedWords.clear();
    repairEvidence.clear();
    _clearFollowHold();
    _positionTracker?.reset();
    followPositionConfirmed = false;
    latest = null;
    waveform = [];
    frameCount = 0;
    chunkCount = 0;
    recognitionResults.clear();
    utteranceFinalized = false;
    recognitionError = null;
    _notify();
  }

  @override
  void dispose() {
    _clearFollowHold();
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    unawaited(_recognitionSubscription?.cancel());
    unawaited(audio.dispose());
    unawaited(engine.dispose());
    _calibrationBytes = null;
    _pendingCalibration = null;
    super.dispose();
  }
}
