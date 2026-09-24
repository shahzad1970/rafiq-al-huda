import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/prayer/qibla.dart';
import 'package:quran_teacher_ai/core/prayer/prayer_schedule.dart';
import 'package:quran_teacher_ai/features/prayer/qibla_screen.dart';

void main() {
  testWidgets(
    'Opening without prayer setup starts; background and back stop sensors',
    (tester) async {
      var starts = 0;
      var stops = 0;
      final readings = StreamController<dynamic>.broadcast(
        onListen: () => starts++,
        onCancel: () => stops++,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => QiblaScreen(readings: readings.stream),
                  ),
                ),
                child: const Text('Open compass'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open compass'));
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(find.text('Stop compass'), findsNothing);
      expect(find.text('Start compass'), findsNothing);
      expect(find.text('Finding true north…'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(stops, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(starts, 2);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(stops, 2);
      expect(readings.hasListener, isFalse);
      await readings.close();
    },
  );
  test('Great-circle bearings across hemispheres and degenerate points', () {
    expect(QiblaDirection.from(40.7128, -74.006)!.bearing, closeTo(58.48, 0.1));
    expect(
      QiblaDirection.from(51.5074, -0.1278)!.bearing,
      closeTo(118.99, 0.1),
    );
    expect(
      QiblaDirection.from(-33.8688, 151.2093)!.bearing,
      closeTo(277.50, 0.1),
    );
    expect(QiblaDirection.from(0, 39.826206)!.bearing, closeTo(0, 0.001));
    expect(QiblaDirection.from(40, 39.826206)!.bearing, closeTo(180, 0.001));
    expect(QiblaDirection.from(21.422487, 39.826206), isNull);
    expect(QiblaDirection.from(-21.422487, -140.173794), isNull);
    expect(() => QiblaDirection.from(double.nan, 0), throwsArgumentError);
  });
  test('Circular filter crosses north without spinning backwards', () {
    final filter = HeadingFilter();
    expect(filter.update(359), 359);
    expect(filter.update(1), closeTo(359.6, 0.001));
    expect(shortestTurn(359, 1), 2);
    expect(shortestTurn(1, 359), -2);
    filter.reset();
    expect(filter.update(10), 10);
  });
  test('Invalid, inaccurate and stale sensor samples cannot guide', () {
    final now = DateTime.now();
    CompassSample sample({
      double heading = 10,
      double accuracy = 5,
      int age = 0,
      int locationAge = 0,
    }) => CompassSample(
      heading: heading,
      accuracy: accuracy,
      latitude: 40,
      longitude: -74,
      locationAccuracy: 100,
      headingTime: now.subtract(Duration(seconds: age)),
      locationTime: now.subtract(Duration(seconds: locationAge)),
    );
    expect(sample().usable(now), isTrue);
    expect(sample(heading: -1).usable(now), isFalse);
    expect(sample(heading: double.nan).usable(now), isFalse);
    expect(sample(accuracy: -1).usable(now), isFalse);
    expect(sample(accuracy: 30).usable(now), isFalse);
    expect(sample(age: 11).usable(now), isFalse);
    expect(sample(locationAge: 121).usable(now), isFalse);
  });
  testWidgets(
    'Compass starts on opening; real-stream shape enables guidance, poor readings hide it, leaving cancels',
    (tester) async {
      const screenshot = bool.fromEnvironment('QIBLA_SCREENSHOT');
      if (screenshot) {
        await tester.runAsync(() async {
          for (final f in {
            'PreviewUI': '/System/Library/Fonts/SFNS.ttf',
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
      await tester.binding.setSurfaceSize(
        screenshot ? const Size(440, 956) : const Size(390, 844),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var cancelled = false;
      final stream = StreamController<dynamic>(
        onCancel: () => cancelled = true,
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: screenshot ? 'PreviewUI' : null,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff146c58),
              ),
            ),
            home: QiblaScreen(
              location: PrayerLocation.cities.first,
              readings: stream.stream,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(stream.hasListener, isTrue);
      final now = DateTime.now().millisecondsSinceEpoch;
      Map<String, dynamic> event(double accuracy) => {
        'state': 'reading',
        'heading': 58.48,
        'accuracy': accuracy,
        'latitude': 40.7128,
        'longitude': -74.006,
        'locationAccuracy': 50,
        'headingTime': now,
        'locationTime': now,
        'orientation': 'portrait',
      };
      stream.add(event(5));
      await tester.pump();
      await tester.pump();
      expect(find.text('Facing Qibla'), findsOneWidget);
      if (screenshot) {
        // Sensor fixture for visual QA only; not a real phone compass capture.
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('docs/screenshots/qibla-ui-fixture.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      stream.add(event(50));
      await tester.pump();
      await tester.pump();
      expect(find.text('Facing Qibla'), findsNothing);
      expect(find.textContaining('Move away from metal'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(cancelled, isTrue);
      unawaited(stream.close());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
