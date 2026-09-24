import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/ask/quran_questions.dart';

void main() {
  final verses =
      (jsonDecode(File('assets/data/ask_translation.json').readAsStringSync())
              as Map)['ayahs']
          as Map;
  test('2:27 starters ask about its covenant and bonds', () {
    expect(quranQuestions(verses['2:27']['translation']), [
      'What does this verse say about keeping a covenant?',
      'What does this verse say about maintaining bonds?',
      'Explain this verse in simple English.',
    ]);
  });
  test('Suggestions change with verse content', () {
    final questions = quranQuestions(verses['1:6']['translation']);
    expect(questions, contains('What does this verse say about guidance?'));
    expect(questions.any((q) => q.contains('covenant')), isFalse);
  });
  test('All verses have two or three unique, compact starters', () {
    for (final verse in verses.values) {
      final questions = quranQuestions(verse['translation']);
      expect(questions.length, inInclusiveRange(2, 3));
      expect(questions.toSet().length, questions.length);
    }
  });
  test('Unknown topics get neutral questions, not invented facts', () {
    expect(quranQuestions(''), [
      'Explain this verse in simple English.',
      'What is the main message of this verse?',
    ]);
  });
}
