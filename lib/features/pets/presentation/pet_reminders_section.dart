import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/error_view.dart';
import '../../household/presentation/providers.dart';
import '../../transactions/presentation/providers.dart';
import '../domain/entities.dart';
import '../domain/pet_reminder_status.dart';
import 'providers.dart';

/// Vaccine / vet-visit reminders of one pet, newest due first.
///
/// Adults only: the router keeps children out of `/pets` and RLS would
/// return zero rows anyway, so there is no per-row role gating here.
class PetRemindersSection extends ConsumerWidget {
  const PetRemindersSection({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final reminders = ref.watch(petRemindersProvider(petId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 20,
            end: 12,
            top: 20,
            bottom: 6,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.pet_reminders_title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                ),
              ),
              IconButton(
                style: AppButtons.inline,
                tooltip: l10n.pet_reminder_add,
                icon: const Icon(Icons.add_alarm_outlined),
                onPressed: () =>
                    context.push('/pets/$petId/reminders/new'),
              ),
            ],
          ),
        ),
        reminders.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
            child: ErrorBanner(error: error),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4),
                child: Text(
                  l10n.pet_reminders_empty,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              );
            }
            final today = DateTime.now();
            final sorted =
                PetReminderStatuses.sorted(list, today: today);
            return Column(
              children: [
                for (final reminder in sorted)
                  _ReminderTile(
                    reminder: reminder,
                    today: today,
                    petId: petId,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({
    required this.reminder,
    required this.today,
    required this.petId,
  });

  final PetReminder reminder;
  final DateTime today;
  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final status = PetReminderStatuses.status(reminder, today: today);
    final dayFormat = DateFormat.yMMMd(locale);

    final (statusLabel, statusColor) = switch (status) {
      PetReminderStatus.overdue => (l10n.pet_reminder_status_overdue, scheme.error),
      PetReminderStatus.dueSoon => (
          l10n.pet_reminder_status_due_soon,
          scheme.tertiary,
        ),
      PetReminderStatus.ok => (l10n.pet_reminder_status_ok, scheme.onSurfaceVariant),
      PetReminderStatus.done => (l10n.pet_reminder_status_done, scheme.onSurfaceVariant),
    };

    final next = PetReminderStatuses.nextDueDate(reminder);
    final subtitle = StringBuffer();
    if (reminder.isDone) {
      subtitle.write(
        l10n.pet_reminder_done_on(dayFormat.format(reminder.doneAt!)),
      );
    } else {
      subtitle.write(l10n.pet_reminder_due_on(dayFormat.format(reminder.dueDate)));
    }
    if (next != null && !reminder.isDone) {
      subtitle.write(' · ${l10n.pet_reminder_next(dayFormat.format(next))}');
    }

    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 20, end: 8),
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(
          switch (reminder.kind) {
            PetReminderKind.vaccine => Icons.vaccines_outlined,
            PetReminderKind.vet => Icons.local_hospital_outlined,
            PetReminderKind.other => Icons.event_note_outlined,
          },
          size: 20,
          color: scheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        reminder.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: reminder.isDone
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: scheme.onSurfaceVariant,
              )
            : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle.toString()),
          if (status != PetReminderStatus.done)
            Text(
              statusLabel,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
            ),
        ],
      ),
      onTap: () => context.push(
        '/pets/$petId/reminders/edit/${reminder.id}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!reminder.isDone)
            IconButton(
              style: AppButtons.inline,
              tooltip: l10n.pet_reminder_complete,
              icon: const Icon(Icons.check_circle_outline_rounded),
              onPressed: () => _complete(context, ref),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _delete(context, ref);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Text(l10n.delete_action),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final currency = ref.read(membershipProvider).value?.household.currency;
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.pet_reminder_complete_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dialogContext.l10n.pet_reminder_complete_body,
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: dialogContext.l10n.pet_reminder_amount_label,
                hintText: dialogContext.l10n.pet_reminder_amount_hint,
                suffixText: currency == null
                    ? null
                    : Currency.label(currency, locale: locale),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteController,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: dialogContext.l10n.note,
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: AppButtons.inline,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            style: AppButtons.inline,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.pet_reminder_complete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final amountText = amountController.text.trim();
    int? amountMinor;
    try {
      amountMinor =
          amountText.isEmpty ? null : Money.decimalStringToMinorUnits(amountText);
    } on FormatException {
      amountMinor = null;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.error_invalid_value)),
        );
      }
      return;
    }

    try {
      await ref.read(petRemindersRepositoryProvider).completeReminder(
            id: reminder.id,
            amountMinorUnits: amountMinor,
            note: noteController.text,
          );
      _invalidate(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pet_reminder_completed)),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.pet_reminder_delete_confirm_title),
        content: Text(dialogContext.l10n.pet_reminder_delete_confirm_body),
        actions: [
          TextButton(
            style: AppButtons.inline,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            style: AppButtons.inline,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.delete_action),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(petRemindersRepositoryProvider)
          .deleteReminder(id: reminder.id);
      _invalidate(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pet_reminder_deleted)),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    }
  }

  /// Completing with a cost posts an expense, so every derived month figure
  /// has to be re-read.
  void _invalidate(WidgetRef ref) {
    ref
      ..invalidate(petRemindersProvider(petId))
      ..invalidate(petMonthTransactionsProvider(petId))
      ..invalidate(monthTransactionsProvider)
      ..invalidate(dashboardMonthTransactionsProvider);
  }
}
