# Development notes — 2026-09-16

## Phase status

The personal/local app is now iPhone-only by user direction. Phases 1–7 have an iOS implementation: real microphone capture, the exact native Kaldi frontend, cache-aware Quran-Lab v3.1 Core ML inference, authoritative CTC decoding, canonical whole-Qur’an phoneme alignment, conservative live word feedback, deterministic finalized findings, isolated word practice, and local progress metadata. Tajwid grading remains disabled. No fallback speech model was implemented.

## Tooling and verification

- 2026-09-23: Renamed the visible iOS app and in-app identity to Rafiq Al-Huda
  (رفيق الهدى, “Companion of Guidance”). The bundle identifier and Dart package
  name remain unchanged to preserve signing and internal imports. Replaced the
  production iOS icon with an opaque emerald, ivory, and gold book-and-guiding-
  star mark generated for the new identity.

- 2026-09-23: Removed Arabic Translator dashboard entry, Flutter screen,
  native service, translator-only tests and manifest, and WhisperKit package
  dependency. Qur’an recognition and existing English translations are unchanged.
  Removed source files are recoverable in the local Caches/removed-arabic-translator
  backup. Existing on-device translator downloads are not deleted by this change.
  App rename awaits user choice; current display name remains Quran Teacher AI.

- 2026-09-23: Unmarked verse bookmark buttons now use the red error palette,
  including their saved state, with “Not good stopping point” and a verse
  countdown/target reference. Progress spans the previous marked stop (or
  surah start) to the next marked stop, falling back to surah end. All surah
  endings remain accepted. Guidance uses existing metadata, not a new ruling.
  Bookmark behavior and recognition are unchanged.

- 2026-09-22: Bookmark button now appears after every numbered Quran verse.
  Unmarked verses have a non-blocking note encouraging a marked stopping point
  or surah end. Every surah's final verse suppresses that note regardless of
  waqf metadata. Synthetic introductory basmalah (verse 0) is not a numbered
  verse and remains excluded. Single-bookmark/next-verse startup is unchanged.

- 2026-09-21: Replaced the flat Prayer Teacher dropdown with five tappable
  daily prayer cards. Each opens an ordered overview of before-sunnah/optional,
  fard, after-sunnah, and Isha Witr as applicable. Tap an individual part or
  Start full prayer; completing each part advances to the next separate prayer
  with a fresh intention/opening rather than merging rakahs. Dhuhr and Witr
  alternatives remain mutually exclusive choices. Back returns to the daily
  overview, then prayer list. Fard/sunnah/wajib labels remain distinct.

- 2026-09-21: Prayer Teacher now offers 14 fully expanded daily fard, sunnah,
  optional and Witr learning paths. Every rakah contains its own recitations,
  numbered ruku and two numbered sujud; middle/final sittings are separate.
  Later fard units omit the example short surah. Hanafi 3-unit Witr and 2+1
  Witr are explicitly separate paths; this is not a full four-school manual.
  Basic Hanafi Qunut uses Qur’an 2:201 as a learner supplication (not a claim
  that it is the customary full wording). Fajr school Qunut differences are
  notes, not fully expanded alternate paths. Sources: Bukhari 776/990,
  Tirmidhi 415; SeekersGuidance Hanafi Witr guidance.
  Missing recordings now use labelled on-device AVSpeechSynthesizer Arabic;
  strongest installed Arabic voice preferred. No voice imitation, network
  speech request, recognition or grading change. TTS pronunciation still
  requires listening review and is not tajwid recitation.

- 2026-09-21: All Arabic Prayer Teacher/wudu steps now offer recorded audio.
  Existing verse audio retained; non-Qur’an human clips bundled offline.
  Four lesson tests pass, including playback payload and stop-on-next behavior;
  analyzer clean; every MP3 decodes successfully. No speech synthesis/model
  changes. Sources and provisional edit boundaries in docs/PRAYER_AUDIO.md.
  Next task: human listening/teacher review of all phrase audio, especially
  the Amin and split tashahhud cuts; redistribution rights not cleared.

- 2026-09-21: Removed Sources panels from every prayer/wudu lesson step
  at user request. References remain in lesson data for provenance/review.
  Prayer Teacher tests pass (3 tests).

- 2026-09-21: Added an 11-step wudu lesson under Prayer Teacher with eight
  locally bundled washing illustrations, opening/closing remembrance and
  source links. Kept illustration height at the original 250 pixels after
  the user withdrew the enlargement request. No microphone or model changes.
  Sources: Qur’an 5:6; Bukhari 159/185; Abu Dawud 101/135; Muslim 234a.
  Limited school notes, not a complete purity manual; teacher review remains
  needed. Image-generation prompts: docs/WUDU_ILLUSTRATIONS.md.

- 2026-09-21: Replaced Prayer Teacher line diagrams with six locally bundled
  imagegen illustrations: standing, opening takbir, reciting, bowing, sitting,
  prostration. Latest requested character is fair-skinned with blond hair/beard.
  Full figures use contain-fit at 250 logical pixels; decode height capped at
  750. School variation notes remain; these are example postures, not an
  exhaustive depiction of every school. Prompt provenance is documented in
  docs/PRAYER_ILLUSTRATION_PROMPTS.md. Original generations retained separately.

- 2026-09-21: Added dashboard Prayer Teacher, first two-rakah voluntary-prayer
  lesson (alone). One step at a time, both rakahs, native posture schematics,
  Arabic/English, Quran playback and selected school-difference notes. Sources
  and limitations: docs/PRAYER_TEACHER.md. No recognition/scoring is added.
  Audio stops on navigation/background/exit; disposed reference players ignore
  late notifications. 23 lesson/reader tests pass; remaining work includes
  full school-specific paths, wudu/Witr/daily prayers, non-Quran recordings and
  qualified teacher review. Do not claim a complete prayer curriculum.

- 2026-09-21: Removed the redundant compass start/stop button. Auto-start on
  opening, pause on background, resume and back/dispose cleanup are unchanged.
  Retry remains available for unreliable readings. Lifecycle test also asserts
  that neither manual start nor stop is shown.

- 2026-09-21: Removed the source paragraph and raw edition URLs below Hadith
  Ask AI. Attribution and edition links remain available through the header
  Source details info button. Translation warnings and answer citations remain.
  Reader regression checks that details are hidden until explicitly opened.

- 2026-09-21: Quran inline Ask now loads topic-matched starter questions from
  the published translation, not word glosses or publisher commentary. Maximum
  two topic prompts plus a simple-English explanation; neutral fallback if no
  topic matches or translation cannot load. Suggestions are deterministic local
  templates, not generated claims. All 6,236 verses covered by compactness tests;
  2:27 covenant/bonds and 1:6 guidance checked; inline tap submission tested.
  19 Ask/question tests pass. Answer generation and citation checks unchanged.

