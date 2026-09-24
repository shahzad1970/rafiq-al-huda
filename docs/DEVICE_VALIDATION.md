# Phase 2 physical-device checklist

This checklist has **not** been completed on a phone in this workspace.

1. Run debug build on physical iOS 18+ and Android devices. Deny permission first: display an actionable error and do not capture. Grant from Settings and retry.
2. Long-press the title for diagnostics. Start capture; verify output 16,000 Hz, mono PCM16 LE and actual hardware/requested input rate. Android AudioRecord reports its capture rate, not necessarily the underlying hardware clock.
3. Speak, pause and softly recite; verify waveform/RMS follow real input. Silence must not become recognized phonemes. Verify counters advance continuously, timestamps derive from output sample offsets and there are no sequence/sample gaps.
4. Stop/start repeatedly. Confirm OS microphone indicator stops; reset counters per attempt. Leave the foreground, interrupt audio and change routes: stop capture and show interruption rather than continue with mismatched streaming state.
5. Run `flutter test integration_test/audio_capture_test.dart -d <id>`; accept the microphone prompt. This checks actual contiguous chunks and format, not pronunciation accuracy.
6. Inspect app storage and network traffic: no recordings or recitation uploads should exist. Delete all local data and verify settings/session reset.
7. On iOS, confirm raw Quran-Lab IDs and phonemes appear only after enough audio for a 61-frame input. Compare a known clip with the Mac reference, then log per-chunk latency, real-time factor, memory and actual Core ML compute placement if obtainable. Do not interpret a token disagreement as a grading result.
8. Log device/OS, source/output sample counts over a timed recording, clock drift, dropped frames and conversion end-tail behavior. The fbank/model stream flushes a final partial feature chunk, but AVAudioConverter still stops without explicitly draining its resampler filter tail; resolve this before forced-alignment timing.

The native fbank parity test passed on the iPhone 17 simulator with 1e-4 feature tolerance. Simulator results cannot validate ANE inference, microphone routing or physical-device performance.
