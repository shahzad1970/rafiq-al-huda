import '../quran/quran_repository.dart';

part 'dua_imported.dart';

class DuaCategory {
  const DuaCategory(this.id, this.title, this.subtitle);
  final String id, title, subtitle;
}

class DuaEntry {
  const DuaEntry(
    this.id,
    this.category,
    this.title,
    this.keywords,
    this.surah,
    this.ayah,
    this.start,
    this.meaning, {
    this.end,
  }) : text = null,
       collectionReference = null,
       collectionUrl = null,
       additionalCategories = const [],
       aliases = '';
  const DuaEntry.text({
    required this.id,
    required this.category,
    required this.title,
    required this.keywords,
    required this.meaning,
    required this.text,
    required this.collectionReference,
    required this.collectionUrl,
    this.additionalCategories = const [],
    this.aliases = '',
  }) : surah = 0,
       ayah = 0,
       start = 0,
       end = null;
  final String? text, collectionReference, collectionUrl;
  final List<String> additionalCategories;
  final String aliases;
  bool get isQuranExcerpt => text == null;
  bool inCategory(String value) =>
      category == value || additionalCategories.contains(value);
  final String id, category, title, keywords, meaning;
  final int surah, ayah, start;
  final int? end;
  String get reference => collectionReference ?? 'Qur’an $surah:$ayah';
  String get sourceUrl => collectionUrl ?? 'https://quran.com/$surah/$ayah';
  List<QuranWord> words(QuranRepository repository) => isQuranExcerpt
      ? repository.getAyah(surah, ayah).words.sublist(start, end)
      : const [];
  String arabic(QuranRepository repository) =>
      text ?? words(repository).map((w) => w.displayText).join(' ');
}

