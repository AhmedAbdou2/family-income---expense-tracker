// Builds the PDF summary samples that AMENDMENT F requires a human to eyeball
// before the PDF path is wired into the app.
//
// Run from the project root:
//   dart run tool/build_pdf_sample.dart
// then render every page and LOOK at the letters:
//   pdftoppm -r 150 -png docs/phase4b/pdf-sample-ar.pdf /tmp/phase4b-ar
//   pdftoppm -r 150 -png docs/phase4b/pdf-sample-en.pdf /tmp/phase4b-en
//
// Why a sample at all: the `pdf` package shapes Arabic itself (BiDi +
// contextual letter forms), and `pdftotext` cannot prove that - the extracted
// characters look the same whether the letters were joined or not. Only the
// rendered pixels can. The machine-checkable half (positions, RTL order,
// title completeness) lives in test/pdf_summary_layout_test.dart.
import 'dart:io';

import 'pdf_summary_fixture.dart';

Future<void> main() async {
  await _write(arabic: true, name: 'pdf-sample-ar.pdf');
  await _write(arabic: false, name: 'pdf-sample-en.pdf');
}

Future<void> _write({required bool arabic, required String name}) async {
  final bytes = await buildSamplePdf(arabic: arabic);
  final output = File('docs/phase4b/$name');
  output.parent.createSync(recursive: true);
  output.writeAsBytesSync(bytes);

  // The automated half of the proof: the font program really is embedded and
  // the file is a real PDF. Whether the glyphs are CONNECTED and in RTL order
  // is the rendered-PNG check above.
  final raw = String.fromCharCodes(bytes);
  stdout.writeln('wrote ${output.path} (${bytes.length} bytes)');
  stdout.writeln('  embedded font program: ${raw.contains('FontFile2')}');
  stdout.writeln('  cairo family name in fonts: ${raw.contains('Cairo')}');
}
