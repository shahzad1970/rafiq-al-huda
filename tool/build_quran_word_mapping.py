"""Build conservative pronunciation groups without changing Quran-Lab tokens.

Requires quran-transcript 0.6.2, source commit
42b9338896e758c69f7deeb10758891b76ab7177. Run --write to update generated data.
Shared CTC tokens and ambiguous reference-version boundaries join adjacent words;
they are NEVER assigned to an invented exact single-word boundary.
"""
import argparse
import hashlib
import importlib.metadata
import json
import re
from collections import Counter
from pathlib import Path
from quran_transcript import quran_phonetizer, MoshafAttributes
from quran_transcript.phonetics.search import get_uth_word_boundaries_in_ph

ROOT = Path(__file__).resolve().parents[1]
COMMIT = '42b9338896e758c69f7deeb10758891b76ab7177'
CONFIG = MoshafAttributes(rewaya='hafs', madd_monfasel_len=4,
    madd_mottasel_len=4, madd_mottasel_waqf=4, madd_aared_len=4)

def letters(text):
    # Comparison only: source/display Quran text is never rewritten.
    # Quran.com has five orthographic variants in this snapshot (alif/madda/
    # hamzat-wasl and alif-maqsura); normalize only to match text locations.
    text = text.translate(str.maketrans({'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ى': 'ا'}))
    return ''.join(re.findall(r'[\u0621-\u063A\u0641-\u064A\u0671]', text))

def distances(a, b):
    rows = [list(range(len(b) + 1))]
    for i, x in enumerate(a, 1):
        row = [i]
        for j, y in enumerate(b, 1):
            row.append(min(rows[-1][j] + 1, row[-1] + 1,
                rows[-1][j-1] + (x != y)))
        rows.append(row)
    return rows

def boundary_projection(source, target, boundaries):
    if source == target:
        return {b: b for b in boundaries}, 0
    forward = distances(source, target)
    backward = distances(source[::-1], target[::-1])
    cost = forward[-1][-1]
    if cost > max(4, len(target) * .05):
        raise ValueError('Reference drift exceeds reviewed mapping policy')
    result = {}
    for b in boundaries:
        possible = [j for j in range(len(target) + 1)
            if forward[b][j] + backward[len(source)-b][len(target)-j] == cost]
        # Split only if ALL optimal reference alignments agree.
        if len(possible) == 1:
            result[b] = possible[0]
    return result, cost

def build_groups(reference, ayah, surah):
    text = reference['aya_text']
    flat = [t for word in ayah['words'] for t in word['phonemes']]
    target = ''.join(flat)
    assert target == reference['aya_phoneme'].replace(' ', '')
    assert letters(text) == ''.join(letters(w['text']) for w in ayah['words']), 'Source/display text differs'
    output = quran_phonetizer(text, CONFIG, remove_spaces=True, sura_idx=surah)
    source_words = text.split(' ')
    source_bounds = [*get_uth_word_boundaries_in_ph(text, output.mappings), len(output.phonemes)]
    assert len(source_bounds) == len(source_words)
    letter_to_phoneme = {}
    count = 0
    for word, boundary in zip(source_words, source_bounds):
        count += len(letters(word))
        letter_to_phoneme[count] = boundary
    display_bounds = {}
    count = 0
    for i, word in enumerate(ayah['words'][:-1], 1):
        count += len(letters(word['text']))
        if count in letter_to_phoneme:
            display_bounds[i] = letter_to_phoneme[count]
    projected, edit_cost = boundary_projection(output.phonemes, target, display_bounds.values())
    offsets = {0: 0}
    end = 0
    for i, token in enumerate(flat, 1):
        end += len(token)
        offsets[end] = i
    cuts = [(0, 0)]
    for word, boundary in display_bounds.items():
        position = projected.get(boundary)
        if position in offsets and cuts[-1][1] < offsets[position] < len(flat):
            cuts.append((word, offsets[position]))
    cuts.append((len(ayah['words']), len(flat)))
    groups = [[a[0], b[0], a[1], b[1]] for a, b in zip(cuts, cuts[1:])]
    assert all(a < b and c < d for a, b, c, d in groups)
    assert groups[0][0] == 0 and groups[-1][1] == len(ayah['words'])
    assert [t for _, _, a, b in groups for t in flat[a:b]] == flat
    return groups, edit_cost

def build(write=False):
    if importlib.metadata.version('quran-transcript') != '0.6.2':
        raise RuntimeError('Install the pinned tool/quran_mapping_requirements.txt dependency')
    model_path = ROOT / 'models/quran_lab/v3_1/ordered_quran_phonemes.json'
    asset_path = ROOT / 'assets/data/quran_v1.json'
    canonical = json.loads(model_path.read_text())
    data = json.loads(asset_path.read_text())
    assert hashlib.sha256(model_path.read_bytes()).hexdigest() == data['quranLabPhonemeSha256'], 'Canonical source checksum changed'
    assert hashlib.sha256((ROOT / 'models/quran_lab/v3_1/tokens.txt').read_bytes()).hexdigest() == data['quranLabTokensSha256'], 'Authoritative token table changed'
    valid_tokens = {line.rsplit(' ', 1)[0] for line in (ROOT / 'models/quran_lab/v3_1/tokens.txt').read_text().splitlines()}
    counts = Counter()
    differences = {}
    for key, ref in canonical.items():
        ayah = data['ayahs'][key]
        assert all(t in valid_tokens and t != '<blank>' for w in ayah['words'] for t in w['phonemes'])
        groups, edit_cost = build_groups(ref, ayah, int(key.split(':')[0]))
        ayah['pronunciationGroups'] = groups
        counts['verses'] += 1
        counts['groups'] += len(groups)
        counts['joinedGroups'] += sum(b - a > 1 for a, b, _, _ in groups)
        counts['singleWordGroups'] += sum(b - a == 1 for a, b, _, _ in groups)
        if edit_cost:
            differences[key] = edit_cost
        if counts['verses'] % 500 == 0:
            print(dict(counts), flush=True)
    assert counts['verses'] == 6236
    metadata = {'version': 1, 'source': 'obadx/quran-transcript', 'commit': COMMIT,
        'canonicalSha256': hashlib.sha256(model_path.read_bytes()).hexdigest(),
        'policy': 'source-character-boundaries; all-optimal-reference-alignment; merge-shared-token-or-ambiguous-boundaries',
        'counts': dict(counts), 'referenceVersionDifferences': differences}
    data['pronunciationMapping'] = metadata
    if write:
        # Mechanical generated-data rewrite; text, audio and token sequences unchanged.
        asset_path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')))
        (ROOT / 'docs/QURAN_WORD_MAPPING_REPORT.json').write_text(json.dumps(metadata, indent=2))
    print(json.dumps(metadata, indent=2))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--write', action='store_true')
    build(parser.parse_args().write)
