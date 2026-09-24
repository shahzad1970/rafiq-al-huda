import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/ask/ask_translation.dart';
import 'package:quran_teacher_ai/core/prayer/prayer_courses.dart';
import 'package:quran_teacher_ai/core/prayer/prayer_lesson.dart';

import 'widget_test.dart' show testRepository;

void main() {
  test(
    'Daily overviews show prayers in order without duplicate alternatives',
    () {
      expect(dailyPrayerSequence('Fajr').map((c) => c.label), [
        '2 sunnah before',
        '2 fard',
      ]);
      expect(dailyPrayerSequence('Isha').map((c) => c.label), [
        '4 fard',
        '2 sunnah after',
        '3 Witr · Hanafi',
      ]);
      expect(
        dailyPrayerSequence('Isha', pairs: true).last.label,
        'Witr · 2 + 1',
      );
      expect(dailyPrayerSequence('Dhuhr').length, 3);
      expect(dailyPrayerSequence('Dhuhr', pairs: true).length, 3);
      expect(dailyPrayerSequence('Maghrib').map((c) => c.rakahs), [3, 2]);
    },
  );
  final translation = AskTranslation(
    jsonDecode(File('assets/data/ask_translation.json').readAsStringSync()),
  );
  for (final course in prayerCourses) {
    test('${course.name}: every unit is expanded and counted', () {
      final steps = prayerCourseLesson(course, testRepository(), translation);
      for (var r = 1; r <= course.rakahs; r++) {
        final unit = steps.where((s) => s.rakah == r);
        expect(
          unit.where((s) => s.title.startsWith('Al-Fātiḥah')),
          hasLength(7),
        );
        expect(unit.where((s) => s.pose == PrayerPose.bowing), hasLength(1));
        expect(
          unit.where((s) => s.pose == PrayerPose.prostrating),
          hasLength(2),
        );
        expect(
          unit.where((s) => s.verse?.surah == 112),
          hasLength(course.fard && r > 2 ? 0 : 4),
        );
      }
      expect(
        steps.where((s) => s.title == 'Salām · Right'),
        hasLength(course.pairs ? 2 : 1),
      );
      expect(
        steps.where((s) => s.title == 'Middle sitting · Tashahhud'),
        hasLength(course.rakahs > 2 && !course.pairs ? 1 : 0),
      );
      expect(
        steps.where((s) => s.title == 'Qunūt · Hanafi Witr'),
        hasLength(course.hanafiWitr ? 1 : 0),
      );
      for (final s in steps.where((s) => s.arabic.isNotEmpty)) {
        expect(
          s.audio != null || s.title == 'Qunūt · Hanafi Witr',
          isTrue,
          reason: s.title,
        );
      }
      expect(steps.last.rakah, course.rakahs);
    });
  }
  test('Hanafi Witr qunut is before the third bow; no early salam', () {
    final steps = prayerCourseLesson(
      prayerCourses.firstWhere((c) => c.hanafiWitr),
      testRepository(),
      translation,
    );
    final qunut = steps.indexWhere((s) => s.title == 'Qunūt · Hanafi Witr');
    expect(steps[qunut + 1].pose, PrayerPose.bowing);
    expect(
      steps.where((s) => s.rakah == 2 && s.title.startsWith('Salām')),
      isEmpty,
    );
  });
}
