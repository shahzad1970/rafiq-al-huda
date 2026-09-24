import 'package:flutter/painting.dart';

/// Preserve source text while letting system fonts render punctuation missing
/// from the Quran face. Shared by the hadith reader and AI evidence viewer.
TextSpan hadithArabicSpan(String text) {
  final spans = <TextSpan>[];
  var cursor = 0;
  for (final match in RegExp(
    r'[\u0000-\u007f\u2000-\u206f]+',
  ).allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(
      TextSpan(
        text: match.group(0),
        style: const TextStyle(fontFamily: 'Arial'),
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return TextSpan(children: spans);
}
