import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Machine-checkable view of the glyphs a PDF actually draws.
///
/// The `pdf` package compresses the page content and the font's ToUnicode CMap,
/// so both have to be inflated (see [inflatePdfStreams]) before they can be
/// read. This file turns a document produced by `buildMonthSummaryPdf` into a
/// list of drawn glyphs with their *advance width*, which is what decides
/// whether a letter sits next to its neighbour or on top of it.
///
/// The reader is deliberately small and only understands what this app emits:
/// one Type0 / Identity-H TrueType font, `Tf`/`Td`/`Tm`/`TJ`/`Tj` operators and
/// a `/W` width array. That is enough to catch a zero-width glyph, which is the
/// failure mode behind the overlapping Arabic letters.

/// A glyph as it is actually placed on the page.
class PdfDrawnGlyph {
  const PdfDrawnGlyph({
    required this.cid,
    required this.codePoint,
    required this.advance,
    required this.x,
  });

  /// The character id in the page's font.
  final int cid;

  /// The Unicode code point the font maps [cid] to.
  final int codePoint;

  /// Advance width in 1/1000 em (0 means the glyph does not move the pen).
  final int advance;

  /// The pen x position (in points) where the glyph is drawn.
  final double x;

  @override
  String toString() =>
      'U+${codePoint.toRadixString(16).toUpperCase().padLeft(4, '0')} '
      'cid=$cid advance=$advance x=${x.toStringAsFixed(2)}';
}

/// A single `Tf` run: the glyphs drawn at one font size.
class PdfGlyphRun {
  const PdfGlyphRun({required this.fontSize, required this.glyphs});

  final double fontSize;
  final List<PdfDrawnGlyph> glyphs;
}

/// True for the Arabic combining marks that the `pdf` package deliberately
/// draws with no advance (they sit on the previous letter). They are the only
/// glyphs allowed to have a zero advance.
bool isArabicDiacritic(int codePoint) =>
    (codePoint >= 0x064B && codePoint <= 0x0652) ||
    codePoint == 0x0670 ||
    (codePoint >= 0xFC5E && codePoint <= 0xFC63);

bool _isHighSurrogate(int code) => code >= 0xD800 && code <= 0xDBFF;

/// Reads every drawn glyph from a document produced by `buildMonthSummaryPdf`.
List<PdfGlyphRun> readPdfGlyphRuns(Uint8List pdf) {
  final raw = latin1.decode(pdf);
  final inflated = inflatePdfStreams(pdf);
  final cidToCodePoint = _readToUnicode(inflated);
  final widths = _readWidths(raw);
  final twoByteCids = raw.contains('/Identity-H');

  final runs = <PdfGlyphRun>[];
  for (final block in _btBlocks(inflated)) {
    var fontSize = 12.0;
    var x = 0.0;
    var glyphs = <PdfDrawnGlyph>[];
    void flush() {
      if (glyphs.isNotEmpty) {
        runs.add(PdfGlyphRun(fontSize: fontSize, glyphs: glyphs));
        glyphs = <PdfDrawnGlyph>[];
      }
    }

    for (final match in _operators.allMatches(block)) {
      if (match.group(1) != null) {
        fontSize = double.parse(match.group(2)!);
      } else if (match.group(3) != null) {
        x = double.parse(match.group(7)!); // Tm e (f is group 8)
      } else if (match.group(9) != null) {
        x += double.parse(match.group(9)!); // Td tx
      } else if (match.group(11) != null) {
        _walkShowText(
          match.group(11)!,
          twoByteCids: twoByteCids,
          fontSize: fontSize,
          widths: widths,
          cidToCodePoint: cidToCodePoint,
          startX: x,
          emit: (glyph) {
            glyphs.add(glyph);
            x += glyph.advance / 1000 * fontSize;
          },
        );
      } else if (match.group(12) != null) {
        _walkShowText(
          '<${match.group(12)}>',
          twoByteCids: twoByteCids,
          fontSize: fontSize,
          widths: widths,
          cidToCodePoint: cidToCodePoint,
          startX: x,
          emit: (glyph) {
            glyphs.add(glyph);
            x += glyph.advance / 1000 * fontSize;
          },
        );
      }
    }
    flush();
  }
  return runs;
}

final RegExp _operators = RegExp(
  r'/(F\d+)\s+([0-9.]+)\s+Tf' // 1 font, 2 size
  r'|(-?[0-9.]+)\s+(-?[0-9.]+)\s+(-?[0-9.]+)\s+(-?[0-9.]+)\s+'
  r'(-?[0-9.]+)\s+(-?[0-9.]+)\s+Tm' // 3..8
  r'|(-?[0-9.]+)\s+(-?[0-9.]+)\s+(?:Td|TD)' // 9 tx, 10 ty
  r'|\[([^\]]*)\]\s*TJ' // 11 array
  r'|<([0-9A-Fa-f]+)>\s*Tj', // 12 hex string
);

final RegExp _tjItems = RegExp(r'<([0-9A-Fa-f]+)>|(-?[0-9.]+)');

