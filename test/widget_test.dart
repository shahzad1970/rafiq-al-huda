import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/app.dart';
import 'package:quran_teacher_ai/core/alignment/word_feedback_engine.dart';
import 'package:quran_teacher_ai/core/audio/audio_capture.dart';
import 'package:quran_teacher_ai/core/audio/quran_reference_player.dart';
import 'package:quran_teacher_ai/core/calibration/calibration_repository.dart';
import 'package:quran_teacher_ai/core/quran/quran_repository.dart';
import 'package:quran_teacher_ai/core/progress/progress_repository.dart';
import 'package:quran_teacher_ai/core/settings/local_settings.dart';
import 'package:quran_teacher_ai/core/speech/quran_speech_engine.dart';
import 'package:quran_teacher_ai/features/recitation/recitation_controller.dart';

LocalQuranRepository? _repository;
LocalQuranRepository testRepository() =>
    _repository ??= LocalQuranRepository.fromJsonString(
      File(LocalQuranRepository.assetPath).readAsStringSync(),
    );

/// No native audio is invoked by display tests, and no recognition is mocked.
class UnavailableCapture implements AudioCapture {
  @override
  Stream<AudioChunk> get chunks => const Stream.empty();
  @override
  Future<void> start() async =>
      throw UnsupportedError('Display test cannot capture');
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

/// Verifies action dispatch without starting hardware or fabricating recognition.
class ActionTrackingController extends RecitationController {
  ActionTrackingController()
    : super(audio: UnavailableCapture(), engine: OnnxQuranSpeechEngine());
  int starts = 0;
  void publishForTest() => notifyListeners();
  @override
  Future<void> startMicrophone() async {
    starts++;
  }
}

class MemorySettingsStore implements SettingsStore {
  final values = <String, Object>{};
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<double?> getDouble(String key) async => values[key] as double?;
  @override
  Future<int?> getInt(String key) async => values[key] as int?;
  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<void> setDouble(String key, double value) async {
    values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class MemoryProgressStore implements ProgressStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> remove() async => value = null;

  @override
  Future<void> write(String value) async => this.value = value;
}

class TestReferencePlayer extends QuranReferencePlayer {
  int? lastWordIndex;
  QuranReferenceAudio? Function()? nextVerse;
  QuranReferenceAudio? currentAudio;
  double? lastWordRate;
  (int, int)? lastPhrase;
  @override
  Future<void> playWords(
    QuranReferenceAudio audio,
    int start,
    int end, {
    double rate = 1,
  }) async {
    lastPhrase = (start, end);
    lastWordRate = rate;
  }

  void showPlayingWord(int index) {
    playing = true;
    playingWordIndex = index;
    notifyListeners();
  }

  @override
  Future<void> playVerse(
    QuranReferenceAudio audio, {
    QuranReferenceAudio? Function()? nextVerse,
  }) async {
    currentAudio = audio;
    this.nextVerse = nextVerse;
    playing = true;
    notifyListeners();
  }

  @override
  Future<void> playWord(
    QuranReferenceAudio audio,
    int wordIndex, {
    double rate = 1,
  }) async {
    lastWordIndex = wordIndex;
    lastWordRate = rate;
  }

