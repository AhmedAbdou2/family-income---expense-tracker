#!/usr/bin/env python3
"""Regenerate test/support/arabic_presentation_forms.dart.

The `pdf` package shapes Arabic into the Unicode Arabic Presentation Forms-B
block (contextual glyphs). `pdftotext` therefore hands back shaped code points,
not the original letters. This table (taken from the Unicode character
database, `unicodedata.decomposition`) maps each shaped code point back to its
base letter(s) so a test can compare an extracted PDF word with the string that
was drawn.

Run from the repository root:

    python3 tool/gen_arabic_presentation_forms.py > test/support/arabic_presentation_forms.dart
"""

import unicodedata

lines = []
for cp in range(0xFE70, 0xFF00):
    decomposition = unicodedata.decomposition(chr(cp))
    if not decomposition or not decomposition.startswith('<'):
        continue
    rest = decomposition.split('>')[1].strip().split()
    if not rest:
        continue
    bases = ''.join(chr(int(part, 16)) for part in rest)
    escaped = ''.join('\\u%04X' % ord(char) for char in bases)
    lines.append("  0x%04X: '%s'," % (cp, escaped))

print("// GENERATED from the Unicode character database (unicodedata.decomposition)")
print("// for the Arabic Presentation Forms-B block (U+FE70..U+FEFF). Each entry")
print("// maps a shaped glyph code point back to its base letter(s), so a")
print("// `pdftotext` extract of a rendered PDF can be turned back into logical")
print("// text and compared with the source string.")
print("//")
print("// Regenerate with tool/gen_arabic_presentation_forms.py.")
print()
print("/// Shaped Arabic (Presentation Forms-B) to base-letter(s).")
print("const Map<int, String> kArabicPresentationForms = <int, String>{")
print('\n'.join(lines))
print("};")
