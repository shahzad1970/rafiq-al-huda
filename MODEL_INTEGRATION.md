# Quran-Lab integration contract

## Status — 2026-09-15

Authorized access was granted and the required v3.1 packages, ONNX graph, `tokens.txt`, packing manifests, reference inference scripts, canonical phoneme JSON and license were downloaded locally from pinned revision `506422c82a81c86e7ae74a5a2ab4641724bcd3b3`. Checksums are recorded in `docs/QURAN_LAB_V3_1_SHA256SUMS.txt`. The iOS package is compiled into the app. Native streaming now implements the exact Kaldi frontend, paired Core ML front/back calls, separate cache carry, processed-length ordering and `tokens.txt` decoding. It is exposed only as raw developer diagnostics pending physical-device validation; no alternative model is enabled.

Sources: [model card](https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3), [file listing](https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3/tree/main).

## Approved artifacts

Default iOS model: `zipformer_p_arabic_v3.1.float8.mlpackage` (iOS 18+).
Default Android model: `zipformer_p_arabic_v3.1.int8.onnx`.
v3 equivalents are allowed through the same engine interface, with version-specific checksummed manifests. No PyTorch development checkpoint is distributed to phones.

Each installation must also contain the authorized `tokens.txt`, `ordered_quran_phonemes.json`, `quran_text2phoneme.json`, license, and the applicable packing metadata. The developer assets are pinned and locally checksummed; production installation must validate that manifest. Never commit an access token or gated weights. Developer import must validate the same manifest as a downloaded installation.

## Phases 1 and 2

Flutter owns presentation, state and channel contracts. Native microphone services capture actual audio; iOS converts hardware input with AVAudioConverter, Android captures PCM16 with AudioRecord. The shared boundary is little-endian PCM16, mono, 16,000 samples/second. Chunk sequence, cumulative samples, RMS, peak, elapsed audio time and input rate are observable. Silence is real silence, not a synthesized recognition event. Android recognition still fails explicitly as not integrated. iOS raw recognition is available to the developer screen but is not connected to alignment or grading.

This capture stream is **not** an acoustic front end. Do not feed waveform directly into an exported feature-input model. Keep a native inference path to avoid copying every model tensor through Dart.

## Phase 3 — Core ML

Use the supplied package directly and compile it locally with Core ML; no reconversion. Load `front` and `back` from the same compiled package with separate configurations. Prefer `cpuAndNeuralEngine`; execution placement is measured, never presumed. Read user-defined metadata and feature descriptions: model type, feature type, fbank options, T, chunk step, left context, function order, cross tensor, counter, blank ID and packing definitions. Validate these against model descriptions and token table before accepting the installation. Fail if required metadata is missing or inconsistent.

The published interface uses 61 input frames and advances 48 frames. Its two functions share a frame counter; both receive the old counter, committed only after both predictions succeed. State blobs must be explicitly zeroed initially; each function carries its own `new_sg_*` outputs into the next call. Packing JSON embedded in metadata is preferred over external manifests. Do not merge the functions' similarly named blobs. A failed pair resets the whole utterance rather than continuing half-updated state. Honour MLMultiArray strides for logits. Validate on a physical iOS 18+ device, not just Simulator.

Direct inspection confirms 16 kHz, `kaldi_fbank_povey`, `dither=0`, `snip_edges=false`, `high_freq=-400`, 80 dimensions, `T=61`, a 48-frame advance, front cross-tensor `(24,1,384)`, and back logits `(1,12,251)`. The app vendors `kaldi-native-fbank` 1.22.3 at commit `b09e686fe2084732ddd30d1ef80acfc0f13eaf01` with its pinned KissFFT dependency `febd4caeed32e33ad8b2e0bb5ea77542c40f18ec`. A deterministic PCM fixture and selected numerical bins were generated with the Python 1.22.3 package; the corresponding native XCTest passed on the iPhone 17 simulator with 1e-4 feature tolerance. The final partial stream is zero-padded only when real frames remain beyond the 13-frame right context. Do not replace this with a generic mel implementation.

## Phase 4 — Android

