import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/app.dart';
import 'package:quran_teacher_ai/core/audio/quran_reference_player.dart';
import 'package:quran_teacher_ai/core/settings/local_settings.dart';
import 'package:quran_teacher_ai/core/speech/quran_speech_engine.dart';
import 'package:quran_teacher_ai/core/theme/app_theme.dart';
import 'package:quran_teacher_ai/features/recitation/recitation_controller.dart';

import 'widget_test.dart'
    show MemorySettingsStore, UnavailableCapture, testRepository;

void main() {
  testWidgets('Render current dashboard for App Store review', (tester) async {
    const screenshots = bool.fromEnvironment('APP_STORE_SCREENSHOTS');
    if (!screenshots) return;
    await tester.binding.setSurfaceSize(const Size(440, 956));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      for (final font in <String, String>{
        'PreviewUI': '/System/Library/Fonts/SFNS.ttf',
        'MaterialIcons': '/Users/shahzadsarwar/Library/Caches/quran-teacher-flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(font.key)..addFont(
              File(font.value).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
    });
    final controller = RecitationController(
      audio: UnavailableCapture(),
      engine: OnnxQuranSpeechEngine(),
    );
    addTearDown(controller.dispose);
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
          ),
          home: ModuleDashboard(
            repository: testRepository(),
            controller: controller,
            settings: LocalSettings(MemorySettingsStore())..acknowledged = true,
            referencePlayer: QuranReferencePlayer(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('docs/app-store/screenshots').create(recursive: true);
      await File('docs/app-store/screenshots/01-dashboard.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
