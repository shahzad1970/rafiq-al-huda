# Local Hadith library

## Coverage (2026-09-20)

All ten collections in the pinned Hadith API catalog are included, not every
hadith work in existence. No blanket claim of complete historical editions or
independent authentication is made.

| Collection | Source records |
| --- | ---: |
| Sahih al-Bukhari | 7,589 |
| Sahih Muslim | 7,563 |
| Sunan Abu Dawud | 5,274 |
| Jami at-Tirmidhi | 3,998 |
| Sunan an-Nasa'i | 5,765 |
| Sunan Ibn Majah | 4,343 |
| Muwatta Malik | 1,858 |
| Forty Hadith of an-Nawawi | 42 |
| Forty Hadith Qudsi | 40 |
| Forty Hadith of Shah Waliullah Dehlawi | 40 |

Total: 36,512 source records. 404 have neither text; 408 lack Arabic and 415 lack
English (these include the 404 blank records). There are 36,108 readable records.
Keep source numbering and show missing-text notices; never invent missing Arabic.
The owner subsequently authorized explicitly labeled AI English translations for
the 11 Arabic-only entries; see below. Collection cards disclose fully blank
source records. The list and reader
also explicitly display missing text/translation. Counts differ by edition.

Source supplies books/sections, not a reliable finer chapter hierarchy. UI uses
book titles as supplied, with “Unsectioned narrations” for unnamed sections.

## Source and reproducibility

- https://github.com/fawazahmed0/hadith-api
- Revision `df57907be35291c91ad6a6691180e22ca9920784`
- Editions: `eng-{collection}` and `ara-{collection}`.
- Repository license: Unlicense, bundled at `assets/licenses/hadith-api.txt`.
- Repository licensing is not an independent review of underlying translation
  rights. The existing private/local-use scope remains; any broader distribution
  requires the same source-content review as the other modules.
- Run `node tool/import_hadith.mjs` to regenerate. It fetches JSON only, executes
  no upstream code, checks unique identities, and records SHA-256 of input files
  in `docs/hadith-import-manifest.json`.
- Arabic and English join only on the composite source identity: hadithnumber,
  arabicnumber, reference.book, reference.hadith. All imported identities matched;
  matching identity does not imply text is present or independent editorial
  verification. Unmatched records would remain single-language, not guessed.
- Text is preserved (outer whitespace trimmed). Grades are attributed to the
  named source graders. Empty grading arrays are not labeled authentic or weak.
- Source-edition links are shown; numbering is not assumed to match Sunnah.com.

## Implementation

- Dashboard → Hadith → collection → book → narration, with back navigation.
- Filter collections by name; filter books by title or look up a source-edition
  hadith number. Search Arabic/English within the selected book. Search is not
  claimed to cover the entire library simultaneously.
- Reader: Arabic with existing size setting, English, edition/book references,
  reported grades, copy, previous/next within the book. No audio or AI rulings.
- All data is bundled for offline use (~60 MB JSON). No backend or runtime API.
- Parse each book off the UI isolate and retain at most two parsed books in the
  repository cache. Lazy list rows avoid constructing the entire library UI.
- This module adds no permanent user data, recordings, network requests or history.
- Test coverage audits all record identities/book counts, gaps, searches, cache
  eviction, load failure/retry, and iPhone navigation/reading.
- Screenshots are actual Flutter widget renders at 390×844, not phone captures:
  `flutter test test/hadith_test.dart --dart-define=HADITH_SCREENSHOTS=true`.

## Limits and next work

### Authorized AI English fallback

The eleven Arabic-only Muwatta Malik entries now have bundled AI-generated English:
471, 486, 523, 672, 695, 995, 1055, 1058, 1390, 1598 and 1763 (source numbering).
They were translated by the OpenAI assistant from the pinned Arabic on 2026-09-20,
not independently scholar-reviewed. Narrator chains, reported speech and original
grades are retained; the translations are not new religious/legal rulings.
Context notes flag the continuation in 672, the skin-bag term in 995, and capacity
measures in 1598. Original English fields remain null; generated English lives in
separate `aiEnglish` fields and is never attributed to the source publisher.

The editable translation sidecar is `assets/data/hadith_ai_translations.json`.
The importer verifies each exact Arabic SHA-256, refuses overwriting existing
source English or attaching a translation to absent Arabic, and rejects unused
IDs. Reader, list preview and clipboard identify AI text; the copy includes the
warning and any context note. Search includes generated English. All translations
are pre-generated and bundled: no runtime model, network upload, or API key needed.
All readable entries now have English available (published or explicitly labeled
AI); the 404 records without either source text remain untranslated.

Source accuracy and translation rights need independent review before wider
distribution. Other collections (for example Riyad as-Salihin and Musnad Ahmad)
are not present in this catalog and are not falsely advertised as installed.
They need separately sourced editions with reviewed provenance. Library-wide
indexed search, bookmarks and audio are not implemented in this milestone.
