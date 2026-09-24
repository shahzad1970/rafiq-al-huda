import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/hadith/hadith_repository.dart';
import 'package:quran_teacher_ai/core/settings/local_settings.dart';
import 'package:quran_teacher_ai/core/theme/app_theme.dart';
import 'package:quran_teacher_ai/features/hadith/hadith_screen.dart';

import 'widget_test.dart' show MemorySettingsStore;

void main() {
  HadithRepository repository() =>
      HadithRepository(loader: (p) async => File(p).readAsStringSync());
  test(
    'All ten pinned editions and every book have consistent identities',
    () async {
      final collections = await repository().collections();
      expect(collections.length, 10);
      expect(collections.map((c) => c.id).toSet(), {
        'bukhari',
        'muslim',
        'abudawud',
        'tirmidhi',
        'nasai',
        'ibnmajah',
        'malik',
        'nawawi',
        'qudsi',
        'dehlawi',
      });
      final ids = <String>{};
      var total = 0;
      var missing = 0;
      for (final collection in collections) {
        var count = 0;
        for (final book in collection.books) {
          final rows = parseHadithBook(
            File('${HadithRepository.assetRoot}/${book.file}')
                .readAsStringSync(),
          );
          expect(rows.length, book.count);
          expect(rows.map((r) => r.number).toSet(), book.numbers);
          for (final row in rows) {
            expect(ids.add(row.id), isTrue, reason: row.id);
            expect(row.book, book.id);
            if (row.arabic == null && row.english == null) missing++;
            for (final grade in row.grades) {
              expect(grade['name'], isA<String>());
              expect(grade['grade'], isA<String>());
            }
          }
          count += rows.length;
        }
        expect(count, collection.count);
        total += count;
      }
      expect(total, 36512);
      expect(missing, 404);
      expect(
        collections.fold<int>(0, (n, c) => n + c.unavailableCount),
        missing,
      );
    },
  );
  test('Search handles Arabic marks, exact number, and source text', () async {
    final repo = repository();
    final collection = (await repo.collections()).firstWhere(
      (c) => c.id == 'nawawi',
    );
    expect(collection.search('42').length, 1);
    expect(collection.search('999999'), isEmpty);
    final rows = await repo.loadBook(collection.books.single);
    expect(rows.where((r) => r.matches('1')).length, 1);
    expect(rows.first.matches('motives'), isTrue);
    expect(rows.first.matches('الاعمال بالنيات'), isTrue);
    expect(rows.first.grades, isEmpty);
  });
  test('Repository bounds book cache and retries failures', () async {
    var calls = 0;
    final repo = HadithRepository(
      loader: (path) async {
        calls++;
        return File(path).readAsStringSync();
      },
    );
    final books = (await repo.collections()).first.books.take(3).toList();
    await repo.loadBook(books[0]);
    await repo.loadBook(books[1]);
    await repo.loadBook(books[2]);
    final before = calls;
    await repo.loadBook(books[2]);
    expect(calls, before);
    await repo.loadBook(books[0]);
    expect(calls, before + 1);
    var fail = true;
    final retry = HadithRepository(
      loader: (path) async {
        if (fail) {
          fail = false;
          throw const FormatException('test');
        }
        return File(path).readAsStringSync();
      },
    );
    await expectLater(retry.collections(), throwsFormatException);
    expect((await retry.collections()).length, 10);
  });
  test('Missing translation remains absent, never invented', () {
    const punctuation = 'قال: "إنما الأعمال" [1]';
    expect(hadithArabicSpan(punctuation).toPlainText(), punctuation);
    final row = HadithRecord(
      jsonDecode(
        '{"id":"test:1","number":"1","book":"1","bookNumber":"1","arabic":"نص","english":null,"grades":[]}',
      ) as Map<String, dynamic>,
    );
    expect(row.english, isNull);
    expect(row.grades, isEmpty);
  });
  test('AI fills eleven gaps without replacing source English', () async {
    final collections = await repository().collections();
    final ai = <HadithRecord>[];
    var missing = 0;
    for (final c in collections) {
      for (final b in c.books) {
        for (final h in parseHadithBook(
          File('${HadithRepository.assetRoot}/${b.file}').readAsStringSync(),
        )) {
          if (h.usesAiTranslation) {
            ai.add(h);
            expect(h.english, isNull);
            expect(h.arabic, isNotEmpty);
            expect(
              h.englishForCopy,
              startsWith(HadithRecord.aiTranslationLabel),
            );
          }
          if (h.english != null) expect(h.displayEnglish, h.english);
          if (h.displayEnglish == null) {
            missing++;
            expect(h.arabic, isNull);
          }
        }
      }
    }
    expect(ai.length, 11);
    expect(missing, 404);
    expect(
      ai.firstWhere((h) => h.number == '471').matches('Musaylimah'),
      isTrue,
    );
    final published = HadithRecord({
      'id': 'test',
      'number': '1',
      'book': '1',
      'bookNumber': '1',
      'english': 'Published text',
      'arabic': 'نص',
      'aiEnglish': 'AI text',
      'grades': [],
    });
    expect(published.displayEnglish, 'Published text');
    expect(published.usesAiTranslation, isFalse);
    final absent = HadithRecord({
      'id': 'test',
      'number': '1',
      'book': '1',
      'bookNumber': '1',
      'english': null,
      'arabic': null,
      'aiEnglish': 'AI text',
      'grades': [],
    });
    expect(absent.displayEnglish, isNull);
    expect(absent.usesAiTranslation, isFalse);
  });
  testWidgets('Hadith reader offers inline Ask and no reported grading', (
    tester,
  ) async {
    const channel = MethodChannel('org.quranteacher/ask');
    const events = MethodChannel('org.quranteacher/ask/events');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'status' ? true : null,
    );
    messenger.setMockMethodCallHandler(events, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(events, null);
    });
    final catalog = jsonDecode(
      File('${HadithRepository.assetRoot}/catalog.json').readAsStringSync(),
    );
    final collection = HadithCollection(
      (catalog['collections'] as List).cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id'] == 'nawawi',
      ),
    );
    final book = collection.books.first;
    final rows = parseHadithBook(
      File('${HadithRepository.assetRoot}/${book.file}').readAsStringSync(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HadithReaderScreen(
          collection: collection,
          book: book,
          records: rows,
          index: 0,
          settings: LocalSettings(MemorySettingsStore()),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Ask AI about this hadith'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Reported grading'), findsNothing);
    expect(find.textContaining('Source: Hadith API'), findsNothing);
    await tester.tap(find.byTooltip('Source details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Source: Hadith API'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Source: Hadith API'), findsNothing);
    expect(find.byTooltip('Ask about this hadith'), findsNothing);
    await tester.tap(find.text('Ask AI about this hadith'));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('What does this hadith teach about intentions?'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('What does this hadith teach about intentions?'),
      findsOneWidget,
    );
    expect(find.text('Hadith ${rows.first.number}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('AI notice appears before generated English', (tester) async {
    final catalog = jsonDecode(
      File('${HadithRepository.assetRoot}/catalog.json').readAsStringSync(),
    );
    final collection = HadithCollection(
      (catalog['collections'] as List).cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id'] == 'malik',
      ),
    );
    final book = collection.books.firstWhere((b) => b.id == '15');
    final rows = parseHadithBook(
      File('${HadithRepository.assetRoot}/${book.file}').readAsStringSync(),
    );
    final index = rows.indexWhere((r) => r.number == '471');
    await tester.pumpWidget(
      MaterialApp(
        home: HadithReaderScreen(
          collection: collection,
          book: book,
          records: rows,
          index: index,
          settings: LocalSettings(MemorySettingsStore()),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ai-translation-notice')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('AI translation — not scholar-reviewed'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text(rows[index].displayEnglish!),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(rows[index].displayEnglish!), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'iPhone library opens collection, book, reader and next narration',
    (tester) async {
      const screenshots = bool.fromEnvironment('HADITH_SCREENSHOTS');
      tester.view.physicalSize = screenshots
          ? const Size(440, 956)
          : const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = repository();
      await tester.runAsync(() async {
        final c = (await repo.collections()).firstWhere(
          (c) => c.id == 'nawawi',
        );
        await repo.loadBook(c.books.single);
      });
      if (screenshots) {
        await tester.runAsync(() async {
          for (final f in {
            'PreviewUI': '/System/Library/Fonts/SFNS.ttf',
            'Arial': '/System/Library/Fonts/Supplemental/Arial.ttf',
            'QuranIndoPak':
                'assets/fonts/indopak-nastaleeq-waqf-lazim-v4.2.1.ttf',
            'MaterialIcons': '/Users/shahzadsarwar/Library/Caches/quran-teacher-flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          }.entries) {
            await (FontLoader(f.key)..addFont(
                  File(f.value).readAsBytes().then(ByteData.sublistView),
                ))
                .load();
          }
        });
      }
      final boundary = GlobalKey();
      var theme = buildAppTheme(AppColorTheme.emerald, Brightness.light);
      if (screenshots) {
        theme = theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'PreviewUI'),
          appBarTheme: theme.appBarTheme.copyWith(
            titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
              fontFamily: 'PreviewUI',
            ),
          ),
        );
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: HadithScreen(
              repository: repo,
              settings: LocalSettings(MemorySettingsStore()),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await repo.collections();
      });
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        if (!screenshots) return;
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('docs/screenshots/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('hadith-library');
      await tester.enterText(find.byType(TextFormField), 'Nawawi');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hadith-nawawi')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hadith-book-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hadith 1'));
      await tester.pumpAndSettle();
      await capture('hadith-reader');
      expect(find.text('Hadith 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Next hadith'));
      await tester.pumpAndSettle();
      expect(find.text('Hadith 2'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Hadith 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
