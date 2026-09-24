# Isolated Alif iPhone probe

This is a separate native test app, not a replacement for the working Flutter app.
It uses real Alif inference, no network during testing, no microphone, and no
fabricated responses. `--cpu --suite` runs the four existing Ask fixtures. The
probe logs raw answers and timing, not a religious-accuracy score.

Model: https://huggingface.co/ahmedtamseer3/alif-islamic-v4-base

- Revision: `f7847ebcc1568007ab585bcaf1bffd062bca534c`
- File: `alif-islamic-v4-base.task`
- Size: 946,786,704 bytes (946.8 MB / 902.9 MiB)
- SHA256: `79deeca9f2120c08454ccb09f0399b42d4b3146e8d3fdc0bde4cfa2787f2bbaa`
- Model card declares Apache-2.0, based on Qwen2.5-1.5B-Instruct.

Download the pinned model to the local cache path in `project.yml`. Download and
extract these official Google distributions into the same cache directory:

- https://dl.google.com/cpdc/20260427-204215/MediaPipeTasksGenAI-0.10.35.tar.gz
  SHA256 `d43cae3e8c42346ab2ffae4f78a731b6fb4047a63486d9e982b8b8d382c00201`
- https://dl.google.com/cpdc/20260427-204219/MediaPipeTasksGenAIC-0.10.35.tar.gz
  SHA256 `a8413525fea24f531a97ce399e8c29912928369c7e396e9adb7bb8e948d239e5`

The local paths/team in `project.yml` target this development Mac. Generate using
`xcodegen generate --spec tool/alif_probe/project.yml`, build the `AlifProbe`
scheme for a physical iPhone, install and launch using `--cpu --suite` arguments.
Without `--suite`, a single short source-grounded question is tested. Without
`--cpu`, the probe explicitly tests Metal. Results are in app Documents/result.txt.
The model is bundled only in this disposable test app for direct device testing;
it must not be added to the production application's bundled resources.

The bundle contains TF_LITE_PREFILL_DECODE, TOKENIZER_MODEL, and METADATA. Its
metadata specifies Qwen ChatML role delimiters. MediaPipe 0.10.35 on iOS reports
`has_prompt_templates: 0`; this probe therefore supplies those delimiters itself.
Sending an unformatted plain prompt repeated the input until the context limit.
The model card's `gemmaIt` example should not be copied blindly.