- 2026-09-21: Removed reader Reported grading block (underlying source grading
  metadata retained). Hadith Ask now expands inline below English, keyed by
  record so navigation resets the answer. Two content-matched topic questions
  at most plus a plain-English explanation starter; neutral fallback for
  unmatched subjects. These are local deterministic suggestions, not model
  claims. AI-only translations remain excluded as answer evidence. 25 Ask,
  Hadith and question tests pass, including inline reader and intentions prompt;
  analyzer clean. No model, recognition or source-validation changes.

- 2026-09-21: Fixed incomplete Ask JSON with llama.cpp grammar-constrained
  sampling before greedy selection. This constrains structure only, does not
  repair text or fabricate citations; Dart source-ID validation remains intact.
  Format failures and invalid citations now have separate messages. Both real
  2:27 starter regressions pass (Mac: 7.61/7.13 s), all four existing real-model
  smoke cases pass, and 14 Ask tests pass. Syntax/source checks are not semantic
  or religious-authority validation. Physical-phone reproduction still pending.

- 2026-09-20: Reproduced both inline 2:27 starter failures using the production
  Qwen3.5-4B runtime on the Mac and exact app retrieval/prompt/parser. Both real
  outputs ended with `]` instead of `]}`: missing the outer JSON closing brace.
  Their source IDs were valid (1), but JSON parsing failed before citation checks.
  Times: 7.34 s and 5.19 s (Mac, not iPhone measurements). Added opt-in
  `test/ask_227_inference_test.dart` via ASK_TEST_MODEL; both cases currently fail
  as expected, ordinary tests skip them. No production behavior changed. Next:
  constrain generated JSON syntax and distinguish format from citation errors,
  preserving source-ID validation. No inference about semantic correctness.

- 2026-09-20: Quran Ask AI now expands inline below the current verse instead of
  navigating from a header shortcut. Starter questions and cited answers stay in
  that section. Verse changes reset its state; asking stops recitation capture
  and playback before inference. Standalone dashboard Ask remains available.
  34 Ask/reader widget tests pass, plus the updated inline Ask regression (13
  Ask tests). Physical inline layout inspection remains pending.

- 2026-09-20: Ask UI compacted at user request. Ask button is inline with a
  one-line expanding question field; tappable starter questions submit in-place
  and adapt to selected-passage/Hadith/Quran scope. Removed repeated explanatory
  copy and answer timing from the main view; retained concise accuracy warning,
  source access and full About disclaimer. 13 Ask tests pass (including starter
  submission), analyzer clean. No model/prompt/scoring changes.

- 2026-09-20: Ask input made prominent: persistent “Ask a question” heading,
  three-line filled outlined field, 19px input, example prompt, 54px Ask button;
  disclaimer retained below the form. 13 Ask tests pass and analyzer clean.
  Release installed on connected iPhone. Explicit --diagnose-ask-answer tested
  real installed Qwen3.5-4B through production verification/inference using fixed
  public Quran 112:1 translation evidence (no user question logging). Actual
  output: {"claims":[{"text":"The verse states that Allah is the One.","sources":[1]}]}.
  Native model load/generation 2.126 seconds, excluding prior hash verification.
  Source ID/statement valid for this fixture. This was a native engine test plus
  separate Flutter widget tests, not a physical UI end-to-end or airplane-mode
  test. No remote inference path used. Relaunched normally after diagnostic.

- 2026-09-20: Fixed Ask verification allocation lifetime with a per-1-MiB
  autoreleasepool around FileHandle reads/hash updates. Completed HTTP transfers
  now stay as completed.download until SHA verification succeeds; cancellation
  retains them for the next attempt, while failed validation removes invalid
  pending data. No unverified file is marked installed or used for inference.
  Interrupted network transfers still restart (not background/resumable transport).
  Release build installed on physical iPhone; repeated real 2,740,937,888-byte
  download logged HTTP 200, verified_model_ready, result=success, with no observed
  memory-warning cancellation. 13 Ask tests pass. Diagnostic used the production
  native downloader from a fresh launch. Cancellation recovery code reviewed but
  forced-interruption device test and quantitative memory profiling remain pending.

- 2026-09-20: Reproduced Ask download cancellation on connected iPhone using
  explicit --diagnose-ask-download launch flag and the unchanged production
  downloader. Available storage 90,980,343,016 bytes. Download reached
  2,740,937,888 bytes (100%), HTTP 200, no transfer error; immediately afterwards
  logged cancel_reason=ios_memory_warning and result=cancelled. No verified-ready
  event. This confirms a memory-warning-triggered cancellation after transfer,
  during installation/verification, not a network failure in this run. Fresh launch
  invoked native download directly (not the Flutter download-screen interaction).
  Added progress, error codes and distinct cancellation reasons only; no audio or
  question logging. Release build installed. Next: investigate checksum-loop
  allocation lifetime/autorelease handling and make verification memory-bounded;
  preserve completed transfers for retry. Root allocation cause not yet proven.

- 2026-09-20: Qibla compass now has its own dashboard entry and a labeled shortcut
  in Prayer Times. Opening the screen automatically subscribes to the real native
  sensors; no prayer setup is required. With no saved location, no bearing is
  fabricated while GPS is pending. Route-pop callback and disposal cancel the
  stream/timer; background pause stops sensors and resume restarts only if requested.
  Added auto-start, setup-free entry, pause/resume and Back cancellation coverage.
  Native permission and true-heading/accuracy gating are unchanged.

- 2026-09-20: Tested pinned/checksummed Qwen3.5-2B Q4_K_M (1.28 GB) locally with
  source-separated 15-case suite. Corrected evidenceQuote example and reran,
  preserving both reports. Five basic passes; material failures include invented
  revelation year 112 and attribution to missing commentary. Other failures
  include strict quote formatting and abstention contract, not all hallucinations.
  Mac 0.79–3.38 s, peak ~1.51 GB RSS; no phone test/integration. Production model
  remains unchanged. See docs/QWEN35_2B_EVALUATION.md. Next: decide larger optional
  model versus source-only search; expanded evaluation also needed for current 4B.

- 2026-09-20: Apple probe v2 separates optional publisher commentary into distinct
  source IDs/kinds and derives source labels from metadata; ordinary prompts omit
  notes. Added exact evidence-quote validation and expanded to 15 device cases.
  Five basic passes, two failures, eight default guardrail errors. Missing-notes
  answer falsely attributed text to absent commentary; multi-source output altered
  quotes. Not ready for integration. Main app unchanged; logs and limitations in
  docs/apple-ask-separated-results.txt and docs/APPLE_ASK_EVALUATION.md. Next:
  discuss Qwen3.5-2B trial with expanded checks; do not weaken safety validators.

- 2026-09-20: Apple FoundationModels on-device probe compiled and ran on connected
  iPhone 17 Pro Max, iOS 27.0 (24A435). Model available; 9/10 cases returned
  structured results with expected basic citation-ID/abstention behavior, taking
  0.53–2.41 seconds. Publisher-attribution question blocked by default guardrails;
  several other answers lacked publisher-note attribution on manual review. Not
  a full quality pass. Production app unchanged. See docs/APPLE_ASK_EVALUATION.md
  and real device log. Next: source/commentary separation and broader evaluation
  before app integration; unavailable/cancellation/offline tests pending.

