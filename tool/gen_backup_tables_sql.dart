// Regenerates the backup registry the Docker completeness check reads.
//
// Run after changing `lib/features/backup/domain/backup_tables.dart`:
//   dart run tool/gen_backup_tables_sql.dart
// test/backup_tables_test.dart fails if the committed file is stale.
import 'dart:io';

import 'package:family_income_expense_tracker/features/backup/domain/backup_tables_sql.dart';

void main() {
  const path = 'supabase/tests/support/backup_tables.generated.sql';
  File(path).writeAsStringSync(buildBackupRegistrySql());
  stdout.writeln('wrote $path');
}