Inspect `export_quran_streaming_onnx.py`, `quran_per_eval.py` and actual graph metadata. Choose sherpa-onnx only after confirming the supplied streaming CTC Zipformer2 interface exposes the raw per-frame token scores/timestamps needed by the decoder. Otherwise use ONNX Runtime with the exact supplied cache-aware contract, not a redesigned network. Record the decision and inspect the actual 99-in/99-out graph before allocating caches. Preserve all cache tensors, frame counters, input overlap and final flush. Validate a CPU baseline before evaluating hardware execution providers; accept acceleration only after accuracy parity and latency measurements.

## Decoding and reference data gate

IDs come exclusively from `tokens.txt`, not raw phoneme inventory IDs. The public card identifies blank as 250; runtime code nevertheless requires a validated metadata-supplied blank ID. Implement streaming CTC collapse across chunk boundaries and the reference `margin_peak` confidence aggregation. Preserve repeats separated by blank. Use exact emitted symbols, never silently correct to expected text. Establish timestamp offset/stride with test audio; do not infer duration from repeated collapsed symbols.

The QuranRepository is keyed by surah/ayah, not a seven-item special case. Text display is bundled for Al-Fatihah, sourced from Quran.com. Expected phonemes and word/letter spans are unavailable until canonical data can be inspected. Do not fabricate them or derive IDs from `phoneme_units.json`. Importing all 6,236 references and validating span coverage is required before enabling alignment. Word/letter mapping must preserve display indices and document any canonical dataset gaps.

## Acceptance gates

1. Both native runners compile and physical microphones produce correctly timed 16 kHz mono PCM.
2. Exact Kaldi extractor matches reference fixtures in dimensions, timing and numerical values.
3. Known real Quran audio produces sensible tokens on both models; measure parity, chunk latency, memory and real-time factor.
4. Only then connect canonical phonemes to alignment, deterministic errors and debounced word highlighting.
5. Test held-out correct, incorrect, skipped/repeated-word, noisy and quiet recordings. No expected-output hardcoding.

## Current local validation

A local-only EveryAyah Al-Fatihah 1:1 recording (Abdul Samad, 16 kHz mono PCM16, 6.478375 s) was passed through the exact Python reference frontend and the compiled v3.1 Float8 Core ML package on Apple silicon. The 13 paired streaming calls completed in 0.213 s (inference harness RTF 0.033) and produced a sensible Quranic phoneme sequence:

`بِسمِللَااهِررَحمَاانِررَحِۦۦم`

The canonical v3.1 file has `بِسمِللَااهِررَحمَاانِررَحِۦۦۦۦم`; this difference is recorded, not corrected or treated as a learner error. It is consistent with the model card warning that free-choice/end-of-ayah madd duration must not be graded from repeated token count. This proves that the package and streaming contract can execute coherently on this Mac; it does not replace a physical-iPhone microphone test or establish grading accuracy. The source dataset card has conflicting license labels (MIT front matter and CC BY 4.0 prose), so the clip remains git-ignored and must not be redistributed until provenance is resolved.

## Scoring safety

The model card documents canonical-label bias, unreliable token-based free-choice madd length and weaker child-reciter performance. Token-only output cannot establish quality-contrast tajwid violations. Madd requires acoustic/forced-alignment duration and confidence, with recitation rate and valid stopping choices considered. Until these measurements are validated, show unavailable rather than a correct/incorrect judgement. LLM explanations are optional downstream consumers of deterministic evidence, never graders.

## License and privacy

The developer signed in to Hugging Face and accepted the Quran-Lab NPL-1.2 conditions before downloading the gated artifacts. No bypass mechanism is provided. Exact redistribution terms in the authorized LICENSE must be reviewed before app distribution or a model download endpoint is enabled. All features remain free and non-commercial. Attribution and the teacher disclaimer are displayed in-app. Microphone input is neither uploaded nor permanently stored. Core inference will have no backend dependency.

The v3.1 Core ML package's embedded metadata names NPL-1.1, while the pinned repository's accompanying LICENSE is NPL-1.2 and explicitly describes the change from 1.1. The project retains and bundles the current repository LICENSE and records this upstream metadata discrepancy; it does not rewrite the signed model package.
