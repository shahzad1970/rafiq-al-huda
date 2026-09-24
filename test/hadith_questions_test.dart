import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/ask/hadith_questions.dart';

void main() {
  test('Starter questions follow the narration content', () {
    expect(
      hadithQuestions('Actions are judged by intentions.'),
      contains('What does this hadith teach about intentions?'),
    );
    final prayer = hadithQuestions('He was praying the prayer.');
    expect(prayer, contains('What does this hadith say about prayer?'));
    expect(prayer.any((q) => q.contains('fasting')), isFalse);
  });
  test('Unmatched text has neutral questions and no invented topic', () {
    expect(hadithQuestions('A narration.'), [
      'Explain this hadith in simple English.',
      'What is the main lesson of this hadith?',
    ]);
    expect(hadithQuestions('breakfast faster'), hasLength(2));
  });
  test('Suggestions stay compact and do not duplicate topics', () {
    final questions = hadithQuestions(
      'Prayer prayers fasting charity intentions',
    );
    expect(questions, hasLength(3));
    expect(questions.toSet(), hasLength(3));
  });
}
