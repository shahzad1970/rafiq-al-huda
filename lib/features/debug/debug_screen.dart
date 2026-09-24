import 'package:flutter/material.dart';

import '../../core/alignment/quran_alignment_engine.dart';
import '../../core/quran/quran_repository.dart';
import '../recitation/recitation_controller.dart';

class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key, required this.controller});
  final RecitationController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Developer diagnostics')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final chunk = controller.latest;
        final results = controller.recognitionResults;
        final ids = results.map((result) => result.token).join(' ');
        final detected = results
            .map((result) => result.decodedPhoneme)
            .toList();
        final phonemes = detected.join(' ');
        final ayah = controller.expectedAyah;
        final expected = ayah?.expectedPhonemes ?? const <String>[];
        final alignment = controller.followRecitation
            ? const <PhonemeAlignment>[]
            : controller.alignment;
        final lastObserved = alignment.lastIndexWhere(
          (item) => item.detectedIndex != null,
        );
        final observedAlignment = lastObserved < 0
            ? const <PhonemeAlignment>[]
            : alignment.sublist(0, lastObserved + 1);
        final alignmentText = observedAlignment
            .map((item) {
              final expectedSymbol = item.expectedIndex == null
                  ? '∅'
                  : expected[item.expectedIndex!];
              final detectedSymbol = item.detectedIndex == null
                  ? '∅'
                  : detected[item.detectedIndex!];
              final marker = item.kind == AlignmentKind.correct ? '✓' : '≠';
              return '$expectedSymbol → $detectedSymbol $marker';
            })
            .join('\n');
        final currentWord = _wordAtAlignment(ayah, observedAlignment);
        final confidence = results
            .map(
              (result) =>
                  '${result.decodedPhoneme} ${(result.confidence * 100).toStringAsFixed(1)}% '
                  'peak margin ${(result.marginPeak * 100).toStringAsFixed(1)}% '
                  '${result.start.inMilliseconds}–${result.end.inMilliseconds} ms',
            )
            .join('\n');
        final latestRecognition = results.lastOrNull;
        final findings = controller.pronunciationErrors
            .map(
              (finding) =>
                  '${finding.word}: ${finding.type.name} '
                  '${finding.expectedPhoneme ?? "∅"} → ${finding.detectedPhoneme ?? "∅"} '
                  '[${finding.evidenceStatus.name}]',
            )
            .join('\n');
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (controller.followRecitation)
              Text(
                'Follow mode (not grading)\n'
                'Evidence: ${results.length}/24 symbols\n'
                'Position: ${controller.followPositionConfirmed
                    ? "confirmed"
                    : controller.followPositionHeld
                    ? "held briefly"
                    : "searching"}\n'
                'Verse: ${controller.followedPosition?.verse.surah}:${controller.followedPosition?.verse.ayah}\n'
                'Word: ${controller.followedPosition?.wordIndex}\n'
                'Pronunciation mapping: ${ayah?.pronunciationGroups.isNotEmpty == true
                    ? "source-mapped word/phrase groups"
                    : ayah?.exactWordMapping == true
                    ? "legacy word mapping"
                    : "unavailable"}',
              ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.science_outlined),
                title: const Text('Calibration recordings'),
                subtitle: const Text(
                  'Collect explicitly labeled local WAV files for threshold testing.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: controller.listening
                    ? null
                    : () => Navigator.pushNamed(context, '/calibration'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Microphone',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: controller.busy
                  ? null
                  : controller.listening
                  ? controller.stopMicrophone
                  : controller.startMicrophone,
              icon: Icon(controller.listening ? Icons.stop : Icons.mic),
              label: Text(
                controller.listening
                    ? 'Stop microphone'
                    : 'Start microphone and recognition',
              ),
            ),
            if (controller.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  controller.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            SizedBox(
              height: 120,
              child: CustomPaint(painter: WaveformPainter(controller.waveform)),
            ),
            Text(
              'Input: ${chunk?.inputSampleRate ?? "unavailable"} Hz\nOutput: ${chunk?.sampleRate ?? "unavailable"} Hz · mono PCM16 LE\n'
              'RMS: ${chunk?.rms.toStringAsFixed(4) ?? "unavailable"}\nPeak: ${chunk?.peak.toStringAsFixed(4) ?? "unavailable"}\n'
              'PCM frames: ${controller.frameCount}\nChunks: ${controller.chunkCount}\nLast sequence: ${chunk?.sequence ?? "unavailable"}\n'
              'Audio end: ${chunk?.end.inMilliseconds ?? "unavailable"} ms\n'
              'Exact Kaldi fbank runs natively when iOS recognition is active.',
            ),
            const SizedBox(height: 24),
            const Text(
              'Inference',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              '${controller.recognitionActive ? "Quran-Lab v3.1 Core ML stream active" : "Not active"}\n'
              'Latest chunk processing: ${latestRecognition == null ? "unavailable" : "${latestRecognition.chunkProcessingMillis.toStringAsFixed(1)} ms"}\n'
              'Real-time factor: ${latestRecognition == null ? "unavailable" : latestRecognition.realTimeFactor.toStringAsFixed(3)}\n'
              'Requested compute: CPU + Neural Engine; actual placement not yet measured\n'
              'Recognition error: ${controller.recognitionError ?? "none"}',
            ),
            const SizedBox(height: 24),
            const Text(
              'Recognition and alignment',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SelectableText(
              'Expected: ${expected.isEmpty ? "unavailable" : expected.join(" ")}\n'
              'Detected: ${phonemes.isEmpty ? "unavailable" : phonemes}\n'
              'Raw CTC IDs: ${ids.isEmpty ? "unavailable" : ids} (after streaming collapse)\n'
              'Phonemes / confidence / timestamps:\n${confidence.isEmpty ? "unavailable" : confidence}\n'
              'Current expected word: ${currentWord?.text ?? "unavailable"}\n'
              'Live alignment preview:\n${alignmentText.isEmpty ? "unavailable" : alignmentText}\n'
              'Structured findings:\n${findings.isEmpty ? "none (or utterance not finalized)" : findings}',
            ),
            const SizedBox(height: 20),
            const Text('No diagnostic audio is saved.'),
          ],
        );
      },
    ),
  );
}

QuranWord? _wordAtAlignment(QuranAyah? ayah, List<PhonemeAlignment> alignment) {
  if (ayah == null || alignment.isEmpty) return null;
  final expectedIndex = alignment
      .where((item) => item.detectedIndex != null && item.expectedIndex != null)
      .map((item) => item.expectedIndex!)
      .fold<int?>(
        null,
        (largest, value) =>
            largest == null || value > largest ? value : largest,
      );
  if (expectedIndex == null) return null;
  var offset = 0;
  for (final word in ayah.words) {
    final end = offset + (word.phonemes?.length ?? 0);
    if (expectedIndex < end) return word;
    offset = end;
  }
  return null;
}

class WaveformPainter extends CustomPainter {
  WaveformPainter(this.samples);
  final List<double> samples;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff006c70)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()..color = Colors.grey,
    );
    if (samples.length < 2) return;
    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = i * size.width / (samples.length - 1),
          y = size.height / 2 - samples[i] * size.height / 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) =>
      oldDelegate.samples != samples;
}
