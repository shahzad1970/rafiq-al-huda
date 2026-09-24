# Arabic Translator — experimental iOS module

This module is independent of Quran-Lab and does not grade recitation. It uses WhisperKit 0.9.4 with multilingual Whisper Small Core ML models to translate Arabic audio directly into English, displayed as English text. Quran recognition remains unchanged.

## Use

Open Arabic Translator from the dashboard. Download the approximately 490 MB model once. Tap Start listening. Capture continues while short phrases translate into English text. Tap Stop listening to cancel immediately, discarding unfinished speech. Translation is always text-only; headphones are optional. Connecting/disconnecting an input device stops capture and asks for a restart. Physical headphone routing still needs validation.

## Low-delay pipeline

AVAudioEngine converts microphone PCM to 16 kHz mono floats, using a two-second locked handoff buffer. A 20 ms energy detector retains 200 ms pre-roll and submits a phrase after 460 ms of silence (at least one second total), or six seconds maximum. It requires 300 ms of above-threshold energy, but this is only an uncalibrated energy heuristic, not a trained speech detector. Quiet speech may be missed and noise can trigger it. Hard six-second boundaries can split words or reduce translation context; no overlap or partial-text stability is claimed.

One inference plus one pending phrase are allowed; capture continues in parallel. If a third phrase arrives before processing catches up, listening stops with an explicit message rather than silently discarding audio or growing the queue. No temperature retries, one decode worker, and a 128-token decode budget bound each request. Long translations can be truncated by that budget. Last phrase processing time is displayed, excluding phrase collection. These are mini-batches, not token-by-token streaming translation or a guaranteed real-time speed.

## Privacy and downloads

Microphone audio never uploads or writes to disk in live mode. PCM is bounded in memory (capture handoff, collecting phrase, one pending phrase and one inference input); model/runtime allocations are additional and need measurement. Only ten translations are retained in memory; leaving the screen discards them. Stop, interruption and backgrounding clear capture/queues; a canceled Core ML request may retain its bounded input until it returns. Model files are excluded from iCloud backup. Delete translation model removes the module's downloaded model and tokenizer.

`ios/Runner/TranslatorModelManifest.json` pins model and tokenizer file revisions, lengths and authoritative SHA256/LFS or Git blob SHA1 hashes. Downloads are checked before installation and files are reverified before loading. Inference uses local model and tokenizer paths with model download disabled. First-use offline inference requires physical-device testing.

## Limitations and validation

Speech-to-English translation is probabilistic and can omit or invent wording. Filtering low-quality/silence segments reduces but does not eliminate this. Do not treat it as an authoritative religious translation. Qur'an text translations remain in the separate Qur'an module.

Flutter analysis is clean; 52 tests pass, including Stop availability while inference is active. Native production-buffer tests cover silence, pause boundaries, maximum phrase size, click rejection, callback fragmentation, draining and overflow. Run with `xcrun swiftc ios/Runner/TranslatorAudioBuffer.swift test/translator_audio_test.swift -o /tmp/quran-translator-audio-tests` then execute that binary. Synthetic PCM in these tests tests buffering only, never fabricated recognition.

No real translation accuracy, latency, battery or headset routing measurements have been obtained yet. Next: translate known Arabic phrases on iPhone, compare with a bilingual speaker, repeat in airplane mode, test Bluetooth/wired headphones, interruptions and ten minutes of continuous speech. Check whether inference consistently processes a phrase faster than its audio duration.

## Sources and licensing

- WhisperKit 0.9.4: https://github.com/argmaxinc/WhisperKit/tree/v0.9.4 — MIT notice bundled at assets/licenses/WhisperKit.txt.
- Core ML weights: https://huggingface.co/argmaxinc/whisperkit-coreml
- Multilingual Whisper Small/tokenizer: https://huggingface.co/openai/whisper-small — MIT.
- Apple simultaneous audio route option: https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/allowbluetootha2dp

No hosted application or speech backend is used.
