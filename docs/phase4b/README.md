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

Look for, in the Arabic sheet: `الملخص الشهري` on one joined line at the **right**
margin; the header, divider and tables sharing the same right edge; table names
on the right with their amounts on the left; the summary reading
`الإيرادات … المصروفات … الرصيد` from right to left; a normal space between
`يونيو` and `٢٠٢٦`. In the English sheet the same page is mirrored (title and
names left, amounts right).

The Arabic sample sets `arabicDigits: true` (the Arabic-Indic numerals); the
app's *default* is Western digits (`arabicDigits` defaults to `false` in
Settings), and the PDF follows whatever the setting says.

**Until that review happens the PDF action stays hidden from users**:
`pdfExportEnabled` in `lib/features/export/presentation/export_screen.dart` is
`false`, and `test/export_layout_test.dart` pins it that way. Flipping the
constant to `true` is the whole wiring change; do it once the samples above look
right (and update that test on purpose).

## What Docker cannot prove (cloud checklist)

See the "Phase 4b cloud checklist" section in `AGENTS.md`.
