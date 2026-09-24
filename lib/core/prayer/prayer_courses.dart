import '../ask/ask_translation.dart';
import '../quran/quran_repository.dart';
import 'prayer_lesson.dart';

class PrayerCourse {
  const PrayerCourse(
    this.prayer,
    this.label,
    this.rakahs, {
    this.fard = false,
    this.pairs = false,
    this.hanafiWitr = false,
  });
  final String prayer, label;
  final int rakahs;
  final bool fard, pairs, hanafiWitr;
  String get name => '$prayer · $label';
}

const prayerCourses = [
  PrayerCourse('Fajr', '2 sunnah before', 2),
  PrayerCourse('Fajr', '2 fard', 2, fard: true),
  PrayerCourse('Dhuhr', '4 sunnah before · Hanafi', 4),
  PrayerCourse('Dhuhr', '4 sunnah before · 2 + 2', 4, pairs: true),
  PrayerCourse('Dhuhr', '4 fard', 4, fard: true),
  PrayerCourse('Dhuhr', '2 sunnah after', 2),
  PrayerCourse('Asr', '4 optional before · 2 + 2', 4, pairs: true),
  PrayerCourse('Asr', '4 fard', 4, fard: true),
  PrayerCourse('Maghrib', '3 fard', 3, fard: true),
  PrayerCourse('Maghrib', '2 sunnah after', 2),
  PrayerCourse('Isha', '4 fard', 4, fard: true),
  PrayerCourse('Isha', '2 sunnah after', 2),
  PrayerCourse('Isha', '3 Witr · Hanafi', 3, hanafiWitr: true),
  PrayerCourse('Isha', 'Witr · 2 + 1', 3, pairs: true),
];

const dailyPrayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

/// Alternatives are choices, never extra prayers to perform back-to-back.
List<PrayerCourse> dailyPrayerSequence(String prayer, {bool pairs = false}) =>
    prayerCourses.where((course) {
      if (course.prayer != prayer) return false;
      if (prayer == 'Dhuhr' && course.rakahs == 4 && !course.fard) {
        return course.pairs == pairs;
      }
      if (prayer == 'Isha' && course.rakahs == 3) {
        return course.pairs == pairs;
      }
      return true;
    }).toList();

/// Fully expanded sequences: no "repeat previous rakah" shortcuts.
List<PrayerLessonStep> prayerCourseLesson(
  PrayerCourse course,
  QuranRepository repository,
  AskTranslation translation,
) {
  final base = twoRakahLesson(repository, translation);
  final opening = base.take(5).toList();
  final cycle = base
      .where((s) => s.rakah == 1 && !opening.contains(s))
      .toList();
  final ending = base.sublist(
    base.indexWhere((s) => s.title == 'Final sitting · Tashahhud'),
  );
  final steps = <PrayerLessonStep>[
    PrayerLessonStep(
      'Before you begin',
      '${course.name}. ${course.rakahs} rakʿahs, shown in full. Have wudu and face the Qibla. This lesson demonstrates praying alone, not the follower’s recitation behind an imam.',
      differences:
          'Fard prayers are obligatory; sunnah prayers are additional, not fard. Witr is wajib in the Hanafi school and an emphasized sunnah in the other three Sunni schools. These are common learning paths, not every valid school variation. Follow your teacher. ${course.pairs ? 'This path ends the first pair with salām, then begins a new prayer for the remaining unit(s).' : ''}',
    ),
    PrayerLessonStep(
      'Intention',
      'Know in your heart: “I intend to offer ${course.name} for Allah.” This is an example, not a required spoken formula.',
    ),
    ...opening.skip(2),
  ];
  for (var r = 1; r <= course.rakahs; r++) {
    if (r > 1) {
      if (course.pairs && r == 3) {
        steps.addAll(opening.skip(2).map((s) => s.forRakah(r)));
      } else {
        steps.add(
          base
              .firstWhere((s) => s.title == 'Stand for the second rakʿah')
              .forRakah(
                r,
                title: 'Stand for rakʿah $r',
                instruction:
                    'Say Allāhu akbar as you rise. Begin rakʿah $r of ${course.rakahs}.',
              ),
        );
      }
    }
    for (final step in cycle) {
      if (course.fard &&
          r > 2 &&
          (step.verse?.surah == 112 ||
              step.title == 'Bismillāh before the short surah')) {
        continue;
      }
      if (course.hanafiWitr && r == 3 && step.title == 'Bow · Rukūʿ') {
        steps.add(
          opening[2].forRakah(
            r,
            title: 'Takbīr before Qunūt',
            instruction: 'Remain standing. Raise your hands and say Allāhu akbar, then fold them again.',
          ),
        );
        steps.add(
          PrayerLessonStep(
            'Qunūt · Hanafi Witr',
            'Remain standing and recite a supplication before bowing. This brief Qur’anic supplication may be used while learning the longer Qunūt.',
            rakah: r,
            arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
            meaning: 'Our Lord, grant us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.',
            source: 'https://quran.com/2/201\nhttps://seekersguidance.org/answers/hanafi-fiqh/forgetting-to-recite-the-qunut-in-witr-prayer/',
            differences: 'This is the Hanafi placement before rukūʿ. Other schools differ on Qunūt wording, timing and when it is recited.',
          ),
        );
      }
      var detail = step.instruction;
      if (step.pose == PrayerPose.bowing ||
          step.pose == PrayerPose.prostrating) {
        detail += ' Say the praise three times: 1, 2, 3. This is the teaching count, not a universal minimum across schools.';
      }
      if (step.verse?.surah == 112) detail += ' Al-Ikhlāṣ is an example; another suitable Qur’an passage may be recited.';
      steps.add(
        step.forRakah(
          r,
          instruction: detail,
          title: step.pose == PrayerPose.bowing
              ? 'Rukūʿ $r of ${course.rakahs}'
              : step.pose == PrayerPose.prostrating
              ? 'Sujūd ${step.title == 'Second prostration' ? 2 : 1} of 2'
              : null,
          differences:
              course.prayer == 'Fajr' &&
                  course.fard &&
                  r == 2 &&
                  step.title == 'Rise from bowing'
              ? 'Shafiʿi practice includes Qunūt here after bowing in Fajr. Maliki practice places it before bowing. Hanafi and Hanbali practice do not routinely include Fajr Qunūt. Ask your teacher for the full wording and method.'
              : null,
        ),
      );
    }
    final endPrayer = r == course.rakahs || (course.pairs && r == 2);
    steps.addAll(
      (endPrayer
              ? ending
              : r == 2
              ? ending.take(2)
              : <PrayerLessonStep>[])
          .map(
            (s) => s.forRakah(
              r,
              title: !endPrayer && s.title == 'Final sitting · Tashahhud'
                  ? 'Middle sitting · Tashahhud'
                  : null,
            ),
          ),
    );
  }
  return steps;
}
