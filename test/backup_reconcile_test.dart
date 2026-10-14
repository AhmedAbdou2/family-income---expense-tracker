import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:family_income_expense_tracker/core/errors/app_exception.dart';
import 'package:family_income_expense_tracker/core/utils/money.dart';
import 'package:family_income_expense_tracker/features/backup/data/backup_service.dart';
import 'package:family_income_expense_tracker/features/backup/domain/backup_repository.dart';
import 'package:family_income_expense_tracker/features/backup/domain/backup_tables.dart';
import 'package:family_income_expense_tracker/features/household/domain/dashboard_summary.dart';
import 'package:family_income_expense_tracker/features/recurring/domain/entities.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';

/// The backup must agree with the dashboard on the same source rows. The
/// fixture is the one the Budgets/Reports/Export reconcile tests use, so the
/// expense total is exactly 23,845.67.
final _month = DateTime(DateTime.now().year, DateTime.now().month);

final _transactions = <Transaction>[
  Transaction(
    id: 't1',
    householdId: 'h1',
    type: TransactionType.expense,
    amountMinorUnits: 1234567,
    categoryId: 'food',
    memberId: 'm1',
    date: _month,
  ),
  Transaction(
    id: 't2',
    householdId: 'h1',
    type: TransactionType.expense,
    amountMinorUnits: 250000,
    categoryId: 'transport',
    memberId: 'm1',
    date: _month,
  ),
  Transaction(
    id: 't3',
    householdId: 'h1',
    type: TransactionType.expense,
    amountMinorUnits: 900000,
    categoryId: 'rent',
    memberId: 'm2',
    date: _month,
    recurringRuleId: 'r1',
  ),
  Transaction(
    id: 't4',
    householdId: 'h1',
    type: TransactionType.income,
    amountMinorUnits: 5000000,
    categoryId: 'salary',
    memberId: 'm1',
    date: _month,
  ),
];

final _rules = <RecurringRule>[
  RecurringRule(
    id: 'r1',
    householdId: 'h1',
    categoryId: 'rent',
    memberId: 'm2',
    amountMinorUnits: 900000,
    frequency: RecurrenceFrequency.monthly,
    nextDue: _month,
    isActive: true,
    dayOfMonth: 1,
    startDate: _month,
  ),
];

/// Raw `transactions` rows as PostgREST returns them (`amount::text`), so the
/// service has to do the minor-unit conversion itself.
List<Map<String, dynamic>> _transactionRows() => [
      for (final tx in _transactions)
        {
          'id': tx.id,
          'household_id': 'h1',
          'type': tx.type.name,
          'amount': Money.minorUnitsToDecimalString(tx.amountMinorUnits),
          'category_id': tx.categoryId,
          'member_id': tx.memberId,
          'date': tx.date.toIso8601String().substring(0, 10),
        },
    ];

class _FakeBackupRepository implements BackupRepository {
  _FakeBackupRepository({
    this.tableRows = const {},
    this.failDownloads = const {},
    this.receiptBytes = const {},
  });

  final Map<String, List<Map<String, dynamic>>> tableRows;
  final Set<String> failDownloads;
  final Map<String, int> receiptBytes;

  @override
  Future<List<Map<String, dynamic>>> fetchPage({
    required BackupTable table,
    required String householdId,
    required int offset,
    required int limit,
  }) async {
    final rows = tableRows[table.name] ?? const [];
    if (offset >= rows.length) return const [];
    final end = (offset + limit).clamp(0, rows.length);
    return rows.sublist(offset, end);
  }

  @override
  Future<List<int>> downloadReceipt(String storagePath) async {
    if (failDownloads.contains(storagePath)) {
      throw const AppException(AppErrorCode.network);
    }
    return List<int>.filled(receiptBytes[storagePath] ?? 4, 1);
  }
}

Archive _unzip(Uint8List bytes) => ZipDecoder().decodeBytes(bytes);

Map<String, dynamic> _jsonEntry(Archive archive, String name) {
  final file = archive.findFile(name)!;
  return jsonDecode(utf8.decode(file.readBytes()!)) as Map<String, dynamic>;
}

