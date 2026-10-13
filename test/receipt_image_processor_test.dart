import 'dart:typed_data';

import 'package:family_income_expense_tracker/features/receipts/domain/entities.dart';
import 'package:family_income_expense_tracker/features/receipts/domain/receipt_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// The re-encoder is the privacy boundary: a photo taken on a phone carries
/// EXIF with GPS, and the stored file must not (AMENDMENT D). It also has to
/// downscale to [receiptMaxDimension] and stay inside the bucket's size cap.
Uint8List _sourceJpeg({
  int width = 2400,
  int height = 1200,
  int? orientation,
  bool withGps = false,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(90, 120, 150));
  // Some structure, so the JPEG is a realistic size and resizing is visible.
  for (var y = 0; y < height; y += 40) {
    img.fillRect(
      image,
      x1: 0,
      y1: y,
      x2: width,
      y2: y + 20,
      color: img.ColorRgb8(200, 30, 30),
    );
  }
  image.exif.imageIfd.make = 'TestCam';
  image.exif.imageIfd.model = 'TestCam 1';
  if (orientation != null) image.exif.imageIfd.orientation = orientation;
  if (withGps) {
    image.exif.gpsIfd.setGpsLocation(latitude: 30.0444, longitude: 31.2357);
  }
  return img.encodeJpg(image, quality: 95);
}

void main() {
  test('the fixture really carries EXIF + GPS', () {
    final decoded = img.decodeImage(_sourceJpeg(withGps: true))!;

    expect(decoded.exif.isEmpty, isFalse);
    expect(decoded.exif.imageIfd.make, 'TestCam');
    expect(decoded.exif.gpsIfd.gpsLatitude, closeTo(30.0444, 0.001));
    expect(decoded.width, 2400);
    expect(decoded.height, 1200);
  });

  test('the re-encoded file has no EXIF and no GPS left', () {
    final output = reencodeReceiptImage(_sourceJpeg(withGps: true));
    final decoded = img.decodeImage(output)!;

    expect(decoded.exif.isEmpty, isTrue);
    expect(decoded.exif.gpsIfd.isEmpty, isTrue);
    expect(decoded.exif.getTag(0x010f), isNull); // Make
    expect(decoded.exif.imageIfd.hasOrientation, isFalse);
  });

  test('a big photo is downscaled so the long edge is 1600', () {
    final output = reencodeReceiptImage(_sourceJpeg());
    final decoded = img.decodeImage(output)!;

    expect(decoded.width, receiptMaxDimension);
    expect(decoded.height, 800);
    expect(output.length, lessThanOrEqualTo(receiptMaxBytes));
  });

  test('a portrait photo keeps its orientation, long edge capped', () {
    final output = reencodeReceiptImage(_sourceJpeg(width: 1200, height: 2400));
    final decoded = img.decodeImage(output)!;

    expect(decoded.height, receiptMaxDimension);
    expect(decoded.width, 800);
  });

  test('EXIF orientation 6 is applied to the pixels before being dropped', () {
    // 2400x1200 tagged "rotate 90 clockwise" -> the stored pixels must be
    // 1200x2400 (then capped to 800x1600), not the pre-rotation shape.
    final output = reencodeReceiptImage(
      _sourceJpeg(orientation: 6),
    );
    final decoded = img.decodeImage(output)!;

    expect(decoded.width, 800);
    expect(decoded.height, receiptMaxDimension);
    expect(decoded.exif.isEmpty, isTrue);
  });

  test('a small image is never upscaled', () {
    final output = reencodeReceiptImage(_sourceJpeg(width: 100, height: 60));
    final decoded = img.decodeImage(output)!;

    expect(decoded.width, 100);
    expect(decoded.height, 60);
  });

  test('the result is always a JPEG', () {
    final output = reencodeReceiptImage(_sourceJpeg(width: 50, height: 50));
    // JPEG SOI marker.
    expect(output.sublist(0, 2), const [0xFF, 0xD8]);
    expect(img.findFormatForData(output), img.ImageFormat.jpg);
  });

  test('prepareImageUpload wraps it as image/jpeg', () {
    final upload = prepareImageUpload(_sourceJpeg(width: 50, height: 50));
    expect(upload.mime, 'image/jpeg');
    expect(upload.sizeBytes, upload.bytes.length);
    expect(isAllowedReceiptSize(upload.sizeBytes), isTrue);
  });

  test('the quality knob is honoured (a tiny quality makes a smaller file)',
      () {
    final source = _sourceJpeg();
    final high = reencodeReceiptImage(source, quality: 95);
    final low = reencodeReceiptImage(source, quality: 40);
    expect(low.length, lessThan(high.length));
  });
}
