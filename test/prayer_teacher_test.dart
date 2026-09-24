import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/ask/ask_translation.dart';
import 'package:quran_teacher_ai/core/prayer/prayer_lesson.dart';
import 'package:quran_teacher_ai/core/prayer/wudu_lesson.dart';
import 'package:quran_teacher_ai/core/settings/local_settings.dart';
import 'package:quran_teacher_ai/core/theme/app_theme.dart';
import 'package:quran_teacher_ai/features/prayer/prayer_teacher_screen.dart';

import 'widget_test.dart' show testRepository, MemorySettingsStore;

void main() {
  test('Wudu covers the washing sequence with bundled illustrations', () {
    expect(wuduLesson.length, 11);
    expect(
      wuduLesson.map((s) => s.title),
      containsAllInOrder([
        'Wash your hands',
        'Rinse your mouth',
        'Rinse your nose',
        'Wash your face',
        'Wash your arms',
        'Wipe your head',
        'Wipe your ears',
        'Wash your feet',
        'After wudu',
      ]),
    );
    for (final step in wuduLesson) {
      expect(File(step.illustrationAsset).existsSync(), isTrue);
      expect(step.source, isNotEmpty);
    }
  });
  final translation = AskTranslation(
    jsonDecode(File('assets/data/ask_translation.json').readAsStringSync()),
  );
  test('Every Arabic lesson step has audio and phrase files are bundled', () {
    for (final step in [
      ...twoRakahLesson(testRepository(), translation),
      ...wuduLesson,
    ]) {
      if (step.arabic.isEmpty) continue;
      expect(step.audio, isNotNull, reason: step.title);
      if (step.verse == null) {
        expect(File(step.audio!.asset!).lengthSync(), greaterThan(1000));
      }
    }
  });
  test('Both rakahs include Fatiha, short surah and two prostrations', () {
    final steps = twoRakahLesson(testRepository(), translation);
    for (final step in steps) {
      expect(File(step.illustrationAsset).existsSync(), isTrue);
    }
    expect(
      steps.firstWhere((s) => s.title == 'Opening takbir').illustration,
      'takbir',
    );
    expect(steps.firstWhere((s) => s.verse != null).illustration, 'reciting');
    for (var r = 1; r <= 2; r++) {
      final unit = steps.where((s) => s.rakah == r);
      expect(unit.where((s) => s.title.startsWith('Al-Fātiḥah')), hasLength(7));
      expect(unit.where((s) => s.verse?.surah == 112), hasLength(4));
      expect(unit.where((s) => s.pose == PrayerPose.prostrating), hasLength(2));
    }
    expect(steps.where((s) => s.title == 'Opening takbir'), hasLength(1));
    final titles = steps.map((s) => s.title).toList();
    expect(
      titles.indexOf('Testimony · Shahādah'),
      lessThan(titles.indexOf('Send blessings')),
    );
    expect(
      titles.indexOf('Send blessings'),
      lessThan(titles.indexOf('Duʿā before finishing')),
    );
    expect(steps.last.title, 'Salām · Left');
    expect(fingerDifferences, contains('Hanafi'));
    expect(fingerDifferences, contains('Maliki'));
    for (final s in steps.where((s) => s.verse != null)) {
      expect(s.arabic, s.verse!.uthmani);
      expect(s.verse!.referenceAudio, isNotNull);
    }
  });
  testWidgets('Small iPhone lesson navigates without overflow', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const channel = MethodChannel('org.quranteacher/playback');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PrayerTeacherScreen(
          repository: testRepository(),
          settings: LocalSettings(MemorySettingsStore()),
        ),
      ),
    );
    for (
      var i = 0;
      i < 50 && find.byKey(const ValueKey('prayer-Fajr')).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('prayer-Fajr')));
    await tester.pumpAndSettle();
    expect(find.text('2 sunnah before'), findsOneWidget);
    expect(find.text('2 fard'), findsOneWidget);
    await tester.tap(find.text('Start full prayer'));
    await tester.pumpAndSettle();
    expect(find.text('Before you begin'), findsOneWidget);
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('Intention'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous step'));
    await tester.pumpAndSettle();
    expect(find.text('Before you begin'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Listen'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Listen'));
    await tester.pump();
    expect(calls.last.method, 'play');
    expect(
      (calls.last.arguments as Map)['asset'],
      'assets/audio/prayer/takbir.mp3',
    );
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    expect(calls.last.method, 'stop');
    for (
      var n = 0;
      n < 80 && find.text('Next prayer part').evaluate().isEmpty;
      n++
    ) {
      await tester.tap(find.text('Next step'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Next prayer part'), findsOneWidget);
    await tester.tap(find.text('Next prayer part'));
    await tester.pumpAndSettle();
    expect(find.text('2 fard'), findsOneWidget);
    expect(find.text('Before you begin'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to prayers'));
    await tester.pumpAndSettle();
    expect(find.text('Start full prayer'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to prayers'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('prayer-Isha')),
      200,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('prayer-Isha')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('prayer-Isha')));
    await tester.pumpAndSettle();
    expect(find.text('4 fard'), findsOneWidget);
    expect(find.text('2 sunnah after'), findsOneWidget);
    expect(find.text('3 Witr · Hanafi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Render Prayer Teacher and wudu for App Store review', (
    tester,
  ) async {
    const screenshots = bool.fromEnvironment('APP_STORE_SCREENSHOTS');
    if (!screenshots) return;
    await tester.binding.setSurfaceSize(const Size(440, 956));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      for (final font in <String, String>{
        'PreviewUI': '/System/Library/Fonts/SFNS.ttf',
        'QuranIndoPak': 'assets/fonts/indopak-nastaleeq-waqf-lazim-v4.2.1.ttf',
        'MaterialIcons': '/Users/shahzadsarwar/Library/Caches/quran-teacher-flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(font.key)..addFont(
              File(font.value).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
    });
    const channel = MethodChannel('org.quranteacher/playback');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final boundary = GlobalKey();
    final theme = buildAppTheme(AppColorTheme.emerald, Brightness.light);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'PreviewUI'),
            appBarTheme: theme.appBarTheme.copyWith(
              titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                fontFamily: 'PreviewUI',
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: theme.filledButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontFamily: 'PreviewUI', fontSize: 16),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: theme.outlinedButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontFamily: 'PreviewUI', fontSize: 16),
                ),
              ),
            ),
          ),
          home: PrayerTeacherScreen(
            repository: testRepository(),
            settings: LocalSettings(MemorySettingsStore()),
          ),
        ),
      ),
    );
    for (
      var i = 0;
      i < 50 && find.byKey(const ValueKey('prayer-Fajr')).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }

    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('docs/app-store/screenshots').create(recursive: true);
        await File('docs/app-store/screenshots/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.tap(find.byKey(const ValueKey('prayer-Fajr')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start full prayer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('Opening takbir'), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    await capture('04-prayer-teacher');

    await tester.tap(find.byTooltip('Back to prayers'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to prayers'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Learn wudu'), 250);
    await tester.tap(find.text('Learn wudu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('Wash your hands'), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    await capture('05-wudu-guide');
    expect(tester.takeException(), isNull);
  });
}
