"""Audit canonical Quran-Lab labels against source-provenance word boundaries.

Development only; requires quran-transcript 0.6.2 at commit
42b9338896e758c69f7deeb10758891b76ab7177. Never changes acoustic labels.
"""
import json
import re
from collections import Counter
from pathlib import Path
from quran_transcript import quran_phonetizer, MoshafAttributes
from quran_transcript.phonetics.search import get_uth_word_boundaries_in_ph

ROOT = Path(__file__).resolve().parents[1]
CONFIG = MoshafAttributes(rewaya="hafs", madd_monfasel_len=4,
    madd_mottasel_len=4, madd_mottasel_waqf=4, madd_aared_len=4)

def audit():
    canonical = json.loads((ROOT / 'models/quran_lab/v3_1/ordered_quran_phonemes.json').read_text())
    data = json.loads((ROOT / 'assets/data/quran_v1.json').read_text())
    counts = Counter()
    examples = {}
    for key, reference in canonical.items():
        ayah = data['ayahs'][key]
        text = reference['aya_text']
        flat = [t for w in ayah['words'] for t in w['phonemes']]
        phonemes = ''.join(flat)
        assert phonemes == reference['aya_phoneme'].replace(' ', ''), key
        output = quran_phonetizer(text, CONFIG, remove_spaces=True, sura_idx=int(key.split(':')[0]))
        boundaries = [0, *get_uth_word_boundaries_in_ph(text, output.mappings), len(output.phonemes)]
        offsets = [0]
        for token in flat:
            offsets.append(offsets[-1] + len(token))
        if output.phonemes != phonemes:
            kind = 'phoneme_difference'
            if len(examples.get(kind, [])) < 12:
                examples.setdefault(kind, []).append([key, phonemes, output.phonemes])
        elif len(boundaries) != len(ayah['words']) + 1:
            kind = 'word_count_difference'
        elif any(b not in offsets for b in boundaries):
            kind = 'shared_token_boundary'
        elif any(a >= b for a, b in zip(boundaries, boundaries[1:])):
            kind = 'empty_word'
        else:
            kind = 'exact'
        counts[kind] += 1
        if kind != 'phoneme_difference' and len(examples.get(kind, [])) < 5:
            examples.setdefault(kind, []).append(key)
        if sum(counts.values()) % 500 == 0:
            print(sum(counts.values()), dict(counts), flush=True)
    print(json.dumps({'counts': counts, 'examples': examples}, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    audit()
