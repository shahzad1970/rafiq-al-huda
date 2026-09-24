# Third-party notices

## Hadith API by Fawaz Ahmed

- Source: https://github.com/fawazahmed0/hadith-api
- Pinned revision: `df57907be35291c91ad6a6691180e22ca9920784`
- Repository license: Unlicense (`assets/licenses/hadith-api.txt`)
- Ten Arabic/English source editions, split into locally bundled book files.
- Source text, numbering and named grading attributions are preserved. See
  `docs/HADITH_LIBRARY.md` for missing records, matching rules and coverage limits.
- Underlying translation rights have not been independently cleared for broader
  distribution; this addition remains in the personal/local app.

## Fitrahive Duʿā & Dhikr

- Source: https://github.com/fitrahive/dua-dhikr
- Pinned revision: `f42f895f914319a844c3e3c2279483cae060ea19`
- Repository license: MIT, Copyright (c) 2023 Fitrahive
- Bundled license: `assets/licenses/fitrahive-dua-dhikr.txt`
- Arabic/English text and reported references retained for 59 unique entries.
- Counts/virtue claims omitted; selected unclear/unreferenced rows excluded.
- See `docs/DUA_CONTENT.md` and `docs/dua-import-manifest.json` for provenance,
  filtering and review limitations. Repository licensing is not an independent
  audit of every translation's upstream rights or every narration's grading.

## Quran pronunciation mapping

- Development-time provenance library: https://github.com/obadx/quran-transcript
- Version 0.6.2, pinned commit `42b9338896e758c69f7deeb10758891b76ab7177`.
- Code MIT license; upstream Tanzil Quran text attribution CC BY 3.0: https://tanzil.net.
- Full upstream notices bundled in `assets/licenses/quran-transcript.txt`.
- Mapping is generated from the already-authorized Quran-Lab canonical text; no expected phoneme tokens or displayed Quran text are changed. Only source-derived word/phrase spans are added. See `docs/QURAN_WORD_MAPPING.md`.

## kaldi-native-fbank

- Source: https://github.com/csukuangfj/kaldi-native-fbank
- Pinned commit: `b09e686fe2084732ddd30d1ef80acfc0f13eaf01`
- Version: 1.22.3
- License: Apache License 2.0
- License text: `third_party/kaldi-native-fbank/LICENSE`

The project uses this library without source modification behind `QuranFbankBridge` for the model-compatible online Kaldi fbank frontend.

## KissFFT

- Source: https://github.com/mborgerding/kissfft
- Pinned commit: `febd4caeed32e33ad8b2e0bb5ea77542c40f18ec`
- License: BSD 3-Clause
- License text: `third_party/kissfft/COPYING` and `third_party/kissfft/LICENSES/BSD-3-Clause`

KissFFT is the FFT dependency pinned by the selected kaldi-native-fbank revision.

## Quran-Lab Zipformer

- Source: https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3
- Pinned revision: `506422c82a81c86e7ae74a5a2ab4641724bcd3b3`
- License: Quran-Lab No-Profit License 1.2
- Local authorized license text: `models/quran_lab/v3_1/LICENSE`

The gated model and its license are kept outside source control. Redistribution requires a separate license review.

## Quran.com IndoPak Nastaleeq font and text

- Font source: https://github.com/quran/quran.com-frontend-next/tree/master/public/fonts/quran/hafs/nastaleeq/indopak
- Font file: `indopak-nastaleeq-waqf-lazim-v4.2.1.ttf`
- Font SHA-256: `4c8f002e7538ef6351ac676eb0f2c1708ecd17f6f8a5fc4a19dbc8eaf4dddff5`
- Whole-Qur’an IndoPak and canonical Uthmani text source: Quran.com Content API v4
- Retrieved: 2026-09-16

The font and all 6,236 ayah display strings are installed only in this personal, local application. Canonical Uthmani text remains separate for model-compatible alignment.

## AbdulBaset AbdulSamad Mujawwad recitation

- Reciter: AbdulBaset AbdulSamad
- Style: Mujawwad
- Audio source: QuranicAudio / Quran Foundation verse audio
- Source pages: https://quranicaudio.com/about and https://api-docs.quran.com/docs/content_apis_versioned/4.0.0/recitation-audio-files/
- Quran Foundation recitation ID: 1
- Retrieved: 2026-09-16

The seven Al-Fatihah MP3 files are bundled. Other verses are downloaded only when played or when the user requests a surah for offline use, and remain in local app storage. QuranicAudio states that its MP3 files may be downloaded and used free for personal use and may not be used for commercial purposes. Word playback seeks within the original verse file using Quran Foundation timing metadata; Al-Fatihah 1:4 uses a documented local timing split because the published response supplied one aggregate segment.

## Quran.com word translations and timing metadata

- Word translations: Quran.com Content API
- Recitation timing: Quran Foundation Content API v4, recitation ID 1
- Retrieved: 2026-09-16

The versioned local snapshot covers all 114 surahs and 6,236 ayahs. It stores Quran.com English word meanings and AbdulBaset Mujawwad verse URLs/timing data for the one-verse word-by-word teaching interface.
