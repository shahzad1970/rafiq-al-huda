import 'dart:async';

import 'package:flutter/services.dart';

enum StreamingStatus { provisional, finalized }

class PhonemeRecognitionResult {
  const PhonemeRecognitionResult({
    required this.token,
    required this.decodedPhoneme,
    required this.confidence,
    required this.start,
    required this.end,
    required this.sequencePosition,
    required this.streamingStatus,
    this.marginPeak = 0,
    this.chunkProcessingMillis = 0,
    this.realTimeFactor = 0,
  });
  final int token;
  final String decodedPhoneme;
  final double confidence;
  final Duration start;
  final Duration end;
  final int sequencePosition;
  final StreamingStatus streamingStatus;
  final double marginPeak;
  final double chunkProcessingMillis;
  final double realTimeFactor;
}

abstract interface class QuranSpeechEngine {
  Future<void> initialize();
  Future<void> startListening();
  Future<void> stopListening();
  Stream<PhonemeRecognitionResult> get results;
  Future<void> reset();
  Future<void> dispose();
}

/// Phase 3/4 seam. Native inference is intentionally not represented as working.
abstract class PendingQuranSpeechEngine implements QuranSpeechEngine {
  PendingQuranSpeechEngine(this.platform, this.approvedArtifact);
  final String platform;
  final String approvedArtifact;
  @override
  Stream<PhonemeRecognitionResult> get results => const Stream.empty();
  @override
  Future<void> initialize() async => throw PlatformException(
    code: 'model_integration_pending',
    message:
        '$platform inference is not integrated. Authorized $approvedArtifact, '
        'tokens and reference metadata are required. See MODEL_INTEGRATION.md.',
  );
  @override
  Future<void> startListening() => initialize();
  @override
  Future<void> stopListening() async {}
  @override
  Future<void> reset() async {}
  @override
  Future<void> dispose() async {}
}

class CoreMLQuranSpeechEngine implements QuranSpeechEngine {
  static const _methods = MethodChannel('org.quranteacher/speech/coreml');
  static const _events = EventChannel('org.quranteacher/speech/coreml/events');

  Stream<PhonemeRecognitionResult>? _results;

  @override
  Future<void> initialize() async {
    await _methods.invokeMapMethod<String, dynamic>('initialize');
  }

  @override
  Future<void> startListening() async {
    await _methods.invokeMethod<void>('start');
  }

  @override
  Future<void> stopListening() => _methods.invokeMethod<void>('stop');

  @override
  Future<void> reset() => _methods.invokeMethod<void>('reset');

  @override
  Future<void> dispose() => _methods.invokeMethod<void>('dispose');

  @override
  Stream<PhonemeRecognitionResult> get results => _results ??= _events
      .receiveBroadcastStream()
      .map<PhonemeRecognitionResult>((dynamic value) {
        final event = Map<Object?, Object?>.from(value as Map);
        return PhonemeRecognitionResult(
          token: event['token']! as int,
          decodedPhoneme: event['decodedPhoneme']! as String,
          confidence: (event['confidence']! as num).toDouble(),
          start: Duration(microseconds: event['startMicros']! as int),
          end: Duration(microseconds: event['endMicros']! as int),
          sequencePosition: event['sequencePosition']! as int,
          streamingStatus: event['finalized'] == true
              ? StreamingStatus.finalized
              : StreamingStatus.provisional,
          marginPeak: (event['marginPeak'] as num?)?.toDouble() ?? 0,
          chunkProcessingMillis:
              (event['chunkProcessingMillis'] as num?)?.toDouble() ?? 0,
          realTimeFactor: (event['realTimeFactor'] as num?)?.toDouble() ?? 0,
        );
      });
}

class OnnxQuranSpeechEngine extends PendingQuranSpeechEngine {
  OnnxQuranSpeechEngine() : super('ONNX', 'zipformer_p_arabic_v3.1.int8.onnx');
}
