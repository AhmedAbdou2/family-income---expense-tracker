import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/errors/app_exception.dart';
import 'entities.dart';

/// Re-encodes a picked image into the form we store.
///
/// Guarantees, all of them asserted by tests:
///   * the result is a JPEG (`image/jpeg`);
///   * no EXIF block survives - in particular no GPS tags (the source
///     photo's `bakeOrientation` is applied first so the pixels are right,
///     then the metadata is dropped);
///   * the long edge is at most [maxDimension];
///   * the bytes fit the bucket's 5 MiB cap.
///
/// Pure Dart and isolate-friendly: the app runs it through `compute` so a
/// 12 MP photo never blocks the UI thread. On Flutter web `compute` runs
/// inline, which is why the picker is also told to downscale (see
/// `receipt_image_picker.dart`) - the work here stays small either way.
Uint8List reencodeReceiptImage(
  Uint8List input, {
  int maxDimension = receiptMaxDimension,
  int quality = receiptJpegQuality,
}) {
  final decoded = img.decodeImage(input);
  if (decoded == null) {
    throw const AppException(AppErrorCode.invalidReceipt);
  }

  // Apply the camera's EXIF rotation to the pixels, then throw the EXIF
  // block (and its GPS tags) away.
  var image = img.bakeOrientation(decoded);
  image.exif.clear();

  if (image.width > maxDimension || image.height > maxDimension) {
    image = image.width >= image.height
        ? img.copyResize(
            image,
            width: maxDimension,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            image,
            height: maxDimension,
            interpolation: img.Interpolation.average,
          );
    // copyResize builds a fresh image; clear again so this holds even if a
    // future version starts carrying metadata across.
    image.exif.clear();
  }

  final bytes = img.encodeJpg(image, quality: quality);
  if (bytes.length > receiptMaxBytes) {
    // Only reachable for an extremely detailed image at 1600px; the retry
    // keeps the guarantee instead of letting the upload be rejected.
    image.exif.clear();
    return img.encodeJpg(image, quality: 60);
  }
  return bytes;
}

/// Wraps [input] as a ready-to-upload JPEG.
ReceiptUpload prepareImageUpload(Uint8List input) {
  final bytes = reencodeReceiptImage(input);
  return ReceiptUpload(bytes: bytes, mime: 'image/jpeg');
}

/// Validates a document (PDF) picked from the device. Documents are stored
/// as-is - re-encoding a PDF would be pointless, so only the bucket's rules
/// are re-checked here.
ReceiptUpload prepareDocumentUpload(Uint8List input, String mime) {
  if (!isAllowedReceiptMime(mime)) {
    throw const AppException(AppErrorCode.invalidMime);
  }
  if (!isAllowedReceiptSize(input.length)) {
    throw const AppException(AppErrorCode.invalidValue);
  }
  return ReceiptUpload(bytes: input, mime: mime);
}
