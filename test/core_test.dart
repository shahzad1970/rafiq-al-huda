import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/audio/audio_capture.dart';
import 'package:quran_teacher_ai/core/audio/quran_reference_player.dart';
import 'package:quran_teacher_ai/core/calibration/calibration_repository.dart';
import 'package:quran_teacher_ai/core/speech/quran_phoneme_decoder.dart';
import 'package:quran_teacher_ai/core/alignment/quran_alignment_engine.dart';
import 'package:quran_teacher_ai/core/alignment/recitation_position_tracker.dart';
import 'package:quran_teacher_ai/core/alignment/word_feedback_engine.dart';
import 'package:quran_teacher_ai/core/quran/quran_repository.dart';
import 'package:quran_teacher_ai/core/progress/progress_repository.dart';
import 'package:quran_teacher_ai/core/scoring/pronunciation_error.dart';
import 'package:quran_teacher_ai/core/scoring/pronunciation_scoring_engine.dart';
import 'package:quran_teacher_ai/core/speech/quran_speech_engine.dart';
import 'package:quran_teacher_ai/core/tajwid/tajwid_rule_engine.dart';
import 'package:quran_teacher_ai/features/recitation/recitation_controller.dart';

LocalQuranRepository? _repository;
LocalQuranRepository testRepository() =>
    _repository ??= LocalQuranRepository.fromJsonString(
      File(LocalQuranRepository.assetPath).readAsStringSync(),
    );

PhonemeRecognitionResult recognition(
  String symbol,
  int position,
  double confidence,
) => PhonemeRecognitionResult(
  token: position,
  decodedPhoneme: symbol,
  confidence: confidence,
  start: Duration(milliseconds: position * 40),
  end: Duration(milliseconds: (position + 1) * 40),
  sequencePosition: position,
  streamingStatus: StreamingStatus.provisional,
  marginPeak: confidence,
);

class MemoryProgressStore implements ProgressStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> remove() async => value = null;

  @override
  Future<void> write(String value) async => this.value = value;
}

class CalibrationAudioCapture implements AudioCapture {
  final _chunks = StreamController<AudioChunk>.broadcast(sync: true);

  @override
  Stream<AudioChunk> get chunks => _chunks.stream;

