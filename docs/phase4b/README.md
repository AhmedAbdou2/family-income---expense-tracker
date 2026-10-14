# Phase 4b proof artifacts

## `pdf-sample-ar.pdf` / `pdf-sample-en.pdf` — the pixel check

The PDF summary is built by
`lib/features/export/presentation/pdf_summary.dart` using the `pdf` package,
which has its own Arabic shaping engine (the `bidi` fork it depends on applies
both the BiDi algorithm and the *contextual* letter forms). Three proofs are
automated and one is visual:

| proof | how | where |
| --- | --- | --- |
| the Cairo subset is really embedded | the raw PDF contains `FontFile2` and `Cairo` | `test/pdf_summary_test.dart` |
| the glyphs used are the joined (contextual) forms, not the raw letters | the decompressed `ToUnicode` CMap contains `FE8D FEDF FEE4 FEE0 FEA8 FEBA` for `الملخص` and `FEFB` for `لا`, and does **not** contain the bare `0627 0644 …` | `test/pdf_summary_test.dart` |
| the page is laid out right-to-left | `pdftotext -bbox-layout` word positions: Arabic header at the **right** margin, table names right of the amounts, summary income → expenses → balance right to left, and the mirror image for the English sheet | `test/pdf_summary_layout_test.dart` |
| letters really *look* connected and run RTL | render to PNG and look at it by eye | this folder |

`pdftotext` cannot answer the last one — it prints the same characters whether
the letters were joined or not — so the samples are rendered to PNGs and looked
at by a human.

```sh
# rebuild both samples (also prints the two embedded-font checks)
dart run tool/build_pdf_sample.dart

# render every page of both and open the PNGs
pdftoppm -r 150 -png docs/phase4b/pdf-sample-ar.pdf /tmp/phase4b-ar
pdftoppm -r 150 -png docs/phase4b/pdf-sample-en.pdf /tmp/phase4b-en
```

Look for, in the Arabic sheet: `ملخص الشهر` on one joined line at the **right**
margin, and `أسرة الشهري` in the header line below it — `الشهري` ends in an
*isolated* YEH (a YEH right after a non-joining REH), which is exactly the
letter that used to be drawn with a zero advance and overlap the REH. It must
now sit cleanly to the left of the REH (see `arabic_pdf_font.dart` and
`test/pdf_summary_glyph_advance_test.dart`). Then: the header, divider and
tables sharing the same right edge; table names on the right with their amounts
on the left; the summary reading `الإيرادات … المصروفات … الرصيد` from right to
left; a normal space between `يونيو` and `٢٠٢٦`. In the English sheet the same
page is mirrored (title and names left, amounts right).

The Arabic sample sets `arabicDigits: true` (the Arabic-Indic numerals); the
app's *default* is Western digits (`arabicDigits` defaults to `false` in
Settings), and the PDF follows whatever the setting says.

The samples were reviewed and approved; the PDF action is wired in
(`pdfExportEnabled` in `lib/features/export/presentation/export_screen.dart` is
`true`, and `test/export_layout_test.dart` reflects that). The machine checks
remain in place (Cairo embedding, contextual forms, RTL layout).

### The isolated-letter fix (`arabic_pdf_font.dart`)

The `pdf` package rewrites Arabic letters to their legacy *Presentation
Forms-B* code points. Cairo has no glyph for the isolated forms and the
package's own fallback table points YEH at the ALEF MAKSURA glyph, so a word
ending in a YEH right after a non-joining letter (`الشهري`, `شاي`, `المصري`,
`الدوري`, `البدوي`, …) was drawn with a zero-advance YEH on top of its
neighbour. `lib/features/export/domain/arabic_pdf_font.dart` adds the missing
isolated forms to the *in-memory* font bytes only; the asset (and the UI font)
are untouched.

`test/pdf_summary_glyph_advance_test.dart` is the guard: it proves the check
fails on the unpatched font, then sweeps the whole word list in both weights
and forbids any zero advance except a combining mark. The batch form:

```sh
dart run tool/pdf_word_sweep.dart assets/fonts /tmp/opencode/pdfprobe/sweep
# add `raw` as a third argument to see the pre-fix failures
```

## What Docker cannot prove (cloud checklist)

See the "Phase 4b cloud checklist" section in `AGENTS.md`.
