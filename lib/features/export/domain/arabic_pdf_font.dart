import 'dart:typed_data';

/// Legacy Unicode *Presentation Forms-B* isolated code point for each standard
/// Arabic letter (`U+0621`..`U+064A`).
///
/// The `pdf` package shapes Arabic by rewriting every letter to its contextual
/// form before drawing it. For a letter that stands alone - which happens in
/// Arabic whenever a YEH follows a non-joining letter such as ALEF, DAL, REH,
/// ZAIN or WAW - the shaper emits the *isolated* form, e.g. `U+FEF1` for YEH.
///
/// Cairo is a modern font: it ships the base letters and shapes through
/// OpenType features, so it carries no glyph for most of these legacy code
/// points. The `pdf` package tries to paper over the gap with a hard-coded
/// table (`bidi_utils.basicToIsolatedMappings`) that points each base letter at
/// its isolated form, but that table maps YEH (`U+064A`) to `U+FEEF` - the
/// **ALEF MAKSURA** isolated form - instead of `U+FEF1`. The shaper's `U+FEF1`
/// therefore resolves to no glyph and the package gives it an advance width of
/// 0, so the YEH is drawn on top of its neighbour (a word like `الشهري` renders
/// with the final YEH overlapping the REH).
const Map<int, int> arabicIsolatedForms = <int, int>{
  0x0621: 0xFE80, // ء
  0x0622: 0xFE81, // آ
  0x0623: 0xFE83, // أ
  0x0624: 0xFE85, // ؤ
  0x0625: 0xFE87, // إ
  0x0626: 0xFE89, // ئ
  0x0627: 0xFE8D, // ا
  0x0628: 0xFE8F, // ب
  0x0629: 0xFE93, // ة
  0x062A: 0xFE95, // ت
  0x062B: 0xFE99, // ث
  0x062C: 0xFE9D, // ج
  0x062D: 0xFEA1, // ح
  0x062E: 0xFEA5, // خ
  0x062F: 0xFEA9, // د
  0x0630: 0xFEAB, // ذ
  0x0631: 0xFEAD, // ر
  0x0632: 0xFEAF, // ز
  0x0633: 0xFEB1, // س
  0x0634: 0xFEB5, // ش
  0x0635: 0xFEB9, // ص
  0x0636: 0xFEBD, // ض
  0x0637: 0xFEC1, // ط
  0x0638: 0xFEC5, // ظ
  0x0639: 0xFEC9, // ع
  0x063A: 0xFECD, // غ
  0x0641: 0xFED1, // ف
  0x0642: 0xFED5, // ق
  0x0643: 0xFED9, // ك
  0x0644: 0xFEDD, // ل
  0x0645: 0xFEE1, // م
  0x0646: 0xFEE5, // ن
  0x0647: 0xFEE9, // ه
  0x0648: 0xFEED, // و
  0x0649: 0xFEEF, // ى
  0x064A: 0xFEF1, // ي
};

