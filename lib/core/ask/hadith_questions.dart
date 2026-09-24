/// Content-matched starter questions, not generated religious claims.
/// Use only the published English text; answers still need cited evidence.
List<String> hadithQuestions(String english) {
  final questions = <String>[];
  const topics = <String, String>{
    r'intention|intentions|motive|motives|niyyah|intended':
        'What does this hadith teach about intentions?',
    r'migration|hijrah|migrated': 'What does this hadith say about migration?',
    r'prayer|prayers|pray|praying': 'What does this hadith say about prayer?',
    r'fast|fasting|ramadan': 'What does this hadith teach about fasting?',
    r'charity|alms|zakat': 'What does this hadith say about giving?',
    r'parent|parents|mother|father': 'What does this hadith say about parents?',
    r'neighbor|neighbors|neighbour|neighbours':
        'What does this hadith teach about neighbours?',
    r'mercy|merciful|kindness|gentle':
        'How is kindness described in this hadith?',
    r'anger|angry': 'What does this hadith say about anger?',
    r'patience|patient': 'What does this hadith teach about patience?',
    r'forgive|forgiveness|repentance|repent':
        'What does this hadith say about forgiveness?',
    r'truth|truthful|honesty|lying|lie':
        'What does this hadith say about honesty?',
    r'knowledge|learn|learning': 'What does this hadith teach about learning?',
    r'pilgrimage|hajj|umrah': 'What does this hadith say about pilgrimage?',
    r'food|eat|eating|drink|drinking':
        'What does this hadith say about eating or drinking?',
  };
  for (final topic in topics.entries) {
    if (RegExp(
      '\\b(?:${topic.key})\\b',
      caseSensitive: false,
    ).hasMatch(english)) {
      questions.add(topic.value);
      if (questions.length == 2) break;
    }
  }
  return [
    ...questions,
    'Explain this hadith in simple English.',
    if (questions.isEmpty) 'What is the main lesson of this hadith?',
  ];
}
