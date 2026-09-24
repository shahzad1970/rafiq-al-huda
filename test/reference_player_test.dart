import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/audio/quran_reference_player.dart';
import 'package:quran_teacher_ai/core/quran/quran_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('org.quranteacher/playback');
  const events = MethodChannel('org.quranteacher/playback/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final repository = LocalQuranRepository.fromJsonString(
    File(LocalQuranRepository.assetPath).readAsStringSync(),
  );
  late QuranReferencePlayer player;
  late List<MethodCall> calls;

  Future<void> event(String state) async {
    await messenger.handlePlatformMessage(
      events.name,
      const StandardMethodCodec().encodeSuccessEnvelope({'state': state}),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(events, (_) async => null);
    player = QuranReferencePlayer();
  });

  tearDown(() async {
    player.dispose();
    await Future<void>.delayed(Duration.zero);
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  test(
    'Natural verse completion starts the next audio and stops at sequence end',
    () async {
      var advances = 0;
      await player.playVerse(
        repository.getAyah(1, 1).referenceAudio!,
        nextVerse: () {
          advances++;
          return advances == 1 ? repository.getAyah(1, 2).referenceAudio : null;
        },
      );
      await event('playing');
      await event('completed');
      expect(advances, 1);
      expect(calls.where((call) => call.method == 'play').length, 2);
      expect(
        calls.last.arguments['cacheKey'],
        repository.getAyah(1, 2).referenceAudio!.cacheKey,
      );
      await event('playing');
      await event('completed');
      expect(advances, 2);
      expect(player.playing, isFalse);
      expect(player.loading, isFalse);
    },
  );

  for (final interruption in ['stop', 'word', 'error', 'stopped']) {
    test('$interruption cancels automatic verse playback', () async {
      var advances = 0;
      final audio = repository.getAyah(1, 1).referenceAudio!;
      await player.playVerse(
        audio,
        nextVerse: () {
          advances++;
          return audio;
        },
      );
      await event('playing');
      if (interruption == 'stop') {
        await player.stop();
      } else if (interruption == 'word') {
        await player.playWord(audio, 0);
      } else {
        await event(interruption);
      }
      await event('completed');
      expect(advances, 0);
    });
  }
}
