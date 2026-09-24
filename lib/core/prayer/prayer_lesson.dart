import '../quran/quran_repository.dart';
import '../ask/ask_translation.dart';

enum PrayerPose { standing, bowing, sitting, prostrating }

class PrayerLessonStep {
  const PrayerLessonStep(
    this.title,
    this.instruction, {
    this.rakah = 0,
    this.pose = PrayerPose.standing,
    this.arabic = '',
    this.meaning = '',
    this.source = '',
    this.differences = '',
    this.verse,
    this.imageAsset,
    this.recordedAudio,
  });
  final String title, instruction, arabic, meaning, source, differences;
  final int rakah;
  final PrayerPose pose;
  final QuranAyah? verse;
  final String? imageAsset;
  final QuranReferenceAudio? recordedAudio;
  PrayerLessonStep forRakah(
    int number, {
    String? title,
    String? instruction,
    String? differences,
  }) => PrayerLessonStep(
    title ?? this.title,
    instruction ?? this.instruction,
    rakah: number,
    pose: pose,
    arabic: arabic,
    meaning: meaning,
    source: source,
    differences: differences ?? this.differences,
    verse: verse,
    imageAsset: imageAsset,
    recordedAudio: audio,
  );
  QuranReferenceAudio? get audio {
    if (recordedAudio != null) return recordedAudio;
    if (verse != null) return verse!.referenceAudio;
    final name = switch (title) {
      'Opening takbir' || 'Stand for the second rakʿah' => 'takbir',
      'Opening supplication' => 'opening',
      'Seek refuge' => 'refuge',
      'Āmīn' => 'amin',
      'Bow · Rukūʿ' => 'bowing',
      'Rise from bowing' => 'rising',
      'First prostration · Sujūd' || 'Second prostration' => 'prostration',
      'Sit between prostrations' => 'forgive',
      'Final sitting · Tashahhud' => 'testimony',
      'Testimony · Shahādah' => 'shahadah',
      'Send blessings' => 'blessings',
      'Duʿā before finishing' => 'dua',
      'Salām · Right' || 'Salām · Left' => 'salam',
      'Begin with Allah’s name' => 'bismillah',
      'After wudu' => 'wudu-testimony',
      _ => null,
    };
    if (name == null || arabic.isEmpty) return null;
    return QuranReferenceAudio(
      asset: 'assets/audio/prayer/$name.mp3',
      remoteUrl: '',
      cacheKey: 'prayer-$name',
      durationMilliseconds: 0,
      wordSegments: const [],
    );
  }

  String get illustration {
    if (title == 'Opening takbir') return 'takbir';
    if (pose == PrayerPose.standing &&
        (verse != null ||
            title == 'Opening supplication' ||
            title == 'Seek refuge' ||
            title == 'Āmīn')) {
      return 'reciting';
    }
    return pose.name;
  }

  String get illustrationAsset =>
      imageAsset ?? 'assets/illustrations/prayer/$illustration.png';
}

const fingerDifferences =
    'Hanafi: raise the index finger at “lā ilāha”, then lower it at “illā Allāh”.\n\nShafiʿi: raise it at “illā Allāh” and keep it still until the sitting ends.\n\nMaliki: move the index finger gently during the testimony.\n\nHanbali: point when mentioning Allah, without continuous movement.\n\nThese are brief summaries; learn the details with a teacher of your school.';
const fingerSource =
    'https://seekersguidance.org/answers/shafii-fiqh/how-to-understand-the-concept-of-raising-the-finger-during-tashahhud/';

