import 'package:family_income_expense_tracker/core/errors/app_exception.dart';
import 'package:family_income_expense_tracker/features/receipts/domain/entities.dart';
import 'package:family_income_expense_tracker/features/receipts/domain/receipt_image.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:typed_data';

/// The bucket `receipts` is private with a 5 MiB size limit and a 4-entry mime
/// allow list; the app mirrors those rules so a bad pick fails before any
/// bytes leave the device. These are the exact boundaries.
void main() {
  group('mime allow list', () {
    test('accepts exactly the four documented types', () {
      expect(receiptMimeAllowList, [
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf',
      ]);
      for (final mime in receiptMimeAllowList) {
        expect(isAllowedReceiptMime(mime), isTrue, reason: mime);
      }
    });

    test('rejects everything else, including near-misses', () {
      for (final mime in const [
        'image/gif',
        'image/heic',
        'image/jpg',
        'IMAGE/JPEG',
        'image/jpeg ',
        'application/pdf;charset=utf-8',
        'application/octet-stream',
        'text/csv',
        '',
      ]) {
        expect(isAllowedReceiptMime(mime), isFalse, reason: '"$mime"');
      }
    });
  });

  group('size rule', () {
    test('the limit is exactly 5 MiB', () {
      expect(receiptMaxBytes, 5 * 1024 * 1024);
    });

    test('0 bytes is rejected (nothing to store)', () {
      expect(isAllowedReceiptSize(0), isFalse);
    });

    test('1 byte and exactly 5 MiB pass, one byte more does not', () {
      expect(isAllowedReceiptSize(1), isTrue);
      expect(isAllowedReceiptSize(receiptMaxBytes), isTrue);
      expect(isAllowedReceiptSize(receiptMaxBytes + 1), isFalse);
    });
  });

  test('the per-transaction cap is 3', () {
    expect(maxReceiptsPerTransaction, 3);
  });

  group('Receipt', () {
    const receipt = Receipt(
      id: 'r1',
      transactionId: 't1',
      storagePath: 'h1/t1/9f1c.jpg',
      mime: 'image/jpeg',
      sizeBytes: 1000,
    );

    test('file name is the last path segment', () {
      expect(receipt.fileName, '9f1c.jpg');
      expect(receipt.isImage, isTrue);
      expect(receipt.isPdf, isFalse);
    });

    test('a pdf is recognized as such', () {
      const pdf = Receipt(
        id: 'r2',
        transactionId: 't1',
        storagePath: 'h1/t1/9f1c.pdf',
        mime: 'application/pdf',
        sizeBytes: 1000,
      );
      expect(pdf.isPdf, isTrue);
      expect(pdf.isImage, isFalse);
    });

    test('the path always has the three documented segments', () {
      // `<household_id>/<transaction_id>/<uuid>.<ext>` - the storage policies
      // read the first folder and reject anything else.
      expect(receipt.storagePath.split('/').length, 3);
    });
  });

  group('prepareDocumentUpload', () {
    test('a PDF is stored byte-for-byte as picked', () {
      final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
      final upload = prepareDocumentUpload(bytes, 'application/pdf');
      expect(upload.mime, 'application/pdf');
      expect(upload.bytes, bytes);
      expect(upload.sizeBytes, 64);
    });

    test('a mime outside the allow list is refused', () {
      expect(
        () => prepareDocumentUpload(Uint8List(10), 'application/zip'),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', AppErrorCode.invalidMime),
        ),
      );
    });

    test('an oversized document is refused', () {
      expect(
        () => prepareDocumentUpload(
          Uint8List(receiptMaxBytes + 1),
          'application/pdf',
        ),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', AppErrorCode.invalidValue),
        ),
      );
    });

    test('an empty document is refused', () {
      expect(
        () => prepareDocumentUpload(Uint8List(0), 'application/pdf'),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', AppErrorCode.invalidValue),
        ),
      );
    });
  });

  test('bytes that are not an image at all are refused', () {
    expect(
      () => reencodeReceiptImage(Uint8List.fromList(List.filled(32, 7))),
      throwsA(
        isA<AppException>()
            .having((e) => e.code, 'code', AppErrorCode.invalidReceipt),
      ),
    );
  });
}
