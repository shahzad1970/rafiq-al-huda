# Offline Qur’an & Hadith assistant — experimental prototype

## What is implemented

- Dashboard → Ask Qur’an & Hadith; contextual Ask icons in the Qur’an and hadith
  readers. Contextual questions use that single passage, not unrestricted search.
- Native, real Qwen3.5-4B Q4_K_M inference through llama.cpp/Metal. No server,
  cloud fallback, API key, microphone access or changes to Quran-Lab recognition.
- Optional 2,740,937,888-byte model download with explicit confirmation, byte
  progress, free-space check, cancellation, SHA-256 verification and pinned
  revision. Models are outside backups. Verification also runs before inference.
- General questions search a generated local BM25-style lexical index covering
  all 6,236 canonical verses and 36,097 records with published English. The eleven
  AI-translated entries and entries lacking English are excluded from AI evidence.
- Search recognizes `2:255`, `٢:٢٥٥`, `Al-Baqarah verse 5`, `surah 2 verse 255`, `Bukhari hadith #1`, etc. Source numbering
  follows the bundled edition, not presumed Sunnah.com numbering. General search
  is lexical with curated related-topic expansion (e.g. salah/prayer, sabr/patience),
  not semantic embeddings. Unrecognized paraphrases and Arabic morphology can miss.
  All / Qur’an / Hadith filters constrain both exact references and topic search.
- The top four distinct English passages are supplied. Context prompts use at
  most 1,000 English characters (1,800 for a single passage), 400 publisher-note
  characters (1,200 for a single passage), and 220 Arabic characters per passage, explicitly
  marked when excerpted. Tapping a source displays the full bundled passage and
  source/grade metadata. The model does not generate the displayed source text.
  English excerpts select an unchanged contiguous window around query terms;
  truncation markers disclose omitted context. Completed answers scroll into view
  and show elapsed search-plus-answer time measured on the running device.
- Every answer must parse as short JSON claims with nonempty, in-range citation
  IDs. Invalid/truncated output is withheld; an empty list is an abstention.
  This validates identity/structure only, NOT semantic entailment. A valid cited
  claim can still be wrong. The UI states that clearly.
- No chat history is written to disk. Each question is independent. Clear removes
  the visible question; leaving stops work. The native model, context and backend
  are freed after each question. Backgrounding/memory warnings cancel inference.
- 4,096-token native context; prompt cap 3,196 tokens; output cap 850 tokens.
  Input is capped to 600 characters in Flutter. Excess context fails visibly.
- Delete AI model in module options, and removal through Delete all local data.
  Download cancellation currently restarts the file on retry, not byte-resume.

## Provenance and integration

Qur’an English: **Rowwad Translation Center**, QuranEnc.com, **v1.0.19**.
All 6,236 original API rows, Arabic source text and publisher footnotes are retained
unchanged in `assets/data/ask_translation.json`. AI display Arabic still uses the
existing canonical repository; no recognition data or word-by-word reader is changed.
The source reader exposes the complete translation, complete publisher notes,
publisher/version attribution and source URL. Notes are explicitly commentary,
not Qur’anic text or generated output; they are not a complete classical tafsir.

Source: https://quranenc.com/en/browse/english_rwwad
Terms: https://quranenc.com/en/home (Terms of Use), bundled in
`assets/licenses/quranenc.txt` and registered in app licenses.
The terms require unchanged content, source/publisher and version attribution,
retention of transcript information, notification of translation issues, current
editions and no inappropriate advertisements. Import captures full catalog metadata
and SHA-256 of all 114 chapter responses; rechecks the edition after download.
Run `node tool/import_ask_translation.mjs` then rebuild the index before distributing
a refreshed edition. Core operation stays offline; no questions are sent to QuranEnc.

Base model: https://huggingface.co/Qwen/Qwen3.5-4B (Apache 2.0).
Conversion: https://huggingface.co/unsloth/Qwen3.5-4B-GGUF
Revision: `e87f176479d0855a907a41277aca2f8ee7a09523`.
File: `Qwen3.5-4B-Q4_K_M.gguf`.
SHA-256: `00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4`.

Runtime: https://github.com/ggml-org/llama.cpp/releases/tag/b11065 (MIT), official
Apple XCFramework; its SHA-256 is pinned in `tool/prepare_ask_runtime.mjs`.
The binary is fetched separately, not the huge model bundled into Runner.
The official Qwen3.5 text chat template is used with thinking disabled, special
role-token delimiters escaped in user/source input, and deterministic greedy
sampling. This is not an instruction-injection guarantee.

MLX 2.31.3 was considered but requires swift-transformers 1.2.x, conflicting with
the existing WhisperKit 0.9.4 exact 0.1.8 dependency. llama.cpp avoids changing the
working translator. SwiftPM remote binary downloading hung on this development
Mac; verified curl download into a local binary target compiled successfully.

Licenses are bundled and registered in the Flutter license screen. The model's
license does not grant new rights to the existing Qur’an/hadith translations;
existing local-only/distribution restrictions remain in force.

## Build and evaluation

1. `node tool/prepare_ask_runtime.mjs` (one-time pinned runtime download).
2. `node tool/import_ask_translation.mjs` to refresh the authorized translation;
   `node tool/build_ask_index.mjs` after any source dataset changes.
3. `flutter analyze` and `flutter test`.
4. Build signed iOS using the existing external-cache build-directory procedure.
5. For real-model smoke tests:
   - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path ios/LocalQwen`
   - `node tool/prepare_ask_probe.mjs`
   - `node tool/run_ask_smoke.mjs /absolute/path/to/Qwen3.5-4B-Q4_K_M.gguf`

The model must be separately downloaded and checksum-verified. A developer copy
on this Mac is in `~/Library/Caches/quran-teacher-ask/`; it is not an app asset.
`docs/ask-model-smoke.json` records measured runs with the real model, machine,
fixture hashes and generated answers. Tests use the same native inference actor
as iOS, but a Mac run is NOT an iPhone performance or integration measurement.
Flutter bridge doubles test UI behavior only and are never production fallbacks.
`docs/screenshots/ask-*.png` are iPhone-sized Flutter layout captures replaying the
recorded native answers, not phone screenshots. Their elapsed-time label reflects
the instantaneous test bridge (0.0 s), not model performance; use the smoke report
for measured Mac timings and collect separate physical-iPhone measurements.

## Known limitations / next gate

- Experimental reading assistance, not tafsir scholarship, authentication or
  personal fatwas. No claim of reliable madhhab comparison or complete evidence.
- Full English verse translation and publisher notes are installed, but no separate
  classical English tafsir is bundled. `english_mokhtasar` still returned API data
  during review but was absent from the current catalog and its public reading page
  returned 404. Do not install this unversioned/stale source without verification.
- A retrieved excerpt can omit context. Short passages and explicit references
  are the best initial use. Add reviewed tafsir/translation sources only with
  provenance and reuse permission, never invent missing scholarship.
- Four real smoke cases are a starting check, not a broad quality benchmark.
  More representative Arabic/English and adversarial tests need human review.
- Phone is currently unavailable. Physical offline download, airplane-mode
  answering, backgrounding, memory/thermal behavior and repeated cancellation
  still require device testing. Initial Metal startup may be noticeably slower.
- Before TestFlight, update/review required-reason privacy declarations for file
  timestamps/storage-space APIs and all existing content permissions.
- Nothing has been published or uploaded.
