# Prayer Times — local iOS module

## Source and scope

The user requested MAWAQIT calculations. The official organization has two
distinct integration paths: `mawaqit-py` is an authenticated mosque timetable API;
`prayer-times` is a PHP astronomical calculator, based on PrayTimes.org.
This module uses the latter, adapted into offline Dart. It does not scrape the
website, request credentials or claim to show a particular mosque’s timetable.

- https://github.com/mawaqit/prayer-times
- Revision: `640157265aaa4e71e33b8aa718f36f35fb99eb92`
- Original PHP retained in `third_party/mawaqit_prayer_times/`.
- Dart adaptation: `lib/core/prayer/mawaqit_calculator.dart`.
- Original authors credited: Hamid Zarrabi-Zadeh / PrayTimes.org and Meezaan-ud-Din.
- LGPL v3 and the incorporated GPL v3 texts are bundled and registered in licenses.
  Local-only work; future distribution must separately satisfy LGPL obligations,
  including modified-source availability and applicable relinking requirements.
  The README’s short license summary is not a substitute for those obligations.

## What is implemented

Dashboard module with back navigation, six rows (Sunrise explicitly not a prayer),
next actual prayer countdown, previous/next day (±365 days), timezone label,
12/24-hour device formatting and a setup screen. No fabricated initial location.
22 published presets; Standard/Hanafi Asr; angle/middle/seventh/no high-latitude
adjustment; per-event −60 to +60 minute adjustments. No automatic Ramadan change
to the upstream fixed-minute Isha presets: setup clearly discloses this.
Moonsighting and custom angle methods are NOT offered; their extra formulas have
not been ported. Elevation is sea-level (0m), as disclosed in calculation info.

Timezone database: Dart `timezone` 0.11.1, IANA 2025c. Date-specific offsets and
unwrapped day boundaries are retained, including Isha after midnight and DST.
The next-prayer search includes yesterday/today/tomorrow and excludes sunrise.
Dates are based on the saved location’s zone, not the phone’s current clock zone.
The display updates every 30 seconds while foregrounded; timer stops in background.

## Explicit upstream corrections

1. Upstream `asrTime` calls `gregorianToJulianDate`, whose fraction uses PHP `date()`
   (the wall clock), unlike its other solar calculations. The Dart port uses the
   selected date and longitude-adjusted Julian day consistently. This is not an
   exact byte-for-byte port of that defect.
2. Upstream clamps out-of-domain solar hour angles to ±1, yielding misleading
   apparent rise/set times at polar locations. The port returns unavailable
   instead. High-latitude twilight estimation is only applied if sunrise/sunset
   exist, with visible estimate labels. No invented polar fallback.
3. Missing events remain null; timezone-aware timestamps preserve adjacent-day
   times rather than wrapping every result onto the displayed date.

## Privacy / location

- City presets and manual coordinates + IANA timezone work offline.
- Optional current location requests When In Use permission and one location,
  kilometer desired accuracy. It uses the **phone timezone**, explicitly shown
  for confirmation in setup; no reverse-geocoding request is made for this action.
- Explicit city search uses Apple CLGeocoder and needs internet. Search text is
  sent to Apple, not to MAWAQIT or an app server. First returned place is shown in
  editable fields; the user confirms before saving.
- Pending lookups time out after 30s, cancel on leaving setup/backgrounding, and
  stale geocoding callbacks cannot overwrite later requests.
- No background location, analytics, saved location history or adhan notification
  scheduling. Only the chosen location and settings are persisted locally.
  Delete All Local Data also removes `prayer_configuration`.

## Verification

`node tool/build_prayer_reference.mjs` runs the pinned PHP implementation locally.
The harness explicitly corrects only the Asr wall-clock line in memory, keeps the
source files unchanged, and generates 1,056 cases: 22 methods × 2 Asr schools ×
6 locations × 4 dates. Its Moonsighting constant is only a metadata dependency;
that method is never evaluated. Dart tests compare all six rounded minute values.
This is implementation parity, not validation of a mosque’s local timetable.

Other tests cover unavailable polar events, high-latitude labeling, no-adjustment
behavior, DST transitions, next-day Fajr, sunrise exclusion, invalid input,
minute tuning, persistence/deletion and iPhone-sized UI. Physical location
permission/GPS/search, timezone confirmation and local-mosque comparison still
need device checks. Calculations and stored-location use do not require internet.

2026-09-20: analyzer clean; 111 tests pass and opt-in light/dark visual renders pass.
Signed iOS release build succeeds (218.2 MB). Not uploaded or installed on a phone.
Screenshots: `docs/screenshots/prayer-light.png`, `prayer-dark.png` are Flutter
renders at iPhone size using New York / ISNA / Hanafi on 2026-09-20 at 11:00 local,
not the user's saved location or live device captures.

## Qibla compass

Dashboard → Qibla Compass, or Prayer Times header → Qibla. Opening automatically
starts the sensors, subject to system location permission. Prayer setup is optional.
Saved-location true-north bearing can be shown while acquiring a fix, but there is no directional arrow without real
usable sensors. The live mode uses current coordinates, not a potentially distant
saved city, and does not overwrite prayer settings.

Great-circle initial bearing targets Kaaba coordinates 21.422487° N, 39.826206° E.
Coincident/antipodal directions are undefined. Guidance is suppressed when distance
to the Kaaba is below max(100m, five times reported position uncertainty).

Native Core Location heading + location updates are active only on this screen
after the user opens it. Apple requires location updates to determine `trueHeading`:
https://developer.apple.com/documentation/corelocation/clheading/trueheading
Magnetic heading is never substituted for true heading. Orientation follows the
visible screen (including landscape); circular low-pass smoothing avoids a 359→0
full-turn jump. Native events are limited to 10 Hz; UI stale checks run at 1 Hz.

Invalid heading/negative accuracy, heading age >10s, location age >120s, heading
uncertainty >25°, or location uncertainty >5km hide the arrow. These are conservative
product thresholds, not certified accuracy guarantees. "Approximately aligned"
requires ±5° displayed error and reported compass uncertainty ≤15°. The screen
also requires the latest unsmoothed heading to be within ±5° to avoid smoothing
lag falsely reporting alignment during a turn. The screen
shows reported uncertainty and calibration/interference guidance. Lack of hardware,
denied permission and missing true north are visibly unavailable—not simulated.

Leaving, stopping or backgrounding stops both sensors; returning to foreground
restarts only a previously requested session (including automatic start on entry).
An explicitly stopped session remains stopped. Locations/headings remain in memory,
not recorded or uploaded. iOS permission text now describes both setup and compass.
The operating system may use its own location services; no app geocoding or server
request is made by the compass.

Unit tests cover known-city/axis bearings, degenerate coordinates, wrap smoothing,
invalid/stale samples; injected-stream widget tests cover automatic start, setup-free
entry, alignment, poor-reading suppression, background/resume and Back cancellation. These are not physical magnetometer
validation. Next device checks: rotate through north; test portrait/landscape while
flat; compare a known Qibla direction away from metal; test denied permission,
background/return, current-location travel and sensor shutdown on back navigation.

`docs/screenshots/qibla-ui-fixture.png` is an iPhone-sized Flutter visual test with
injected sensor values (not a physical reading or device screenshot). Production
has no simulated sensor fallback. Cardinal labels use the app font and were
visually checked at 390×844.
