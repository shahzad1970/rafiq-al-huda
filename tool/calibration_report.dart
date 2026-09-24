import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/calibration_report.dart <recording-directory> '
      '[--output <report.md>]',
    );
    exitCode = 64;
    return;
  }
  final directory = Directory(arguments.first);
  if (!await directory.exists()) {
    stderr.writeln('Recording directory does not exist: ${directory.path}');
    exitCode = 66;
    return;
  }
  String? outputPath;
  final outputIndex = arguments.indexOf('--output');
  if (outputIndex >= 0 && outputIndex + 1 < arguments.length) {
    outputPath = arguments[outputIndex + 1];
  }

  final samples = <_Sample>[];
  await for (final entity in directory.list()) {
    if (entity is! File ||
        !entity.path.endsWith('.json') ||
        entity.path.endsWith('index.json')) {
      continue;
    }
    final json = jsonDecode(await entity.readAsString());
    if (json is! Map || json['recognition'] is! Map) continue;
    samples.add(await _Sample.read(Map<String, dynamic>.from(json), directory));
  }
  samples.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final report = _report(samples);
  stdout.write(report);
  if (outputPath != null) {
    final output = File(outputPath);
    await output.parent.create(recursive: true);
    await output.writeAsString(report, flush: true);
  }
}

String _report(List<_Sample> samples) {
  final buffer = StringBuffer('# Quran Teacher calibration report\n\n');
  if (samples.isEmpty) {
    return '${buffer}No labeled recordings found.\n';
  }
  final correct = samples.fold<int>(0, (sum, sample) => sum + sample.correct);
  final expected = samples.fold<int>(0, (sum, sample) => sum + sample.expected);
  final errors = samples.fold<int>(0, (sum, sample) => sum + sample.errors);
  final usable = samples.where((sample) => sample.detected > 0).toList();
  final recognitionFailures = samples.length - usable.length;
  final usableExpected = usable.fold<int>(
    0,
    (sum, sample) => sum + sample.expected,
  );
  final usableErrors = usable.fold<int>(
    0,
    (sum, sample) => sum + sample.errors,
  );
  final careful = samples.where(
    (sample) => sample.label == 'carefulRecitation',
  );
  final usableCareful = careful.where((sample) => sample.detected > 0);
  final carefulFailures = careful.length - usableCareful.length;
  final carefulExact = usableCareful
      .where((sample) => sample.errors == 0)
      .length;
  final confirmedCarefulFindings = careful.fold<int>(
    0,
    (sum, sample) => sum + sample.confirmedFindings,
  );
  final suggestionCarefulFindings = careful.fold<int>(
    0,
    (sum, sample) => sum + sample.suggestionFindings,
  );
  final meanConfidence = usable.isEmpty
      ? 0.0
      : usable.map((sample) => sample.meanConfidence).reduce((a, b) => a + b) /
            usable.length;

  buffer
    ..writeln('Generated: ${DateTime.now().toUtc().toIso8601String()}')
    ..writeln()
    ..writeln('- Recordings: ${samples.length}')
    ..writeln('- Expected phonemes: $expected')
    ..writeln('- Correct alignments: $correct')
    ..writeln('- Alignment errors: $errors')
    ..writeln('- Recognition failures: $recognitionFailures')
    ..writeln(
      '- Phoneme alignment error rate: '
      '${(errors / max(1, expected) * 100).toStringAsFixed(2)}%',
    )
    ..writeln(
      '- Usable-sample alignment error rate: '
      '${(usableErrors / max(1, usableExpected) * 100).toStringAsFixed(2)}%',
    )
    ..writeln(
      '- Mean model confidence: ${(meanConfidence * 100).toStringAsFixed(2)}%',
    )
    ..writeln(
      '- Careful recitations exact: $carefulExact/${usableCareful.length} usable '
      '($carefulFailures recognition failure${carefulFailures == 1 ? "" : "s"})',
    )
    ..writeln(
      '- Findings on careful recitations: $confirmedCarefulFindings confirmed, '
      '$suggestionCarefulFindings low-confidence suggestions',
    )
    ..writeln()
    ..writeln(
      '| Āyah | Label | Duration | Detected | Correct | Errors | Confidence | RMS | Peak | Findings |',
    )
    ..writeln('|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|');
  for (final sample in samples) {
    buffer.writeln(
      '| ${sample.ayah} | ${sample.label} | '
      '${sample.durationSeconds.toStringAsFixed(1)}s | '
      '${sample.detected}/${sample.expected} | '
      '${sample.correct}/${sample.expected} | ${sample.errors} | '
      '${(sample.meanConfidence * 100).toStringAsFixed(1)}% | '
      '${sample.rmsDbfs.toStringAsFixed(1)} dBFS | '
      '${sample.peakDbfs.toStringAsFixed(1)} dBFS | '
      '${sample.confirmedFindings} confirmed / '
      '${sample.suggestionFindings} suggestion |',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Data sufficiency')
    ..writeln();
  if (usableCareful.length < 21) {
    buffer.writeln(
      '- Need at least three careful recordings for each of seven āyāt '
      'before estimating a careful-recitation false-warning rate.',
    );
  }
  final controlledErrors = samples.where(
    (sample) =>
        sample.label == 'deliberatePronunciationChange' ||
        sample.label == 'skippedWord',
  );
  if (controlledErrors.length < 14) {
    buffer.writeln(
      '- Need controlled pronunciation-change and skipped-word samples '
      'before estimating missed-error rates.',
    );
  }
  buffer.writeln(
    '- Repeated-word and short-madd labels remain exploratory because those '
    'detectors are not implemented.',
  );
  return buffer.toString();
}

class _Sample {
  const _Sample({
    required this.ayah,
    required this.label,
    required this.createdAt,
    required this.durationSeconds,
    required this.expected,
    required this.detected,
    required this.correct,
    required this.errors,
    required this.meanConfidence,
    required this.confirmedFindings,
    required this.suggestionFindings,
    required this.rmsDbfs,
    required this.peakDbfs,
  });

  final int ayah;
  final String label;
  final DateTime createdAt;
  final double durationSeconds;
  final int expected;
  final int detected;
  final int correct;
  final int errors;
  final double meanConfidence;
  final int confirmedFindings;
  final int suggestionFindings;
  final double rmsDbfs;
  final double peakDbfs;

  static Future<_Sample> read(
    Map<String, dynamic> json,
    Directory directory,
  ) async {
    final recognition = Map<String, dynamic>.from(json['recognition'] as Map);
    final alignment = List<Map<String, dynamic>>.from(
      (recognition['alignment'] as List).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final findings = List<Map<String, dynamic>>.from(
      (recognition['findings'] as List).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final wav = await File('${directory.path}/${json['wavFileName']}')
        .readAsBytes();
    final levels = _levels(wav);
    final expected = (recognition['expectedPhonemes'] as List).length;
    final detected = (recognition['detected'] as List).length;
    final correct = alignment.where((item) => item['kind'] == 'correct').length;
    final explicitErrors = alignment
        .where((item) => item['kind'] != 'correct')
        .length;
    // An empty/partial alignment must not make missing recognition look like
    // zero errors. Preserve explicit insertions when they exceed omissions.
    final errors = max(explicitErrors, expected - correct);
    return _Sample(
      ayah: json['ayah'] as int,
      label: json['label'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      durationSeconds: (json['durationMilliseconds'] as num) / 1000,
      expected: expected,
      detected: detected,
      correct: correct,
      errors: errors,
      meanConfidence: (recognition['meanConfidence'] as num?)?.toDouble() ?? 0,
      confirmedFindings: findings
          .where((item) => item['evidenceStatus'] == 'confirmed')
          .length,
      suggestionFindings: findings
          .where((item) => item['evidenceStatus'] == 'lowConfidenceSuggestion')
          .length,
      rmsDbfs: levels.rmsDbfs,
      peakDbfs: levels.peakDbfs,
    );
  }
}

({double rmsDbfs, double peakDbfs}) _levels(Uint8List wav) {
  if (wav.length < 44) throw const FormatException('WAV header is incomplete.');
  final bytes = ByteData.sublistView(wav);
  var squared = 0.0;
  var peak = 0.0;
  var count = 0;
  for (var offset = 44; offset + 1 < wav.length; offset += 2) {
    final value = bytes.getInt16(offset, Endian.little) / 32768.0;
    squared += value * value;
    peak = max(peak, value.abs());
    count++;
  }
  final rms = count == 0 ? 0.0 : sqrt(squared / count);
  double db(double value) => value <= 0 ? -120 : 20 * log(value) / ln10;
  return (rmsDbfs: db(rms), peakDbfs: db(peak));
}
