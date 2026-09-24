enum AlignmentKind { correct, substitution, deletion, insertion }

class PhonemeAlignment {
  const PhonemeAlignment(this.expectedIndex, this.detectedIndex, this.kind);
  final int? expectedIndex, detectedIndex;
  final AlignmentKind kind;
}

/// Deterministic edit alignment. Not connected to capture until model validation.
class QuranAlignmentEngine {
  List<PhonemeAlignment> align(List<String> expected, List<String> detected) {
    return _align(expected, detected, streamingPrefix: false);
  }

  /// Aligns only the observed prefix. Unread expected suffixes are not treated
  /// as deletions, preventing repeated sounds from jumping to a later word.
  List<PhonemeAlignment> alignStreamingPrefix(
    List<String> expected,
    List<String> detected,
  ) {
    return _align(expected, detected, streamingPrefix: true);
  }

  List<PhonemeAlignment> _align(
    List<String> expected,
    List<String> detected, {
    required bool streamingPrefix,
  }) {
    final costs = List.generate(
      expected.length + 1,
      (_) => List.filled(detected.length + 1, 0),
    );
    for (var i = 0; i <= expected.length; i++) {
      costs[i][0] = i;
    }
    for (var j = 0; j <= detected.length; j++) {
      costs[0][j] = j;
    }
    for (var i = 1; i <= expected.length; i++) {
      for (var j = 1; j <= detected.length; j++) {
        final substitution =
            costs[i - 1][j - 1] + (expected[i - 1] == detected[j - 1] ? 0 : 1);
        costs[i][j] = [
          substitution,
          costs[i - 1][j] + 1,
          costs[i][j - 1] + 1,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    var i = expected.length;
    if (streamingPrefix) {
      i = 0;
      for (var candidate = 1; candidate <= expected.length; candidate++) {
        if (costs[candidate][detected.length] < costs[i][detected.length]) {
          i = candidate;
        }
      }
    }
    var j = detected.length;
    final result = <PhonemeAlignment>[];
    while (i > 0 || j > 0) {
      if (i > 0 &&
          j > 0 &&
          costs[i][j] ==
              costs[i - 1][j - 1] +
                  (expected[i - 1] == detected[j - 1] ? 0 : 1)) {
        result.add(
          PhonemeAlignment(
            i - 1,
            j - 1,
            expected[i - 1] == detected[j - 1]
                ? AlignmentKind.correct
                : AlignmentKind.substitution,
          ),
        );
        i--;
        j--;
      } else if (i > 0 && costs[i][j] == costs[i - 1][j] + 1) {
        result.add(PhonemeAlignment(i - 1, null, AlignmentKind.deletion));
        i--;
      } else {
        result.add(PhonemeAlignment(null, j - 1, AlignmentKind.insertion));
        j--;
      }
    }
    return result.reversed.toList();
  }
}
