# Alif v4 evaluation — 2026-09-20 (local time)

## Decision

Do not replace the working Ask model with this artifact. It can execute on the
connected iPhone 17 Pro Max's CPU, but failed all four existing Ask acceptance
fixtures with the same source-grounded instructions used by the working runtime.
This is a small integration smoke test, not a comprehensive benchmark or a claim
that every possible Alif configuration fails. No alternative model was silently
substituted. Main-app code, Qur'an recognition, and user data were unchanged.

## Artifact and runtime

- `ahmedtamseer3/alif-islamic-v4-base`, revision
  `f7847ebcc1568007ab585bcaf1bffd062bca534c`.
- Downloaded 946,786,704 bytes; verified SHA256
  `79deeca9f2120c08454ccb09f0399b42d4b3146e8d3fdc0bde4cfa2787f2bbaa`.
- MediaPipeTasksGenAI/GenAIC 0.10.35, real native Swift Release app,
  separately signed `org.quranteacher.alifProbe`.
- CPU: 4096-token context matching the model's cache, top-k 1, temperature 0,
  random seed 42, explicit ChatML from bundled metadata, fresh session per case.
- No remote inference, microphone access, or private question collection.
- Source and reproducibility details: `tool/alif_probe/`.
- Raw device output: `docs/alif-probe-results.txt`.

## Compatibility findings

Metal initialization failed at both 1024 and 4096 context sizes:
`Node number 398 (STABLEHLO_COMPOSITE) failed to prepare`, followed by
`ModifyGraphWithDelegate(gpu_delegate.get()) == kTfLiteOk (1 vs. 0)` in
`llm_litert_metal_executor.mm:219`. Changing to the recommended 4096-token cache
size did not resolve it. This is a failure of the tested artifact/runtime path,
not proof that all MediaPipe or Qwen models cannot run on iOS.

CPU loaded in 1.24–1.45 seconds. Plain untemplated input repeated until the context
limit; the iOS runtime logged `has_prompt_templates: 0`. Using the bundle's Qwen
ChatML roles fixed the simple prompt. It returned a short response in 2.46 seconds
including loading, first output at 2.03 seconds. The response added “no partners”
and omitted the requested reference, so even this is not an accuracy pass.

## Existing acceptance fixtures

Times below measure generation after adding each prompt, with an already loaded
model. They are not end-to-end UI latency and do not include cold loading.

| Fixture | Seconds | Result |
| --- | ---: | --- |
| supported | 3.28 | Plain quotation, no required JSON claims/source IDs |
| hadith | 7.39 | Plain paraphrase presented in quotes, no structured citations |
| unsupported | 4.48 | Failed to abstain; added claims about the Qur'an not supported by supplied 112:1 |
| injection | 6.47 | Did not invent the requested payment narration, but failed to abstain; emitted unsupported repetitive claims without source IDs |

The app's existing structured-answer validator would reject these outputs. Do not
relax it or assign fabricated citations to make this model appear successful.

## Limitations and next step

No peak-memory, battery, thermal, long-session, Arabic-question, scholarly review,
or wider quality results are claimed. This trial is sufficient to reject a blind
production swap, not to establish a comprehensive model ranking.

Next proposed task (requires user choice): benchmark the official Qwen2.5-1.5B
Q4_K_M GGUF with the existing llama.cpp path and the same fixtures. Alternatively,
investigate a corrected Alif export/runtime version with its author. The current
working 4B model remains selected; no fallback has been downloaded or installed.

The temporary probe app was removed after saving its generated test log. The
verified model remains in the development Mac cache for reproduction.
