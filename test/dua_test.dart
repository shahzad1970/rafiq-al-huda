import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/dua/dua_catalog.dart';
import 'package:quran_teacher_ai/core/quran/quran_repository.dart';
import 'package:quran_teacher_ai/core/settings/local_settings.dart';
import 'package:quran_teacher_ai/core/theme/app_theme.dart';
import 'package:quran_teacher_ai/features/dua/dua_screen.dart';

import 'widget_test.dart' show MemorySettingsStore;

void main() {
  final repository = LocalQuranRepository.fromJsonString(
    File(LocalQuranRepository.assetPath).readAsStringSync(),
  );
  test(
    'Dua excerpts are valid, sourced and searchable without Arabic diacritics',
    () {
      expect(
        DuaCatalog.entries.map((d) => d.id).toSet().length,
        DuaCatalog.entries.length,
      );
      for (final entry in DuaCatalog.entries) {
        expect(entry.arabic(repository).trim(), isNotEmpty);
        expect(entry.meaning.trim(), isNotEmpty);
        expect(entry.reference.trim(), isNotEmpty);
        if (entry.isQuranExcerpt) {
          expect(entry.words(repository), isNotEmpty);
          expect(
            entry.sourceUrl,
            'https://quran.com/${entry.surah}/${entry.ayah}',
          );
        } else {
          expect(
            entry.sourceUrl,
            startsWith('https://github.com/fitrahive/dua-dhikr/blob/'),
          );
          expect(entry.words(repository), isEmpty);
        }
        expect(
          DuaCatalog.categories.any((c) => c.id == entry.category),
          isTrue,
        );
      }
      expect(DuaCatalog.entries.length, 91);
      expect(
        DuaCatalog.search(repository, 'parents').map((d) => d.id),
        contains('parents'),
      );
      expect(DuaCatalog.search(repository, 'رب زدني علما').map((d) => d.id), [
        'knowledge',
      ]);
      expect(DuaCatalog.search(repository, 'nonexistent'), isEmpty);
      expect(
        DuaCatalog.search(repository, '', category: 'family').length,
        greaterThan(2),
      );
      for (final category in DuaCatalog.categories) {
        expect(
          DuaCatalog.search(repository, '', category: category.id),
          isNotEmpty,
        );
      }
      final shared = DuaCatalog.entries.firstWhere(
        (d) => d.id == 'fitrahive-daily-dua-27',
      );
      expect(shared.inCategory('morning'), isTrue);
      expect(shared.inCategory('evening'), isTrue);
      expect(DuaCatalog.search(repository, 'sleep'), isNotEmpty);
      expect(DuaCatalog.search(repository, 'travel'), isNotEmpty);
      expect(
        DuaCatalog.search(repository, '', favourites: {'mercy'}).single.id,
        'mercy',
      );
    },
  );
  test('Dua favourites survive reload and delete all clears them', () async {
    final store = MemorySettingsStore();
    final settings = LocalSettings(store);
    await settings.toggleDuaFavourite('knowledge');
    await settings.toggleDuaFavourite('fitrahive-daily-dua-1');
    final reloaded = LocalSettings(store);
    await reloaded.load();
    expect(reloaded.favouriteDuas, {'knowledge', 'fitrahive-daily-dua-1'});
    await reloaded.deleteAll();
    await settings.load();
    expect(settings.favouriteDuas, isEmpty);
  });

  testWidgets('Dua category, search, save and detail work on an iPhone', (
    tester,
  ) async {
    const screenshots = bool.fromEnvironment('DUA_SCREENSHOTS');
    tester.view.physicalSize = screenshots
        ? const Size(440, 956)
        : const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = LocalSettings(MemorySettingsStore());
    final boundary = GlobalKey();
    if (screenshots) {
      await tester.runAsync(() async {
        for (final font in <String, String>{
          'PreviewUI': '/System/Library/Fonts/SFNS.ttf',
          'QuranIndoPak':
              'assets/fonts/indopak-nastaleeq-waqf-lazim-v4.2.1.ttf',
          'MaterialIcons': '/Users/shahzadsarwar/Library/Caches/quran-teacher-flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        }.entries) {
          final loader = FontLoader(
            font.key,
          )..addFont(File(font.value).readAsBytes().then(ByteData.sublistView));
          await loader.load();
        }
      });
    }
    final theme = buildAppTheme(AppColorTheme.emerald, Brightness.light);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: screenshots
              ? theme.copyWith(
                  textTheme: theme.textTheme.apply(fontFamily: 'PreviewUI'),
                  appBarTheme: theme.appBarTheme.copyWith(
                    titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                      fontFamily: 'PreviewUI',
                    ),
                  ),
                )
              : theme,
          home: DuaScreen(repository: repository, settings: settings),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      if (!screenshots) return;
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('docs/screenshots').create(recursive: true);
        await File('docs/screenshots/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('dua-library');
    await tester.ensureVisible(
      find.byKey(const ValueKey('dua-category-guidance')),
    );
    await tester.tap(find.byKey(const ValueKey('dua-category-guidance')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Save Increase me in knowledge'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Increase me in knowledge'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Save Increase me in knowledge'));
    await tester.tap(find.byTooltip('Save Increase me in knowledge'));
    await tester.pumpAndSettle();
    expect(settings.favouriteDuas, contains('knowledge'));
    await tester.tap(find.byKey(const ValueKey('dua-knowledge')));
    await tester.pumpAndSettle();
    expect(find.text('My Lord, increase my knowledge.'), findsOneWidget);
    await capture('dua-reading');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('All categories'),
      -350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('All categories'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'parents');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('For parents and believers'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('For parents and believers'), findsOneWidget);
    expect(find.text('Increase me in knowledge'), findsNothing);
    await tester.scrollUntilVisible(
      find.byTooltip('Clear search'),
      -350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Clear search'));
    await tester.tap(find.text('Saved (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Increase me in knowledge'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Imported daily dua displays Arabic, meaning and attribution', (
    tester,
  ) async {
    final dua = DuaCatalog.entries.firstWhere(
      (d) => d.id == 'fitrahive-daily-dua-1',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DuaDetailScreen(
          dua: dua,
          repository: repository,
          settings: LocalSettings(MemorySettingsStore()),
        ),
      ),
    );
    expect(find.text(dua.arabic(repository)), findsOneWidget);
    expect(find.text(dua.meaning), findsOneWidget);
    await tester.ensureVisible(find.textContaining('individual narrations'));
    expect(find.textContaining('individual narrations'), findsOneWidget);
    expect(find.textContaining('excerpt from'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
