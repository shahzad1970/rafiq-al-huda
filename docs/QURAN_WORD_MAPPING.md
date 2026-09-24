# Whole-Quran pronunciation mapping

## Coverage and limits

All 6,236 canonical verses now have contiguous, nonempty pronunciation groups covering every display word and every installed Quran-Lab token. There are 72,666 single-word groups and 2,317 multi-word groups. A group is not a new acoustic model output: it maps the unchanged expected CTC sequence to visible words. When a CTC token spans a word boundary, the corresponding phrase is reviewed/underlined together. Do not claim which individual letter within that joined sound was wrong.

This replaces the previous all-or-nothing grading gate based on equal counts of acoustic space-separated strings and display words. Legacy approximate display spans are retained solely for Follow positioning; they are not used by the new pronunciation scoring path. `exactWordMapping` remains a legacy display-span flag. `supportsPronunciation` accepts the validated new group mapping. The scoring engine and word feedback engine use `scoringReference`; joined practice uses that same canonical phrase and reference audio range. No recorded student sound is rewritten or corrected to match expected text.

This is coverage of the existing conservative phoneme-feedback mechanism, not a clinical/pedagogical accuracy validation, support for every stopping variant, or full tajwīd grading. Existing confidence gates remain. Low-confidence substitutions are not promoted to errors. Tajwīd grading has not been broadened; joined phrases do not acquire unvalidated tajwīd claims. Reference audio timing has not been re-aligned and retains its existing estimated ranges where documented.

## Reproducible provenance

Source: https://github.com/obadx/quran-transcript, commit `42b9338896e758c69f7deeb10758891b76ab7177`, version 0.6.2. This is the phonetic-script library identified by the Quran-Lab model card. Use the pinned dependency in `tool/quran_mapping_requirements.txt` in a separate Python environment.

Inputs are the authorized local `ordered_quran_phonemes.json`, `tokens.txt` and the existing `assets/data/quran_v1.json`. Canonical SHA256 is `4782e90e190a59207f5d74a909dd917a0cfead1959338d1fbc97fe55faf1c09c`. Source settings are Hafs/murattal with madd monfasel, mottasel, mottasel-waqf and aared length 4, matching the canonical reference's configuration.

1. Generate phonetic character provenance from the canonical Uthmani text using `quran_phonetizer(..., remove_spaces=True)`.
2. Associate display-word boundaries with source text boundaries, checking the entire normalized letter sequence. Normalization is only for textual correspondence (alif forms and alif-maqsura); no display text or phoneme changes. This handles five orthographic differences in the snapshot and four API display tokens containing two written words.
3. Compare generated phonetics with the installed canonical phoneme string. They match exactly in 6,175 verses. For the other 61, retain the canonical tokens and project source boundaries through all minimum-edit reference-to-reference alignments. A split is accepted only when every optimal alignment agrees on one position. Larger unexpected drift fails the build. The per-verse edit costs are recorded in `QURAN_WORD_MAPPING_REPORT.json`.
4. Split only at an actual installed CTC-token boundary; merge adjacent words otherwise. The original full token sequence is preserved, including madd and joined sounds.
5. Validate all tokens against `tokens.txt`; assert complete contiguous coverage. The runtime repository rejects corrupt/incomplete spans.

Build using the pinned environment:

```sh
python tool/build_quran_word_mapping.py --write
PYTHONPATH=. python -m unittest discover -s test -p quran_mapping_builder_test.py
```

`tool/generate_quran_data.dart` requires `QURAN_MAPPING_PYTHON` pointing at that environment and runs the mapping pass after generating fresh Quran.com data. Never ship a data generation that exits unsuccessfully. This is an offline development step, not a runtime dependency or new speech model download.

## Validation

The corpus test checks all 6,236 complete group partitions and compares every concatenated expected token with the original Quran-Lab reference. Deterministic substitution and confidence tests cover 2:27, 2:7, 11:13, 37:130, 70:1 and 114:6, including multi-word ownership. Additional tests cover malformed mapping rejection, joined practice selection, reference-version ambiguity and changed-source rejection. These fixtures test mapping/scoring, not real-world acoustic performance. Physical recitation validation across surahs is still required; no new latency or accuracy measurements are claimed.

Full upstream MIT and Tanzil notices are bundled at `assets/licenses/quran-transcript.txt` and attributed in Settings → App information.
