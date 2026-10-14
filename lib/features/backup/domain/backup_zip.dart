import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One receipt object that made it into the archive.
class BackupReceiptBlob {
  const BackupReceiptBlob({required this.storagePath, required this.bytes});

  final String storagePath;
  final List<int> bytes;
}

/// Packs the archive in memory: `data.json`, `manifest.json`, and every
/// receipt object under `receipts/<storage_path>`.
///
/// The ZIP is NOT encrypted - the Backup card says so in plain language and
/// `docs/backup.md` repeats it. Kept free of any Flutter/Supabase dependency
/// so it is unit-testable byte-for-byte.
Uint8List buildBackupZip({
  required List<int> dataJson,
  required List<int> manifestJson,
  required List<BackupReceiptBlob> receipts,
}) {
  final archive = Archive();
  archive.addFile(ArchiveFile.bytes('data.json', dataJson));
  archive.addFile(ArchiveFile.bytes('manifest.json', manifestJson));
  for (final receipt in receipts) {
    final file = ArchiveFile.bytes('receipts/${receipt.storagePath}', receipt.bytes);
    // Receipts are JPEG/PNG/WebP/PDF - already compressed. Storing them keeps
    // a large archive from burning CPU (and time) on deflate for no gain.
    file.compression = CompressionType.none;
    archive.addFile(file);
  }
  return ZipEncoder().encodeBytes(archive);
}
