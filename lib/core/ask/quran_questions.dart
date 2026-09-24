/// Local, content-matched questions; not interpretations or model output.
/// Match the published translation, not commentary or word-by-word glosses.
List<String> quranQuestions(String translation) {
  const topics = <String, String>{
    r'covenant|pledge|pledges':
        'What does this verse say about keeping a covenant?',
    r'bonds|kinship|relatives':
        'What does this verse say about maintaining bonds?',
    r'corruption|corrupt': 'What does this verse say about corruption?',
    r'guidance|guide|guided|straight path':
        'What does this verse say about guidance?',
    r'mercy|merciful|compassionate':
        'What does this verse say about Allah’s mercy?',
    r'forgive|forgiveness|forgiving|repent|repentance':
        'What does this verse say about forgiveness?',
    r'patient|patience|steadfast': 'What does this verse teach about patience?',
    r'grateful|gratitude|thankful|thanks':
        'What does this verse teach about gratitude?',
    r'prayer|prayers|pray': 'What does this verse say about prayer?',
    r'charity|alms|zakat|spend|spending':
        'What does this verse say about giving?',
    r'fasting|ramadan': 'What does this verse say about fasting?',
    r'parents|mother|father': 'What does this verse say about parents?',
    r'justice|justly|fairness': 'What does this verse teach about justice?',
    r'resurrection|judgment|judgement|hereafter':
        'What does this verse say about the Hereafter?',
    r'paradise|gardens': 'What does this verse say about Paradise?',
    r'creation|created|heavens|earth':
        'What does this verse say about creation?',
    r'worship|worshiping|worshipping':
        'What does this verse say about worship?',
    r'knowledge|knows|knowing':
        'What does this verse say about Allah’s knowledge?',
  };
  final questions = <String>[];
  for (final topic in topics.entries) {
    if (RegExp(
      '\\b(?:${topic.key})\\b',
      caseSensitive: false,
    ).hasMatch(translation)) {
      questions.add(topic.value);
      if (questions.length == 2) break;
    }
  }
  return [
    ...questions,
    'Explain this verse in simple English.',
    if (questions.isEmpty) 'What is the main message of this verse?',
  ];
}
