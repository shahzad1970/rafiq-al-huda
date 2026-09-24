# Layer boundaries and gates

```text
Flutter UI / local settings / diagnostics
  RecitationController
    AudioCapture -> Swift AVAudioEngine / Kotlin AudioRecord [implemented, device test pending]
    QuranSpeechEngine [interface]
      CoreMLQuranSpeechEngine / OnnxQuranSpeechEngine [explicitly unavailable]
        Native exact Kaldi fbank / streaming inference [pending authorized reference files]
  QuranPhonemeDecoder [table parsing / streaming ID collapse only]
  QuranRepository [114 surahs; Uthmani/IndoPak/English; canonical Quran-Lab phonemes]
  QuranAlignmentEngine [independent edit alignment, not yet live]
  PronunciationScoringEngine [typed interface, no acoustic judgements]
  TajwidRuleEngine [typed timing evidence interface, no rules active]
  TeacherFeedbackEngine [typed evidence consumer interface, no LLM]
  ModelManager [approved install/import contract, implementation pending]
```

Native PCM delivery and debug UI are separate from inference. No mic-to-text substitute is used. The platform engine selects a versioned model, while downstream objects represent symbols/evidence independently of weight format. The two platforms use the identical channel name, PCM schema and engine abstraction.

Do not attach alignment to microphone capture until real-audio recognition acceptance passes. Partial utterances must not be graded as final deletions. Word-skip/repetition classification requires canonical word spans; Levenshtein edits alone are not those classifications. Acoustic confidence aggregation and debounce thresholds require measured calibration, not arbitrary labels shown as facts.

The QuranRepository is keyed by surah/ayah and loads a versioned local snapshot containing all 114 surahs and 6,236 ayahs. Full-ayah expected sequences come directly from Quran-Lab and are tokenized only with its authoritative `tokens.txt`. Quran.com supplies display text, English word meanings, AbdulBaset Mujawwad URLs, and published timing segments. Joined Quran-Lab acoustic units are never split invisibly or rewritten; estimated display-word spans are labeled as such.
