import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/ask/ask_engine.dart';
import 'package:quran_teacher_ai/core/ask/ask_library.dart';
import 'package:quran_teacher_ai/core/hadith/hadith_repository.dart';
import 'package:quran_teacher_ai/features/ask/ask_screen.dart';

const source = AskSource(
  id: 'fixture:112:1',
  title: 'Qur’an 112:1',
  arabic: 'قُلْ هُوَ ٱللَّهُ أَحَدٌ',
  english: 'Say He is Allah the One',
  provenance: 'Word-by-word glosses, not tafsir.',
);

// A bridge test double, never a production fallback or a model-quality test.
class TestAskEngine implements AskEngine {
  bool isInstalled = true;
  int calls = 0, cancellations = 0;
  String response =
      '{"claims":[{"text":"The verse describes Allah as One.","sources":[1]}]}';
  Completer<String>? pending;
  @override
  Future<bool> installed() async => isInstalled;
  @override
  Future<void> download() async {
    isInstalled = true;
  }

  @override
  Future<String> answer(String evidence) async {
    calls++;
    return pending == null ? response : pending!.future;
  }

  @override
  Future<void> cancel() async {
    cancellations++;
  }

  @override
  Future<void> deleteModel() async {
    isInstalled = false;
  }

  @override
  Stream<Map<String, dynamic>> get events => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Selected Quran sources receive the unmodified published translation and notes', () async {
    final source = await AskLibrary(null).enrich(
      const AskSource(
        id: 'quran:1:2',
        title: 'Qur’an 1:2',
        arabic: '',
        english: '',
        provenance: '',
      ),
    );
    final data = jsonDecode(
      File('assets/data/ask_translation.json').readAsStringSync(),
    ) as Map;
    expect(source.english, data['ayahs']['1:2']['translation']);
    expect(source.notes, data['ayahs']['1:2']['footnotes']);
    expect(source.provenance, contains('v1.0.19'));
    expect(source.englishLabel, 'Translation of the meanings');
  });
  test(
    'English plurals, Arabic diacritics and stopwords normalize consistently',
    () {
      expect(askTerms('What do intentions mean?'), ['intention']);
      expect(askTerms('الأَعْمَالُ بِالنِّيَّاتِ'), ['الاعمال', 'بالنيات']);
    },
  );
  test(
    'Canonical index includes all ayat and excludes AI-only translations',
    () {
      final index = jsonDecode(
        File('assets/data/ask_index.json').readAsStringSync(),
      ) as Map;
      final docs = (index['documents'] as List).cast<Map>();
      expect(
        docs.where((d) => (d['id'] as String).startsWith('quran:')).length,
        6236,
      );
      expect(docs.length, 42333);
      expect(docs.any((d) => d['id'] == 'malik:471|471|15|2'), isFalse);
      expect(docs.map((d) => d['id']).toSet().length, docs.length);
    },
  );
  test('Exact Quran reference, empty query and lexical source retrieval', () {
    final index = File('assets/data/ask_index.json').readAsStringSync();
    List<Map<String, dynamic>> search(String q) =>
        rankAskSources({'index': index, 'query': q});
    expect(search('What does 2:255 mean?').single['id'], 'quran:2:255');
    expect(search('Explain surah 2 verse 255').single['id'], 'quran:2:255');
    expect(search('Explain Bukhari 1').single['id'], startsWith('bukhari:1|'));
    expect(search('999:999'), isEmpty);
    expect(search('what is it'), isEmpty);
    expect(search('actions intentions'), isNotEmpty);
    expect(search('Al-Baqarah verse 5').single['id'], 'quran:2:5');
    expect(search('Al Fatiha 1').single['id'], 'quran:1:1');
    expect(search('٢:٢٥٥').single['id'], 'quran:2:255');
    expect(search('Bukhari hadith #1').single['id'], startsWith('bukhari:1|'));
    expect(search('What does Islam teach about sabr?'), isNotEmpty);
    for (final scope in ['quran', 'hadith']) {
      final results = rankAskSources({
        'index': index,
        'query': 'salah',
        'scope': scope,
      });
      expect(results, isNotEmpty);
      expect(
        results.every((d) => (d['surah'] != null) == (scope == 'quran')),
        isTrue,
      );
    }
    expect(
      rankAskSources({'index': index, 'query': '2:255', 'scope': 'hadith'}),
      isEmpty,
    );
  });
  test('Rejects missing, invented, fractional and out-of-range references', () {
    for (final raw in [
      '{"claims":[{"text":"Uncited","sources":[]}]}',
      '{"claims":[{"text":"Unknown","sources":[2]}]}',
      '{"claims":[{"text":"Invalid","sources":[0]}]}',
      '{"claims":[{"text":"Invalid","sources":[1.1]}]}',
      '{"claims":[{"text":"Invalid","sources":["1"]}]}',
      '{"claims":[{"text":"Uncited"}]}',
      'Not JSON',
    ]) {
      expect(() => AskAnswer.parse(raw, 1), throwsFormatException);
    }
    expect(AskAnswer.parse('{"claims":[]}', 1).claims, isEmpty);
    expect(
      AskAnswer.parse(
        '{"claims":[{"text":"Supported","sources":[1,1]}]}',
        1,
      ).claims.single.citations,
      [1],
    );
  });
  test('Incomplete JSON is distinguished from invalid source references', () {
    expect(
      () => AskAnswer.parse('{"claims":[{"text":"Test","sources":[1]}]', 1),
      throwsA(
        isA<FormatException>().having(
          (error) => error is AskCitationException,
          'citation error',
          false,
        ),
      ),
    );
    expect(
      () => AskAnswer.parse('{"claims":[{"text":"Test","sources":[2]}]}', 1),
      throwsA(isA<AskCitationException>()),
    );
  });
  test('AI English cannot be promoted to source evidence', () {
    final record = HadithRecord({
      'id': 'test',
      'number': '1',
      'book': '1',
      'bookNumber': '1',
      'arabic': 'عربي',
      'aiEnglish': 'Generated text',
      'grades': [],
    });
    expect(() => AskSource.hadith(record, 'Test'), throwsFormatException);
  });
  test('Prompts preserve source IDs and mark bounded excerpts', () {
    final prompt = jsonDecode(
      askPrompt('Explain this', [
        AskSource(
          id: 'x',
          title: 'A',
          arabic: 'a' * 1000,
          english: 'e' * 5000,
          provenance: 'Test',
        ),
      ]),
    ) as Map;
    expect(prompt['passages'][0]['source'], 1);
    expect(prompt['passages'][0]['english'], endsWith('[excerpt ends]'));
    expect((prompt['passages'][0]['english'] as String).length, lessThan(1900));
  });
  test('Full published edition preserves all verses and publisher notes', () {
    final data = jsonDecode(
      File('assets/data/ask_translation.json').readAsStringSync(),
    ) as Map;
    expect(data['edition']['version'], '1.0.19');
    final rows = data['ayahs'] as Map;
    expect(rows.length, 6236);
    expect(
      rows.values.every((r) => (r['translation'] as String).isNotEmpty),
      isTrue,
    );
    expect(
      rows.values.any((r) => (r['footnotes'] as String? ?? '').isNotEmpty),
      isTrue,
    );
    expect((data['chapterSha256'] as Map).length, 114);
  });
  test('Long passages retain a relevant unchanged source window', () {
    final text =
        '${'opening context ' * 100} patience sabr endurance ${'closing context ' * 50}';
    final excerpt = askRelevantExcerpt(text, 'patience sabr', 200);
    expect(excerpt, contains('patience sabr'));
    expect(excerpt, startsWith('[excerpt begins]'));
    expect(
      text,
      contains(
        excerpt
            .replaceAll('[excerpt begins] ', '')
            .replaceAll(' [excerpt ends]', ''),
      ),
    );
  });
  testWidgets('Quran inline suggestions use the published verse translation', (
    tester,
  ) async {
    final engine = TestAskEngine();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AskScreen(
              inline: true,
              engine: engine,
              selected: const AskSource(
                id: 'quran:2:27',
                title: 'Qur’an 2:27',
                arabic: '',
                english: 'Not used to generate questions',
                provenance: '',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final question = find.text(
      'What does this verse say about keeping a covenant?',
    );
    // Large bundled translation loading uses a real background isolate.
    for (var i = 0; i < 40 && question.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(question, findsOneWidget);
    await tester.ensureVisible(question);
    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(engine.calls, 1);
    expect(find.byType(AppBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Ask screen renders local answers and tappable exact sources', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = TestAskEngine();
    var prepared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AskScreen(
              selected: source,
              engine: engine,
              inline: true,
              beforeAsk: () async {
                prepared = true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
      'Ask a question…',
    );
    expect(tester.widget<TextField>(find.byType(TextField)).minLines, 1);
    await tester.tap(find.text('What does this passage mean?'));
    await tester.pumpAndSettle();
    expect(engine.calls, 1);
    expect(prepared, isTrue);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('The verse describes Allah as One.'), findsOneWidget);
    await tester.ensureVisible(find.text('Source 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Source 1'));
    await tester.pumpAndSettle();
    expect(find.text(source.english), findsWidgets);
    expect(find.text(source.provenance), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Invalid citations are hidden, not displayed as an answer', (
    tester,
  ) async {
    final engine = TestAskEngine()
      ..response = '{"claims":[{"text":"Do not show this","sources":[99]}]}';
    await tester.pumpWidget(
      MaterialApp(
        home: AskScreen(selected: source, engine: engine),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Explain');
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    expect(find.text('Do not show this'), findsNothing);
    expect(
      find.textContaining('missing or invalid source references'),
      findsOneWidget,
    );
  });
  testWidgets('Cancellation prevents a late answer from resurfacing', (
    tester,
  ) async {
    final engine = TestAskEngine()..pending = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        home: AskScreen(selected: source, engine: engine),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Explain');
    await tester.tap(find.text('Ask'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    engine.pending!.complete(engine.response);
    await tester.pumpAndSettle();
    expect(find.text('The verse describes Allah as One.'), findsNothing);
    expect(engine.cancellations, greaterThan(0));
  });
  testWidgets('Download is opt-in and setup fits iPhone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = TestAskEngine()..isInstalled = false;
    final key = GlobalKey();
    const screenshots = bool.fromEnvironment('ASK_SCREENSHOTS');
    if (screenshots) {
      await tester.runAsync(() async {
        for (final font in {
          'PreviewUI': '/System/Library/Fonts/SFNS.ttf',
          'MaterialIcons': '/Users/shahzadsarwar/Library/Caches/quran-teacher-flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        }.entries) {
          await (FontLoader(font.key)..addFont(
                File(font.value).readAsBytes().then(ByteData.sublistView),
              ))
              .load();
        }
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          fontFamily: screenshots ? 'PreviewUI' : null,
        ),
        home: RepaintBoundary(
          key: key,
          child: AskScreen(selected: source, engine: engine),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(engine.isInstalled, isFalse);
    expect(engine.calls, 0);
    expect(find.text('Download offline AI'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (screenshots) {
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/screenshots/ask-offline-setup.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('Download offline AI'));
    await tester.pumpAndSettle();
    expect(find.text('Download offline AI?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(engine.isInstalled, isFalse);
  });
}
