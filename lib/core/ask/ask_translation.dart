import 'dart:convert';

import 'package:flutter/services.dart';

/// Translation and publisher notes stay separate; neither is an AI answer.
class AskTranslation {
  AskTranslation(this.data) {
    if (data['schemaVersion'] != 1 || (data['ayahs'] as Map).length != 6236) {
      throw const FormatException('Incomplete translation');
    }
  }
  final Map<String, dynamic> data;
  static Future<AskTranslation> load() async => AskTranslation(
    jsonDecode(
      await rootBundle.loadString(
        'assets/data/ask_translation.json',
        cache: false,
      ),
    ) as Map<String, dynamic>,
  );
  String get version => (data['edition'] as Map)['version'] as String;
  String get attribution =>
      'Rowwad Translation Center · QuranEnc.com · v$version';
  Map<String, dynamic> ayah(String key) =>
      Map<String, dynamic>.from((data['ayahs'] as Map)[key] as Map);
}
