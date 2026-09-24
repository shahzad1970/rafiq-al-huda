# Private internal TestFlight preparation — 2026-09-20

## Authorized scope

The owner authorized App Store Connect / TestFlight for their own account only.
This is a narrow exception to local-only development: no public App Store
release, external testers, public invitation links, or hosted application.
No microphone recordings, practice history, credentials, or user data belong
in an archive. Recognition remains on-device.

## Configuration

Local archive succeeded at
`/Users/shahzadsarwar/Library/Caches/quran-teacher-ai-build/ios/archive/Runner.xcarchive`
(275.3 MB). It is unsigned; IPA export was deliberately skipped. Flutter's basic
settings validation passed, but flagged the default launch-image placeholder.
Resolve that warning before final archive/Apple validation. Build-dir override
was cleared after the command. This is not an uploaded or installable build.

That archive predates the expanded Duʿā library and new Hadith module. Rebuild a
fresh archive after the current content review before any future TestFlight upload;
do not upload the older archive as if it contains these updates. Hadith translation
rights/provenance must now also be included in the distribution review.

- Bundle ID: `org.quranteacher.quranTeacherAi`
- Existing team: `AL74EJURSE`
- Proposed first upload: version `0.1.0`, build `2026092001` (check for collisions
  in App Store Connect before uploading).
- `ios/ExportOptions-InternalTestFlight.plist` uses `app-store-connect`, automatic
  signing, and `testFlightInternalTestingOnly = true`. Its destination is
  deliberately `export`, not automatic upload. Preserve this restriction when
  exporting/uploading with Xcode. Internal builds cannot later be submitted to
  external testers or the public store.
- Local certificate inspection currently finds Apple Development only. Export
  requires distribution signing/provisioning through the authorized account.
- App Store Connect browser is at Apple sign-in. The owner must complete sign-in
  and verification privately. No app record, group, invite or upload has yet
  been verified.

## Content checks before upload

This is an engineering checklist, not legal clearance. Being free does not
automatically establish distribution rights.

- Quran-Lab: local NPL-1.2 reviewed; retain its full license for bundled weights
  and derivatives, respect no-charge/share-alike conditions, and confirm Apple
  distribution does not impose incompatible terms. Authorized HF access is not
  by itself redistribution clearance. Existing Xcode resources include LICENSE.
- Quran Foundation: current developer terms (updated 2026-09-14) permit integrated
  font bundling with an active Developer Console account and accessible credit.
  Confirm that account and add in-app attribution before upload. The current
  offline data snapshot needs storage permission or the documented sync policy;
  indefinite static caching is not automatically covered. Preserve text and
  source-specific translation/audio permissions. Terms also require public
  privacy/terms documents; publishing those needs a deliberate hosting decision.
- QuranicAudio: personal-use download permission is documented, but broader
  redistribution is not established. Resolve the seven bundled MP3s before
  distributing even a restricted beta; do not invite others on that assumption.
- All other bundled libraries retain their notices. Audit the actual archive,
  privacy manifests and required-reason APIs before Apple validation.

Sources checked:

- https://api-docs.quran.com/legal/developer-terms/
- https://quranicaudio.com/about
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers
- `models/quran_lab/v3_1/LICENSE`
- Installed Xcode `xcodebuild -help` export-option reference

## Completion sequence

1. Resolve the content/account checks above and complete Apple sign-in.
2. Inspect existing app records; create one only if absent, matching the bundle
   ID/team. Do not accept new agreements on the owner's behalf without approval.
3. Sign/export the local archive using the internal-only plist. Check its version,
   assets, privacy manifests, license files and entitlements. Validate with Apple.
4. Upload the internal-only build and wait for processing. Complete export
   compliance truthfully after auditing dependencies; do not guess exemptions.
5. Create/select a private internal group containing only the account owner.
   Disable automatic distribution if other groups exist. No external/public link.
6. Owner installs Apple's TestFlight app and accepts the internal invitation.
   Verify launch, on-device model, offline data/audio, microphone and saved data.

The existing development-signed Runner.app is not a TestFlight upload artifact.
An unsigned xcarchive is only preparation, not a signed or installable IPA.