- 2026-09-20: Tested official Qwen2.5-1.5B Q4_K_M (1.12 GB, pinned revision and
  SHA verified) using the existing native runtime and correct non-thinking
  ChatML. On M3 Pro, four cases took 0.76–1.97 seconds with ~1.36 GB peak RSS.
  Two basic structure checks passed; abstention contract and adversarial
  invented-hadith tests failed. No iPhone integration or default-model change.
  See docs/QWEN25_EVALUATION.md and docs/ask-qwen25-smoke.json. Added an explicit
  opt-in probe flag; production keeps its existing Qwen3.5 prompt unchanged.

- 2026-09-20: Evaluated the user-requested Alif Islamic v4 Base on the physical
  iPhone in an isolated signed Swift test app. Verified the 946,786,704-byte file
  against its pinned SHA256. MediaPipe 0.10.35 Metal failed model preparation at
  both 1024 and 4096 context sizes; CPU runs with explicit Qwen ChatML. Simple
  response took 2.46 seconds including load, but all four existing source-grounded
  Ask fixtures failed structure/citation or abstention checks (3.28–7.39 seconds
  generation). Did not integrate or weaken validators. Main app and Quran-Lab
  recognition unchanged. See docs/ALIF_EVALUATION.md and saved real device output.
  Next proposed task: test official 1.5B GGUF only if user chooses to proceed.

- 2026-09-20: Prayer/Qibla visual cleanup: larger next-prayer time on a theme-aware
  accent card, compact daily rows and location line, quiet calculation-method link.
  Long provenance/timezone/iqamah explanations moved to an info dialog. Qibla uses
  a lighter concentric dial, prominent bearing and concise alignment/accuracy text;
  detailed calibration/privacy guidance is in the header help sheet. Important
  unavailable/estimated/permission/stale-reading warnings remain. No calculation,
  sensor gating or persistence changes. All 115 tests pass; light/dark prayer and
  injected-sensor compass screenshots regenerated and visually inspected.

- 2026-09-20: Added opt-in Qibla Compass in Prayer Times header. Native iOS
  CLLocationManager supplies true-north heading and current location; no magnetic
  fallback, fake readings, network geocoding or saved compass history. Live location
  is independent of the saved prayer city. Great-circle Kaaba bearing, circular
  smoothing, orientation handling, accuracy/staleness gates and calibration guidance.
  Stops sensors on back/stop/background. Near-target/undefined bearings suppressed.
  Qibla unit/widget tests pass; physical compass accuracy/calibration/orientation
  still require the phone. See docs/PRAYER_TIMES.md for thresholds and device checklist.
  Full suite: 115 tests pass. Analyzer clean. iPhone-size compass layout visually
  reviewed with a clearly documented injected sensor fixture, not real-device data.
  Signed iOS release build succeeds (218.3 MB); temporary build-directory setting
  restored. No upload or phone installation in this turn. Next: physical compass QA.

- 2026-09-20: Added Prayer Times dashboard module using an offline Dart adaptation
  of the official MAWAQIT/prayer-times repository, pinned at
  640157265aaa4e71e33b8aa718f36f35fb99eb92. LGPL/GPL license texts, attribution,
  source PHP and documented modifications retained. 22 method presets, Standard/
  Hanafi Asr, high-latitude rules, adjustments, saved location/timezone, daily
  navigation and next-prayer countdown. Optional one-shot iOS location; optional
  Apple city search; offline cities/manual setup. No Mawaqit account/server,
  scraping, background tracking, mosque iqamah claims or adhan notifications.
  Deterministic Asr corrects upstream's wall-clock dependency; impossible polar
  events stay unavailable rather than being clamped into plausible times.
  Date-specific IANA offsets, adjacent-day events and DST retained. Full timezone
  dataset includes Apple-returned aliases such as Europe/Stockholm.
  Analyzer clean; all 111 Flutter tests pass (plus visual screenshot test).
  Signed iOS release build succeeds (218.2 MB); build-directory override cleared.
  Not installed on the phone or uploaded; native location flow still needs device QA.
  Calculator matches 1,056 real PHP reference cases with the explicit Asr fix.
  Light/dark iPhone-sized calculation renders inspected, not physical screenshots.
  See docs/PRAYER_TIMES.md for scope, source/license review and physical test gaps.
  Next: compare chosen method with user's local mosque and verify iPhone permission,
  city search/current location, offline restart and travel/timezone settings.

- 2026-09-20, Ask improvements: imported all 6,236 unchanged Rowwad English
  translations and publisher notes from QuranEnc, edition 1.0.19, with API metadata,
  per-chapter response hashes, terms and attribution. Rebuilt version-2 search index.
  Added Qur’an/Hadith filters, named-surah and Arabic-digit references, topic synonym
  expansion, relevant contiguous excerpts, complete source notes, local answer timing
  and answer auto-scroll. No recognition or microphone behavior changed.
  Separate English tafsir deferred: candidate Mokhtasar edition is missing from the
  current catalog and reading page is 404, despite an API response. No tafsir claim.
  Native Swift build and real-model Mac smoke checks pass: supported verse 3.11 s,
  hadith 2.39 s, unsupported/injection abstentions 1.42 s each. Not iPhone measurements.
  Verification: analyzer clean; all 102 Flutter tests pass, plus opt-in iPhone-sized
  screenshot replay test. Source sheet visually inspected. Signed release iOS build
  succeeds; temporary external build-directory override cleared. Screenshots replay
  actual recorded answers; their 0.0 s bridge timing is not a performance result.
  Next gate remains physical offline, cancellation, memory/thermal tests and broader
  human review of answer support; no on-phone install or upload performed here.

- 2026-09-20: Added experimental Ask Qur’an & Hadith module and contextual Ask
  buttons. Real Qwen3.5-4B Q4_K_M / llama.cpp b11065 Metal inference is entirely
  local, independent of recognition and translation. Opt-in 2.74 GB pinned,
  SHA-256-verified download; progress, stop, model deletion, no saved chat history;
  native model/context released after each answer. General lexical retrieval
  covers 6,236 verses and 36,097 published-English hadith records; generated
  translations never become AI evidence. Excerpts and word-by-word gloss limits
  are disclosed. JSON citation-identity checks withhold malformed/unreferenced
  responses but do not establish factual or religious correctness.
  MLX's tokenizer dependency conflicted with WhisperKit, so the native runtime
  uses a verified official llama.cpp XCFramework without changing WhisperKit.
  Analyzer clean; all 99 Flutter tests pass. Signed release device build succeeds
  (~214 MB, model downloaded separately). Real-model Mac smoke tests pass for a
  verse, intentions narration, unsupported question and reference-invention
  attack: 4.33 / 2.40 / 1.29 / 1.28 seconds on M3 Pro, maximum process RSS in those
  runs 2.13–3.09 GB. Earlier cold runs took 22–27 seconds. These are not iPhone
  measurements or scholarly validation. Report: docs/ask-model-smoke.json;
  integration/limitations: docs/ASK_AI.md. Phone unavailable, so not installed.
  Next: physical download + airplane-mode answers, background/cancel/delete,
  memory/thermal checks and broader human-reviewed grounding evaluation.