/// Returns a copy of [fontBytes] whose `cmap` also resolves every Arabic
/// *isolated* Presentation Forms-B code point in [arabicIsolatedForms], each
/// pointing at the same glyph as the letter it belongs to.
///
/// The fix is applied in memory, so the font asset on disk - and therefore the
/// on-screen UI font - is never modified. Only the bytes handed to the `pdf`
/// package are.
///
/// If the font is not a usable TrueType/OpenType file, or already carries every
/// isolated form, [fontBytes] is returned unchanged.
Uint8List withArabicLetterForms(Uint8List fontBytes) {
  if (fontBytes.length < 12) return fontBytes;
  final source = ByteData.sublistView(fontBytes);
  final numTables = source.getUint16(4);

  var cmapRecord = -1;
  for (var i = 0; i < numTables; i++) {
    final at = 12 + i * 16;
    if (fontBytes[at] == 0x63 && // c
        fontBytes[at + 1] == 0x6D && // m
        fontBytes[at + 2] == 0x61 && // a
        fontBytes[at + 3] == 0x70) {
      // p
      cmapRecord = i;
      break;
    }
  }
  if (cmapRecord < 0) return fontBytes; // No cmap - not a font we can patch.

  final recordAt = 12 + cmapRecord * 16;
  final cmapOffset = source.getUint32(recordAt + 8);
  final cmapLength = source.getUint32(recordAt + 12);
  if (cmapOffset + cmapLength > fontBytes.length) return fontBytes;

  final existing = _readCmap(source, cmapOffset, cmapLength);

  // The isolated forms this font cannot currently reach, mapped to the glyph of
  // the letter they belong to (which *is* the isolated shape).
  final additions = <int, int>{};
  arabicIsolatedForms.forEach((letter, isolated) {
    final glyph = existing[letter];
    if (glyph == null || glyph == 0) return;
    if (existing.containsKey(isolated)) return;
    additions[isolated] = glyph;
  });
  if (additions.isEmpty) return fontBytes; // Nothing to do - already complete.

  final cmap = fontBytes.sublist(cmapOffset, cmapOffset + cmapLength);
  final newCmap = _extendCmap(cmap, _format4Subtable(additions));

  // Append the rebuilt cmap at the end of the file and repoint the directory
  // entry at it. No other table moves, so no other offset changes.
  //
  // Two details make this work with the pdf package's parser:
  //  * `_parseCMap` dispatches on each subtable's `format` field and ignores
  //    the platform/encoding pair, so an extra subtable is always picked up;
  //  * the new subtable is appended LAST, so it is parsed LAST. The package
  //    augments the map itself while reading the original subtable: at the
  //    base letter `U+064A` its buggy table writes `U+FEEF`, which would
  //    otherwise clobber the isolated ALEF MAKSURA. Parsing ours afterwards
  //    lets the correct values win.
  final out = BytesBuilder()..add(fontBytes);
  while (out.length % 4 != 0) {
    out.addByte(0);
  }
  final newOffset = out.length;
  out.add(newCmap);
  final result = out.toBytes();
  final resultData = ByteData.sublistView(result);
  resultData.setUint32(recordAt + 8, newOffset);
  resultData.setUint32(recordAt + 12, newCmap.length);
  return result;
}

/// Reads every `cmap` subtable of [source] into a code point -> glyph id map.
Map<int, int> _readCmap(ByteData source, int base, int length) {
  final result = <int, int>{};
  final subtables = source.getUint16(base + 2);
  for (var i = 0; i < subtables; i++) {
    final subtable = base + source.getUint32(base + 4 + i * 8 + 4);
    final format = source.getUint16(subtable);
    switch (format) {
      case 4:
        _readFormat4(source, subtable, result);
      case 12:
        _readFormat12(source, subtable, result);
    }
  }
  return result;
}

void _readFormat4(ByteData d, int base, Map<int, int> out) {
  final segCount = d.getUint16(base + 6) ~/ 2;
  final endBase = base + 14;
  final startBase = base + 16 + segCount * 2;
  final deltaBase = base + 16 + segCount * 4;
  final rangeBase = base + 16 + segCount * 6;
  for (var s = 0; s < segCount; s++) {
    final end = d.getUint16(endBase + s * 2);
    final start = d.getUint16(startBase + s * 2);
    if (start > end || start == 0xFFFF) continue;
    final delta = d.getUint16(deltaBase + s * 2);
    final rangeOffset = d.getUint16(rangeBase + s * 2);
    for (var c = start; c <= end; c++) {
      final glyph = rangeOffset == 0
          ? (delta + c) & 0xFFFF
          : d.getUint16(rangeBase + s * 2 + rangeOffset + (c - start) * 2);
      if (glyph != 0) out[c] = glyph;
    }
  }
}

void _readFormat12(ByteData d, int base, Map<int, int> out) {
  final groups = d.getUint32(base + 12);
  for (var i = 0; i < groups; i++) {
    final at = base + 16 + i * 12;
    final start = d.getUint32(at);
    final end = d.getUint32(at + 4);
    final startGlyph = d.getUint32(at + 8);
    for (var c = start; c <= end; c++) {
      out[c] = startGlyph + c - start;
    }
  }
}

