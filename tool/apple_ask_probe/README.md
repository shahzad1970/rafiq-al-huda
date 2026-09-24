# Apple on-device Q&A probe

Isolated physical-iPhone test; not linked into the main app. Requires iOS 26+
and available Apple Intelligence. Uses only SystemLanguageModel.default, with
default guardrails and native structured generation. No model downloads, cloud
fallback, microphone, or URLSession in this code.

Generate with `xcodegen generate --spec tool/apple_ask_probe/project.yml`.
Build the AppleAskProbe scheme in Release for a physical iPhone. The project
uses this workspace's development team; change it for another developer.
Install and launch `org.quranteacher.appleAskProbe`. The suite runs once per
launch and writes generated results to Documents/result.txt. Copy that log out
before removing the disposable test app.

The four fixtures are shared with the Qwen trials. Additional questions reuse
the same source passages; no fabricated scripture or recognition outputs are
used. The adversarial source case is explicitly synthetic test data.
BasicStructureAndAbstentionPass validates only response shape, reference IDs,
and expected empty/nonempty claims. Review actual responses for semantic errors
and commentary attribution; never present this flag as religious accuracy.

See docs/APPLE_ASK_EVALUATION.md for measured findings and limitations.

V2 separates publisher commentary into its own optional source ID; it is never
included for ordinary test questions. Source labels are derived from metadata.
The probe requests exact evidence quotes and verifies substring identity in a
cited source in addition to basic IDs and abstention. This does not verify
semantic entailment. Fifteen cases now cover absent notes, source attribution,
multiple sources, and invented grades. The fixture-title kind classifier is
test-only; use authoritative repository types for any eventual app integration.
Default Apple guardrails remain enabled, and blocked responses are errors, not
successful abstentions. V2 results are in docs/apple-ask-separated-results.txt.
