import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/ask/ask_library.dart';
import 'package:quran_teacher_ai/core/quran/quran_repository.dart';

// Opt-in real local inference, using the same retrieval and parser as the UI.
// No ordinary user questions or generated production answers are logged.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final model = Platform.environment['ASK_TEST_MODEL'];
  for (final question in [
    'What does this passage mean?',
    'What can I learn from this passage?',
  ]) {
    test(
      'Real 2:27 starter: $question',
      () async {
        final repository = await LocalQuranRepository.load();
        final sources = await AskLibrary(repository).search(
          question,
          selected: AskSource.quran(repository.getAyah(2, 27)),
        );
        final directory = await Directory.systemTemp.createTemp('ask-227-');
        try {
          final input = File('${directory.path}/input.json');
          await input.writeAsString(askPrompt(question, sources));
          final result = await Process.run(
            'ios/LocalQwen/.build/debug/QwenProbe',
            [model!, input.path],
          );
          expect(result.exitCode, 0, reason: '${result.stderr}');
          final raw = '${result.stdout}'
              .split('\nElapsed seconds:')
              .first
              .trim();
          // Public regression fixture only; retained in the developer test log.
          stdout.writeln('2:27 / $question\n${result.stdout}');
          final answer = AskAnswer.parse(raw, sources.length);
          expect(answer.claims, isNotEmpty);
        } finally {
          await directory.delete(recursive: true);
        }
      },
      skip: model == null,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
