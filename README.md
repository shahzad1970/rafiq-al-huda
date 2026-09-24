# Rafiq Al-Huda

Free, non-commercial, local-only iPhone application for on-device Quran phoneme practice. This remains an incrementally verified teaching aid, **not an authoritative tajwīd judgement or a replacement for a qualified teacher**.

## Implemented

- A header book icon opens the surah/verse popup. Added Bismillāh opening lessons reuse Al-Fātiḥah 1:1 before applicable surahs without renumbering canonical verses; Al-Fātiḥah and At-Tawbah are excluded. Both recorded recitation playback and microphone recognition keep the active word in view automatically.

- iPhone-focused Flutter UI covering all 114 surahs and 6,236 ayahs, one verse at a time in Quran.com IndoPak Nastaleeq, with English beneath every word, verse-ending marks, searchable surah/verse navigation, adjustable Arabic size, and native on-device microphone capture.
- A native-feeling visual system with System, Light, and Dark appearance modes plus Emerald, Ocean, Sand, and Plum color schemes. The saved choice applies throughout the app, including reading, playback, feedback, settings, and navigation.
- A custom emerald-and-ivory app icon combines an open Qur’an with a listening-wave motif and includes every required iPhone and iPad icon size.
- Bottom Back, Record, Play, and Forward controls; tap any word to hear its timed segment or play the whole verse in AbdulBaset AbdulSamad's Mujawwad recitation. Al-Fatihah audio is bundled. Other audio is cached locally when first played, and each surah has an explicit offline-download control.
- A verse carrying a supported preferred or necessary waqf mark offers one bookmark action. Merely permissible stops do not qualify. Saving a bookmark replaces the previous one; the next launch begins with the following verse, including across surah boundaries. Browsing and listening never overwrite that saved position. Quran Foundation sajdah metadata produces a clear sajdah notice on the 14 marked verses in the installed IndoPak/Hafs dataset.
- The main lesson view omits persistent instructions and privacy/status cards; only the verse, meanings, direct controls, relevant errors, the optional bookmark, and the optional sajdah notice remain.
- During microphone practice, the active recognized word is kept in view automatically. Reaching the final expected phoneme with sufficient context starts a 900 ms stability debounce; the app then finalizes the verse, advances across verse or surah boundaries, and resumes listening on the next verse.
- Focused word practice is available by holding a word: it shows the word's English meaning, offers normal and slower reference playback, and records repeat attempts through the same on-device Quran-Lab engine.
- Focused practice identifies Al-Fātiḥah words containing canonical shaddah or madd targets. Strong single-vs-doubled shaddah evidence can trigger a cautious practice suggestion. Madd CTC timing is measured but deliberately not graded until tempo-aware ranges are validated from real recitations.
- Finalized scoring detects supported substitutions, insertions, deletions, skipped words, repeated phonemes, and exact repeated words. Feedback comes directly from acoustic recognition and deterministic alignment; no language model corrects or invents results.
- Practice progress is actionable: tapping a weak word or recent attempt opens that exact verse and word in focused practice for listening and another attempt.
- Settings includes a local **Accuracy check** for explicitly saved, labeled test samples. It tracks the minimum careful and controlled-error pilot counts; normal prayer practice remains ephemeral and is never added automatically.
- Quran-Lab Zipformer v3.1 Float8 Core ML inference using the exact 80-bin native Kaldi fbank frontend, cache-aware streaming state, and authoritative `tokens.txt` decoding.
- Canonical Quran-Lab phonemes for the whole Qur’an, deterministic streaming alignment, conservative live word highlighting, and focused practice by holding a word.
- Plain-language learner feedback; raw token IDs, phonemes, confidence, timing, waveform, and alignment remain in hidden Developer Diagnostics.
- Local progress metadata, practice history deletion, mandatory disclaimer, model attribution, and complete local-data reset.
- Optional developer calibration WAV capture is explicit, local, excluded from iCloud backup, and never used during normal practice.
- No fake recognition, Whisper fallback, language-model correction, backend, telemetry, or unsupported tajwīd claims.

## Run and validate

Use Flutter stable 3.47.4 / Dart 3.13.3 or a compatible newer release.

```sh
flutter pub get
flutter analyze
flutter test
flutter build ios --no-codesign
flutter run -d <physical-device-id>
flutter test integration_test/audio_capture_test.dart -d <physical-device-id>
```

The microphone integration test requires a real iPhone and the OS permission prompt. It is not run as a desktop unit test. iOS requires full Xcode, iOS 18+ and signing for physical installation. On this machine, set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` until the global `xcode-select` path is corrected. Build products may need a cache location outside the file-provider-backed Documents folder; see DEVELOPMENT_NOTES. Development signatures are not App Store distribution signatures.

This workspace's Flutter SDK is `/Users/shahzadsarwar/Library/Caches/quran-teacher-flutter`; invoke `bin/flutter` there if Flutter is not in your PATH. Android SDK: `/opt/homebrew/share/android-commandlinetools`. Java: `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`. No shell profiles were changed.

## Model and next gates

Read [MODEL_INTEGRATION.md](MODEL_INTEGRATION.md) before inference work. Authorized Quran-Lab v3.1 development assets are present under the git-ignored `models/quran_lab/v3_1/` directory. They are pinned to repository revision `506422c82a81c86e7ae74a5a2ab4641724bcd3b3`; locally computed checksums are recorded in [docs/QURAN_LAB_V3_1_SHA256SUMS.txt](docs/QURAN_LAB_V3_1_SHA256SUMS.txt). No fallback is enabled. The ModelManager is currently an interface: production download/import, verification and install progress are **not implemented yet**.

Canonical whole-Qur’an phonemes, confidence aggregation, alignment, conservative findings, word practice, progress persistence, and local AbdulBaset Mujawwad reference playback are implemented. Quran-Lab frequently joins acoustic units across displayed word boundaries; the app preserves the exact full-ayah sequence and explicitly marks estimated per-word spans in its data. Letter-level spans and validated tajwīd grading are not implemented. Red/error-authority feedback remains disabled.

For build results and exact blockers see [DEVELOPMENT_NOTES.md](DEVELOPMENT_NOTES.md). For device checks see [docs/DEVICE_VALIDATION.md](docs/DEVICE_VALIDATION.md).

## Privacy and attribution

No backend, telemetry, or recording uploader exists. Normal-practice PCM remains ephemeral. Practice metadata, settings, and explicitly saved developer calibration files stay locally on the iPhone and can be deleted in the app. Speech recognition is powered by Quran-Lab Zipformer under NPL-1.2; the current repository license is bundled with the local iOS development build.

Automatic tajwīd and pronunciation feedback can be wrong and does not replace a qualified Qur’an teacher.

Canonical Uthmani text and Quran.com IndoPak display text are stored separately for all 6,236 ayahs. The generated snapshot records whether each visible-word boundary maps exactly to Quran-Lab's canonical acoustic units; the complete ayah phoneme sequence is never altered.