void main() {
  test('data.json sums to the dashboard totals (23,845.67)', () async {
    final service = _FakeBackupRepository(
      tableRows: {'transactions': _transactionRows()},
    );
    final outcome = await BackupService(service).run(
      householdId: 'h1',
      includeReceipts: false,
      now: DateTime.utc(2026, 10, 14),
    );

    final data = _jsonEntry(_unzip(outcome.zipBytes), 'data.json');
    final rows =
        ((data['tables'] as Map)['transactions'] as List).cast<Map>();

    var expenses = 0;
    var income = 0;
    for (final row in rows) {
      final amount = row['amount_minor_units'] as int;
      if (row['type'] == 'expense') {
        expenses += amount;
      } else {
        income += amount;
      }
    }

    final dashboard = dashboardSummary(
      transactions: _transactions,
      rules: _rules,
      incomeCategoryIds: const {'salary'},
      month: _month,
    );
    expect(expenses, dashboard.expensesMinor);
    expect(expenses, 2384567);
    expect(income, dashboard.incomeMinor);
    expect(income, 5000000);
    expect(income - expenses, dashboard.balanceMinor);
  });

  test('the manifest counts rows and lists every excluded table', () async {
    final service = _FakeBackupRepository(
      tableRows: {'transactions': _transactionRows()},
    );
    final outcome = await BackupService(service).run(
      householdId: 'h1',
      includeReceipts: false,
      now: DateTime.utc(2026, 10, 14),
    );
    final archive = _unzip(outcome.zipBytes);
    final manifest = _jsonEntry(archive, 'manifest.json');
    final counts = manifest['counts'] as Map<String, dynamic>;
    expect(counts['transactions'], 4);
    expect((manifest['excluded_tables'] as Map).containsKey('invites'), isTrue);
    expect(outcome.tableCounts['transactions'], 4);
  });

  test('data-only marks receipts omitted, and never downloads them', () async {
    final service = _FakeBackupRepository(
      tableRows: {
        'transaction_receipts': [
          {'id': 'r1', 'storage_path': 'h1/t1/a.jpg', 'size_bytes': 111},
        ],
      },
    );
    final outcome = await BackupService(service).run(
      householdId: 'h1',
      includeReceipts: false,
    );
    final archive = _unzip(outcome.zipBytes);
    final manifest = _jsonEntry(archive, 'manifest.json');
    final receipts = (manifest['receipts'] as List).cast<Map>();
    expect(receipts.single['included'], false);
    expect(receipts.single['reason'], 'omitted_data_only');
    // No `receipts/...` entry in the archive.
    expect(
      archive.files.where((file) => file.name.startsWith('receipts/')),
      isEmpty,
    );
  });

  test('a failed receipt download is recorded as missing, not fatal', () async {
    final service = _FakeBackupRepository(
      tableRows: {
        'transaction_receipts': [
          {'id': 'r1', 'storage_path': 'h1/t1/a.jpg', 'size_bytes': 10},
          {'id': 'r2', 'storage_path': 'h1/t1/b.jpg', 'size_bytes': 20},
        ],
      },
      failDownloads: {'h1/t1/b.jpg'},
      receiptBytes: {'h1/t1/a.jpg': 10},
    );
    final outcome = await BackupService(service).run(
      householdId: 'h1',
      includeReceipts: true,
    );
    expect(outcome.receiptsIncluded, 1);
    expect(outcome.receiptsMissing, 1);
    final archive = _unzip(outcome.zipBytes);
    expect(archive.findFile('receipts/h1/t1/a.jpg'), isNotNull);
    expect(archive.findFile('receipts/h1/t1/b.jpg'), isNull);
    final manifest = _jsonEntry(archive, 'manifest.json');
    final receipts = (manifest['receipts'] as List).cast<Map>();
    expect(
      receipts.firstWhere((row) => row['storage_path'] == 'h1/t1/b.jpg')['reason'],
      'download_failed',
    );
  });

  test('above the hard cap the service refuses to include receipts', () async {
    final service = _FakeBackupRepository(
      tableRows: {
        'transaction_receipts': [
          {
            'id': 'r1',
            'storage_path': 'h1/t1/big.pdf',
            'size_bytes': backupMaxReceiptBytes + 1,
          },
        ],
      },
    );
    expect(
      () => BackupService(service).run(
        householdId: 'h1',
        includeReceipts: true,
      ),
      throwsA(
        isA<AppException>()
            .having((e) => e.code, 'code', AppErrorCode.backupTooLarge),
      ),
    );
  });
}