/// First lesson: a two-rakah voluntary prayer, alone. Not a complete madhhab manual.
/// Quran text and translation are taken unchanged from the bundled repositories.
List<PrayerLessonStep> twoRakahLesson(
  QuranRepository quran,
  AskTranslation translation,
) {
  final steps = <PrayerLessonStep>[
    const PrayerLessonStep(
      'Before you begin',
      'Have wudu, wear suitable prayer clothing, and choose a clean place facing the Qibla. This lesson is for learning a two-rakʿah voluntary prayer while praying alone. Practise before praying, rather than operating the phone during prayer.',
    ),
    const PrayerLessonStep(
      'Intention',
      'Know in your heart which prayer you are offering for Allah. For this lesson: “I intend to offer two rakʿahs of voluntary prayer for Allah.” This is an example of the intention, not a required spoken formula.',
    ),
    const PrayerLessonStep(
      'Opening takbir',
      'Stand if able. Raise your hands for the opening, then say:',
      rakah: 1,
      arabic: 'اللَّهُ أَكْبَرُ',
      meaning: 'Allah is greater.',
      source: 'https://sunnah.com/bukhari:757',
      differences: 'Hand height and where the hands rest while standing differ between schools. Follow the method taught by your teacher; the diagram shows only the broad posture.',
    ),
    const PrayerLessonStep(
      'Opening supplication',
      'One transmitted opening supplication:',
      rakah: 1,
      arabic: 'سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ وَتَبَارَكَ اسْمُكَ وَتَعَالَى جَدُّكَ وَلَا إِلَهَ غَيْرُكَ',
      meaning: 'O Allah, You are free from imperfection and all praise belongs to You. Blessed is Your name, exalted is Your majesty, and none is worthy of worship except You.',
      source: 'https://sunnah.com/abudawud:775',
      differences: 'Opening supplications and their use vary by school. This is one narrated wording, not the only opening form.',
    ),
    const PrayerLessonStep(
      'Seek refuge',
      'Before Qur’an recitation:',
      rakah: 1,
      arabic: 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ',
      meaning: 'I seek Allah’s protection from the rejected Satan.',
      source: 'https://quran.com/16/98',
    ),
  ];
  void verse(int surah, int ayah, int rakah, String title) {
    final v = quran.getAyah(surah, ayah);
    steps.add(
      PrayerLessonStep(
        title,
        'Recite while standing.',
        rakah: rakah,
        verse: v,
        arabic: v.uthmani,
        meaning: translation.ayah('$surah:$ayah')['translation'] as String,
        source: 'https://quran.com/$surah/$ayah',
      ),
    );
  }

  for (var r = 1; r <= 2; r++) {
    if (r == 2) {
      steps.add(
        const PrayerLessonStep(
          'Stand for the second rakʿah',
          'Say Allāhu akbar as you rise. Continue with the second rakʿah.',
          rakah: 2,
          arabic: 'اللَّهُ أَكْبَرُ',
          meaning: 'Allah is greater.',
        ),
      );
    }
    for (var a = 1; a <= 7; a++) {
      verse(1, a, r, 'Al-Fātiḥah · $a of 7');
    }
    steps.add(
      PrayerLessonStep(
        'Āmīn',
        'After Al-Fātiḥah:',
        rakah: r,
        arabic: 'آمِين',
        meaning: 'O Allah, answer our prayer.',
        source: 'https://sunnah.com/bukhari:780',
        differences: 'The schools differ on audible or quiet Āmīn and on recitation behind an imam. This lesson is for praying alone.',
      ),
    );
    verse(1, 1, r, 'Bismillāh before the short surah');
    for (var a = 1; a <= 4; a++) {
      verse(112, a, r, 'Al-Ikhlāṣ · $a of 4');
    }
    steps.addAll([
      PrayerLessonStep(
        'Bow · Rukūʿ',
        'Say Allāhu akbar as you bow. Settle into the bow with your hands on your knees. Recite the praise calmly.',
        rakah: r,
        pose: PrayerPose.bowing,
        arabic: 'سُبْحَانَ رَبِّيَ الْعَظِيمِ',
        meaning: 'My Lord, the Magnificent, is free from imperfection.',
        source: 'https://sunnah.com/muslim:772',
        differences: 'Raising the hands before and after bowing is practised in the Shafiʿi school; the Hanafi method omits it here. Do not treat this difference as a prayer mistake.',
      ),
      PrayerLessonStep(
        'Rise from bowing',
        'Return to a fully upright, settled position.',
        rakah: r,
        arabic: 'سَمِعَ اللَّهُ لِمَنْ حَمِدَهُ\nرَبَّنَا لَكَ الْحَمْدُ',
        meaning: 'Allah hears the one who praises Him. Our Lord, praise belongs to You.',
        source: 'https://sunnah.com/muslim:772',
      ),
      PrayerLessonStep(
        'First prostration · Sujūd',
        'Say Allāhu akbar and prostrate. Place forehead and nose, hands, knees and toes on the ground. Pause calmly.',
        rakah: r,
        pose: PrayerPose.prostrating,
        arabic: 'سُبْحَانَ رَبِّيَ الْأَعْلَى',
        meaning: 'My Lord, the Most High, is free from imperfection.',
        source: 'https://sunnah.com/muslim:772',
      ),
      PrayerLessonStep(
        'Sit between prostrations',
        'Say Allāhu akbar and sit calmly. Rest your hands on your thighs. A supplication for this sitting:',
        rakah: r,
        pose: PrayerPose.sitting,
        arabic: 'رَبِّ اغْفِرْ لِي',
        meaning: 'My Lord, forgive me.',
        source: 'https://sunnah.com/abudawud:874',
      ),
      PrayerLessonStep(
        'Second prostration',
        'Say Allāhu akbar and prostrate again. Settle before moving on.',
        rakah: r,
        pose: PrayerPose.prostrating,
        arabic: 'سُبْحَانَ رَبِّيَ الْأَعْلَى',
        meaning: 'My Lord, the Most High, is free from imperfection.',
        source: 'https://sunnah.com/muslim:772',
      ),
    ]);
  }
  steps.addAll([
    const PrayerLessonStep(
      'Final sitting · Tashahhud',
      'Say Allāhu akbar and sit. Keep the hands resting on the thighs; pointing with the finger does not mean raising the whole hand.',
      rakah: 2,
      pose: PrayerPose.sitting,
      arabic: 'التَّحِيَّاتُ لِلَّهِ وَالصَّلَوَاتُ وَالطَّيِّبَاتُ، السَّلَامُ عَلَيْكَ أَيُّهَا النَّبِيُّ وَرَحْمَةُ اللَّهِ وَبَرَكَاتُهُ، السَّلَامُ عَلَيْنَا وَعَلَى عِبَادِ اللَّهِ الصَّالِحِينَ',
      meaning: 'Honour, worship and goodness belong to Allah. Peace, Allah’s mercy and blessings be upon you, O Prophet. Peace be upon us and Allah’s righteous servants.',
      source: 'https://sunnah.com/muslim:402a',
      differences: 'Several transmitted tashahhud wordings are valid. This lesson uses the narration of Ibn Masʿūd; schools may prefer another wording.',
    ),
    const PrayerLessonStep(
      'Testimony · Shahādah',
      'Continue the tashahhud:',
      rakah: 2,
      pose: PrayerPose.sitting,
      arabic: 'أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ',
      meaning: 'I testify that none is worthy of worship except Allah, and that Muhammad is His servant and messenger.',
      source: 'https://sunnah.com/muslim:402a',
      differences: fingerDifferences,
    ),
    const PrayerLessonStep(
      'Send blessings',
      'Remain seated and send blessings upon the Prophet ﷺ.',
      rakah: 2,
      pose: PrayerPose.sitting,
      arabic: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ\nاللَّهُمَّ بَارِكْ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا بَارَكْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ',
      meaning: 'O Allah, honour Muhammad and his family as You honoured Ibrahim and his family. You are worthy of praise and glory. O Allah, bless Muhammad and his family as You blessed Ibrahim and his family. You are worthy of praise and glory.',
      source: 'https://sunnah.com/bukhari:3370',
    ),
    const PrayerLessonStep(
      'Duʿā before finishing',
      'One supplication taught for prayer:',
      rakah: 2,
      pose: PrayerPose.sitting,
      arabic: 'اللَّهُمَّ إِنِّي ظَلَمْتُ نَفْسِي ظُلْمًا كَثِيرًا وَلَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ فَاغْفِرْ لِي مَغْفِرَةً مِنْ عِنْدِكَ وَارْحَمْنِي إِنَّكَ أَنْتَ الْغَفُورُ الرَّحِيمُ',
      meaning: 'O Allah, I have greatly wronged myself. Only You forgive sins. Grant me Your forgiveness and mercy; You are the Forgiving, the Merciful.',
      source: 'https://sunnah.com/bukhari:834',
    ),
    const PrayerLessonStep(
      'Salām · Right',
      'Turn your head to the right and say:',
      rakah: 2,
      pose: PrayerPose.sitting,
      arabic: 'السَّلَامُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ',
      meaning: 'Peace and Allah’s mercy be upon you.',
      source: 'https://sunnah.com/abudawud:996',
    ),
    const PrayerLessonStep(
      'Salām · Left',
      'Then turn your head to the left and say:',
      rakah: 2,
      pose: PrayerPose.sitting,
      arabic: 'السَّلَامُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ',
      meaning: 'Peace and Allah’s mercy be upon you.',
      source: 'https://sunnah.com/abudawud:996',
      differences: 'This lesson demonstrates two salāms. The Maliki method for someone praying alone uses one salām; follow your school’s teaching.',
    ),
  ]);
  return steps;
}