- At the owner's explicit request, added offline AI English for the 11 Arabic-only
  Muwatta Malik entries. Source English/Arabic and grades are unchanged. Separate
  fields plus visible list/reader/copy labels distinguish AI from published text;
  not scholar-reviewed. Import uses exact Arabic hashes and refuses source-English
  replacement, absent Arabic or stale IDs. The 404 source blanks remain blank.
  No runtime LLM service, microphone upload or Quran engine change.
  Analyzer clean; 89 tests pass, including all-corpus fallback coverage, published
  translation precedence, absent-Arabic guard, search and visible AI notice. These
  are implementation checks, not scholarly validation of translation accuracy.

- Hadith module added: all ten collections from pinned Hadith API Arabic/English
  editions, with 36,512 source records (36,108 containing text), offline book
  browsing, source-number lookup, in-book Arabic/English search, reader previous/
  next and copy. Missing text and grading are explicit, never fabricated. Source
  identities match across languages; named graders remain attributed. Book JSON
  loads lazily off-isolate with a two-book cache. Data import provenance, hashes,
  collection counts, source gaps and distribution limits: docs/HADITH_LIBRARY.md.
  All 87 Flutter tests pass. Actual-widget iPhone library/reader screenshots were
  inspected; Latin punctuation is rendered with a system font to avoid missing
  glyph boxes in the Quran face, while preserving every source character.

- Duʿā expansion: 91 entries across 15 categories (32 Qur'anic excerpts and 59
  unique texts imported from pinned MIT Fitrahive Dua & Dhikr). Search includes
  alternate titles and category context; shared texts preserve cross-category
  membership and one favourite ID. View-all action, dynamic counts and explicit
  source attribution added. Unreferenced/unclear imports and unverified counts/
  benefit claims omitted. No recognition, translator, or Quran changes; no audio
  feature or exhaustive/authenticity claim. TestFlight work paused at owner request.
  All 82 Flutter tests pass and analyzer is clean. Actual-widget 390×844 screenshots
  regenerated; library screen visually inspected. Imported-text/detail, cross-category
  membership, search, source spans, long-list scrolling and persistent favourites
  have automated coverage. No new religious-authenticity or acoustic validation claimed.

- 2026-09-20: owner authorized private internal TestFlight preparation only. Added a local-export plist with Apple's internal-only restriction and a release checklist in docs/TESTFLIGHT.md. Apple sign-in, distribution signing, content/storage permissions and archive validation remain release gates. No public release or external testers authorized; no upload claimed.

- Dua module replaces the dashboard placeholder with six categories, ten sourced Qur'anic entries, normalized Arabic/English search, saved favourites, and an IndoPak Arabic/English reading view with verse/excerpt references and copy action. Favourites persist locally and are removed by Delete All Local Data. No Dua speech assessment or audio feature is implied. Source spans/meanings documented in docs/DUA_CONTENT.md. Added category/search/persistence/detail tests and actual-widget iPhone-size screenshots; library and reading images visually inspected.

- Feedback spacing/detail checks: 78 Flutter tests pass and analysis is clean. Phone-size UI regression verifies the extra bottom padding and scrolling to the retry action; retained-prefix findings are compared as structured data. Run Flutter analysis/tests before (not concurrently with) the iOS build: their dependency generation can invalidate Xcode's generated Flutter package references.

- Feedback readability: verse scrolling now reserves bottom space for the feedback panel (including safe area), with extra resting padding even when closed. The taller, independently scrollable panel uses 18px/1.45-line-height explanations. Deterministic substitution explanations identify expected sound, heard sound and a next action; missing/extra/repeated sounds have tailored uncertain wording. Earlier detected errors/tajwid findings now survive an inline restart from a later word, matching preserved prefix underlines; rerecording that earlier section clears its old details. Regression tests verify retained details and phone-size scroll access to feedback/retry. No invented sound-level diagnosis when evidence is absent.

- Double-tap word feedback: single tap still listens from the word; double tap instead stops capture, plays the canonical word/linked phrase reference and opens an inline bottom explanation. Explanations come only from deterministic pronunciation/shaddah findings; absent evidence is explicitly not a correctness verdict. Listen from here closes the explanation and restarts inline. Native Flutter gesture disambiguation prevents the double tap from first starting capture. Manual navigation, new listening and verse Play clear the panel. Added a UI regression for double tap, stopped capture, audio selection, detected substitution text and inline retry; no new acoustic validation claimed.

- Inline restart supersedes the separate retry-screen flow: tapping any verse word or Retry wrong part stops/restarts listening on the same verse, aligning the canonical suffix beginning at that word's pronunciation-group boundary. Prefix feedback is retained without inventing recognized prefix tokens; subsequent words are reassessed and normal next-verse logic resumes at the suffix end, still blocked by unresolved warnings. Tap no longer plays a word; long-press still opens optional word practice/reference playback, and Play remains whole-verse audio. Tests cover inline tap/start without navigation, preserved prefix feedback, suffix scoring and clean transition to the next verse. 76 Flutter tests pass; physical recitation verification remains outstanding.

- Focused-repair verification: all 74 Flutter tests pass and signed iOS release builds. The practice-route pop regression also uncovered and fixed a null practice index during the outgoing screen animation. Real microphone testing remains necessary; no new recognition accuracy or latency measurements were made.

- Focused correction: the verse's Retry wrong part action (also tapping an underlined word) stops capture and opens practice for only the selected canonical word/phrase. Returning restores the original verse transcript and all unrelated feedback. A finalized accepted practice attempt marks only its mapped group as corrected; cancellation, missing/uncertain evidence and failed attempts do not clear the warning. Separate ephemeral repair evidence is retained without replacing original recognized tokens. New verse/new full recording clears corrections. Normal whole-verse retry remains available during capture. Parent auto-advance is suppressed during focused practice. Tests cover cancellation, successful targeted repair, preserved original evidence/unrelated feedback and UI round-trip. Next: physical microphone verification of correction flow; synthetic test results do not establish acoustic accuracy.

- Tajwid scope update (2026-09-20): conservative shaddah-to-single-consonant suggestions now use canonical pronunciation groups across all 6,236 ayat, including shared-word phrases. Only finalized, high-confidence emissions (confidence >= .90, margin peak >= .60) with valid timestamps can trigger advice. Suggestions appear in the verse UI, underline the affected range, and prevent Listen auto-advance at the completed verse. Phrase/word practice shows the same guidance; Follow is ungraded. Repeated special markers are not classified as consonant gemination. Madd retains diagnostic CTC emission start/end/duration only, explicitly not forced-aligned duration or a length grade. Other tajwid rules remain unimplemented, not silently accepted.
- Validation: 73 Flutter tests pass, including full-corpus range coverage and rejection of provisional/low-confidence/low-margin/deletion-only evidence. These test deterministic logic, NOT acoustic accuracy. Quran-Lab's model card warns of canonical-label bias (especially ikhfaa) and unreliable free-choice madd token lengths: https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3#honest-limitations. No full-tajwid correctness claim is justified. Next task: obtain teacher-reviewed correct/incorrect shaddah samples and forced-aligned madd boundaries before expanding grading; latency not newly measured.

