import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/alignment/quran_alignment_engine.dart';
import 'package:quran_teacher_ai/core/quran/quran_repository.dart';
import 'package:quran_teacher_ai/core/speech/quran_speech_engine.dart';
import 'package:quran_teacher_ai/core/tajwid/tajwid_rule_engine.dart';

void main() {
  final repository = LocalQuranRepository.fromJsonString(
    File(LocalQuranRepository.assetPath).readAsStringSync(),
  );
  const engine = DeterministicTajwidRuleEngine();
  PhonemeRecognitionResult result(
    String token,
    int i, {
    double confidence = .96,
    double margin = .8,
    StreamingStatus status = StreamingStatus.finalized,
  }) => PhonemeRecognitionResult(
    token: i,
    decodedPhoneme: token,
    confidence: confidence,
    marginPeak: margin,
    start: Duration(milliseconds: i * 100),
    end: Duration(milliseconds: i * 100 + 80),
    sequencePosition: i,
    streamingStatus: status,
  );

  test(
    'All canonical verses map tajwid evidence to valid word or phrase ranges',
    () {
      var count = 0;
      for (final chapter in repository.chapters) {
        for (final ayah in repository.getSurah(chapter.number)) {
          final tokens = ayah.expectedPhonemes!;
          final findings = engine.evaluate(
            expected: ayah,
            detected: [
              for (var i = 0; i < tokens.length; i++) result(tokens[i], i),
            ],
            alignment: [
              for (var i = 0; i < tokens.length; i++)
                PhonemeAlignment(i, i, AlignmentKind.correct),
            ],
            utteranceFinalized: true,
          );
          for (final finding in findings) {
            expect(
              finding.wordIndex,
              inInclusiveRange(0, ayah.words.length - 1),
            );
            expect(
              finding.wordEnd,
              inInclusiveRange(finding.wordIndex + 1, ayah.words.length),
            );
            expect(finding.assessment, isNot(TajwidAssessment.needsPractice));
            if (finding.rule == TajwidRuleType.madd) {
              expect(finding.assessment, TajwidAssessment.measuredOnly);
              expect(finding.end! - finding.start!, finding.measuredDuration);
            }
          }
          count++;
        }
      }
      expect(count, 6236);
    },
  );

  test('Shaddah advice requires final, strong evidence; no rule judgment from silence', () {
    final word = repository.getAyah(1, 2).words[2];
    final ayah = QuranAyah(
      surah: 1,
      ayah: 2,
      uthmani: word.text,
      words: [word],
      expectedPhonemes: word.phonemes,
    );
    final index = word.phonemes!.indexOf('ببِ');
    final alignment = [PhonemeAlignment(index, 0, AlignmentKind.substitution)];
    List<TajwidFinding> evaluate(
      PhonemeRecognitionResult token, {
      bool finalized = true,
    }) => engine.evaluate(
      expected: ayah,
      detected: [token],
      alignment: alignment,
      utteranceFinalized: finalized,
    );
    expect(
      evaluate(result('بِ', 0)).single.assessment,
      TajwidAssessment.needsPractice,
    );
    expect(evaluate(result('بِ', 0, confidence: .5)), isEmpty);
    expect(evaluate(result('بِ', 0, margin: .1)), isEmpty);
    expect(
      evaluate(result('بِ', 0, status: StreamingStatus.provisional)),
      isEmpty,
    );
    expect(evaluate(result('بِ', 0), finalized: false), isEmpty);
    expect(
      engine.evaluate(
        expected: ayah,
        detected: [],
        alignment: [PhonemeAlignment(index, null, AlignmentKind.deletion)],
        utteranceFinalized: true,
      ),
      isEmpty,
    );
  });
}