  @override
  Future<void> start() async {
    _chunks.add(
      AudioChunk(
        pcm: Uint8List(3200),
        sequence: 0,
        startSample: 0,
        inputSampleRate: 48000,
      ),
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _chunks.close();
}

class CalibrationSpeechEngine implements QuranSpeechEngine {
  final _results = StreamController<PhonemeRecognitionResult>.broadcast(
    sync: true,
  );

  @override
  Stream<PhonemeRecognitionResult> get results => _results.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> startListening() async {
    _results.add(recognition('بِ', 0, .97));
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> reset() async {}

  @override
  Future<void> dispose() => _results.close();
}

void main() {
  test('Earlier mistake details survive restarting from a later word', () {
    final controller = RecitationController(
      audio: CalibrationAudioCapture(),
      engine: CalibrationSpeechEngine(),
    );
    controller.selectAyah(testRepository().getAyah(1, 1));
    for (final entry in ['بِ', 'ش', 'مِ', 'للَ'].asMap().entries) {
      controller.recognitionResults.add(
        recognition(entry.value, entry.key, .97),
      );
    }
    controller.utteranceFinalized = true;
    final original = controller.pronunciationErrors
        .where((f) => f.wordIndex == 0)
        .toList();
    expect(original, isNotEmpty);
    controller.prepareListeningFromWord(2);
    expect(
      controller.pronunciationErrors
          .where((f) => f.wordIndex == 0)
          .map((f) => f.toJson())
          .toList(),
      original.map((f) => f.toJson()).toList(),
    );
    controller.prepareListeningFromWord(0);
    expect(controller.pronunciationErrors, isEmpty);
    controller.selectAyah(testRepository().getAyah(1, 2));
    expect(controller.pronunciationErrors, isEmpty);
    controller.dispose();
  });
  test('Inline listening scores suffix and preserves earlier feedback', () {
    final controller = RecitationController(
      audio: CalibrationAudioCapture(),
      engine: CalibrationSpeechEngine(),
    );
    final ayah = testRepository().getAyah(1, 1);
    controller.selectAyah(ayah);
    for (final entry in ayah.expectedPhonemes!.asMap().entries) {
      controller.recognitionResults.add(
        recognition(entry.value, entry.key, .97),
      );
    }
    controller.utteranceFinalized = true;
    final before = controller.wordFeedback;
    controller.prepareListeningFromWord(2);
    final group = ayah.groupForWord(2)!;
    expect(
      controller.expectedSequence,
      ayah.expectedPhonemes!.sublist(group.tokenStart),
    );
    expect(controller.practiceWordIndex, isNull);
    for (var i = 0; i < group.wordStart; i++) {
      expect(controller.wordFeedback[i].status, before[i].status);
    }
    for (final entry in controller.expectedSequence!.asMap().entries) {
      controller.recognitionResults.add(
        recognition(entry.value, entry.key, .97),
      );
    }
    controller.utteranceFinalized = true;
    expect(controller.wordFeedback.length, ayah.words.length);
    expect(
      controller.wordFeedback.every(
        (w) => w.status == WordFeedbackStatus.accepted,
      ),
      isTrue,
    );
    expect(controller.pronunciationErrors, isEmpty);
    controller.listening = true;
    expect(controller.continueWithAyah(testRepository().getAyah(1, 2)), isTrue);
    expect(controller.listeningFromWord, isNull);
    expect(
      controller.expectedSequence,
      testRepository().getAyah(1, 2).expectedPhonemes,
    );
    controller.dispose();
  });
  test('Focused repair preserves verse evidence and clears only a successful target', () {
    final controller = RecitationController(
      audio: CalibrationAudioCapture(),
      engine: CalibrationSpeechEngine(),
    );
    final ayah = testRepository().getAyah(1, 1);
    controller.selectAyah(ayah);
    final original = [
      for (final entry in ['بِ', 'ش', 'مِ', 'للَ'].asMap().entries)
        recognition(entry.value, entry.key, .97),
    ];
    controller.recognitionResults.addAll(original);
    controller.utteranceFinalized = true;
    expect(controller.needsVerseRetry, isTrue);
    final before = controller.wordFeedback;
    controller.beginWrongPartPractice(0);
    expect(controller.expectedSequence, ayah.pronunciationWord(0).phonemes);
    controller.endWrongPartPractice(); // Cancellation must not accept anything.
    expect(controller.needsVerseRetry, isTrue);
    expect(controller.recognitionResults, original);
    controller.beginWrongPartPractice(0);
    for (final entry in controller.expectedSequence!.asMap().entries) {
      controller.recognitionResults.add(
        recognition(entry.value, entry.key, .97),
      );
    }
    controller.utteranceFinalized = true;
    expect(controller.practiceFeedback!.status, WordFeedbackStatus.accepted);
    controller.endWrongPartPractice();
    expect(controller.wordFeedback.first.status, WordFeedbackStatus.accepted);
    expect(
      controller.recognitionResults,
      original,
    ); // Never rewrite the transcript.
    expect(controller.repairEvidence[0], isNotEmpty);
    for (var i = 1; i < before.length; i++) {
      expect(controller.wordFeedback[i].status, before[i].status);
    }
    controller.selectAyah(testRepository().getAyah(1, 2));
    expect(controller.repairEvidence, isEmpty);
    controller.dispose();
  });
  test('Canonical repeated Quran words are not called an extra repetition', () {
    final verse = testRepository().getAyah(89, 21);
    final symbols = verse.expectedPhonemes!;
    final detected = [
      for (var i = 0; i < symbols.length; i++) recognition(symbols[i], i, .97),
    ];
    final errors = const DeterministicPronunciationScoringEngine().score(
      expected: verse,
      detected: detected,
      alignment: QuranAlignmentEngine().align(symbols, symbols),
      utteranceFinalized: true,
    );
    expect(errors, isEmpty);
  });
  test('All 6236 verses have complete source-mapped canonical pronunciation coverage', () {
    final repository = testRepository();
    final canonical = jsonDecode(
      File('models/quran_lab/v3_1/ordered_quran_phonemes.json')
          .readAsStringSync(),
    ) as Map;
    var checked = 0;
    for (final chapter in repository.chapters) {
      for (final verse in repository.getSurah(chapter.number)) {
        expect(verse.supportsPronunciation, isTrue);
        expect(verse.pronunciationGroups, isNotEmpty);
        var word = 0, token = 0;
        for (final group in verse.pronunciationGroups) {
          expect(group.wordStart, word);
          expect(group.tokenStart, token);
          expect(group.wordEnd, greaterThan(word));
          expect(group.tokenEnd, greaterThan(token));
          word = group.wordEnd;
          token = group.tokenEnd;
        }
        expect(word, verse.words.length);
        expect(token, verse.expectedPhonemes!.length);
        expect(
          verse.scoringReference.words.expand((w) => w.phonemes!).toList(),
          verse.expectedPhonemes,
        );
        expect(
          verse.expectedPhonemes!.join(),
          (canonical['${verse.surah}:${verse.ayah}']['aya_phoneme'] as String)
              .replaceAll(' ', ''),
        );
        checked++;
      }
    }
    expect(checked, 6236);
  });

  for (final location in [
    (2, 27),
    (2, 7),
    (11, 13),
    (37, 130),
    (70, 1),
    (114, 6),
  ]) {
    test('Mapped pronunciation feedback at ${location.$1}:${location.$2}', () {
      final verse = testRepository().getAyah(location.$1, location.$2);
      final group = verse.pronunciationGroups.firstWhere(
        (g) => g.wordEnd - g.wordStart > 1,
        orElse: () => verse.pronunciationGroups.first,
      );
      final expected = verse.expectedPhonemes!;
      final symbols = [...expected];
      symbols[group.tokenStart] = expected[group.tokenStart] == 'ه' ? 'ح' : 'ه';
      final detected = [
        for (var i = 0; i < symbols.length; i++)
          recognition(symbols[i], i, .97),
      ];
      final alignment = QuranAlignmentEngine().align(expected, symbols);
      final feedback = const WordFeedbackEngine().evaluate(
        ayah: verse,
        detected: detected,
        alignment: alignment,
        utteranceFinalized: true,
      );
      for (var word = group.wordStart; word < group.wordEnd; word++) {
        expect(feedback[word].status, WordFeedbackStatus.needsReview);
      }
      final errors = const DeterministicPronunciationScoringEngine().score(
        expected: verse,
        detected: detected,
        alignment: alignment,
        utteranceFinalized: true,
      );
      expect(
        errors.any(
          (e) =>
              e.wordIndex == group.wordStart &&
              e.type == PronunciationErrorType.substitution,
        ),
        isTrue,
      );
      final quiet = [
        for (var i = 0; i < symbols.length; i++) recognition(symbols[i], i, .2),
      ];
      final uncertain = const WordFeedbackEngine().evaluate(
        ayah: verse,
        detected: quiet,
        alignment: alignment,
        utteranceFinalized: true,
      );
      expect(
        uncertain.any((w) => w.status == WordFeedbackStatus.needsReview),
        isFalse,
      );
    });
  }

  test('Joined practice uses full canonical phrase rather than approximate single word', () {
    final verse = testRepository().getAyah(2, 27);
    final group = verse.groupForWord(13)!;
    expect(group.wordStart, 12);
    expect(group.wordEnd, 14);
    final controller = RecitationController(
      audio: CalibrationAudioCapture(),
      engine: CalibrationSpeechEngine(),
    );
    controller.selectAyah(verse);
    controller.beginWordPractice(13);
    expect(controller.practiceWordIndex, 12);
    expect(
      controller.expectedSequence,
      verse.expectedPhonemes!.sublist(group.tokenStart, group.tokenEnd),
    );
    controller.dispose();
  });

  test('Malformed pronunciation mapping is rejected rather than graded', () {
    final data = jsonDecode(
      File(LocalQuranRepository.assetPath).readAsStringSync(),
    ) as Map<String, dynamic>;
    data['ayahs']['1:1']['pronunciationGroups'][0][3] = 0;
    expect(
      () => LocalQuranRepository.fromJsonString(jsonEncode(data)),
      throwsFormatException,
    );
  });

  test(
    'Opening lessons reuse canonical Fatiha without renumbering the Quran',
    () {
      final repository = testRepository();
      final source = repository.getAyah(1, 1);
      expect(repository.firstLessonAyah(1), 1);
      expect(repository.firstLessonAyah(9), 1);
      expect(() => repository.getAyah(9, 0), throwsStateError);
      for (var surah = 2; surah <= 114; surah++) {
        if (surah == 9) continue;
        expect(repository.firstLessonAyah(surah), 0);
        final opening = repository.getAyah(surah, 0);
        expect(opening.surah, surah);
        expect(opening.ayah, 0);
        expect(opening.words, same(source.words));
        expect(opening.expectedPhonemes, same(source.expectedPhonemes));
        expect(opening.referenceAudio, same(source.referenceAudio));
        expect(
          repository.getSurah(surah).length,
          repository.getChapter(surah).versesCount,
        );
      }
    },
  );
  test('PCM16 endianness, normalized samples and 100ms frame timing', () {
    final pcm = Uint8List(3200);
    ByteData.sublistView(pcm).setInt16(0, -32768, Endian.little);
    final chunk = AudioChunk(
      pcm: pcm,
      sequence: 0,
      startSample: 1600,
      inputSampleRate: 48000,
    );
    expect(chunk.frameCount, 1600);
    expect(chunk.samples.first, -1);
    expect(chunk.start.inMilliseconds, 100);
    expect(chunk.end.inMilliseconds, 200);
    expect(chunk.peak, 1);
    expect(chunk.rms, greaterThan(0));
  });
  test('Reject malformed PCM', () {
    expect(
      () => AudioChunk(
        pcm: Uint8List(3),
        sequence: 0,
        startSample: 0,
        inputSampleRate: 16000,
      ),
      throwsFormatException,
    );
  });
  test('Synthetic table: preserve CTC collapse across chunks', () {
    // Unit fixture, not Quran-Lab IDs or simulated recognition.
    final decoder = QuranPhonemeDecoder('r 8\nħ 9\n<blank> 42', blankId: 42);
    expect(decoder.collapse([8, 8]), ['r']);
    expect(decoder.collapse([8, 42, 8, 9]), ['r', 'ħ']);
    decoder.reset();
    expect(decoder.collapse([9]), ['ħ']);
    expect(() => decoder.collapse([0]), throwsFormatException);
  });
  test('Reject duplicate IDs and invalid authoritative blank', () {
    expect(
      () => QuranPhonemeDecoder('a 1\nb 1', blankId: 1),
      throwsFormatException,
    );
    expect(() => QuranPhonemeDecoder('a 1', blankId: 0), throwsFormatException);
  });
  test('Synthetic substitution alignment is deterministic', () {
    final result = QuranAlignmentEngine().align(
      ['r', 'a', 'ħ', 'm', 'aː', 'n'],
      ['r', 'a', 'h', 'm', 'aː', 'n'],
    );
    expect(result[2].kind, AlignmentKind.substitution);
    expect(result[2].expectedIndex, 2);
    expect(result[2].detectedIndex, 2);
  });
  test('Insertion and deletion alignment', () {
    final engine = QuranAlignmentEngine();
    expect(
      engine
          .align(['a', 'b'], ['a', 'x', 'b'])
          .where((x) => x.kind == AlignmentKind.insertion)
          .length,
      1,
    );
    expect(
      engine
          .align(['a', 'b', 'c'], ['a', 'c'])
          .where((x) => x.kind == AlignmentKind.deletion)
          .length,
      1,
    );
  });
  test('Streaming alignment does not jump to a repeated later sound', () {
    final result = QuranAlignmentEngine().alignStreamingPrefix(
      ['a', 'b', 'a'],
      ['a'],
    );
    expect(result, hasLength(1));
    expect(result.single.expectedIndex, 0);
    expect(result.single.kind, AlignmentKind.correct);
  });
  test(
    'Verse-end detection requires the final phoneme and sufficient context',
    () {
      final controller = RecitationController(
        audio: CalibrationAudioCapture(),
        engine: OnnxQuranSpeechEngine(),
      );
      final ayah = testRepository().getAyah(1, 1);
      controller.selectAyah(ayah);
      final expected = ayah.expectedPhonemes!;
      controller.recognitionResults.addAll([
        for (var i = 0; i < expected.length ~/ 2; i++)
          recognition(expected[i], i, .95),
      ]);
      expect(controller.reachedEndOfExpectedSequence, isFalse);
      controller.recognitionResults
        ..clear()
        ..addAll([
          for (var i = 0; i < expected.length; i++)
            recognition(expected[i], i, .95),
        ]);
      expect(controller.reachedEndOfExpectedSequence, isTrue);
      controller.dispose();
    },
  );
  test(
    'Continuous verse handoff retains trailing sounds and capture counters',
    () {
      final controller = RecitationController(
        audio: CalibrationAudioCapture(),
        engine: OnnxQuranSpeechEngine(),
      );
      final first = QuranAyah(
        surah: 1,
        ayah: 1,
        uthmani: '',
        words: [],
        expectedPhonemes: ['a', 'b', 'c'],
      );
      final next = QuranAyah(
        surah: 1,
        ayah: 2,
        uthmani: '',
        words: [],
        expectedPhonemes: ['x', 'y'],
      );
      controller.selectAyah(first);
      controller.listening = true;
      controller.recognitionActive = true;
      controller.frameCount = 16000;
      controller.chunkCount = 10;
      controller.recognitionResults.addAll([
        for (final entry in ['a', 'b', 'c', 'x'].asMap().entries)
          recognition(entry.value, entry.key, .95),
      ]);
      expect(controller.continueWithAyah(next), isTrue);
      expect(controller.expectedAyah, same(next));
      expect(controller.recognitionResults.map((r) => r.decodedPhoneme), ['x']);
      expect(controller.recognitionResults.single.sequencePosition, 3);
      expect(controller.listening, isTrue);
      expect(controller.recognitionActive, isTrue);
      expect(controller.frameCount, 16000);
      expect(controller.chunkCount, 10);
      expect(controller.utteranceFinalized, isFalse);
      expect(controller.continueWithAyah(first), isFalse);
      controller.listening = false;
      controller.dispose();
    },
  );

  test('Follow tracker reacquires backward words and a different verse', () {
    final repository = testRepository();
    final tracker = RecitationPositionTracker(repository);
    var sequence = 0;
    void feed(List<String> symbols, [double confidence = .95]) {
      for (final symbol in symbols) {
        tracker.add(recognition(symbol, sequence++, confidence));
      }
    }

    final long = repository.getAyah(2, 282);
    feed(long.expectedPhonemes!.sublist(35, 60));
    expect(tracker.position?.verse, same(long));
    final later = tracker.position!.offset;
    feed(long.expectedPhonemes!.sublist(0, 25));
    expect(tracker.position?.verse, same(long));
    expect(tracker.position!.offset, lessThan(later));
    final different = repository.getAyah(2, 72);
    feed(different.expectedPhonemes!);
    expect(tracker.position?.verse, same(different));
    expect(tracker.bufferedSymbols, 24);
    tracker.reset();
    feed(different.expectedPhonemes!, .1);
    expect(tracker.position, isNull);
  });

  test('Follow tracker does not guess from a repeated Quranic opening', () {
    final repository = testRepository();
    final tracker = RecitationPositionTracker(repository);
    final symbols = repository.getAyah(1, 1).expectedPhonemes!;
    for (final entry in symbols.asMap().entries) {
      tracker.add(recognition(entry.value, entry.key, .95));
    }
    // Bismillah also appears inside 27:30. No current position disambiguates it.
    expect(tracker.position, isNull);
  });

  test('Follow highlights approximate Baqarah word spans without changing exactness', () {
    final repository = testRepository();
    final tracker = RecitationPositionTracker(repository);
    var sequence = 0;
    // Keep preceding-verse context: 2:5 is also recited elsewhere in the Quran.
    for (final number in [2, 3, 4, 5, 6, 7]) {
      final verse = repository.getAyah(2, number);
      final words = <int>{};
      for (final symbol in verse.expectedPhonemes!) {
        final match = tracker.add(recognition(symbol, sequence++, .95));
        if (identical(match?.verse, verse) && match?.wordIndex != null) {
          words.add(match!.wordIndex!);
        }
      }
      expect(
        words.length,
        greaterThan(1),
        reason: '2:$number should follow words',
      );
      expect(tracker.position?.wordIndex, verse.words.last.index);
      expect(verse.exactWordMapping, number == 3 || number == 6);
    }
  });

  test('Known verse ending bridges to next opening despite boundary noise', () {
    final repository = testRepository();
    final tracker = RecitationPositionTracker(repository);
    var sequence = 0;
    for (final symbol in repository.getAyah(2, 72).expectedPhonemes!) {
      tracker.add(recognition(symbol, sequence++, .95));
    }
    expect(tracker.position?.verse.ayah, 72);
    for (var i = 0; i < 3; i++) {
      tracker.add(recognition('boundary-noise', sequence++, .1));
    }
    expect(tracker.position?.verse.ayah, 72);
    final next = repository.getAyah(2, 73);
    for (var i = 0; i < 7; i++) {
      final match = tracker.add(
        recognition(next.expectedPhonemes![i], sequence++, .95),
      );
      if (i >= 4) expect(match?.verse, same(next));
    }
    expect(tracker.bufferedSymbols, 24);
  });

  test('Slightly lower confidence is accepted nearby but not for distant acquisition', () {
    final repository = testRepository();
    final tracker = RecitationPositionTracker(repository);
    var sequence = 0;
    RecitationPosition? feed(int verse, double confidence) {
      RecitationPosition? match;
      for (final symbol in repository.getAyah(2, verse).expectedPhonemes!) {
        match = tracker.add(recognition(symbol, sequence++, confidence));
      }
      return match;
    }

    feed(72, .62);
    expect(tracker.position, isNull);
    feed(72, .95);
    expect(tracker.position?.verse.ayah, 72);
    feed(73, .62);
    expect(tracker.position?.verse.ayah, 73);
    feed(90, .62);
    expect(tracker.position?.verse.ayah, isNot(90));
    tracker.reset();
    feed(72, .95);
    // Strong evidence from 72 can carry the opening of 73, but once the
    // window contains only .55 observations it must no longer confirm a match.
    expect(feed(73, .55), isNull);
  });

  test('Follow searches two verses back and ahead, with distant fallback', () {
    final repository = testRepository();
    final tracker = RecitationPositionTracker(repository);
    var sequence = 0;
    for (final location in [(2, 72), (2, 70), (2, 72), (2, 74), (112, 1)]) {
      final verse = repository.getAyah(location.$1, location.$2);
      for (final symbol in verse.expectedPhonemes!) {
        tracker.add(recognition(symbol, sequence++, .95));
      }
      expect(tracker.position?.verse, same(verse));
    }
    expect(tracker.bufferedSymbols, 24);
  });

  test(
    'Follow tracker tolerates an inserted or missed sound near the tail',
    () {
      final repository = testRepository();
      final verse = repository.getAyah(2, 72);
      final clean = verse.expectedPhonemes!;
      final baseline = RecitationPositionTracker(repository);
      for (var i = 0; i < clean.length; i++) {
        baseline.add(recognition(clean[i], i, .95));
      }
      for (final inserted in [true, false]) {
        final tracker = RecitationPositionTracker(repository);
        final heard = List<String>.of(clean);
        if (inserted) {
          heard.insert(heard.length - 3, 'test-extra-sound');
        } else {
          heard.removeAt(heard.length - 3);
        }
        RecitationPosition? finalMatch;
        for (var i = 0; i < heard.length; i++) {
          finalMatch = tracker.add(recognition(heard[i], i, .95));
        }
        expect(finalMatch?.verse, same(verse));
        expect(finalMatch?.offset, baseline.position?.offset);
        expect(tracker.bufferedSymbols, 24);
      }
    },
  );

  test('Follow highlight holds briefly without moving then expires', () async {
    final repository = testRepository();
    final engine = CalibrationSpeechEngine();
    final controller = RecitationController(
      audio: CalibrationAudioCapture(),
      engine: engine,
    );
    controller.selectAyah(repository.getAyah(2, 72));
    controller.setFollowRecitation(true, repository);
    await controller.startMicrophone();
    var sequence = 1;
    for (final symbol in repository.getAyah(2, 72).expectedPhonemes!) {
      engine._results.add(recognition(symbol, sequence++, .95));
    }
    expect(controller.followPositionConfirmed, isTrue);
    final position = controller.followedPosition;
    engine._results.add(recognition('test-uncertain', sequence++, .1));
    expect(controller.followPositionHeld, isTrue);
    expect(controller.followPositionConfirmed, isFalse);
    expect(controller.followedPosition, same(position));
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(controller.followPositionVisible, isTrue);
    for (var i = 0; i < 4; i++) {
      engine._results.add(recognition('test-uncertain', sequence++, .1));
    }
    expect(controller.followPositionHeld, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    expect(controller.followPositionVisible, isFalse);
    engine._results.add(recognition('test-uncertain', sequence++, .1));
    expect(controller.followPositionVisible, isFalse);
    expect(controller.pronunciationErrors, isEmpty);
    expect(controller.recognitionResults.length, 24);
    await controller.stopMicrophone();
    controller.dispose();
  });

  test('Word feedback waits for the next word before accepting a match', () {
    final ayah = testRepository().getAyah(1, 1);
    final symbols = [...ayah.words[0].phonemes!, ayah.words[1].phonemes!.first];
    final detected = [
      for (final entry in symbols.asMap().entries)
        recognition(entry.value, entry.key, .9),
    ];
    final alignment = QuranAlignmentEngine().align(
      ayah.expectedPhonemes!,
      symbols,
    );
    final feedback = const WordFeedbackEngine().evaluate(
      ayah: ayah,
      detected: detected,
      alignment: alignment,
      utteranceFinalized: false,
    );
    expect(feedback[0].status, WordFeedbackStatus.accepted);
    expect(feedback[1].status, WordFeedbackStatus.current);
    expect(feedback[2].status, WordFeedbackStatus.unread);
  });
  test('Confident completed substitution is review, never red', () {
    final ayah = testRepository().getAyah(1, 1);
    final symbols = ['بِ', 'ش', 'مِ', ayah.words[1].phonemes!.first];
    final detected = [
      for (final entry in symbols.asMap().entries)
        recognition(entry.value, entry.key, .9),
    ];
    final feedback = const WordFeedbackEngine().evaluate(
      ayah: ayah,
      detected: detected,
      alignment: QuranAlignmentEngine().align(ayah.expectedPhonemes!, symbols),
      utteranceFinalized: false,
    );
    expect(feedback.first.status, WordFeedbackStatus.needsReview);
  });
  test('One missing CTC token is uncertain, not a pronunciation warning', () {
    final ayah = testRepository().getAyah(1, 2);
    final symbols = [...ayah.expectedPhonemes!]..removeAt(9);
    final detected = [
      for (final entry in symbols.asMap().entries)
        recognition(entry.value, entry.key, .95),
    ];
    final feedback = const WordFeedbackEngine().evaluate(
      ayah: ayah,
      detected: detected,
      alignment: QuranAlignmentEngine().align(ayah.expectedPhonemes!, symbols),
      utteranceFinalized: true,
    );
    expect(feedback[2].word.text, 'رَبِّ');
    expect(feedback[2].status, WordFeedbackStatus.uncertain);
  });
  test(
    'Structured substitution requires finalized high-confidence evidence',
    () {
      final source = testRepository().getAyah(1, 1);
      final word = source.words.first;
      final expected = QuranAyah(
        surah: 1,
        ayah: 1,
        uthmani: word.text,
        words: [word],
        expectedPhonemes: word.phonemes,
      );
      final symbols = ['بِ', 'ش', 'مِ'];
      final detected = [
        for (final entry in symbols.asMap().entries)
          recognition(entry.value, entry.key, .95),
      ];
      final alignment = QuranAlignmentEngine().align(
        expected.expectedPhonemes!,
        symbols,
      );
      const engine = DeterministicPronunciationScoringEngine();
      expect(
        engine.score(
          expected: expected,
          detected: detected,
          alignment: alignment,
          utteranceFinalized: false,
        ),
        isEmpty,
      );
      final findings = engine.score(
        expected: expected,
        detected: detected,
        alignment: alignment,
        utteranceFinalized: true,
      );
      expect(findings, hasLength(1));
      expect(findings.single.type, PronunciationErrorType.substitution);
      expect(findings.single.word, 'بِسْمِ');
      expect(findings.single.expectedPhoneme, 'س');
      expect(findings.single.detectedPhoneme, 'ش');
      expect(findings.single.evidenceStatus, EvidenceStatus.confirmed);
      expect(findings.single.toJson()['wordIndex'], 0);
      expect(findings.single.toJson()['errorType'], 'substitution');
    },
  );
  test('Low-confidence disagreement is not promoted to a finding', () {
    final source = testRepository().getAyah(1, 1);
    final word = source.words.first;
    final expected = QuranAyah(
      surah: 1,
      ayah: 1,
      uthmani: word.text,
      words: [word],
      expectedPhonemes: word.phonemes,
    );
    final symbols = ['بِ', 'ش', 'مِ'];
    final detected = [
      for (final entry in symbols.asMap().entries)
        recognition(entry.value, entry.key, .4),
    ];
    final findings = const DeterministicPronunciationScoringEngine().score(
      expected: expected,
      detected: detected,
      alignment: QuranAlignmentEngine().align(
        expected.expectedPhonemes!,
        symbols,
      ),
      utteranceFinalized: true,
    );
    expect(findings, isEmpty);
  });
  test('A confidently repeated complete word is one structured finding', () {
    final source = testRepository().getAyah(1, 1);
    final word = source.words.first;
    final expected = QuranAyah(
      surah: 1,
      ayah: 1,
      uthmani: word.text,
      words: [word],
      expectedPhonemes: word.phonemes,
    );
    final symbols = [...word.phonemes!, ...word.phonemes!];
    final detected = [
      for (final entry in symbols.asMap().entries)
        recognition(entry.value, entry.key, .96),
    ];
    final findings = const DeterministicPronunciationScoringEngine().score(
      expected: expected,
      detected: detected,
      alignment: QuranAlignmentEngine().align(
        expected.expectedPhonemes!,
        symbols,
      ),
      utteranceFinalized: true,
    );
    expect(findings, hasLength(1));
    expect(findings.single.type, PronunciationErrorType.repeatedWord);
    expect(findings.single.wordIndex, word.index);
    expect(findings.single.evidenceStatus, EvidenceStatus.confirmed);
  });
  test('Practice progress persists locally without audio', () async {
    final store = MemoryProgressStore();
    final repository = LocalProgressRepository(store);
    await repository.add(
      surah: 1,
      ayah: 1,
      wordIndex: 2,
      word: 'ٱلرَّحْمَـٰنِ',
      status: WordFeedbackStatus.needsReview,
      meanConfidence: .81,
      findings: const [],
    );
    expect(store.value, isNot(contains('pcm')));
    expect(store.value, isNot(contains('audio')));

    final restored = LocalProgressRepository(store);
    await restored.load();
    expect(restored.totalAttempts, 1);
    expect(restored.reviewAttempts, 1);
    expect(restored.records.single.wordIndex, 2);
    expect(restored.weakWords.values.single, 1);
    expect(restored.weakWordSummaries.single.ayah, 1);
    expect(restored.weakWordSummaries.single.wordIndex, 2);
    expect(restored.weakWordSummaries.single.word, 'ٱلرَّحْمَـٰنِ');
    expect(restored.weakWordSummaries.single.reviewCount, 1);

    await restored.deleteAll();
    expect(restored.records, isEmpty);
    expect(store.value, isNull);
  });
  test('Calibration WAV and label are saved only on explicit save', () async {
    final directory = await Directory.systemTemp.createTemp(
      'quran_teacher_calibration_test_',
    );
    try {
      final repository = LocalCalibrationRepository(
        directoryProvider: () async => directory,
      );
      final pcm = Uint8List(3200);
      ByteData.sublistView(pcm).setInt16(0, 1234, Endian.little);
      final record = await repository.save(
        surah: 1,
        ayah: 1,
        label: CalibrationLabel.carefulRecitation,
        pcm16le: pcm,
        recognitionMetadata: const {
          'expectedPhonemes': ['بِ'],
          'detected': [],
        },
      );
      expect(repository.records, hasLength(1));
      expect(record.durationMilliseconds, 100);
      final wav = await File('${directory.path}/${record.wavFileName}')
          .readAsBytes();
      expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
      expect(ByteData.sublistView(wav).getUint32(24, Endian.little), 16000);
      expect(wav.length, 44 + pcm.length);
      final metadata = jsonDecode(
        await File('${directory.path}/${record.metadataFileName}')
            .readAsString(),
      ) as Map<String, dynamic>;
      expect(metadata['label'], 'carefulRecitation');
      expect(metadata['recognition']['detected'], isEmpty);
      await repository.deleteAll();
      expect(await directory.exists(), isFalse);
      expect(repository.records, isEmpty);
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });
  test(
    'Calibration audio and recognition metadata are snapshotted together',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'quran_teacher_calibration_snapshot_',
      );
      final repository = LocalCalibrationRepository(
        directoryProvider: () async => directory,
      );
      final controller = RecitationController(
        audio: CalibrationAudioCapture(),
        engine: CalibrationSpeechEngine(),
        calibration: repository,
      );
      try {
        controller.selectAyah(testRepository().getAyah(1, 1));
        await controller.startCalibrationMicrophone();
        await controller.stopMicrophone();
        expect(controller.hasPendingCalibrationAudio, isTrue);
        controller.clearSession();
        expect(controller.recognitionResults, isEmpty);

        final record = await controller.savePendingCalibration(
          label: CalibrationLabel.carefulRecitation,
        );
        final metadata = jsonDecode(
          await File('${directory.path}/${record.metadataFileName}')
              .readAsString(),
        ) as Map<String, dynamic>;
        final saved = metadata['recognition'] as Map<String, dynamic>;
        expect(saved['chunkCount'], 1);
        expect(saved['pcmFrameCount'], 1600);
        expect((saved['detected'] as List).single['phoneme'], 'بِ');
      } finally {
        controller.dispose();
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    },
  );
  test('Seven Fatihah ayat use canonical Quran-Lab word phonemes', () {
    final repository = testRepository();
    expect(repository.getSurah(1).length, 7);
    for (final ayah in repository.getSurah(1)) {
      expect(ayah.words.map((w) => w.text).join(' '), ayah.uthmani);
      expect(ayah.words.every((word) => word.indopakText != null), isTrue);
      expect(
        ayah.words.map((w) => w.index),
        List.generate(ayah.words.length, (i) => i),
      );
      expect(ayah.words.every((word) => word.phonemes!.isNotEmpty), isTrue);
      expect(
        ayah.words.expand((word) => word.phonemes!),
        ayah.expectedPhonemes,
      );
    }
    expect(repository.getAyah(1, 1).words.first.phonemes, ['بِ', 'س', 'مِ']);
    expect(repository.getAyah(1, 3).expectedPhonemes, contains('ۦۦۦۦ'));
  });
  test('Whole Quran snapshot contains 114 surahs and 6,236 ayat', () {
    final repository = testRepository();
    expect(repository.chapters, hasLength(114));
    expect(
      repository.chapters
          .map((chapter) => chapter.versesCount)
          .fold<int>(0, (sum, count) => sum + count),
      6236,
    );
    expect(repository.getSurah(2), hasLength(286));
    expect(repository.getSurah(114), hasLength(6));
    expect(repository.getAyah(114, 6).words, isNotEmpty);
    for (final chapter in repository.chapters) {
      for (final ayah in repository.getSurah(chapter.number)) {
        expect(
          ayah.expectedPhonemes,
          isNotEmpty,
          reason: '${ayah.surah}:${ayah.ayah}',
        );
        expect(ayah.referenceAudio?.wordSegments, hasLength(ayah.words.length));
        expect(ayah.words.every((word) => word.english.isNotEmpty), isTrue);
      }
    }
  });
  test('Installed metadata identifies waqf bookmarks and sajdah verses', () {
    final repository = testRepository();
    final sajdahAyat = [
      for (final chapter in repository.chapters)
        for (final ayah in repository.getSurah(chapter.number))
          if (ayah.sajdahNumber != null) ayah,
    ];
    expect(sajdahAyat, hasLength(14));
    expect(repository.getAyah(7, 206).sajdahNumber, 1);
    expect(repository.getAyah(96, 19).sajdahNumber, 14);
    expect(repository.getAyah(2, 1).hasRecommendedStop, isFalse);
    expect(repository.getAyah(2, 2).hasRecommendedStop, isFalse);
    expect(repository.getAyah(2, 8).hasRecommendedStop, isTrue);
    expect(repository.getAyah(1, 2).hasRecommendedStop, isFalse);
  });
  test('Every Fatihah word has English and a valid Mujawwad audio range', () {
    final ayat = testRepository().getSurah(1);
    for (final ayah in ayat) {
      final audio = ayah.referenceAudio;
      expect(audio, isNotNull, reason: 'Missing audio for 1:${ayah.ayah}');
      expect(
        ayah.words.every((word) => word.english.trim().isNotEmpty),
        isTrue,
        reason: 'Missing word translation for 1:${ayah.ayah}',
      );
      expect(audio!.wordSegments, hasLength(ayah.words.length));
      expect(
        audio.asset,
        contains('abdulbaset_mujawwad/00100${ayah.ayah}.mp3'),
      );
      for (final segment in audio.wordSegments) {
        expect(segment.startMilliseconds, greaterThanOrEqualTo(0));
        expect(segment.endMilliseconds, greaterThan(segment.startMilliseconds));
        expect(
          segment.endMilliseconds,
          lessThanOrEqualTo(audio.durationMilliseconds),
        );
      }
    }
  });
  test('Playback position highlights only the word currently recited', () {
    final audio = testRepository().getAyah(1, 2).referenceAudio!;
    expect(QuranReferencePlayer.wordIndexAt(audio, 0), isNull);
    expect(QuranReferencePlayer.wordIndexAt(audio, 1700), 0);
    expect(QuranReferencePlayer.wordIndexAt(audio, 2495), isNull);
    expect(QuranReferencePlayer.wordIndexAt(audio, 2500), 1);
    expect(QuranReferencePlayer.wordIndexAt(audio, 10000), isNull);
  });
  test('Tajwid engine detects strong single sound for expected shaddah', () {
    final source = testRepository().getAyah(1, 2);
    final word = source.words[2];
    final ayah = QuranAyah(
      surah: 1,
      ayah: 2,
      uthmani: word.text,
      words: [word],
      expectedPhonemes: word.phonemes,
    );
    final symbols = ['رَ', 'بِ'];
    final detected = [
      recognition(symbols[0], 0, .96),
      PhonemeRecognitionResult(
        token: 1,
        decodedPhoneme: symbols[1],
        confidence: .96,
        start: const Duration(milliseconds: 40),
        end: const Duration(milliseconds: 120),
        sequencePosition: 1,
        streamingStatus: StreamingStatus.finalized,
        marginPeak: .8,
      ),
    ];
    final findings = const DeterministicTajwidRuleEngine().evaluate(
      expected: ayah,
      detected: detected,
      alignment: QuranAlignmentEngine().align(ayah.expectedPhonemes!, symbols),
      utteranceFinalized: true,
    );
    expect(findings, hasLength(1));
    expect(findings.single.rule, TajwidRuleType.shaddah);
    expect(findings.single.assessment, TajwidAssessment.needsPractice);
    expect(findings.single.expectedPhoneme, 'ببِ');
    expect(findings.single.detectedPhoneme, 'بِ');
  });

  test('Madd timing is measured but not graded without calibrated ranges', () {
    final source = testRepository().getAyah(1, 4);
    final word = source.words.first;
    final ayah = QuranAyah(
      surah: 1,
      ayah: 4,
      uthmani: word.text,
      words: [word],
      expectedPhonemes: word.phonemes,
    );
    final detected = [
      for (final entry in word.phonemes!.asMap().entries)
        PhonemeRecognitionResult(
          token: entry.key,
          decodedPhoneme: entry.value,
          confidence: .96,
          start: Duration(milliseconds: entry.key * 100),
          end: Duration(milliseconds: entry.key * 100 + 90),
          sequencePosition: entry.key,
          streamingStatus: StreamingStatus.finalized,
          marginPeak: .8,
        ),
    ];
    final findings = const DeterministicTajwidRuleEngine().evaluate(
      expected: ayah,
      detected: detected,
      alignment: QuranAlignmentEngine().align(word.phonemes!, word.phonemes!),
      utteranceFinalized: true,
    );
    final madd = findings.singleWhere(
      (item) => item.rule == TajwidRuleType.madd,
    );
    expect(madd.assessment, TajwidAssessment.measuredOnly);
    expect(madd.expectedMaddUnits, 2);
    expect(madd.measuredDuration, const Duration(milliseconds: 90));
  });
}