void _walkShowText(
  String array, {
  required bool twoByteCids,
  required double fontSize,
  required Map<int, int> widths,
  required Map<int, int> cidToCodePoint,
  required double startX,
  required void Function(PdfDrawnGlyph) emit,
}) {
  var x = startX;
  for (final item in _tjItems.allMatches(array)) {
    if (item.group(1) != null) {
      final hex = item.group(1)!;
      final step = twoByteCids ? 4 : 2;
      for (var i = 0; i + step <= hex.length; i += step) {
        final cid = int.parse(hex.substring(i, i + step), radix: 16);
        final advance = widths[cid] ?? 1000;
        emit(
          PdfDrawnGlyph(
            cid: cid,
            codePoint: cidToCodePoint[cid] ?? -1,
            advance: advance,
            x: x,
          ),
        );
        x += advance / 1000 * fontSize;
      }
    } else if (item.group(2) != null) {
      // A kerning adjustment moves the pen backwards without drawing.
      x -= double.parse(item.group(2)!) / 1000 * fontSize;
    }
  }
}

/// The `BT`..`ET` text blocks of a page content stream.
Iterable<String> _btBlocks(String content) sync* {
  for (final match in RegExp(r'BT(.*?)ET', dotAll: true).allMatches(content)) {
    yield match.group(1)!;
  }
}

/// CID -> code point from every `beginbfchar` / `beginbfrange` block found in
/// the inflated streams (the document uses a single embedded font).
Map<int, int> _readToUnicode(String inflated) {
  final map = <int, int>{};
  for (final block in RegExp(
    r'beginbfchar(.*?)endbfchar',
    dotAll: true,
  ).allMatches(inflated)) {
    for (final pair in RegExp(
      r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>',
    ).allMatches(block.group(1)!)) {
      map[int.parse(pair.group(1)!, radix: 16)] = _utf16Be(pair.group(2)!);
    }
  }
  for (final block in RegExp(
    r'beginbfrange(.*?)endbfrange',
    dotAll: true,
  ).allMatches(inflated)) {
    for (final range in RegExp(
      r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>',
    ).allMatches(block.group(1)!)) {
      final lo = int.parse(range.group(1)!, radix: 16);
      final hi = int.parse(range.group(2)!, radix: 16);
      final dst = int.parse(range.group(3)!, radix: 16);
      for (var c = lo; c <= hi; c++) {
        map[c] = dst + c - lo;
      }
    }
  }
  return map;
}

int _utf16Be(String hex) {
  final bytes = <int>[];
  for (var i = 0; i + 2 <= hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  var index = 0;
  while (index + 1 < bytes.length) {
    final unit = (bytes[index] << 8) | bytes[index + 1];
    if (_isHighSurrogate(unit) && index + 3 < bytes.length) {
      final low = (bytes[index + 2] << 8) | bytes[index + 3];
      if (low >= 0xDC00 && low <= 0xDFFF) {
        return 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00);
      }
    }
    return unit;
  }
  return -1;
}

/// CID -> advance width in 1/1000 em, from the CIDFont's `/W` array.
Map<int, int> _readWidths(String raw) {
  final match = RegExp(r'/W\s*\[\s*(\d+)\s+(\d+)\s+0\s+R\s*\]').firstMatch(raw);
  if (match == null) return const {};
  final start = int.parse(match.group(1)!);
  final objectNumber = int.parse(match.group(2)!);
  final body = _objectBody(raw, objectNumber);
  if (body == null) return const {};
  final bracket = RegExp(r'\[(.*)\]', dotAll: true).firstMatch(body);
  if (bracket == null) return const {};
  final widths = <int, int>{};
  var cid = start;
  for (final value in RegExp(r'-?\d+').allMatches(bracket.group(1)!)) {
    widths[cid] = int.parse(value.group(0)!);
    cid++;
  }
  return widths;
}

String? _objectBody(String raw, int number) {
  final marker = '$number 0 obj';
  final start = raw.indexOf(marker);
  if (start < 0) return null;
  final end = raw.indexOf('endobj', start);
  return end < 0 ? null : raw.substring(start + marker.length, end);
}

/// Every FlateDecode stream in the document, inflated and concatenated.
String inflatePdfStreams(Uint8List pdf) {
  final zlib = ZLibDecoder();
  final buffer = StringBuffer();
  var index = 0;
  while (true) {
    final start = _indexOf(pdf, 'stream', index);
    if (start < 0) break;
    var cursor = start + 'stream'.length;
    if (pdf[cursor] == 0x0D) cursor++;
    if (pdf[cursor] == 0x0A) cursor++;
    final end = _indexOf(pdf, 'endstream', cursor);
    if (end < 0) break;
    final chunk = Uint8List.sublistView(pdf, cursor, end);
    try {
      buffer.write(latin1.decode(zlib.convert(chunk)));
    } catch (_) {
      buffer.write(latin1.decode(chunk));
    }
    index = end + 'endstream'.length;
  }
  return buffer.toString();
}

int _indexOf(Uint8List bytes, String needle, int from) {
  final target = ascii.encode(needle);
  for (var i = from; i <= bytes.length - target.length; i++) {
    var matched = true;
    for (var j = 0; j < target.length; j++) {
      if (bytes[i + j] != target[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return i;
  }
  return -1;
}