/// Builds a format-4 `cmap` subtable from [mappings] (code point -> glyph id).
Uint8List _format4Subtable(Map<int, int> mappings) {
  final codes = mappings.keys.toList()..sort();
  final segCount = codes.length + 1; // One segment each, plus the 0xFFFF end.
  final length = 16 + segCount * 8;
  final endBase = 14;
  final startBase = 16 + segCount * 2;
  final deltaBase = 16 + segCount * 4;
  final rangeBase = 16 + segCount * 6;

  var searchRange = 2;
  var entrySelector = 0;
  while (searchRange * 2 <= segCount * 2) {
    searchRange *= 2;
    entrySelector++;
  }

  final subtable = ByteData(length);
  subtable.setUint16(0, 4); // format
  subtable.setUint16(2, length); // length
  subtable.setUint16(4, 0); // language
  subtable.setUint16(6, segCount * 2); // segCountX2
  subtable.setUint16(8, searchRange);
  subtable.setUint16(10, entrySelector);
  subtable.setUint16(12, segCount * 2 - searchRange); // rangeShift
  for (var i = 0; i < codes.length; i++) {
    final code = codes[i];
    final glyph = mappings[code]!;
    subtable.setUint16(endBase + i * 2, code);
    subtable.setUint16(startBase + i * 2, code);
    subtable.setUint16(deltaBase + i * 2, (glyph - code) & 0xFFFF);
    subtable.setUint16(rangeBase + i * 2, 0); // Use idDelta, not glyphIdArray.
  }
  final last = codes.length;
  subtable.setUint16(endBase + last * 2, 0xFFFF);
  subtable.setUint16(startBase + last * 2, 0xFFFF);
  subtable.setUint16(deltaBase + last * 2, 1);
  subtable.setUint16(rangeBase + last * 2, 0);
  return subtable.buffer.asUint8List();
}

/// Adds [subtable] to [cmap] as an extra encoding record.
///
/// The subtable directory grows by one 8-byte record, which shifts every
/// existing subtable body by 8 bytes, so their offsets are bumped by 8. The new
/// subtable itself is appended after the existing bodies.
Uint8List _extendCmap(Uint8List cmap, Uint8List subtable) {
  final source = ByteData.sublistView(cmap);
  final count = source.getUint16(2);
  final builder = BytesBuilder();
  builder.addByte(cmap[0]);
  builder.addByte(cmap[1]);
  final newCount = count + 1;
  builder.addByte((newCount >> 8) & 0xFF);
  builder.addByte(newCount & 0xFF);
  for (var i = 0; i < count; i++) {
    final at = 4 + i * 8;
    final platform = source.getUint16(at);
    final encoding = source.getUint16(at + 2);
    final offset = source.getUint32(at + 4) + 8;
    builder
      ..addByte((platform >> 8) & 0xFF)
      ..addByte(platform & 0xFF)
      ..addByte((encoding >> 8) & 0xFF)
      ..addByte(encoding & 0xFF)
      ..addByte((offset >> 24) & 0xFF)
      ..addByte((offset >> 16) & 0xFF)
      ..addByte((offset >> 8) & 0xFF)
      ..addByte(offset & 0xFF);
  }
  final newSubtableOffset = cmap.length + 8;
  builder
    ..addByte(0)
    ..addByte(3) // Platform: Microsoft
    ..addByte(0)
    ..addByte(10) // Encoding: Unicode full repertoire
    ..addByte((newSubtableOffset >> 24) & 0xFF)
    ..addByte((newSubtableOffset >> 16) & 0xFF)
    ..addByte((newSubtableOffset >> 8) & 0xFF)
    ..addByte(newSubtableOffset & 0xFF);
  builder.add(cmap.sublist(4 + count * 8));
  builder.add(subtable);
  return builder.toBytes();
}
