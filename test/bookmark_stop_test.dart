import 'package:flutter_test/flutter_test.dart';
import 'package:quran_teacher_ai/core/quran/bookmark_stop.dart';

import 'widget_test.dart' show testRepository;

void main() {
  test('Every verse targets the nearest marked stop or surah end', () {
    final repository = testRepository();
    for (final chapter in repository.chapters) {
      for (var ayah = 1; ayah <= chapter.versesCount; ayah++) {
        final stop = BookmarkStop.forVerse(repository, chapter.number, ayah);
        expect(stop.next, inInclusiveRange(ayah, chapter.versesCount));
        expect(stop.remaining, stop.next - ayah);
        expect(stop.progress, inInclusiveRange(0, 1));
        expect(
          stop.isGoodStop,
          ayah == chapter.versesCount ||
              repository.getAyah(chapter.number, ayah).hasRecommendedStop,
        );
        expect(
          stop.next == chapter.versesCount ||
              repository.getAyah(chapter.number, stop.next).hasRecommendedStop,
          isTrue,
        );
        for (
          var intermediate = ayah;
          intermediate < stop.next;
          intermediate++
        ) {
          expect(
            repository.getAyah(chapter.number, intermediate).hasRecommendedStop,
            isFalse,
          );
        }
        if (!stop.isGoodStop) {
          final following = BookmarkStop.forVerse(
            repository,
            chapter.number,
            ayah + 1,
          );
          expect(following.remaining, stop.remaining - 1);
          expect(following.progress, greaterThan(stop.progress));
        }
      }
    }
  });
  test('Synthetic basmalah is not included in countdown', () {
    expect(
      () => BookmarkStop.forVerse(testRepository(), 2, 0),
      throwsRangeError,
    );
  });
}