/// Arabic is extracted unchanged from the existing sourced Quran repository.
/// English meanings are brief editorial renderings, not attributed quotations.
/// Categories describe subject matter, not prescribed times or promised merits.
class DuaCatalog {
  static const categories = [
    DuaCategory('goodness', 'Daily goodness', 'This life & the next'),
    DuaCategory(
      'guidance',
      'Guidance & learning',
      'Knowledge & a steady heart',
    ),
    DuaCategory('forgiveness', 'Forgiveness & mercy', 'Turn back to Allah'),
    DuaCategory('family', 'Family & loved ones', 'Parents, spouses & children'),
    DuaCategory('strength', 'Ease & strength', 'Need, patience & resolve'),
    DuaCategory('acceptance', 'Acceptance', 'For the good you do'),
    DuaCategory('morning', 'Morning remembrance', 'Begin the day'),
    DuaCategory('evening', 'Evening remembrance', 'As the day ends'),
    DuaCategory('sleep', 'Sleep & waking', 'Rest and a new day'),
    DuaCategory(
      'home',
      'Home & daily life',
      'Home, clothing & everyday moments',
    ),
    DuaCategory('food', 'Food & fasting', 'Meals and breaking the fast'),
    DuaCategory(
      'prayer',
      'Prayer & mosque',
      'Wudu, adhan & remembrance after prayer',
    ),
    DuaCategory('travel', 'Travel', 'Journeys and farewells'),
    DuaCategory('weather', 'Rain & wind', 'Weather and gratitude'),
    DuaCategory(
      'protection',
      'Protection & wellbeing',
      'Safety, health & refuge',
    ),
  ];
  static const entries = [
    ..._importedDuas,
    DuaEntry(
      'faith_forgiveness',
      'forgiveness',
      'Forgiveness through faith',
      'rabbana fire protection',
      3,
      16,
      2,
      'Our Lord, we have believed. Forgive our sins and protect us from the punishment of the Fire.',
    ),
    DuaEntry(
      'good_offspring',
      'family',
      'For good offspring',
      'children child zakariya parents',
      3,
      38,
      5,
      'My Lord, grant me good offspring from Yourself. You hear every supplication.',
    ),
    DuaEntry(
      'witnesses',
      'guidance',
      'Count us among the witnesses',
      'faith belief messenger',
      3,
      53,
      0,
      'Our Lord, we believe in what You have revealed and follow the messenger. Count us among those who bear witness.',
    ),
    DuaEntry(
      'creation',
      'protection',
      'Reflecting on creation',
      'heavens earth fire',
      3,
      191,
      12,
      'Our Lord, You did not create this without purpose. Glory be to You. Protect us from the punishment of the Fire.',
    ),
    DuaEntry(
      'righteous_end',
      'forgiveness',
      'A righteous end',
      'death sins forgiveness',
      3,
      193,
      10,
      'Our Lord, forgive our sins, remove our misdeeds, and let us die among the righteous.',
    ),
    DuaEntry(
      'promise',
      'goodness',
      'Hope on the Day of Resurrection',
      'hereafter promise resurrection',
      3,
      194,
      0,
      'Our Lord, grant us what You promised through Your messengers, and do not disgrace us on the Day of Resurrection. You never break Your promise.',
    ),
    DuaEntry(
      'wrongdoers',
      'protection',
      'Protection from wrongdoing',
      'injustice wrongdoers',
      7,
      47,
      7,
      'Our Lord, do not place us with the wrongdoing people.',
    ),
    DuaEntry(
      'establish_prayer',
      'acceptance',
      'Keep me and my family in prayer',
      'salah salat children ibrahim',
      14,
      40,
      0,
      'My Lord, make me and my descendants steadfast in prayer. Our Lord, accept my supplication.',
    ),
    DuaEntry(
      'parents_mercy',
      'family',
      'Mercy for my parents',
      'mother father mum dad childhood',
      17,
      24,
      7,
      'My Lord, show them mercy, as they cared for me when I was small.',
    ),
    DuaEntry(
      'truthful_path',
      'guidance',
      'An honest path forward',
      'entry exit truth help',
      17,
      80,
      1,
      'My Lord, let me enter in truth and leave in truth, and grant me supporting strength from Yourself.',
    ),
    DuaEntry(
      'cave_mercy',
      'guidance',
      'Mercy and right direction',
      'cave kahf decisions uncertainty',
      18,
      10,
      6,
      'Our Lord, grant us mercy from Yourself and guide our affairs rightly.',
    ),
    DuaEntry(
      'ayyub',
      'strength',
      'In illness and hardship',
      'illness sick pain health ayyub ayub',
      21,
      83,
      4,
      'Harm has touched me, and You are the most merciful of those who show mercy.',
    ),
    DuaEntry(
      'yunus',
      'forgiveness',
      'The supplication of Yunus',
      'distress darkness whale repentance',
      21,
      87,
      14,
      'There is no god but You. Glory be to You. I have indeed been among the wrongdoers.',
    ),
    DuaEntry(
      'zakariya',
      'family',
      'Do not leave me alone',
      'child children offspring zakariya',
      21,
      89,
      4,
      'My Lord, do not leave me without an heir, though You are the best of inheritors.',
    ),
    DuaEntry(
      'believers_mercy',
      'forgiveness',
      'Mercy for those who believe',
      'faith believers forgiveness',
      23,
      109,
      6,
      'Our Lord, we believe. Forgive us and show us mercy. You are the best of those who show mercy.',
    ),
    DuaEntry(
      'fire_refuge',
      'protection',
      'Refuge from Hell',
      'hereafter punishment fire',
      25,
      65,
      2,
      'Our Lord, turn the punishment of Hell away from us. Its punishment is unrelenting.',
    ),
    DuaEntry(
      'wisdom',
      'guidance',
      'Wisdom and righteous company',
      'judgment knowledge friends ibrahim',
      26,
      83,
      0,
      'My Lord, grant me wisdom and join me with the righteous.',
    ),
    DuaEntry(
      'gratitude',
      'acceptance',
      'Gratitude and good deeds',
      'thankful parents blessings sulayman',
      27,
      19,
      5,
      'My Lord, enable me to thank You for Your blessings upon me and my parents, and to do good that pleases You. By Your mercy, admit me among Your righteous servants.',
    ),
    DuaEntry(
      'musa_forgiveness',
      'forgiveness',
      'I have wronged myself',
      'musa moses forgive mistakes',
      28,
      16,
      1,
      'My Lord, I have wronged myself, so forgive me.',
      end: 7,
    ),
    DuaEntry(
      'righteous_child',
      'family',
      'For a righteous child',
      'offspring baby ibrahim',
      37,
      100,
      0,
      'My Lord, grant me a child from among the righteous.',
    ),
    DuaEntry(
      'heart_without_resentment',
      'family',
      'A heart without resentment',
      'believers brothers sisters hatred forgiveness community',
      59,
      10,
      5,
      'Our Lord, forgive us and our fellow believers who came before us in faith. Do not let our hearts hold resentment toward those who believe. Our Lord, You are truly kind and merciful.',
    ),
    DuaEntry(
      'complete_light',
      'goodness',
      'Complete our light',
      'light hereafter forgiveness',
      66,
      8,
      34,
      'Our Lord, complete our light for us and forgive us. You have power over all things.',
    ),
    DuaEntry(
      'goodness_worlds',
      'goodness',
      'Good in this life and the next',
      'rabbana atina hereafter protection',
      2,
      201,
      3,
      'Our Lord, give us goodness in this world and in the Hereafter, and protect us from the punishment of the Fire.',
    ),
    DuaEntry(
      'knowledge',
      'guidance',
      'Increase me in knowledge',
      'study school learning exam rabbi zidni ilma',
      20,
      114,
      14,
      'My Lord, increase my knowledge.',
    ),
    DuaEntry(
      'steadfast',
      'guidance',
      'Keep my heart guided',
      'faith heart steadfast guidance',
      3,
      8,
      0,
      'Our Lord, do not let our hearts turn away after You have guided us. Give us mercy from Yourself; You are the Giver.',
    ),
    DuaEntry(
      'repentance',
      'forgiveness',
      'When seeking forgiveness',
      'repentance sorry mistakes sin adam',
      7,
      23,
      1,
      'Our Lord, we have wronged ourselves. Unless You forgive us and show us mercy, we will be among those who lose.',
    ),
    DuaEntry(
      'mercy',
      'forgiveness',
      'Ask for forgiveness and mercy',
      'forgive mercy compassion',
      23,
      118,
      1,
      'My Lord, forgive and show mercy. You are the best of those who show mercy.',
    ),
    DuaEntry(
      'parents',
      'family',
      'For parents and believers',
      'mother father mum dad parents family',
      14,
      41,
      0,
      'Our Lord, forgive me, my parents and the believers on the Day of Reckoning.',
    ),
    DuaEntry(
      'family',
      'family',
      'Joy in your family',
      'spouse wife husband children marriage family',
      25,
      74,
      2,
      'Our Lord, make our spouses and children a joy to our eyes, and make us examples for those mindful of You.',
    ),
    DuaEntry(
      'provision',
      'strength',
      'When you are in need',
      'help work job provision rizq hardship musa',
      28,
      24,
      7,
      'My Lord, I am in need of whatever good You send to me.',
    ),
    DuaEntry(
      'patience',
      'strength',
      'Patience and steady steps',
      'sabr patience strength difficulty courage',
      2,
      250,
      5,
      'Our Lord, pour patience upon us and make our steps firm.',
      end: 11,
    ),
    DuaEntry(
      'acceptance',
      'acceptance',
      'May our efforts be accepted',
      'deeds worship acceptance ibrahim',
      2,
      127,
      7,
      'Our Lord, accept this from us. You are the One who hears and knows everything.',
    ),
  ];

  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(
        RegExp(r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed\u0640]'),
        '',
      )
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي');

  static List<DuaEntry> search(
    QuranRepository repository,
    String query, {
    String? category,
    Set<String>? favourites,
  }) {
    final terms = normalize(query)
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty);
    return entries.where((dua) {
      if (category != null && !dua.inCategory(category)) return false;
      if (favourites != null && !favourites.contains(dua.id)) return false;
      final haystack = normalize(
        '${dua.title} ${dua.aliases} ${dua.keywords} ${dua.meaning} ${dua.reference} ${dua.arabic(repository)} ${categories.where((c) => dua.inCategory(c.id)).map((c) => '${c.title} ${c.subtitle}').join(' ')}',
      );
      return terms.every(haystack.contains);
    }).toList();
  }
}
