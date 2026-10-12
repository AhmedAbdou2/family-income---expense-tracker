import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../transactions/domain/entities.dart';

/// What to do with already-posted transactions when removing a fixed
/// expense (a recurring rule).
enum RecurringDeleteChoice {
  /// Archive the rule: it stops posting and leaves the list, but the
  /// transactions it posted keep counting as fixed expenses.
  keep,

  /// Archive the rule AND delete this month's already-posted transactions.
  deleteMonth,
}

/// How many transactions [ruleId] posted in [month] (the "N" in the dialog).
int postedThisMonthCount(
  Iterable<Transaction> transactions,
  String ruleId,
  DateTime month,
) =>
    transactions
        .where(
          (t) =>
              t.recurringRuleId == ruleId &&
              t.date.year == month.year &&
              t.date.month == month.month,
        )
        .length;

/// Shared confirmation dialog for removing a fixed expense. Returns the
/// chosen action, or null when the user cancels.
Future<RecurringDeleteChoice?> showRecurringDeleteDialog(
  BuildContext context, {
  required int postedThisMonthCount,
}) {
  var value = RecurringDeleteChoice.keep;
  return showDialog<RecurringDeleteChoice>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(dialogContext.l10n.recurring_delete_confirm_title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dialogContext.l10n.recurring_delete_confirm_body),
              const SizedBox(height: 12),
              RadioGroup<RecurringDeleteChoice>(
                groupValue: value,
                onChanged: (v) {
                  if (v != null) setLocal(() => value = v);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<RecurringDeleteChoice>(
                      value: RecurringDeleteChoice.keep,
                      title: Text(
                        dialogContext.l10n.recurring_delete_option_keep,
                      ),
                    ),
                    RadioListTile<RecurringDeleteChoice>(
                      value: RecurringDeleteChoice.deleteMonth,
                      title: Text(
                        dialogContext.l10n.recurring_delete_option_delete_month(
                          postedThisMonthCount,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(value),
            child: Text(dialogContext.l10n.delete_action),
          ),
        ],
      ),
    ),
  );
}
