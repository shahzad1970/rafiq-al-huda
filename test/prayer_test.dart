import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/prayer/mawaqit_calculator.dart';
import 'package:quran_teacher_ai/core/prayer/prayer_schedule.dart';
import 'package:quran_teacher_ai/core/settings/local_settings.dart';
import 'package:quran_teacher_ai/features/prayer/prayer_screen.dart';

import 'widget_test.dart' show MemorySettingsStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('After-midnight Isha remains a next prayer from the previous date', () {
    final schedule = PrayerSchedule(
      const PrayerConfiguration(
        location: PrayerLocation(
          'Stockholm',
          59.3293,
          18.0686,
          'Europe/Stockholm',
        ),
        method: 'MAKKAH',
        adjustments: {'Isha': 60},
      ),
    );
    final isha = schedule.forDate(DateTime(2026, 6, 21)).last;
    expect(isha.time!.day, 22);
    expect(
      schedule.next(isha.time!.subtract(const Duration(minutes: 10)))!.time,
      isha.time,
    );
  });
  testWidgets('Location denial offers manual setup and valid settings save', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(prayerLocationChannel, (call) async {
      if (call.method == 'cancel') return null;
      throw PlatformException(
        code: 'permission',
        message: 'Location access is off. Choose a city.',
      );
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(prayerLocationChannel, null),
    );
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final settings = LocalSettings(MemorySettingsStore());
    await tester.pumpWidget(
      MaterialApp(home: PrayerScreen(settings: settings)),
    );
    await tester.tap(find.text('Set up prayer times'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use current location'));
    await tester.pumpAndSettle();
    expect(find.text('Location access is off. Choose a city.'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<PrayerLocation>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New York').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save prayer settings'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save prayer settings'));
    await tester.pumpAndSettle();
    expect(settings.prayerConfiguration!.location.zone, 'America/New_York');
    expect(find.text('Prayer Times'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test(
    'Parity with pinned Mawaqit PHP for 1056 date/location/method/Asr cases',
    () {
      final fixture = jsonDecode(
        File('test/fixtures/prayer/mawaqit-reference.json').readAsStringSync(),
      ) as Map;
      final cases = fixture['cases'] as List;
      expect(cases.length, 1056);
      for (final c in cases) {
        final actual = MawaqitCalculator().calculate(
          date: DateTime.parse(c['date']),
          latitude: (c['latitude'] as num).toDouble(),
          longitude: (c['longitude'] as num).toDouble(),
          utcOffsetHours: (c['offset'] as num).toDouble(),
          method: PrayerMethod.byCode(c['method']),
          hanafi: c['hanafi'],
        );
        expect(
          {for (final t in actual) t.name: t.minutes},
          c['minutes'],
          reason:
              '${c['city']} ${c['date']} ${c['method']} hanafi=${c['hanafi']}',
        );
      }
    },
  );
  test('Polar missing events stay unavailable; no fabricated sunrise', () {
    final times = MawaqitCalculator().calculate(
      date: DateTime(2026, 6, 21),
      latitude: 69.6492,
      longitude: 18.9553,
      utcOffsetHours: 2,
      method: PrayerMethod.all.first,
    );
    expect(times.firstWhere((t) => t.name == 'Sunrise').minutes, isNull);
    expect(times.firstWhere((t) => t.name == 'Maghrib').minutes, isNull);
  });
  test('High-latitude estimates are labeled; none does not fabricate Fajr', () {
    List<CalculatedPrayerTime> run(HighLatitudeRule rule) =>
        MawaqitCalculator().calculate(
          date: DateTime(2026, 6, 21),
          latitude: 51.5074,
          longitude: -0.1278,
          utcOffsetHours: 1,
          method: PrayerMethod.all.first,
          highLatitude: rule,
        );
    expect(run(HighLatitudeRule.angle).first.estimated, isTrue);
    expect(run(HighLatitudeRule.none).first.minutes, isNull);
    expect(run(HighLatitudeRule.middle).first.minutes, isNotNull);
    expect(run(HighLatitudeRule.seventh).first.minutes, isNotNull);
  });
  test('DST, Hanafi, tuning, next-day Fajr and sunrise exclusion', () {
    const location = PrayerLocation(
      'New York',
      40.7128,
      -74.006,
      'America/New_York',
    );
    final schedule = PrayerSchedule(
      const PrayerConfiguration(location: location, method: 'ISNA'),
    );
    final before = schedule.forDate(DateTime(2026, 3, 7));
    final after = schedule.forDate(DateTime(2026, 3, 8));
    expect(before.first.time!.timeZoneOffset, const Duration(hours: -5));
    expect(after.first.time!.timeZoneOffset, const Duration(hours: -4));
    final next = schedule.next(DateTime.utc(2026, 9, 21, 3, 59));
    expect(next!.name, 'Fajr');
    expect(next.time!.day, 21);
    final sunrise = after.firstWhere((e) => e.name == 'Sunrise').time!;
    expect(
      schedule.next(sunrise.subtract(const Duration(minutes: 1)))!.name,
      'Dhuhr',
    );
    final tuned = PrayerSchedule(
      const PrayerConfiguration(
        location: location,
        method: 'ISNA',
        hanafi: true,
        adjustments: {'Fajr': 5},
      ),
    ).forDate(DateTime(2026, 3, 8));
    expect(
      tuned.first.time!.difference(after.first.time!),
      const Duration(minutes: 5),
    );
    expect(tuned[3].time!.isAfter(after[3].time!), isTrue);
  });
  test('Settings persist and Delete All removes saved coordinates', () async {
    final store = MemorySettingsStore();
    final settings = LocalSettings(store);
    await settings.setPrayerConfiguration(
      PrayerConfiguration(
        location: PrayerLocation.cities.first,
        method: 'ISNA',
      ),
    );
    final restored = LocalSettings(store);
    await restored.load();
    expect(restored.prayerConfiguration!.location.name, 'New York');
    await restored.deleteAll();
    expect(restored.prayerConfiguration, isNull);
    expect(store.values.containsKey('prayer_configuration'), isFalse);
  });
  test('Invalid location, method and offset are rejected', () {
    expect(
      () => PrayerLocation.fromMap({
        'name': 'X',
        'latitude': 91,
        'longitude': 0,
        'zone': 'UTC',
      }),
      throwsFormatException,
    );
    expect(
      () => PrayerConfiguration.decode('{"location":{},"method":"fake"}'),
      throwsStateError,
    );
    expect(
      () => MawaqitCalculator().calculate(
        date: DateTime(2026),
        latitude: double.nan,
        longitude: 0,
        utcOffsetHours: 0,
        method: PrayerMethod.all.first,
      ),
      throwsArgumentError,
    );
  });
  testWidgets(
    'iPhone empty and configured screens fit and show real calculated times',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final settings = LocalSettings(MemorySettingsStore());
      await tester.pumpWidget(
        MaterialApp(home: PrayerScreen(settings: settings)),
      );
      expect(find.text('Set up prayer times'), findsOneWidget);
      await settings.setPrayerConfiguration(
        PrayerConfiguration(
          location: PrayerLocation.cities.first,
          method: 'ISNA',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PrayerScreen(
            key: const ValueKey('configured'),
            settings: settings,
            now: () => DateTime.utc(2026, 9, 20, 15),
          ),
        ),
      );
      expect(find.text('New York'), findsOneWidget);
      expect(find.text('UP NEXT'), findsOneWidget);
      expect(find.text('Dhuhr'), findsNWidgets(2));
      expect(
        find.textContaining('Calculated prayer start times'),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Calculation information'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not mosque iqāmah times'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
