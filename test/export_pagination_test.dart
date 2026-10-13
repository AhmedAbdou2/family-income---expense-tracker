import 'package:family_income_expense_tracker/features/export/data/export_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// PostgREST caps any single response at ~1000 rows (the cap applies to
/// table-returning RPCs too), so the CSV/PDF path pages with `.range()`.
/// These tests drive the loop with a fake page source and prove that a long
/// window arrives complete, in order, with no row dropped or repeated.
Map<String, dynamic> _row(int index) => {
      'id': 'tx-$index',
      'household_id': 'h1',
      'type': 'expense',
      'amount': '10.00',
      'category_id': 'food',
      'member_id': 'm1',
      'date': '2026-06-05',
    };

/// A source with [total] rows that records the offsets it was asked for.
class _FakeSource {
  _FakeSource(this.total);

  final int total;
  final List<int> offsets = [];

  Future<List<Map<String, dynamic>>> fetch(int offset) async {
    offsets.add(offset);
    final remaining = total - offset;
    if (remaining <= 0) return const [];
    final count = remaining < exportPageSize ? remaining : exportPageSize;
    return [for (var i = 0; i < count; i++) _row(offset + i)];
  }
}

void main() {
  test('an empty window needs exactly one request', () async {
    final source = _FakeSource(0);
    final rows = await collectTransactionPages(fetchPage: source.fetch);

    expect(rows, isEmpty);
    expect(source.offsets, [0]);
  });

  test('a short window stops after the first page', () async {
    final source = _FakeSource(999);
    final rows = await collectTransactionPages(fetchPage: source.fetch);

    expect(rows.length, 999);
    expect(source.offsets, [0]);
  });

  test('a full page means there may be more, so it asks again', () async {
    final source = _FakeSource(1000);
    final rows = await collectTransactionPages(fetchPage: source.fetch);

    expect(rows.length, 1000);
    // 0 -> 1000 rows, then 1000 -> 0 rows: the empty page ends the walk.
    expect(source.offsets, [0, exportPageSize]);
  });

  test('1007 rows arrive complete in two pages', () async {
    final source = _FakeSource(1007);
    final rows = await collectTransactionPages(fetchPage: source.fetch);

    expect(rows.length, 1007);
    expect(source.offsets, [0, exportPageSize]);
  });

  test('2007 rows arrive complete in three pages, in order, no duplicates',
      () async {
    final source = _FakeSource(2007);
    final rows = await collectTransactionPages(fetchPage: source.fetch);

    expect(rows.length, 2007);
    expect(source.offsets, [0, exportPageSize, exportPageSize * 2]);

    final ids = rows.map((row) => row.id).toList();
    expect(ids.first, 'tx-0');
    expect(ids[1000], 'tx-1000');
    expect(ids.last, 'tx-2006');
    expect(ids.toSet().length, 2007, reason: 'no row may repeat');
  });

  test('the page size is the PostgREST cap', () {
    expect(exportPageSize, 1000);
  });
}
