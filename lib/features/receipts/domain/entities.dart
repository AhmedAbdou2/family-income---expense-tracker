import 'dart:typed_data';

/// Transaction receipts (Phase 4b). Pure Dart - no Flutter or Supabase
/// imports, so the shape rules below are unit-testable.

/// The mime allow list the `receipts` bucket enforces server-side. Mirrored
/// here so an unsupported pick fails before any bytes are uploaded.
const List<String> receiptMimeAllowList = <String>[
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
];

/// 5 MiB - the bucket's `file_size_limit`.
const int receiptMaxBytes = 5 * 1024 * 1024;

/// The cap enforced by `request_receipt_upload` / the table trigger.
const int maxReceiptsPerTransaction = 3;

/// Long edge of a stored photo, in pixels. Bigger images are downscaled by
/// the picker (and again by the pure re-encoder).
const int receiptMaxDimension = 1600;

/// JPEG quality used by the re-encoder.
const int receiptJpegQuality = 85;

/// One attachment of a transaction. Only the metadata lives in Postgres
/// (`transaction_receipts`); the bytes live in the private Storage bucket
/// `receipts` at [storagePath].
class Receipt {
  const Receipt({
    required this.id,
    required this.transactionId,
    required this.storagePath,
    required this.mime,
    required this.sizeBytes,
    this.createdAt,
  });

  final String id;
  final String transactionId;

  /// `<household_id>/<transaction_id>/<uuid>.<ext>` - minted server-side.
  final String storagePath;

  final String mime;
  final int sizeBytes;
  final DateTime? createdAt;

  bool get isImage => mime.startsWith('image/');
  bool get isPdf => mime == 'application/pdf';

  String get fileName => storagePath.split('/').last;
}

/// Bytes ready to upload: the picker's file after the pure re-encode /
/// validation pass, together with the mime type we will declare.
class ReceiptUpload {
  const ReceiptUpload({required this.bytes, required this.mime});

  final Uint8List bytes;
  final String mime;

  int get sizeBytes => bytes.length;
}

/// True when [mime] is one the bucket accepts.
bool isAllowedReceiptMime(String mime) => receiptMimeAllowList.contains(mime);

/// Client-side mirror of the server's size rule.
bool isAllowedReceiptSize(int sizeBytes) =>
    sizeBytes > 0 && sizeBytes <= receiptMaxBytes;
