import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Actual PCM from native microphones. This is not Kaldi feature extraction.
class AudioChunk {
  AudioChunk({
    required this.pcm,
    required this.sequence,
    required this.startSample,
    required this.inputSampleRate,
    this.sampleRate = 16000,
  }) {
    if (sampleRate != 16000 ||
        pcm.length.isOdd ||
        sequence < 0 ||
        startSample < 0) {
      throw const FormatException('Expected 16 kHz mono PCM16 little-endian');
    }
  }
  final Uint8List pcm;
  final int sequence;
  final int startSample;
  final int sampleRate;
  final double inputSampleRate;
  int get frameCount => pcm.length ~/ 2;
  Duration get start =>
      Duration(microseconds: startSample * 1000000 ~/ sampleRate);
  Duration get end => Duration(
    microseconds: (startSample + frameCount) * 1000000 ~/ sampleRate,
  );
  List<double> get samples {
    final bytes = ByteData.sublistView(pcm);
    return List.generate(
      frameCount,
      (i) => bytes.getInt16(i * 2, Endian.little) / 32768.0,
    );
  }

  double get rms {
    final values = samples;
    return values.isEmpty
        ? 0
        : sqrt(values.fold<double>(0, (sum, x) => sum + x * x) / values.length);
  }

  double get peak => samples.fold<double>(0, (p, x) => max(p, x.abs()));
  factory AudioChunk.fromPlatform(Map<Object?, Object?> event) {
    if (event['channels'] != 1 || event['encoding'] != 'pcm16le') {
      throw const FormatException('Unsupported native audio format');
    }
    return AudioChunk(
      pcm: event['pcm'] as Uint8List,
      sequence: event['sequence'] as int,
      startSample: event['startSample'] as int,
      sampleRate: event['sampleRate'] as int,
      inputSampleRate: (event['inputSampleRate'] as num).toDouble(),
    );
  }
}

abstract interface class AudioCapture {
  Stream<AudioChunk> get chunks;
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

class PlatformAudioCapture implements AudioCapture {
  static const _methods = MethodChannel('org.quranteacher/audio');
  static const _events = EventChannel('org.quranteacher/audio/events');
  late final Stream<AudioChunk> _chunks = _events
      .receiveBroadcastStream()
      .map(
        (event) =>
            AudioChunk.fromPlatform(Map<Object?, Object?>.from(event as Map)),
      )
      .asBroadcastStream();
  @override
  Stream<AudioChunk> get chunks => _chunks;
  @override
  Future<void> start() async {
    for (var attempt = 0; attempt < 50; attempt++) {
      if (await _methods.invokeMethod<bool>('isSubscribed') == true) {
        await _methods.invokeMethod<void>('start');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw PlatformException(
      code: 'audio_subscription_timeout',
      message: 'Native microphone listener did not connect.',
    );
  }

  @override
  Future<void> stop() => _methods.invokeMethod<void>('stop');
  @override
  Future<void> dispose() => stop();
}