- Whole-verse Play now continuously advances on native successful completion, updates the displayed verse, resets scrolling and starts the next recitation. Surah transitions include the existing opening Bismillah; the final Quran verse stops. Word/phrase clips remain isolated. Stop, manual navigation, microphone actions, dashboard exit and backgrounding cancel the chain; loading audio can be cancelled. Playback errors do not advance. Added native-event playback lifecycle tests and a UI test through Al-Fatihah into Al-Baqarah; 71 Flutter tests pass. Fixed reference-player disposal notifying an already-disposed listener. Physical continuous-playback listening remains a manual check.

- Whole-Quran mapping verification completed: Flutter analysis clean, 65 app tests pass, five Python mapping-builder tests pass, and signed iOS release compilation succeeds (112.4 MB app). Coverage is structurally checked against all canonical verse phoneme strings; these are not measurements of real-world recitation accuracy. Next: test Al-Baqarah 2:27 and joined-phrase retries with real microphone input, then collect cross-surah human-reviewed mistakes before adjusting confidence thresholds.

- Whole-Quran pronunciation coverage: all 6,236 verses now have generated source-provenance pronunciation groups (72,666 single-word groups, 2,317 joined groups of up to four display words). The 4,116 formerly blocked approximate-display verses can now use mapped conservative pronunciation feedback. Quran-Lab canonical token sequences, tokens.txt IDs, native inference, display text and reference audio are unchanged. Source is quran-transcript 0.6.2 pinned at 42b9338896e758c69f7deeb10758891b76ab7177. Sixty-one reference-version differences are projected conservatively: splits require agreement of all minimum-edit alignments, otherwise adjacent words stay joined. Four multi-word display tokens and five orthographic display differences are handled without changing source text. See docs/QURAN_WORD_MAPPING.md and its machine-readable report.
- Joined sounds now underline/review the mapped phrase together and long-press opens phrase practice with the corresponding reference audio span. No isolated-letter fault is inferred at shared boundaries. Existing low-confidence safeguards remain, and Follow is still ungraded. Fixed repeated-word scoring so wording repeated in the canonical verse itself (e.g. 89:21) is not reported as an extra repetition. Corpus coverage, canonical sequence preservation, substitution/low-confidence cases, phrase practice/playback and bad-mapping rejection are tested. Physical acoustic accuracy across all surahs is not yet measured; full tajwīd grading and stopping-variant handling have not been expanded.

- One-tap Quran actions: replaced the header mode menu with separate bottom Follow (hearing icon) and Listen (microphone icon) actions. Each selects its mode and starts capture; the active action becomes Stop, and switching actions stops the prior session before starting the selected mode. Tests verify single-tap dispatch and compact light/dark layouts.
- Listen/pronunciation mode now blocks automatic advancement on supported word-review feedback, including a mismatch in the final word. Capture stays live and a Retry verse action clears the old alignment without resetting native audio/model state. Manual Back/Forward remain available. Follow remains ungraded. Existing exact-word-mapping/confidence safeguards remain; uncertain recognition is not called a mistake. A regression verifies the mistake holds verse 1, Retry keeps listening, and an accepted replacement attempt advances to verse 2. These are deterministic UI tests, not new acoustic accuracy measurements.

- Back/Forward are enabled during normal Quran recording. Manual navigation switches only the expected verse, clears old verse alignment/follow-position evidence and cancels the old auto-advance timer; microphone capture, native streaming caches, capture counters and subscriptions stay live. Calibration sessions remain protected. A widget lifecycle test checks both directions, retained listening/counters and cleared previous-word evidence. Follow mode may subsequently reacquire the verse actually being recited; manual navigation does not disable follow mode.

- Pronunciation presentation: Arabic words with existing `needsReview` feedback now receive an amber text underline in verse and focused-word views, without changing layout or recognition thresholds. Unread/uncertain words and approximate mappings are not underlined. A widget regression verifies a supported synthetic mismatch underlines and an unread word does not; this is not an acoustic accuracy claim. Continuous verse finalization and incomplete word mapping remain unresolved as described in the review.

- Arabic Translator is now text-only at user request. Removed automatic English speech, replay buttons, speech toggle, native speech synthesizer and pending speech queue. Capture uses a recording-only audio session; headphones are optional. Continuous capture and bounded translation are unchanged. Qur'an reference playback is unaffected.

- Live translator release build compiled successfully for physical iOS after the streaming change. The previous translation model download is reused; no new model or speech server is required. Build-directory override was cleared after verification.

- Live Arabic Translator update: continuous AVAudioEngine capture now replaces 20-second disk recording. Energy-based phrases submit after a 460 ms pause or six-second cap, with 200 ms pre-roll. Translation and headphone-only English playback run alongside capture; microphone/phrase/inference and speech queues are explicitly bounded. Overload stops capture with a message; excess queued speech is replaced with a notice, never hidden. Stop remains available during inference. Analysis is clean, 52 Flutter tests pass, and production Swift buffering/segmentation tests pass. Physical translation latency, quality, route handling, thermal and RAM measurements are still pending. Quran-Lab and Quran follow mode are unchanged. Next: physical continuous speech/headphone test; tune only after measuring the displayed processing times. See ARABIC_TRANSLATOR.md for caps and limitations.

- Arabic Translator is a separate dashboard module using pinned WhisperKit 0.9.4 and multilingual Whisper Small Core ML speech-to-English translation, never a replacement for Quran-Lab recitation recognition. It has hash-verified approximately 490 MB downloads, local tokenizer loading, 20-second ephemeral PCM recordings, English iOS speech playback through the selected output, Bluetooth microphone eligibility, cancellation, bounded in-memory translations and model deletion. Native audio-session ownership prevents idle translator cleanup from deactivating Qur'an audio. Flutter analysis is clean and all 51 tests pass, including model-availability and no-auto-capture UI tests. Release compilation succeeded; actual Arabic translation quality, offline inference, latency, and headphone routing remain unmeasured. See ARABIC_TRANSLATOR.md. Next: physical model download and known-phrase testing, including airplane mode and headphones. Continuous simultaneous translation is not implemented.

- The physical-phone 2:72 screenshot exposed a trailing waqf jeem hanging off the final word. The presentation now removes only a terminal U+06DA (allowing trailing bidi/zero-width characters) from that word's rendered text and centers a jeem above the verse circle. Interior waqf marks, canonical text, model phonemes, and circle numbering are unchanged.

