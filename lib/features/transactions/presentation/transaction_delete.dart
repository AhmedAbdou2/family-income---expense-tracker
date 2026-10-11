import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../recurring/presentation/providers.dart';
import '../../vehicles/domain/entities.dart';
import '../../vehicles/presentation/providers.dart';
import '../domain/entities.dart';
import 'providers.dart';

/// What the user chose in the delete-confirmation dialog.
class TransactionDeleteResult {
  const TransactionDeleteResult({this.confirmed = false, this.pauseRule = false});

  final bool confirmed;

  /// Only meaningful when the transaction was posted by a fixed expense.
  final bool pauseRule;
}

/// Rich confirmation for deleting a transaction from any screen.
///
/// Shows the category, person, date and amount, notes cascades (linked fuel
/// log) and - for a fixed-expense posting - offers an optional "Also pause
/// this fixed expense" checkbox (default off). Buttons are compact and the
/// Delete action uses the error color.
Future<TransactionDeleteResult?> showTransactionDeleteDialog(
  BuildContext context, {
  required String categoryName,
  required String personLabel,
  required String dateLabel,
  required String amountLabel,
  required bool isExpense,
  bool fromFixed = false,
  bool fuelLinked = false,
  bool vehicleLinked = false,
}) {
  var pauseRule = false;
  return showDialog<TransactionDeleteResult>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      final scheme = Theme.of(dialogContext).colorScheme;
      return StatefulBuilder(
        builder: (buildContext, setState) => AlertDialog(
          title: Text(buildContext.l10n.transaction_delete_confirm_title),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: Theme.of(buildContext)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  personLabel,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                Text(
                  dateLabel,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Text(
                  amountLabel,
                  style: Theme.of(buildContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isExpense ? scheme.error : scheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  fromFixed
                      ? l10n.transaction_delete_from_fixed
                      : l10n.transaction_delete_confirm_body,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                if (fuelLinked) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: scheme.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.transaction_delete_fuel_note,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ],
                  ),
                ],
                if (vehicleLinked && !fuelLinked) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.transaction_delete_maintenance_note,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
                if (fromFixed) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => setState(() => pauseRule = !pauseRule),
                    child: Row(
                      children: [
                        Checkbox(
                          value: pauseRule,
                          onChanged: (value) =>
                              setState(() => pauseRule = value ?? false),
                        ),
                        Expanded(
                          child: Text(l10n.transaction_delete_pause_rule),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              style: AppButtons.inline,
              onPressed: () =>
                  Navigator.of(dialogContext).pop(const TransactionDeleteResult()),
              child: Text(buildContext.l10n.cancel),
            ),
            TextButton(
              style: AppButtons.inline,
              onPressed: () => Navigator.of(dialogContext).pop(
                TransactionDeleteResult(confirmed: true, pauseRule: pauseRule),
              ),
              child: Text(
                buildContext.l10n.delete_action,
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Deletes [transaction], cascading to its linked fuel log when present
/// (via `delete_fuel_log`, which removes the log and its transaction), and
/// optionally pausing the fixed rule that posted it. Invalidates every
/// derived provider so no manual reload is needed.
Future<void> deleteTransactionCascade({
  required WidgetRef ref,
  required Transaction transaction,
  bool pauseRule = false,
}) async {
  final fuelRepo = ref.read(fuelRepositoryProvider);
  final logs = await ref.read(fuelLogsProvider(null).future);
  FuelLog? linkedLog;
  for (final log in logs) {
    if (log.transactionId == transaction.id) {
      linkedLog = log;
      break;
    }
  }
  if (linkedLog != null) {
    await fuelRepo.deleteFuelLog(logId: linkedLog.id);
  } else {
    await ref
        .read(transactionsRepositoryProvider)
        .deleteTransaction(id: transaction.id);
  }
  if (pauseRule && transaction.recurringRuleId != null) {
    await ref
        .read(recurringRulesRepositoryProvider)
        .setRuleActive(id: transaction.recurringRuleId!, isActive: false);
  }
  ref
    ..invalidate(monthTransactionsProvider)
    ..invalidate(dashboardMonthTransactionsProvider)
    ..invalidate(memberMonthTransactionsProvider)
    ..invalidate(petMonthTransactionsProvider)
    ..invalidate(fuelLogsProvider)
    ..invalidate(vehiclesProvider)
    ..invalidate(recurringRulesProvider);
}

/// True when a fuel log points at [transactionId].
Future<bool> isFuelLinkedTransaction(WidgetRef ref, String transactionId) async {
  final logs = await ref.read(fuelLogsProvider(null).future);
  for (final log in logs) {
    if (log.transactionId == transactionId) return true;
  }
  return false;
}
