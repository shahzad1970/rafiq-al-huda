import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quran_teacher_ai/core/audio/audio_capture.dart';

/// Run only on a real phone. Accept the OS microphone prompt; no mocked capture.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native microphone emits contiguous 16 kHz mono PCM', (
    tester,
  ) async {
    final capture = PlatformAudioCapture();
    final received = <AudioChunk>[];
    final ready = Completer<void>();
    final subscription = capture.chunks.listen(
      (chunk) {
        received.add(chunk);
        if (received.length >= 5 && !ready.isCompleted) ready.complete();
      },
      onError: (Object error) {
        if (!ready.isCompleted) ready.completeError(error);
      },
    );
    try {
      await capture.start();
      await ready.future.timeout(const Duration(seconds: 30));
      expect(
        received.every(
          (chunk) => chunk.sampleRate == 16000 && chunk.frameCount > 0,
        ),
        isTrue,
      );
      for (var i = 1; i < received.length; i++) {
        expect(received[i].sequence, received[i - 1].sequence + 1);
        expect(
          received[i].startSample,
          received[i - 1].startSample + received[i - 1].frameCount,
        );
      }
      // Silence is valid. Never synthesize speech or force a nonzero microphone level.
    } finally {
      await capture.stop();
      await subscription.cancel();
      await capture.dispose();
    }
  });
}
