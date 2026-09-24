import 'prayer_lesson.dart';

/// A beginner washing sequence, not a complete manual of ritual purity.
const wuduLesson = <PrayerLessonStep>[
  PrayerLessonStep(
    'Prepare for wudu',
    'Intend in your heart to purify yourself for prayer. Use clean water and remove anything that prevents it reaching the skin. Roll sleeves above the elbows. Use a small amount of water and continue without unnecessary pauses.',
    source: 'https://quran.com/5/6',
    differences: 'Schools differ on which details are obligatory or recommended. This lesson shows a complete beginner sequence, not just the minimum requirements. Learn special cases, such as dressings or wiping over footwear, with your teacher.',
  ),
  PrayerLessonStep(
    'Begin with Allah’s name',
    'Say Bismillāh as you begin.',
    arabic: 'بِسْمِ اللَّهِ',
    meaning: 'In the name of Allah.',
    source: 'https://sunnah.com/abudawud:101',
  ),
  PrayerLessonStep(
    'Wash your hands',
    'Wash both hands to the wrists three times, including between the fingers. The three washes shown in this lesson are the recommended complete practice; they are not all required for validity.',
    imageAsset: 'assets/illustrations/prayer/wudu-hands.png',
    source: 'https://sunnah.com/bukhari:159',
  ),
  PrayerLessonStep(
    'Rinse your mouth',
    'Take a little water with your right hand. Swish it around your mouth and spit it out. Repeat three times.',
    imageAsset: 'assets/illustrations/prayer/wudu-mouth.png',
    source: 'https://sunnah.com/bukhari:185',
  ),
  PrayerLessonStep(
    'Rinse your nose',
    'Gently draw a little water into the nostrils with your right hand, then blow it out, using your left hand to help. Repeat three times. Be gentle, especially when fasting.',
    imageAsset: 'assets/illustrations/prayer/wudu-nose.png',
    source: 'https://sunnah.com/bukhari:185',
  ),
  PrayerLessonStep(
    'Wash your face',
    'Wash the whole face three times: from the usual hairline to the chin, and across from ear to ear. Make sure water reaches all of the face.',
    imageAsset: 'assets/illustrations/prayer/wudu-face.png',
    source: 'https://quran.com/5/6\nhttps://sunnah.com/bukhari:159',
  ),
  PrayerLessonStep(
    'Wash your arms',
    'Wash the right hand and arm, including the elbow, three times. Then do the left three times. Rub gently so no area stays dry.',
    imageAsset: 'assets/illustrations/prayer/wudu-arms.png',
    source: 'https://quran.com/5/6\nhttps://sunnah.com/bukhari:159',
  ),
  PrayerLessonStep(
    'Wipe your head',
    'With wet hands, wipe from the front of your head to the back, then return to the front. This is wiping, not pouring water over the head.',
    imageAsset: 'assets/illustrations/prayer/wudu-head.png',
    source: 'https://sunnah.com/bukhari:185',
    differences: 'The minimum portion of the head to wipe differs between schools. The whole-head method shown here follows the narration of ʿAbdullāh ibn Zayd. Your teacher can explain your school’s requirements.',
  ),
  PrayerLessonStep(
    'Wipe your ears',
    'Gently wipe the inner folds of the ears with wet index fingers and behind the ears with your thumbs. Do not push fingers deeply into the ears.',
    imageAsset: 'assets/illustrations/prayer/wudu-ears.png',
    source: 'https://sunnah.com/abudawud:135',
  ),
  PrayerLessonStep(
    'Wash your feet',
    'Wash the right foot, including the ankle, three times, then the left. Reach between the toes and around the heels so no part stays dry.',
    imageAsset: 'assets/illustrations/prayer/wudu-feet.png',
    source: 'https://quran.com/5/6\nhttps://sunnah.com/bukhari:159',
  ),
  PrayerLessonStep(
    'After wudu',
    'When you have finished, say this testimony. Your wudu is complete.',
    arabic: 'أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ',
    meaning: 'I bear witness that there is no god but Allah alone, without a partner, and that Muhammad is His servant and messenger.',
    source: 'https://sunnah.com/muslim:234b',
  ),
];
