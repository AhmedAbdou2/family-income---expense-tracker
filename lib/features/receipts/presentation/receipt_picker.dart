import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/entities.dart';
import '../domain/receipt_image.dart';

/// Where a receipt comes from. Camera + gallery go through image_picker,
/// "document" opens the file picker so a scanned PDF can be attached too.
enum ReceiptSource { camera, gallery, document }

/// Picks a file and normalizes it into something the bucket accepts.
///
/// Returns null when the user cancels. Throws [AppException] for a file we
/// refuse (wrong type / too big).
///
/// Note on threading: the decode+re-encode runs through [compute], so on
/// mobile/desktop the JPEG work happens on a worker isolate and cannot jank
/// the UI. On Flutter web `compute` runs inline, which is why the picker is
/// also told to downscale (`maxWidth`/`maxHeight`/`imageQuality`) - the work
/// left for the isolate is then small.
Future<ReceiptUpload?> pickReceiptUpload(ReceiptSource source) async {
  switch (source) {
    case ReceiptSource.camera:
    case ReceiptSource.gallery:
      final picked = await ImagePicker().pickImage(
        source: source == ReceiptSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: receiptMaxDimension.toDouble(),
        maxHeight: receiptMaxDimension.toDouble(),
        imageQuality: 80,
      );
      if (picked == null) return null;
      final raw = await picked.readAsBytes();
      return ReceiptUpload(
        bytes: await compute(reencodeReceiptImage, raw),
        mime: 'image/jpeg',
      );

    case ReceiptSource.document:
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return null;

      // A PDF is stored as-is (re-encoding it would be pointless); an image
      // is normalized exactly like a photo.
      if (picked.extension?.toLowerCase() == 'pdf') {
        return prepareDocumentUpload(bytes, 'application/pdf');
      }
      return ReceiptUpload(
        bytes: await compute(reencodeReceiptImage, bytes),
        mime: 'image/jpeg',
      );
  }
}
