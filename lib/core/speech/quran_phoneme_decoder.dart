/// The table must be the authorized tokens.txt, never phoneme_units.json.
class QuranPhonemeDecoder {
  QuranPhonemeDecoder(String table, {required this.blankId}) {
    for (final line in table.split('\n')) {
      if (line.trim().isEmpty) continue;
      final match = RegExp(r'^(.+?)\s+(\d+)\s*$').firstMatch(line);
      if (match == null) throw const FormatException('Invalid tokens.txt line');
      final id = int.parse(match.group(2)!);
      if (_tokens.containsKey(id)) {
        throw const FormatException('Duplicate token ID');
      }
      _tokens[id] = match.group(1)!;
    }
    if (!_tokens.containsKey(blankId)) {
      throw const FormatException('Blank absent from table');
    }
  }
  final int blankId;
  final Map<int, String> _tokens = {};
  int? _previous;
  void reset() => _previous = null;

  /// Only collapse IDs here. Production confidence aggregation awaits reference inspection.
  List<String> collapse(List<int> ids) {
    final emitted = <String>[];
    for (final id in ids) {
      final symbol = _tokens[id];
      if (symbol == null) throw FormatException('Unknown CTC token $id');
      if (id != blankId && id != _previous) emitted.add(symbol);
      _previous = id;
    }
    return emitted;
  }
}
