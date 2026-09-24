// Actual Flutter UI renders replaying saved outputs from real native Qwen runs.
// Not a live iPhone inference test; never included in the application.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/ask/ask_library.dart';
import 'package:quran_teacher_ai/core/hadith/hadith_repository.dart';
import 'package:quran_teacher_ai/core/theme/app_theme.dart';
import 'package:quran_teacher_ai/core/settings/local_settings.dart';
import 'package:quran_teacher_ai/features/ask/ask_screen.dart';

import 'ask_test.dart' show TestAskEngine;

void main() {
  testWidgets('Render recorded real-model answers at iPhone size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(440, 956));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      for (final font in {
        'PreviewUI': '/System/Library/Fonts/SFNS.ttf',
        'Arial': '/System/Library/Fonts/Supplemental/Arial.ttf',
        'QuranIndoPak': 'assets/fonts/indopak-nastaleeq-waqf-lazim-v4.2.1.ttf',
        'MaterialIcons': '/Users/shahzadsarwar/Library/Caches/quran-teacher-flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(font.key)..addFont(
              File(font.value).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
    });
    final report =
        jsonDecode(File('docs/ask-model-smoke.json').readAsStringSync()) as Map;
    final theme = buildAppTheme(AppColorTheme.emerald, Brightness.light);
    for (final name in ['supported', 'hadith', 'unsupported']) {
      final fixture = jsonDecode(
        File('test/fixtures/ask/$name.json').readAsStringSync(),
      ) as Map;
      final p = fixture['passages'][0] as Map;
      AskSource source = AskSource(
        id: 'replay:112:1',
        title: p['reference'],
        arabic: p['arabic'],
        english: p['english'],
        provenance: p['provenance'],
        notes: p['publisherNotes'] as String? ?? '',
        englishLabel: 'Translation of the meanings',
      );
      if (name == 'hadith') {
        final catalog = jsonDecode(
          File('assets/data/hadith/catalog.json').readAsStringSync(),
        ) as Map;
        final collection = (catalog['collections'] as List).firstWhere(
          (c) => c['id'] == 'nawawi',
        ) as Map;
        final record = parseHadithBook(
          File('assets/data/hadith/${collection['books'][0]['file']}')
              .readAsStringSync(),
        ).first;
        source = AskSource.hadith(record, collection['title']);
      }
      final result = (report['results'] as List).firstWhere(
        (r) => r['name'] == name,
      ) as Map;
      final engine = TestAskEngine()..response = jsonEncode(result['answer']);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'PreviewUI'),
              filledButtonTheme: FilledButtonThemeData(
                style: theme.filledButtonTheme.style?.copyWith(
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(
                      fontFamily: 'PreviewUI',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              appBarTheme: theme.appBarTheme.copyWith(
                titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                  fontFamily: 'PreviewUI',
                ),
              ),
            ),
            home: AskScreen(
              key: ValueKey(name),
              selected: source,
              engine: engine,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        fixture['question'] as String,
      );
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      // Replay timing is not a measurement of model inference on a phone.
      await tester.drag(find.byType(ListView).first, const Offset(0, -370));
      await tester.pumpAndSettle();
      Future<void> capture(String suffix) async {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('docs/screenshots/ask-$suffix.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      expect(tester.takeException(), isNull);
      await capture(name);
      if (name == 'supported') {
        await tester.ensureVisible(find.text('Source 1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Source 1'));
        await tester.pumpAndSettle();
        await capture('source');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  }, skip: !const bool.fromEnvironment('ASK_ACTION_SCREENSHOTS'));
}