  @override
  Future<void> stop() async {
    nextVerse = null;
    playing = false;
  }
}

PhonemeRecognitionResult recognition(String symbol, int position) =>
    PhonemeRecognitionResult(
      token: position,
      decodedPhoneme: symbol,
      confidence: .9,
      start: Duration(milliseconds: position * 40),
      end: Duration(milliseconds: (position + 1) * 40),
      sequencePosition: position,
      streamingStatus: StreamingStatus.provisional,
      marginPeak: .9,
    );

Future<void> pumpQuranModule(WidgetTester tester, QuranTeacherApp app) async {
  await tester.pumpWidget(app);
  if (app.settings.acknowledged) {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('module-quran')),
      150,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('module-quran')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('module-quran')));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'Double tap plays reference and explains the mistake without starting capture',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ActionTrackingController();
      final repository = testRepository();
      final player = TestReferencePlayer();
      await pumpQuranModule(
        tester,
        QuranTeacherApp(
          settings: LocalSettings(MemorySettingsStore())..acknowledged = true,
          repository: repository,
          controller: controller,
          referencePlayer: player,
        ),
      );
      for (final entry in ['بِ', 'ش', 'مِ', 'للَ'].asMap().entries) {
        controller.recognitionResults.add(recognition(entry.value, entry.key));
      }
      controller.listening = true;
      final target = find.text(
        repository.getAyah(1, 1).words.first.displayText,
      );
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(controller.starts, 0);
      expect(controller.listening, isFalse);
      expect(player.lastWordIndex, 0);
      expect(find.text('Word practice'), findsNothing);
      final explanation = tester
          .widget<Text>(find.byKey(const ValueKey('word-feedback-explanation')))
          .data!;
      expect(explanation, contains('ش'));
      expect(explanation, contains('Expected sound:'));
      expect(explanation, contains('Heard closer to:'));
      expect(explanation, contains('Try this:'));
      final verseList = tester.widget<ListView>(find.byType(ListView).first);
      expect((verseList.padding! as EdgeInsets).bottom, greaterThan(400));
      expect(find.text('Listen from here'), findsOneWidget);
      await tester.ensureVisible(find.text('Listen from here'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen from here'));
      await tester.pumpAndSettle();
      expect(controller.starts, 1);
      expect(
        find.byKey(const ValueKey('word-feedback-explanation')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets('Tapping a word starts listening without a separate view', (
    tester,
  ) async {
    final controller = ActionTrackingController();
    final repository = testRepository();
    await pumpQuranModule(
      tester,
      QuranTeacherApp(
        settings: LocalSettings(MemorySettingsStore())..acknowledged = true,
        repository: repository,
        controller: controller,
        referencePlayer: TestReferencePlayer(),
      ),
    );
    final ayah = repository.getAyah(1, 1);
    await tester.tap(find.text(ayah.words[2].displayText));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(controller.starts, 1);
    expect(controller.listeningFromWord, ayah.groupForWord(2)!.wordStart);
    expect(controller.practiceWordIndex, isNull);
    expect(find.text('Word practice'), findsNothing);
    expect(find.text('Verse 1 of 7'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('Verse Play advances across surahs and opening Bismillah', (
    tester,
  ) async {
    final repository = testRepository();
    final controller = RecitationController(
      audio: UnavailableCapture(),
      engine: OnnxQuranSpeechEngine(),
    );
    final player = TestReferencePlayer();
    await pumpQuranModule(
      tester,
      QuranTeacherApp(
        settings: LocalSettings(MemorySettingsStore())..acknowledged = true,
        repository: repository,
        controller: controller,
        referencePlayer: player,
      ),
    );
    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(player.nextVerse, isNotNull);
    for (var verse = 2; verse <= 7; verse++) {
      expect(
        player.nextVerse!()!.cacheKey,
        repository.getAyah(1, verse).referenceAudio!.cacheKey,
      );
      await tester.pump();
    }
    expect(
      player.nextVerse!()!.cacheKey,
      repository.getAyah(2, 0).referenceAudio!.cacheKey,
    );
    await tester.pump();
    expect(find.text('Al-Baqarah'), findsOneWidget);
    expect(
      player.nextVerse!()!.cacheKey,
      repository.getAyah(2, 1).referenceAudio!.cacheKey,
    );
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(player.nextVerse, isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets(
    'Baqarah joined-word practice shows and plays the mapped phrase',
    (tester) async {
      final settings = LocalSettings(MemorySettingsStore())
        ..acknowledged = true;
      await settings.setBookmark(2, 26);
      final repository = testRepository();
      final controller = ActionTrackingController();
      final player = TestReferencePlayer();
      await pumpQuranModule(
        tester,
        QuranTeacherApp(
          settings: settings,
          repository: repository,
          controller: controller,
          referencePlayer: player,
        ),
      );
      final verse = repository.getAyah(2, 27);
      final target = find.text(verse.words[13].displayText);
      await tester.scrollUntilVisible(target, 250);
      await Scrollable.ensureVisible(tester.element(target), alignment: .5);
      await tester.pumpAndSettle();
      await tester.longPress(target);
      await tester.pumpAndSettle();
      expect(find.text('Phrase practice'), findsOneWidget);
      expect(
        find.text(verse.pronunciationWord(13).displayText),
        findsOneWidget,
      );
      await tester.tap(find.text('Listen slowly'));
      await tester.pump();
      expect(player.lastPhrase, (12, 14));
      expect(player.lastWordRate, .72);
      expect(tester.takeException(), isNull);
      controller.dispose();
    },
  );
  testWidgets(
    'Mistake holds verse; retry keeps microphone and clears feedback',
    (tester) async {
      final controller = ActionTrackingController();
      final repository = testRepository();
      await pumpQuranModule(
        tester,
        QuranTeacherApp(
          settings: LocalSettings(MemorySettingsStore())..acknowledged = true,
          repository: repository,
          controller: controller,
          referencePlayer: TestReferencePlayer(),
        ),
      );
      controller.listening = true;
      final symbols = [...repository.getAyah(1, 1).expectedPhonemes!];
      symbols[1] = 'ش';
      // Deterministic UI fixture, not an acoustic recognition claim.
      for (final entry in symbols.asMap().entries) {
        controller.recognitionResults.add(recognition(entry.value, entry.key));
      }
      controller.publishForTest();
      await tester.pumpAndSettle();
      expect(controller.needsVerseRetry, isTrue);
      expect(controller.expectedAyah?.ayah, 1);
      expect(controller.listening, isTrue);
      await tester.tap(find.text('Needs practice · Retry verse'));
      await tester.pumpAndSettle();
      expect(controller.recognitionResults, isEmpty);
      expect(controller.listening, isTrue);
      for (final entry
          in repository.getAyah(1, 1).expectedPhonemes!.asMap().entries) {
        controller.recognitionResults.add(recognition(entry.value, entry.key));
      }
      controller.publishForTest();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.expectedAyah?.ayah, 2);
      controller.listening = false;
      controller.dispose();
    },
  );
  testWidgets('Back and Forward change verses without ending capture', (
    tester,
  ) async {
    final settings = LocalSettings(MemorySettingsStore())..acknowledged = true;
    final repository = testRepository();
    final controller = RecitationController(
      audio: UnavailableCapture(),
      engine: OnnxQuranSpeechEngine(),
    );
    await pumpQuranModule(
      tester,
      QuranTeacherApp(
        settings: settings,
        repository: repository,
        controller: controller,
        referencePlayer: TestReferencePlayer(),
      ),
    );
    // Lifecycle/UI test only: no microphone or recognition is simulated as real.
    controller.listening = true;
    controller.frameCount = 16000;
    controller.chunkCount = 10;
    controller.navigateWhileListening(repository.getAyah(1, 1));
    await tester.pump();
    await tester.tap(find.text('Forward'));
    await tester.pumpAndSettle();
    expect(controller.expectedAyah?.ayah, 2);
    expect(controller.listening, isTrue);
    expect(find.text('Stop'), findsOneWidget);
    expect(controller.frameCount, 16000);
    expect(controller.chunkCount, 10);
    controller.recognitionResults.add(recognition('بِ', 0));
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(controller.expectedAyah?.ayah, 1);
    expect(controller.recognitionResults, isEmpty);
    expect(controller.listening, isTrue);
    expect(controller.frameCount, 16000);
    controller.listening = false;
    controller.dispose();
  });

  testWidgets('Dashboard opens modules and returns without retaining audio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = RecitationController(
      audio: UnavailableCapture(),
      engine: OnnxQuranSpeechEngine(),
    );
    final player = TestReferencePlayer();
    await tester.pumpWidget(
      QuranTeacherApp(
        settings: LocalSettings(MemorySettingsStore())..acknowledged = true,
        repository: testRepository(),
        controller: controller,
        referencePlayer: player,
      ),
    );
    expect(find.text('Your learning space'), findsOneWidget);
    expect(find.byKey(const ValueKey('module-translator')), findsNothing);
    expect(find.text('Arabic Translator'), findsNothing);
    expect(find.text('Al-Fātiḥah'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('module-prayer')));
    await tester.pumpAndSettle();
    expect(find.text('Set up prayer times'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('module-dua')),
      250,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('module-dua')));
    await tester.pumpAndSettle();
    expect(find.text('Browse by need'), findsOneWidget);
    await tester.tap(find.byTooltip('Return to dashboard'));
    await tester.pumpAndSettle();
    // The first cards may be lazily evicted in the growing module list.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('module-quran')),
      -250,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('module-quran')));
    await tester.pumpAndSettle();
    expect(find.text('Al-Fātiḥah'), findsOneWidget);
    controller.listening = true;
    player.playing = true;
    await tester.tap(find.byTooltip('Return to dashboard'));
    await tester.pumpAndSettle();
    expect(controller.listening, isFalse);
    expect(player.playing, isFalse);
    expect(find.text('Your learning space'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('Reference playback keeps later words in a long verse visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = LocalSettings(MemorySettingsStore())..acknowledged = true;
    await settings.setBookmark(2, 281);
    final controller = RecitationController(
      audio: UnavailableCapture(),
      engine: OnnxQuranSpeechEngine(),
    );
    final player = TestReferencePlayer();
    await pumpQuranModule(
      tester,
      QuranTeacherApp(
        settings: settings,
        repository: testRepository(),
        controller: controller,
        referencePlayer: player,
      ),
    );
    final word = testRepository().getAyah(2, 282).words.last;
    player.showPlayingWord(word.index);
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.pixels, greaterThan(0));
    final target = find.text(word.english).last;
    expect(tester.getCenter(target).dy, greaterThan(80));
    expect(tester.getCenter(target).dy, lessThan(730));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  for (final appearance in [AppAppearance.light, AppAppearance.dark]) {
    testWidgets('Compact iPhone navigation and settings in $appearance', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final settings = LocalSettings(MemorySettingsStore())
        ..acknowledged = true
        ..appearance = appearance;
      final controller = ActionTrackingController();
      await pumpQuranModule(
        tester,
        QuranTeacherApp(
          settings: settings,
          repository: testRepository(),
          controller: controller,
          referencePlayer: TestReferencePlayer(),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
      expect(controller.followRecitation, isTrue);
      expect(controller.starts, 1);
      expect(find.text('Listen'), findsOneWidget);
      expect(controller.pronunciationErrors, isEmpty);
      expect(controller.tajwidFindings, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Listen'));
      await tester.pumpAndSettle();
      expect(controller.followRecitation, isFalse);
      expect(controller.starts, 2);
      await tester.tap(find.text('Al-Fātiḥah'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.text('2. ${testRepository().getChapter(2).name}').last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.text('Bismillāh'), findsOneWidget);
      await tester.tap(find.byTooltip('Go to surah and verse'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '999');
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a number from 0 to 286'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '255');
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.text('Verse 255 of 286'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Settings and model information'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Plum'));
      await tester.pumpAndSettle();
      expect(settings.colorTheme, AppColorTheme.plum);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
  testWidgets('Onboarding clearly disclaims automatic judgement', (
    tester,
  ) async {
    final settings = LocalSettings(MemorySettingsStore());
    final controller = RecitationController(
      audio: UnavailableCapture(),
      engine: OnnxQuranSpeechEngine(),
    );
    await pumpQuranModule(
      tester,
      QuranTeacherApp(
        settings: settings,
        repository: testRepository(),
        controller: controller,
        referencePlayer: TestReferencePlayer(),
      ),
    );
    expect(find.text(teacherDisclaimer), findsOneWidget);
    expect(find.textContaining('Tajwīd feedback is limited'), findsOneWidget);
    controller.dispose();
  });
  testWidgets('Appearance and color choices persist locally', (tester) async {
    final store = MemorySettingsStore();
    final settings = LocalSettings(store)..acknowledged = true;
    await settings.setAppearance(AppAppearance.dark);
    await settings.setColorTheme(AppColorTheme.plum);

    final restored = LocalSettings(store);
    await restored.load();
    expect(restored.appearance, AppAppearance.dark);
    expect(restored.colorTheme, AppColorTheme.plum);

    final controller = RecitationController(
      audio: UnavailableCapture(),
      engine: OnnxQuranSpeechEngine(),
    );
    await pumpQuranModule(
      tester,
      QuranTeacherApp(
        settings: restored,
        repository: testRepository(),
        controller: controller,
        referencePlayer: TestReferencePlayer(),
      ),
    );
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    controller.dispose();
  });
  testWidgets(
    'Follow mode restores without starting the microphone and can be cleared',
    (tester) async {
      final store = MemorySettingsStore();
      final settings = LocalSettings(store);
      await settings.acknowledge();
      await settings.setFollowRecitation(true);
      final restored = LocalSettings(store);
      await restored.load();
      expect(restored.followRecitation, isTrue);
      final controller = RecitationController(
        audio: UnavailableCapture(),
        engine: OnnxQuranSpeechEngine(),
      );
      await pumpQuranModule(
        tester,
        QuranTeacherApp(
          settings: restored,
          repository: testRepository(),
          controller: controller,
          referencePlayer: TestReferencePlayer(),
        ),
      );
      expect(controller.followRecitation, isTrue);
      expect(controller.listening, isFalse);
      expect(find.text('Listen'), findsOneWidget);
      await restored.setFollowRecitation(false);
      final practice = LocalSettings(store);
      await practice.load();
      expect(practice.followRecitation, isFalse);
      await restored.setFollowRecitation(true);
      await restored.deleteAll();
      final cleared = LocalSettings(store);
      await cleared.load();
      expect(cleared.followRecitation, isFalse);
      expect(store.values.containsKey('follow_recitation'), isFalse);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('Only the bookmark controls startup at the following verse', (
    tester,
  ) async {
    final store = MemorySettingsStore();
    store.values['last_surah'] = 7;
    store.values['last_ayah'] = 206;
    final settings = LocalSettings(store);
    await settings.acknowledge();
    await settings.setBookmark(2, 2);
    await settings.setBookmark(2, 8);
    final restored = LocalSettings(store);
    await restored.load();
    final controller = RecitationController(
      audio: UnavailableCapture(),
      engine: OnnxQuranSpeechEngine(),
    );
    await pumpQuranModule(
      tester,
      QuranTeacherApp(
        settings: restored,
        repository: testRepository(),
        controller: controller,
        referencePlayer: TestReferencePlayer(),
      ),
    );
    expect(find.text('Al-Baqarah'), findsOneWidget);
    expect(find.text('Verse 9 of 286'), findsOneWidget);
    expect(restored.bookmarkSurah, 2);
    expect(restored.bookmarkAyah, 8);
    await tester.tap(find.text('Forward'));
    await tester.pump();
    expect(find.text('Verse 10 of 286'), findsOneWidget);
    expect(store.values['last_surah'], 7);
    expect(store.values['last_ayah'], 206);
    controller.dispose();
  });
  for (final location in [(2, 1), (2, 8), (1, 7)]) {
    testWidgets(
      'Bookmark available at ${location.$1}:${location.$2} with appropriate note',
      (tester) async {
        final settings = LocalSettings(MemorySettingsStore())
          ..acknowledged = true;
        if (location.$2 > 1) {
          await settings.setBookmark(location.$1, location.$2 - 1);
        }
        if (location == (2, 1)) await settings.setBookmark(1, 7);
        final controller = RecitationController(
          audio: UnavailableCapture(),
          engine: OnnxQuranSpeechEngine(),
        );
        await pumpQuranModule(
          tester,
          QuranTeacherApp(
            settings: settings,
            repository: testRepository(),
            controller: controller,
            referencePlayer: TestReferencePlayer(),
          ),
        );
        if (location == (2, 1)) {
          await tester.tap(find.text('Forward'));
          await tester.pumpAndSettle();
        }
        final current = testRepository().getAyah(location.$1, location.$2);
        await tester.pumpAndSettle();
        final end =
            location.$2 == testRepository().getChapter(location.$1).versesCount;
        await tester.scrollUntilVisible(
          find.text('Bookmark this verse'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Bookmark this verse'));
        await tester.pumpAndSettle();
        final note = find.text(
          'Not good stopping point',
        );
        expect(
          note,
          current.hasRecommendedStop || end ? findsNothing : findsOneWidget,
        );
        await tester.tap(find.text('Bookmark this verse'));
        await tester.pumpAndSettle();
        expect(settings.bookmarkSurah, location.$1);
        expect(settings.bookmarkAyah, location.$2);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
  testWidgets('A bookmark at a surah end resumes at the next surah', (
    tester,
  ) async {
    final settings = LocalSettings(MemorySettingsStore());
    await settings.acknowledge();
    await settings.setBookmark(1, 7);
    final controller = RecitationController(
      audio: UnavailableCapture(),
      engine: OnnxQuranSpeechEngine(),
    );
    await pumpQuranModule(
      tester,
      QuranTeacherApp(
        settings: settings,
        repository: testRepository(),
        controller: controller,
        referencePlayer: TestReferencePlayer(),
      ),
    );
    expect(find.text('Al-Baqarah'), findsOneWidget);
    expect(find.text('Bismillāh'), findsOneWidget);
    expect(controller.expectedAyah!.ayah, 0);
    await tester.tap(find.text('Forward'));
    await tester.pumpAndSettle();
    expect(find.text('Verse 1 of 286'), findsOneWidget);
    controller.dispose();
  });
  testWidgets('Sajdah verse shows the recitation sajdah message', (
    tester,
  ) async {
    final settings = LocalSettings(MemorySettingsStore())..acknowledged = true;
    await settings.setBookmark(7, 205);
    final controller = RecitationController(
      audio: UnavailableCapture(),
      engine: OnnxQuranSpeechEngine(),
    );
    await pumpQuranModule(
      tester,
      QuranTeacherApp(
        settings: settings,
        repository: testRepository(),
        controller: controller,
        referencePlayer: TestReferencePlayer(),
      ),
    );
    await tester.scrollUntilVisible(find.text('Sajdah verse'), 300);
    expect(find.text('Sajdah verse'), findsOneWidget);
    expect(
      find.text('Perform sajdah after reciting this verse.'),
      findsOneWidget,
    );
    controller.dispose();
  });
  testWidgets(
    'Seven ayat selectable; developer diagnostics do not fabricate results',
    (tester) async {
      final settings = LocalSettings(MemorySettingsStore())
        ..acknowledged = true;
      final controller = RecitationController(
        audio: UnavailableCapture(),
        engine: OnnxQuranSpeechEngine(),
        progress: LocalProgressRepository(MemoryProgressStore()),
      );
      await pumpQuranModule(
        tester,
        QuranTeacherApp(
          settings: settings,
          repository: testRepository(),
          controller: controller,
          referencePlayer: TestReferencePlayer(),
        ),
      );
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Verse 1 of 7'), findsOneWidget);
      await tester.tap(find.text('Forward'));
      await tester.pump();
      await tester.tap(find.text('Forward'));
      await tester.pump();
      expect(find.text('Verse 3 of 7'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Listen'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(find.byTooltip('Practice progress'), findsOneWidget);
      await tester.longPress(find.text('Al-Fātiḥah'));
      await tester.pumpAndSettle();
      expect(find.text('Developer diagnostics'), findsOneWidget);
      expect(find.text('Calibration recordings'), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(SelectableText), 200);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        contains('Raw CTC IDs: unavailable'),
      );
      controller.dispose();
    },
  );
  testWidgets('Supported mismatch is underlined and opens word practice', (
    tester,
  ) async {
    final settings = LocalSettings(MemorySettingsStore())..acknowledged = true;
    final repository = testRepository();
    final controller = RecitationController(
      audio: UnavailableCapture(),
      engine: OnnxQuranSpeechEngine(),
      progress: LocalProgressRepository(MemoryProgressStore()),
    );
    final referencePlayer = TestReferencePlayer();
    await pumpQuranModule(
      tester,
      QuranTeacherApp(
        settings: settings,
        repository: repository,
        controller: controller,
        referencePlayer: referencePlayer,
      ),
    );
    // UI-only synthetic mismatch, not an acoustic accuracy test.
    for (final entry in ['بِ', 'ش', 'مِ', 'للَ'].asMap().entries) {
      controller.recognitionResults.add(recognition(entry.value, entry.key));
    }
    await controller.stopMicrophone();
    await tester.pumpAndSettle();
    final reviewedWord = find.text(
      repository.getAyah(1, 1).words.first.displayText,
    );
    expect(
      tester.widget<Text>(reviewedWord).style?.decoration,
      TextDecoration.underline,
    );
    final unreadWord = find.text(
      repository.getAyah(1, 1).words.last.displayText,
    );
    expect(
      tester.widget<Text>(unreadWord).style?.decoration,
      TextDecoration.none,
    );
    await tester.longPress(reviewedWord);
    await tester.pumpAndSettle();
    expect(find.text('Word practice'), findsOneWidget);
    expect(find.text('Expected model phonemes'), findsNothing);
    expect(find.text('Detected phonemes'), findsNothing);
    expect(find.text('Listen'), findsOneWidget);
    expect(find.text('Listen slowly'), findsOneWidget);
    expect(
      find.text(repository.getAyah(1, 1).words.first.english),
      findsOneWidget,
    );
    await tester.tap(find.text('Listen slowly'));
    await tester.pump();
    expect(referencePlayer.lastWordRate, .72);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(controller.practiceWordIndex, isNull);
    expect(find.text('Verse 1 of 7'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('Settings keeps calibration in developer diagnostics', (
    tester,
  ) async {
    final settings = LocalSettings(MemorySettingsStore())..acknowledged = true;
    final controller = RecitationController(
      audio: UnavailableCapture(),
      engine: OnnxQuranSpeechEngine(),
      progress: LocalProgressRepository(MemoryProgressStore()),
    );
    await pumpQuranModule(
      tester,
      QuranTeacherApp(
        settings: settings,
        repository: testRepository(),
        controller: controller,
        referencePlayer: TestReferencePlayer(),
      ),
    );
    await tester.tap(find.byTooltip('Settings and model information'));
    await tester.pumpAndSettle();
    expect(find.text('Calibration recordings'), findsNothing);
    controller.dispose();
  });

  testWidgets('Progress entries open the exact word for practice', (
    tester,
  ) async {
    final settings = LocalSettings(MemorySettingsStore())..acknowledged = true;
    final repository = testRepository();
    final progress = LocalProgressRepository(MemoryProgressStore());
    final target = repository.getAyah(1, 2).words[2];
    await progress.add(
      surah: 1,
      ayah: 2,
      wordIndex: target.index,
      word: target.text,
      status: WordFeedbackStatus.needsReview,
      meanConfidence: .91,
      findings: const [],
    );
    final controller = RecitationController(
      audio: UnavailableCapture(),
      engine: OnnxQuranSpeechEngine(),
      progress: progress,
    );
    await pumpQuranModule(
      tester,
      QuranTeacherApp(
        settings: settings,
        repository: repository,
        controller: controller,
        referencePlayer: TestReferencePlayer(),
      ),
    );
    await tester.tap(find.byTooltip('Practice progress'));
    await tester.pumpAndSettle();
    expect(find.text('Words to revisit'), findsOneWidget);
    await tester.tap(find.text(target.text).first);
    await tester.pumpAndSettle();
    expect(find.text('Word practice'), findsOneWidget);
    expect(find.text(target.english), findsOneWidget);
    controller.dispose();
  });

  testWidgets('Accuracy check counts capped per-ayah test samples', (
    tester,
  ) async {
    late Directory directory;
    late LocalCalibrationRepository calibration;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp(
        'quran_teacher_accuracy_widget_',
      );
      calibration = LocalCalibrationRepository(
        directoryProvider: () async => directory,
      );
      await calibration.save(
        surah: 1,
        ayah: 1,
        label: CalibrationLabel.carefulRecitation,
        pcm16le: Uint8List(320),
        recognitionMetadata: const {},
      );
    });
    final settings = LocalSettings(MemorySettingsStore())..acknowledged = true;
    final controller = RecitationController(
      audio: UnavailableCapture(),
      engine: OnnxQuranSpeechEngine(),
      calibration: calibration,
    );
    await pumpQuranModule(
      tester,
      QuranTeacherApp(
        settings: settings,
        repository: testRepository(),
        controller: controller,
        referencePlayer: TestReferencePlayer(),
      ),
    );
    await tester.tap(find.byTooltip('Settings and model information'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    expect(find.text('Accuracy check'), findsWidgets);
    await tester.tap(find.text('Accuracy check').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Careful recitations: 1 of 21'), findsOneWidget);
    expect(
      find.text('Known changes or skipped words: 0 of 14'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.runAsync(() => directory.delete(recursive: true));
  });
}