- Arabic layout correction: word tiles measure the current IndoPak text at the user's font size/text scale instead of imposing a 150-point width. Arabic remains a single line, scaling down only if an individual word exceeds the whole reading area. Replaced decorative bracket glyphs with a single circular Arabic-number verse ending based on the user's Quran.com screenshot.

- The navigation popup now accepts a typed verse number with a numeric keyboard. It validates the selected surah's range, supports zero for Bismillāh openings, resets on surah change, and selects the existing value on tap. Compact light/dark navigation checks cover invalid input and direct navigation to 2:255.

- Navigation/opening update: 38 tests pass and analysis is clean. Header book icon opens a surah/verse dialog; the old verse-selector row and memorization visibility toggle are removed. Browse/download access remains in the dialog. 112 optional lesson preludes use the exact 1:1 words, model phonemes, timing, and bundled audio as app verse zero; canonical surah counts and 6,236 verses remain unchanged. Surahs 1 and 9 have no added prelude. Previous/next, microphone advancement and cross-surah bookmark resume include the opening. Playback events now scroll the active word into view; a long-verse widget test verifies the final highlighted word remains above the bottom controls.

- Latest UI review: 36 tests pass, including 375-point iPhone navigation and Settings in light/dark mode at 130% text scale. Corrected long surah header overflow, crowded surah rows, bottom-navigation label wrapping, dark-mode practice contrast, status-bar appearance, and compact palette layout. No recognition or scoring changes.

