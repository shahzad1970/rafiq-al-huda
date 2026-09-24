// iPhone-sized Flutter renders of real calculations; not a connected-device capture.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/settings/local_settings.dart';
import 'package:quran_teacher_ai/core/prayer/prayer_schedule.dart';
import 'package:quran_teacher_ai/core/theme/app_theme.dart';
import 'package:quran_teacher_ai/features/prayer/prayer_screen.dart';

import 'widget_test.dart' show MemorySettingsStore;

void main() {
  testWidgets('Prayer module visual review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 956));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      for (final f in {
        'PreviewUI': '/System/Library/Fonts/SFNS.ttf',
        'MaterialIcons': '/Users/shahzadsarwar/Library/Caches/quran-teacher-flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(f.key)
              ..addFont(File(f.value).readAsBytes().then(ByteData.sublistView)))
            .load();
      }
    });
    final settings = LocalSettings(MemorySettingsStore());
    await settings.setPrayerConfiguration(
      PrayerConfiguration(
        location: PrayerLocation.cities.first,
        method: 'ISNA',
        hanafi: true,
      ),
    );
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final key = GlobalKey();
      final theme = buildAppTheme(AppColorTheme.emerald, brightness);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'PreviewUI'),
              appBarTheme: theme.appBarTheme.copyWith(
                titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                  fontFamily: 'PreviewUI',
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(
                    fontFamily: 'PreviewUI',
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            home: PrayerScreen(
              settings: settings,
              now: () => DateTime.utc(2026, 9, 20, 15),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/screenshots/prayer-${brightness.name}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
  }, skip: !const bool.fromEnvironment('PRAYER_SCREENSHOTS'));
}
