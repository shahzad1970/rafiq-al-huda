# Real-audio acceptance fixtures — not yet supplied

No recognition fixture is fabricated or committed. Local validation currently uses the git-ignored file `local_only/everyayah_abdulsamad_001001.wav`, fetched from the public `tarteel-ai/everyayah` Hugging Face dataset row 0 on 2026-09-15. It is Al-Fatihah 1:1, reciter `abdulsamad`, 16 kHz mono PCM16, 6.478375 seconds, SHA-256 `4ea3e4cbe0032b055795a86b0d5e63c4c00e18242aa94680e4b7b98899b2c50a`.

The dataset card conflicts with itself: YAML front matter says MIT while its licensing section says CC BY 4.0. Keep this file local-only and do not redistribute it until provenance is resolved. Future fixtures must record source, consent/license, speaker age/domain, sample rate, channel count, annotated phoneme/word errors and reviewer.

Required cases: correct Al-Fatihah, deliberate pronunciation substitution, skipped word, repeated word, short madd if annotated timing is available, background noise, and quiet microphone. Run the identical PCM on iOS and Android and compare actual outputs. Exact Kaldi fbank feature fixtures must be produced with Quran-Lab's authorized reference implementation before front-end parity tests can be authored.