- Installed Flutter stable 3.47.4 / Dart 3.13.3 in the user's Library/Caches, outside the project. Restored local-only instructions in AGENTS.md.
- Refreshed existing Homebrew Java 17 and Android command-line tools; selected the existing Android SDK with its previously accepted license. The first Android attempt used a pre-existing incorrect Flutter SDK path pointing at platform-tools; corrected it.
- Dart analysis: clean after fixes.
- Unit/widget tests: 34 passed, including bookmark-only resume at the following verse and across surah boundaries, saved appearance/palette settings, conservative verse-end detection, a complete 114-surah/6,236-ayah integrity traversal, single-bookmark replacement, waqf action visibility, sajdah notice metadata, PCM format/timing, token parsing/collapse, alignment, confidence gating, conservative isolated-deletion handling, exact repeated-word detection, canonical phoneme mapping, IndoPak display mapping, complete English word data, valid AbdulBaset audio ranges, synchronized playback-position mapping, shaddah evidence, ungraded madd timing, atomic calibration metadata snapshots, actionable local progress, guided accuracy collection, onboarding, and the honest developer screen.
- Xcode 27.0 is installed and its license accepted. The global `xcode-select` path still points to CommandLineTools, so verification explicitly sets `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- iOS debug device build passed without signing. Because the project is under a file-provider-backed Documents folder that attaches signing-incompatible provenance metadata, build output was temporarily redirected to `~/Library/Caches/quran-teacher-ai-build`; the global Flutter build-dir override was removed after verification. iOS minimum target is 18.0.
- The authorized Float8 package compiled to `mlmodelc` in the app, and Swift type-checking/build passed for the native loader. The app bundle contains the compiled model, authoritative tokens, packing manifests, canonical phoneme JSON and license.
- Android debug build: passed (`flutter build apk --debug`); APK at `build/app/outputs/flutter-apk/app-debug.apk`. This compiles the Kotlin microphone bridge but does not validate capture on hardware.
- Physical iPhone microphone capture and Core ML recognition have been exercised successfully by the user. The 107.5 MB whole-Qur’an release build passed signing and installed on the connected iPhone 17 Pro Max. Automatic launch was denied only because the phone was locked; open Quran Teacher AI after unlocking to run the device smoke test.
- Vendored `kaldi-native-fbank` 1.22.3 (`b09e686fe2084732ddd30d1ef80acfc0f13eaf01`) and pinned KissFFT (`febd4caeed32e33ad8b2e0bb5ea77542c40f18ec`). The exact 80-bin Povey configuration is compiled through an Objective-C++ bridge. Its deterministic native parity XCTest passed on the iPhone 17 simulator in 0.005 seconds with 1e-4 feature tolerance.
- The native iOS stream explicitly zeroes all Core ML cache arrays, preserves separate front/back state, gives both functions the pre-update processed length, advances 48 of 61 feature frames, handles final partial input, and collapses CTC output across chunk boundaries using `tokens.txt` blank 250.

## Model inspection

Authorized access was granted to the developer account. The v3.1 iOS Float8 package, Android INT8 ONNX model, token table, packing manifests, canonical phoneme JSON, reference decoding/evaluation scripts and NPL-1.2 license were downloaded to the git-ignored `models/quran_lab/v3_1/` directory. The repository is pinned to revision `506422c82a81c86e7ae74a5a2ab4641724bcd3b3`; local SHA-256 values are recorded in `docs/QURAN_LAB_V3_1_SHA256SUMS.txt`. No access control was bypassed and no credential is stored in the project.

The compiled package metadata was read directly. It confirms v3.1, Float8, `cpuAndNeuralEngine`, 16 kHz, Kaldi Povey fbank, 80 bins, `T=61`, hop 48, blank 250, front/back order, separate packed states, and output `(1, 12, 251)`. The package metadata still says NPL-1.1 while the repository LICENSE at the pinned revision is NPL-1.2. The app ships the repository's current NPL-1.2 text and this discrepancy is recorded rather than hidden.

## Measured latency and recognition results

The compiled v3.1 Float8 package ran on Apple silicon against a local-only 6.478375-second EveryAyah Al-Fatihah 1:1 clip. Thirteen paired calls took 0.213 seconds (harness RTF 0.033) and decoded `بِسمِللَااهِررَحمَاانِررَحِۦۦم`. The canonical file ends with four `ۦ` symbols; the detected stream had two. This is not graded because the model card forbids inferring free-choice madd duration from token repetitions. No student audio has been graded. Physical-iPhone latency, execution placement, memory and microphone recognition remain unmeasured.

The repeatable iPhone pilot report at `recordings/calibration/iphone_pilot/REPORT.md` currently contains nine careful samples. Eight are usable and produced 141/144 correct alignments (2.08% usable-sample error) with 96.28% mean confidence, zero confirmed false warnings, and one low-confidence deletion suggestion. One historical verse-6 WAV had healthy signal but its shared controller metadata was reset before saving, so the corrected report counts it as a 15-phoneme recognition failure. Accuracy audio and recognition metadata are now snapshotted atomically, and the hidden lesson screen cannot auto-advance an accuracy session. No controlled-error samples exist, so thresholds remain unchanged.

## Known limitations

- ModelManager, tajwid and teacher layers remain typed interfaces/placeholders. Deterministic pronunciation findings are implemented; tajwid claims are not.
- Canonical Quran-Lab phoneme sequences are installed for all 6,236 ayahs. The full ayah sequence is exact. Quran-Lab joins acoustic units across visible word boundaries in 4,116 ayahs, so those generated per-word spans are explicitly marked estimated rather than exact. Letter-level mapping remains unavailable.
- The native numerical fbank test passed in the iOS simulator. Physical AVAudioEngine-to-feature parity and microphone routing still require an iPhone.
- Physical iPhone testing exposed a false `capture_interrupted` error: activating the recording session can emit harmless category/route-configuration notifications. The iOS bridge now ignores those notifications and stops only for a genuine interruption, unavailable input, or background transition.
- Phase 6 started: all seven Al-Fatihah ayat now use word-level canonical sequences extracted from Quran-Lab `ordered_quran_phonemes.json` and segmented with the repository `tokens.txt`. Developer diagnostics show a deterministic live alignment preview; it is explicitly not scored as a pronunciation result.
- Live word feedback now uses streaming-prefix alignment so repeated phonemes cannot jump to later unread words. Blue marks the active word, green requires a complete exact token match above a conservative confidence threshold, and yellow is deferred until a word is complete or the utterance ends. Red is intentionally disabled pending real-error calibration.
- Long-pressing a word opens isolated word practice. Each attempt runs the same on-device model against only that word's canonical sequence and shows expected/detected phonemes, conservative status, confidence, and in-memory attempt history. A normal tap plays that word from the bundled AbdulBaset Mujawwad verse recording; no synthetic recitation is used.
- Core ML decoding now follows Quran-Lab's `decode_with_confidence.py` run aggregation: mean probability across each greedy CTC run plus peak-frame margin over the runner-up. Review feedback requires both measures; diagnostics expose peak margin, native chunk processing milliseconds, and real-time factor. Thresholds remain provisional and red feedback stays disabled pending calibration recordings.
- A deterministic `PronunciationScoringEngine` emits serializable structured findings for supported substitutions, insertions, deletions, repeated phonemes, skipped-word suggestions, and exact complete-word repetitions. It runs only after utterance finalization, maps findings to the canonical Quran word index, suppresses weak acoustic disagreements, and never assigns a letter or tajwid rule when the reference data/evidence does not support it.
- Local progress persistence stores up to 200 word-practice attempt records (surah/ayah/word, conservative status, confidence, structured findings, timestamp) in SharedPreferences. It never stores PCM or recordings. Settings exposes summaries, weak-word counts, recent attempts, `Delete practice history`, and `Delete all local data` also removes this history.
- Android capture and Swift conversion require hardware tests, including routing, permission/lifecycle and final resampler tail. The model flushes its final feature chunk, but the iOS AVAudioConverter resampler tail still must be resolved before utterance-final timing.
- Practice history contains metadata only; raw microphone audio is ephemeral and never saved.
- Quran.com IndoPak Nastaleeq v4.2.1 and the corresponding whole-Qur’an IndoPak display strings are installed locally. Canonical Uthmani data remains separate for alignment.
- Developer diagnostics now includes an explicit calibration recorder. It captures at most two minutes of the same 16 kHz mono PCM16 stream, holds audio in memory until the user taps Save, then writes a labeled WAV and JSON containing raw recognition, confidence, timestamps, alignment, and deterministic findings. The directory is excluded from iCloud backup and supports individual or complete deletion. Normal recitation remains ephemeral.
- Nine careful-recitation iPhone samples are stored in the git-ignored local pilot directory. The report treats empty or partial recognition as missing expected phonemes, separates recognition failures from usable confidence/error rates, and exposes detected/expected counts per sample. An isolated deletion remains uncertain unless an entire skipped word is supported by later observed phonemes.
- Seven AbdulBaset AbdulSamad Mujawwad Al-Fatihah MP3s are bundled for offline playback under QuranicAudio's stated personal-use permission. Other verse files download on first use or through a per-surah offline action and are stored locally outside iCloud backup. Whole-verse playback uses the original audio; word playback seeks within the same file using Quran Foundation timing metadata. Published aggregate timing ranges are conservatively divided and remain documented as estimates.
- Waqf bookmark eligibility comes only from installed Unicode U+06D7 (preferred pause) or U+06D8 (necessary pause) marks. U+06DA (merely permissible), U+06D6 (preferred continuation), and U+06D9 (do not pause) do not create bookmark actions. This prevents Al-Baqarah 2:1 and other merely permissible stops from being presented as recommended stopping points. The single stored bookmark replaces its predecessor, and startup resumes at the following verse. Ordinary navigation and listening are never persisted; legacy last-location values are ignored.
- Sajdah notices come from Quran Foundation `sajdah_number` metadata. The current IndoPak/Hafs snapshot contains 14 marked ayahs; this is displayed as recitation guidance, not an independently generated religious ruling.
- Live lesson navigation follows the current recognized word with `Scrollable.ensureVisible`. Automatic completion requires the final expected phoneme plus at least 60% observed-sequence context, followed by 900 ms without a new decoded token. It is disabled for word practice and accuracy calibration. A successful automatic completion advances to the next verse (including across surah boundaries) and resumes the microphone.
- Native verse playback emits its actual audio position every 50 ms. Flutter maps that position deterministically to the installed word timing ranges, highlighting only the word currently being recited and leaving introductions or timing gaps neutral.
- Focused word practice now uses the same bundled word segment for normal-speed and 0.72× reference playback. Starting a microphone attempt always stops reference audio first, and leaving practice stops playback. The recorded attempt continues to use only the Quran-Lab on-device recognition path.
- The separate deterministic tajwīd layer now recognizes canonical shaddah and madd targets in Al-Fātiḥah. It may suggest shaddah practice only for a finalized, high-confidence substitution from the expected doubled token to the corresponding single token. Madd token duration is recorded from acoustic timestamps, but no short/long judgement is emitted because tempo-aware ranges are not yet calibrated.
- Weak-word summaries and recent practice records now carry their structured surah, ayah, and word index into navigation. Tapping either opens the exact word in focused practice; there is no text-key parsing or fuzzy word lookup.
- Settings now exposes a nontechnical Accuracy check screen for explicitly saved local samples. It reports progress toward a minimum pilot of 21 careful recitations (three per verse) and 14 controlled pronunciation-change/skipped-word samples. This collection is opt-in and separate from normal ephemeral practice.
- The iPhone UI now uses a cohesive, locally persisted theme system: System/Light/Dark appearance and Emerald/Ocean/Sand/Plum palettes. The verse selector and memorization control share one compact row, the verse uses a quiet tinted reading surface, feedback colors adapt to dark mode, and active playback/recording has a stable filled treatment in the bottom bar. Technical settings are collapsed under App information so practical controls remain easy to reach.
- The default Flutter launcher artwork was replaced with a custom opaque app icon: an ivory open Qur’an and gold listening-wave mark on an emerald background. A 1024px project master is retained under `assets/branding/`, and all required Apple asset-catalog sizes were regenerated from it.
- Model redistribution review and broader production hardening remain pending. Android work is stopped because the user no longer needs Android.

## Next implementation task

Module dashboard: startup now shows Qur’an and Duʿā cards after onboarding. Qur’an opens as a full-screen route with a dashboard back arrow; its title/dropdown opens the existing surah/verse picker. Duʿā opens an explicitly Coming soon placeholder with its own back arrow. Header return awaits microphone/playback stop; route disposal also stops capture/playback for system back/swipe. Re-entering Qur’an retains saved mode and bookmark-based starting behavior. Delete All returns to the root/onboarding instead of leaving a stale module route visible. Existing module tests now enter through the dashboard, plus a dashboard navigation/audio-stop regression test. No Duʿā content or audio has been fabricated.

Display preference: approximate word mappings now use the same normal active highlight colors as exact mappings. The approximate-position label remains; only temporarily held/uncertain positions retain the softer style. Recognition and scoring are unchanged.

Confirmed a display-mapping cause for the user's Baqarah report: 2:2, 2:4, 2:5 and 2:7 are marked exactWordMapping=false, while 2:3 and 2:6 are exact. Follow previously returned no word index for all approximate verses despite successful verse recognition. It now uses existing approximate per-word canonical spans for display/scroll only, with a softer highlight and an explicit approximate-position label. Canonical symbols and exactness flags are unchanged; grading remains disabled in Follow and exact-only elsewhere. Added regression coverage for word movement in 2:2/4/5/6/7. This does not explain unconfirmed dropouts on exact-mapped verses such as 2:3.

Verse-boundary follow trial: when strict matching fails and the last confirmed location is within the final three symbols, recognize a literal 4–16-symbol prefix of the immediately following ayah in the same surah. Mean confidence must be >=0.60 and each symbol >=0.45; entry requires two advancing confirmations. Continue verifying that prefix until ordinary alignment takes over, so the first few symbols do not immediately lose lock. No switch occurs on silence, inferred timing or arbitrary nearby words; distant jumps retain existing checks. A regression fixture covers three unrecognized boundary sounds and continuous highlighting by the fifth next-verse symbol. This is a targeted hypothesis for the user's reported boundary loss, not a confirmed diagnosis from their audio.

Small user-requested confidence adjustment: mean confidence for the established-position ±2-verse search is now 0.60 instead of 0.65. Initial acquisition and whole-Quran fallback remain at 0.65. The final-symbol floor (0.45), eight-match requirement, one-edit limit, ambiguity margin and jump confirmation remain unchanged. These model confidence scores are tuning values, not calibrated probabilities of correctness. Added a regression test distinguishing nearby acceptance from distant/low-confidence rejection; live benefit is still to be evaluated.

After the user's report that relaxed nearby-word matching worsened live tracking, replaced that path with a current-verse ±2 canonical-verse search (including across surah boundaries), followed by whole-Quran fallback when no clear local candidate exists. Removed the new three-second evidence reset and restored identical conservative eight-match/one-edit/0.65 thresholds for both scopes. Discontinuous moves still need two advancing confirmations. The 1.5-second soft UI hold, saved mode and screen-awake behavior remain unchanged. Tests cover two verses backward/forward and a distant jump to 112:1; real-world improvement remains unverified until retried.

Follow continuity refinement: search the next five canonical symbols in the same verse first, using six or more matches, up to two edits, mean confidence >=0.60, a positive score >=4 and a two-point runner-up margin. After three uncertain observations, disable the relaxed local path until strict reacquisition succeeds. Backward/verse jumps retain global eight-match, one-edit, 0.65 confidence and confirmation rules. Acoustic gaps >3 seconds discard old matching evidence but do not move the displayed position; silence alone never advances it, and sustained CTC sounds remain unchanged. Held highlights now use a softer color for at most 1.5 seconds from the first unmatched observation, without the former two-symbol cutoff or deadline extension. No special madd detection or audio-duration judgement is claimed. Added tests for nearby two-error recovery, evidence reset after a pause, and non-extending highlight grace. Physical recitation accuracy remains to be checked.

Listening convenience: the header's Follow/Practice choice now persists locally and is restored when the reading screen opens; restoration never starts the microphone. Delete All Local Data removes the choice. Actual iOS audio capture disables the idle timer only after AVAudioEngine starts successfully, and restores its previous value on stop, interruption, backgrounding, capture errors or service disposal. This uses the native capture lifecycle, so word practice/calibration also stay awake only while capturing. Longer-session battery/thermal/RAM measurements and physical auto-lock verification are still pending; no long-session results are claimed.

Follow-mode refinement: suffix matching now allows one inserted, deleted or substituted symbol within the 24-observation window. Seeds from the last six observations propose bounded endpoints; each is verified, and the final highlighted symbol must match acoustic output with confidence >=0.45. The existing mean-confidence, uniqueness margin and two-confirmation jump checks remain. Candidate evaluation is capped at 4,096 locations per event. The UI may hold the last reliable word through two unmatched observations, for at most 650 ms, without advancing; developer diagnostics distinguish held from confirmed. Timer state is cleared on reset, stop and disposal. Unit tests cover inserted/deleted symbols near a verse ending and timed highlight expiry. These are deterministic tests, not new measured mosque/audio accuracy results.

Experimental Follow recitation mode is selectable from the header microphone/hearing menu while stopped. It uses Quran-Lab acoustic symbols unchanged and a fixed canonical-corpus three-symbol index; at most 24 recent observations/results are retained. A candidate needs at least eight matching symbols with mean confidence >=0.65, at most one substitution in the suffix, a three-point lead over alternatives for reacquisition, and two advancing confirmations before a discontinuous jump. Established local progression can disambiguate repeated phrases. This is conservative substring matching, not generic speech-to-text or a claim of calibrated mosque accuracy. Insertions/deletions and wrong final seed symbols can delay reacquisition. Backward word/verse jumps update the UI and scroll without microphone/model resets. Ambiguous/low-confidence evidence clears the active highlight and shows finding-place status; no grading or tajwid findings are produced. Verses without exact canonical word mapping follow at verse level only. Tests cover canonical backward reacquisition, a different verse, low confidence, and ambiguous Bismillah. Live imam/speaker/echo testing and memory profiling remain pending; no such recognition results have been fabricated.

Continuous listening: automatic verse transitions now update only the expected ayah and discard its aligned result prefix, retaining any trailing phonemes for the next verse. The microphone, feature overlap, CTC run, timestamps and Core ML streaming caches remain live. Only explicit stop, app interruption, overload or Qur’an completion stops capture. Native pending PCM is capped at 64,000 bytes (two seconds), processed Kaldi frames are recycled immediately, and current-attempt recognition results stop at 4,096 tokens rather than growing indefinitely. Overflow is surfaced as an error, never silently dropped. Raw audio remains ephemeral except opt-in calibration. Long-session device memory/latency and fast boundary accuracy still require live recitation validation; this is not a measured RAM claim.

Automatic listening transitions debounce a completed phoneme alignment for 200 ms (previously 900 ms). Existing end-of-sequence coverage checks and practice/calibration exclusions remain unchanged. There is no automatic microphone restart or extra navigation pause at verse boundaries.

Validate whole-Qur’an navigation, first-use audio download, per-surah offline download, and cache deletion on the physical iPhone. Then collect broader real recitations before calibrating madd duration ranges or stronger pronunciation thresholds.
