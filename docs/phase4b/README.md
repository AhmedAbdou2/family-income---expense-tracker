# Phase 4b proof artifacts

## `pdf-sample-ar.pdf` — the one thing a machine cannot check

The Arabic PDF summary is built by `lib/features/export/presentation/pdf_summary.dart`
using the `pdf` package, which has its own Arabic shaping engine (the `bidi`
fork it depends on applies both the BiDi algorithm and the *contextual* letter
forms). Two of the three proofs are automated:

| proof | how | where |
| --- | --- | --- |
| the Cairo subset is really embedded | the raw PDF contains `FontFile2` and `Cairo` | `test/pdf_summary_test.dart` |
| the glyphs used are the joined (contextual) forms, not the raw letters | the decompressed `ToUnicode` CMap contains `FE8D FEDF FEE4 FEE0 FEA8 FEBA` for `الملخص` and `FEFB` for `لا`, and does **not** contain the bare `0627 0644 …` | `test/pdf_summary_test.dart` |

The third proof is visual: whether those glyphs, as rendered, actually *look*
connected and run right-to-left. `pdftotext` cannot answer that — it prints the
same characters either way — so the sample is rendered to a PNG and looked at
by a human.

```sh
# rebuild the sample (also prints the two automated checks)
dart run tool/build_pdf_sample.dart

# render it and open the PNG(s)
pdftoppm -r 150 -png docs/phase4b/pdf-sample-ar.pdf /tmp/phase4b-ar
```

Look for: `الملخص الشهري` on one joined line, the `لا` in `لا توجد` joined as a
single ligature, the amounts on the opposite side of the row from the labels
(the page is laid out RTL), and Arabic-Indic digits (the sample sets
`arabicDigits: true`).

**Until that review happens the PDF action stays hidden from users**:
`pdfExportEnabled` in `lib/features/export/presentation/export_screen.dart` is
`false`, and `test/export_layout_test.dart` pins it that way. Flipping the
constant to `true` is the whole wiring change; do it once the sample above
looks right (and update that test on purpose).

## What Docker cannot prove (cloud checklist)

See the "Phase 4b cloud checklist" section in `AGENTS.md` — the storage bucket,
signed URLs, upload rejection and cross-household lockout can only be proven
against the real Supabase Storage.
