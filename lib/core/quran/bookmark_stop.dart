import 'quran_repository.dart';

/// Navigation guidance from bundled waqf metadata, not a religious ruling.
class BookmarkStop {
  const BookmarkStop(this.previous, this.current, this.next);
  final int previous, current, next;
  bool get isGoodStop => current == next;
  int get remaining => next - current;
  double get progress =>
      isGoodStop ? 1 : (current - previous) / (next - previous);

  static BookmarkStop forVerse(
    QuranRepository repository,
    int surah,
    int ayah,
  ) {
    final end = repository.getChapter(surah).versesCount;
    if (ayah < 1 || ayah > end) throw RangeError.range(ayah, 1, end);
    var next = ayah;
    while (next < end && !repository.getAyah(surah, next).hasRecommendedStop) {
      next++;
    }
    var previous = ayah - 1;
    while (previous > 0 &&
        !repository.getAyah(surah, previous).hasRecommendedStop) {
      previous--;
    }
    return BookmarkStop(previous, ayah, next);
  }
}
