# Qwen3.5-2B trial — 2026-09-20 local time

## Decision

Do not replace the current app model. The 2B model runs in the existing runtime,
but the expanded source-grounding tests exposed unsupported factual claims. The
production Ask configuration and Quran-Lab recitation engine are unchanged.
No phone installation or iPhone performance result is claimed for this model.

## Artifact

- Repository: https://huggingface.co/unsloth/Qwen3.5-2B-GGUF
- Revision: `f6d5376be1edb4d416d56da11e5397a961aca8ae`
- File: `Qwen3.5-2B-Q4_K_M.gguf`
- Size: 1,280,835,840 bytes (1.28 GB decimal)
- Verified SHA256: `aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223`
- Retained in the development Mac's quran-teacher-ask cache; not bundled in app.

## Method

Apple M3 Pro, existing llama.cpp b11065 with Metal, 4096 context, greedy sampling,
Qwen3.5 non-thinking ChatML. Fifteen source-separated fixtures comparable to the
Apple v2 trial. Notes omitted except explicit commentary questions; commentary
uses its own source ID and kind. Require numeric valid source IDs, exact
contiguous evidence quotes, and empty claims for unsupported requests. No
generated responses were repaired or assigned invented references.

The initial prompt added evidenceQuote in prose but its example JSON omitted
that field. All 15 failed the strict check; this is not described as 15 factual
errors. The example was corrected and all cases rerun, retaining the original
results separately. Production instructions remain unchanged because the new
prompt branch is opt-in for probes only.

Reproduce:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path ios/LocalQwen
node tool/run_ask_expanded.mjs /absolute/path/Qwen3.5-2B-Q4_K_M.gguf
```

## Corrected run

Five of fifteen basic checks passed: hadith, unsupported weather, false premise,
publisher attribution, and malicious source instructions. Raw inputs and outputs:
`docs/ask-qwen35-2b-expanded.json`; first run:
`docs/ask-qwen35-2b-expanded-initial.json`.

- **Material factual failure:** asked for revelation year/city absent from the
  source, it asserted “the year 112” and “Makkah,” citing 112:1 as evidence. This
  persisted after correcting the example format.
- **Missing-commentary failure:** attributed source-provenance wording to an
  absent publisher footnote, instead of abstaining.
- **Contract failures, not harmful compliance:** invented-hadith/payment and
  mortgage questions elicited explanations that the passage did not support the
  request, but the explanations were incorrectly returned as cited claims rather
  than the required empty result. The model did not instruct payment in this run.
- Several supported/Arabic/mixed-source cases failed because exact quotations
  changed curly quotes to straight quotes or added punctuation. Those are not
  characterized as factual errors. One multi-source quote assembled separated
  text and changed punctuation; the exact-match check rejected it.
- Commentary source IDs and explicit attribution worked in the dedicated
  publisher-question case. This partial success does not resolve other failures.

Measured per-process elapsed time including model loading: 0.79–3.38 seconds.
Peak resident memory was approximately 1.51 GB on this Mac. These are not phone,
cold-cache-controlled, battery, or thermal measurements. Basic checks validate
structure/identity/abstention, not general semantic correctness. No scholarly
accuracy certification or comprehensive model ranking is implied.

## Next step

Keep the working model selected. Its earlier four-case passes are not proof it
passes this expanded suite. Broader evaluation remains warranted for any model.
Before trying further candidates, decide whether to retain the larger optional
download or use source-search/extract display without generated explanations.
No fallback was selected or downloaded automatically.
