# Duʿā library

The local library contains 91 unique entries in 15 categories: 32 Qur'anic
supplications and 59 imported supplication/remembrance texts. This is not an
exhaustive collection of all duas or a complete Hisn al-Muslim edition.

The 59 imported texts come from Fitrahive Dua & Dhikr, MIT license, pinned at
`f42f895f914319a844c3e3c2279483cae060ea19`. Arabic and English are preserved from
that collection; references and source-file URLs are shown on detail screens.
Its individual hadith references/gradings have not all been independently checked;
the screen explicitly says so. No blanket authenticity claim is made. Repetition
counts, reward claims and benefits are omitted. Titles are shortened for browsing;
the count/reward wording in two titles is replaced with neutral wording.

Run `node tool/import_duas.mjs` then `dart format lib/core/dua/dua_imported.dart`
to reproduce the imported catalog. The import manifest records upstream hashes
and each omission. Of 97 source rows, 22 were omitted: missing reference (3),
existing Qur'anic entries (3), Quran-module recitations (12), and combined formulas
or unclear contexts pending review (4). Sixteen repeated texts were merged.
Merged entries preserve alternate titles in search, category membership, and
source references. Distinct wording remains distinct. Favourites use stable IDs.
No upstream programs are executed, and no runtime network/API is needed.

New categories cover morning/evening, sleep, home, food/fasting, prayer/mosque,
travel, weather, and protection. Topic categories are browsing aids, not rulings.
Collection-based occasion labels retain the upstream context, not new prescriptions.

Qur'anic Arabic comes unchanged from the existing Quran repository's IndoPak display words.
The catalog records zero-based start/end word offsets; end is exclusive. Excerpts
are labelled in the reading screen. Brief English meanings are editorial renderings,
not quotations attributed to a published translator. Check with a qualified teacher
before adding practice-specific guidance. The extra 22 Qur'anic excerpts have
their exact source verses and zero-based word offsets in `dua_catalog.dart`;
tests validate every span and category. Their meanings are editorial paraphrases.

| Entry | Verse/source | Words |
| --- | --- | --- |
| Goodness in both worlds | https://quran.com/2/201 | 3–end |
| Knowledge | https://quran.com/20/114 | 14–end |
| Steadfast heart | https://quran.com/3/8 | whole verse |
| Repentance | https://quran.com/7/23 | 1–end |
| Mercy | https://quran.com/23/118 | 1–end |
| Parents and believers | https://quran.com/14/41 | whole verse |
| Family | https://quran.com/25/74 | 2–end |
| Need/provision | https://quran.com/28/24 | 7–end |
| Patience | https://quran.com/2/250 | 5–11 (excerpt) |
| Acceptance | https://quran.com/2/127 | 7–end |

Starter source verse pages and all local word spans checked 2026-09-20. Existing Quran text/font
provenance and distribution restrictions continue to apply. No new speech grading
or dua audio is represented as available. Reading/search/favourites work offline.

Fitrahive attribution/license is bundled in `assets/licenses/fitrahive-dua-dhikr.txt`
and visible in each imported entry's source section. MIT licensing at the repository
level is recorded; an independent upstream translation-rights audit remains part
of any future distribution review. No TestFlight upload was made for this change.

Screenshots in `docs/screenshots/dua-*.png` are rendered from the actual Flutter
widgets at 390×844 logical pixels, not AI mockups or connected-phone captures.
Generate on the development Mac using:
`flutter test test/dua_test.dart --dart-define=DUA_SCREENSHOTS=true`.
