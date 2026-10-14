// Builds a one-line PDF for every probe word in both weights, so the fixed
// font can be swept for zero-advance glyphs in one run. Run from the project
// root:
//
//   dart run tool/pdf_word_sweep.dart <fontdir> <outdir> [raw]
//
// Passing `raw` skips the in-memory Arabic presentation-form fix, which shows
// exactly which words the pdf package breaks. The permanent guard is
// test/pdf_summary_glyph_advance_test.dart; this tool is the batch equivalent
// used while investigating (render the output and look at it).
import 'dart:io';
import 'dart:typed_data';

import 'package:family_income_expense_tracker/features/export/domain/arabic_pdf_font.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const List<String> words = <String>[
  'الملخص الشهري',
  'ديون',
  'زكريا',
  'ريال',
  'دين',
  'إيجار',
  'وقود',
  'اشتراكات',
  'طعام',
  'مواصلات',
  'صحة',
  'تعليم',
  'ترفيه',
  'هدايا',
  'ملخص الشهر',
  'شاي',
  'المصري',
  'الدوري',
  'البدوي',
  'الأمير',
];

Future<void> main(List<String> args) async {
  final fontDir = args.isNotEmpty ? args[0] : 'assets/fonts';
  final outDir = args.length > 1 ? args[1] : '/tmp/opencode/pdfprobe/sweep';
  final raw = args.length > 2 && args[2] == 'raw';
  Directory(outDir).createSync(recursive: true);
  Uint8List load(String name) {
    final bytes = File('$fontDir/$name').readAsBytesSync();
    return raw ? bytes : withArabicLetterForms(bytes);
  }

  final regular = load('Cairo-Regular.ttf');
  final bold = load('Cairo-Bold.ttf');
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(ByteData.sublistView(regular)),
    bold: pw.Font.ttf(ByteData.sublistView(bold)),
  );
  var index = 0;
  for (final word in words) {
    for (final isBold in <bool>[false, true]) {
      final document = pw.Document(compress: false);
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          textDirection: pw.TextDirection.rtl,
          build: (context) => <pw.Widget>[
            pw.Text(
              word,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                wordSpacing: 2,
              ),
            ),
          ],
        ),
      );
      final bytes = Uint8List.fromList(await document.save());
      final safe = 'w${index.toString().padLeft(2, '0')}';
      File('$outDir/$safe.pdf').writeAsBytesSync(bytes);
      File('$outDir/$safe.txt')
          .writeAsStringSync('${isBold ? 'bold' : 'regular'}\t$word');
      index++;
    }
  }
  stdout.writeln('wrote $index PDFs to $outDir (raw=$raw)');
}
