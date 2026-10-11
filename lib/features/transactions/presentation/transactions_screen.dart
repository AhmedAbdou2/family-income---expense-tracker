import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/l10n/l10n.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../categories/presentation/providers.dart';
import '../../household/presentation/home_shell.dart';
import '../../household/presentation/providers.dart';
import '../../members/presentation/providers.dart';
import '../domain/entities.dart';
import 'providers.dart';

/// Month-by-month list of transactions, newest day first, with a person
/// filter chip row. Tapping a row opens the edit form.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final month = ref.watch(transactionsMonthProvider);
    final filter = ref.watch(transactionsMemberFilterProvider);
    final transactions = ref.watch(monthTransactionsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final members = ref.watch(membersProvider).value ?? const [];
    final arabicDigits = ref.watch(settingsProvider).arabicDigits;
    final currency = ref.watch(membershipProvider).value?.household.currency;
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(
        leading: ShellScope.maybeOf(context) == null
            ? null
            : const ShellMenuButton(),
        title: Text(l10n.nav_transactions),
      ),
      body: Column(
        children: [
          // Month navigation: [previous] month label [next] - the Row
          // mirrors automatically in RTL, only the chevrons flip.
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.month_prev,
                  icon: Icon(rtl
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded),
                  onPressed: () =>
                      ref.read(transactionsMonthProvider.notifier).previous(),
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM(locale).format(month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: l10n.month_next,
                  icon: Icon(rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded),
                  onPressed: () =>
                      ref.read(transactionsMonthProvider.notifier).next(),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(l10n.filter_everyone),
                    selected: filter == null,
                    onSelected: (_) => ref
                        .read(transactionsMemberFilterProvider.notifier)
                        .select(null),
                  ),
                ),
                for (final member in members)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(member.name),
                      selected: filter == member.id,
                      onSelected: (_) => ref
                          .read(transactionsMemberFilterProvider.notifier)
                          .select(member.id),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: transactions.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(monthTransactionsProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: filter == null
                        ? l10n.empty_transactions_title
                        : l10n.month_no_data,
                    body: l10n.empty_transactions_body,
                  );
                }

                // Day groups, preserving the repo's newest-first order.
                final groups = <String, List<Transaction>>{};
                for (final transaction in list) {
                  final key = transaction.date.toIso8601String().substring(0, 10);
                  (groups[key] ??= []).add(transaction);
                }

                return ListView(
                  padding: const EdgeInsetsDirectional.only(bottom: 96),
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 20, end: 20, top: 16, bottom: 4,
                        ),
                        child: Text(
                          DateFormat.yMMMd(locale).format(
                            DateTime.parse('${entry.key}T00:00:00'),
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      for (final transaction in entry.value)
                        _TransactionTile(
                          transaction: transaction,
                          categoryName: () {
                            final matches = categories
                                .where((c) => c.id == transaction.categoryId);
                            if (matches.isEmpty) return transaction.categoryId;
                            final category = matches.first;
                            return category.localizedName(
                              Localizations.localeOf(context).languageCode,
                            );
                          }(),
                          memberName: () {
                            final matches =
                                members.where((m) => m.id == transaction.memberId);
                            return matches.isEmpty
                                ? l10n.person
                                : matches.first.name;
                          }(),
                          icon: () {
                            final matches = categories
                                .where((c) => c.id == transaction.categoryId);
                            return matches.isEmpty
                                ? Icons.receipt_long_outlined
                                : iconFor(matches.first.icon);
                          }(),
                          colorHex: () {
                            final matches = categories
                                .where((c) => c.id == transaction.categoryId);
                            return matches.isEmpty
                                ? '#78909C'
                                : matches.first.color;
                          }(),
                          amountLabel: Money.format(
                            minorUnits: transaction.amountMinorUnits,
                            arabicDigits: arabicDigits,
                            currencyCode: currency,
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({
    required this.transaction,
    required this.categoryName,
    required this.memberName,
    required this.icon,
    required this.colorHex,
    required this.amountLabel,
  });

  final Transaction transaction;
  final String categoryName;
  final String memberName;
  final IconData icon;
  final String colorHex;
  final String amountLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = transaction.type == TransactionType.expense;
    final color = colorFromHex(colorHex);

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _confirmDelete(context, ref),
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 16),
        child: Icon(Icons.delete_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      onDismissed: (_) async {
        if (context.mounted) await _delete(context, ref);
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(categoryName),
        subtitle: Text(
          '$memberName'
          '${transaction.note == null || transaction.note!.isEmpty ? '' : ' • ${transaction.note}'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isExpense ? '-' : '+'} $amountLabel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isExpense
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  final confirmed = await _confirmDelete(context, ref);
                  if (confirmed == true && context.mounted) {
                    await _delete(context, ref);
                  }
                } else if (value == 'edit') {
                  if (context.mounted) {
                    context.push('/transactions/edit/${transaction.id}');
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(context.l10n.transaction_edit_title),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(context.l10n.delete_action),
                ),
              ],
            ),
          ],
        ),
        onTap: () => context.push('/transactions/edit/${transaction.id}'),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    String content = l10n.transaction_delete_confirm_body;
    if (transaction.recurringRuleId != null) {
      content = l10n.transaction_delete_from_fixed;
    }
    if (!context.mounted) return false;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.transaction_delete_confirm_title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.delete_action),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .deleteTransaction(id: transaction.id);
      ref
        ..invalidate(monthTransactionsProvider)
        ..invalidate(dashboardMonthTransactionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.transaction_deleted)),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    }
  }
}
