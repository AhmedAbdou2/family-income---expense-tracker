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
import '../../categories/domain/entities.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../categories/presentation/providers.dart';
import '../../members/presentation/providers.dart';
import '../../recurring/domain/entities.dart';
import '../../recurring/domain/fixed_summary.dart';
import '../../recurring/presentation/providers.dart';
import '../../transactions/domain/entities.dart';
import '../../transactions/presentation/providers.dart';
import '../../transactions/presentation/transaction_delete.dart';
import '../domain/entities.dart';
import 'home_shell.dart';
import 'providers.dart';

/// Month summary (income / expenses / balance) + the latest rows.
/// All sums happen on integer minor units - never on doubles.
///
/// Opening the dashboard also runs the idempotent recurring generator, so
/// due fixed commitments post as soon as an adult opens the app.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateRecurring());
  }

  Future<void> _generateRecurring() async {
    if (!mounted) return;
    try {
      final membership = await ref.read(membershipProvider.future);
      if (membership == null || membership.role == MemberRole.child) return;
      final created =
          await ref.read(recurringRulesRepositoryProvider).generateDue();
      if (created > 0 && mounted) {
        ref
          ..invalidate(dashboardMonthTransactionsProvider)
          ..invalidate(monthTransactionsProvider)
          ..invalidate(recurringRulesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.recurring_generated(created))),
        );
      }
    } catch (error) {
      // Best-effort: a pending cloud migration or an offline launch must
      // never block the dashboard - but do surface it so fixed commitments
      // silently not posting is never a mystery.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(context, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final membership = ref.watch(membershipProvider);
    final month = ref.watch(dashboardMonthProvider);
    final transactions = ref.watch(dashboardMonthTransactionsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final members = ref.watch(membersProvider).value ?? const [];
    final rules =
        ref.watch(recurringRulesProvider).value ?? const <RecurringRule>[];
    final arabicDigits = ref.watch(settingsProvider).arabicDigits;
    final currency = membership.value?.household.currency;
    final locale = Localizations.localeOf(context).toString();
    final incomeCategoryIds = <String>{
      for (final category in categories)
        if (category.group == CategoryGroup.income) category.id,
    };

    return Scaffold(
      appBar: AppBar(
        leading: ShellScope.maybeOf(context) == null
            ? null
            : const ShellMenuButton(),
        title: Text(membership.value?.household.name ?? l10n.nav_dashboard),
      ),
      body: membership.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(membershipProvider),
        ),
        data: (_) => Column(
          children: [
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
                        ref.read(dashboardMonthProvider.notifier).previous(),
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
                        ref.read(dashboardMonthProvider.notifier).next(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: transactions.when(
                loading: () => const LoadingView(),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(dashboardMonthTransactionsProvider),
                ),
                data: (list) {
                  var income = 0;
                  var expense = 0;
                  for (final transaction in list) {
                    if (transaction.type == TransactionType.income) {
                      income += transaction.amountMinorUnits;
                    } else {
                      expense += transaction.amountMinorUnits;
                    }
                  }
                  final balance = income - expense;
                  final fixed = fixedMonthSummary(
                    rules: rules,
                    incomeCategoryIds: incomeCategoryIds,
                    month: month,
                  );
                  var postedFixed = 0;
                  for (final transaction in list) {
                    if (transaction.type == TransactionType.expense &&
                        transaction.recurringRuleId != null) {
                      postedFixed += transaction.amountMinorUnits;
                    }
                  }
                  final remaining = income - postedFixed - fixed.dueMinor;

                  if (list.isEmpty && fixed.totalMinor == 0) {
                    return EmptyState(
                      icon: Icons.pie_chart_outline_rounded,
                      title: l10n.month_no_data,
                      body: l10n.empty_dashboard_body,
                    );
                  }

                  String label(int minorUnits, {String? sign}) {
                    final formatted = Money.format(
                      minorUnits: minorUnits,
                      arabicDigits: arabicDigits,
                      currencyCode: currency,
                    );
                    return sign == null ? formatted : '$sign $formatted';
                  }

                  return ListView(
                    padding: const EdgeInsetsDirectional.only(bottom: 96),
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 16,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: l10n.type_income,
                                value: label(income),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                title: l10n.dashboard_expenses,
                                value: label(expense),
                                color: Theme.of(context).colorScheme.error,
                                help: l10n.dashboard_expenses_help,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                title: l10n.dashboard_balance,
                                value: label(
                                  balance,
                                  sign: balance < 0 ? '-' : null,
                                ),
                                color: balance < 0
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 20, end: 20, top: 20, bottom: 4,
                        ),
                        child: Text(
                          l10n.dashboard_fixed_header,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 16,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: l10n.dashboard_fixed_posted,
                                value: label(postedFixed),
                                color: Theme.of(context).colorScheme.error,
                                help: l10n.dashboard_fixed_posted_help,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                title: l10n.dashboard_fixed_due,
                                value: label(fixed.dueMinor),
                                color: Theme.of(context).colorScheme.tertiary,
                                help: l10n.dashboard_fixed_due_help,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          16, 10, 16, 0,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.dashboard_after_fixed,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge,
                                ),
                              ),
                              Text(
                                label(remaining, sign: remaining < 0 ? '-' : null),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: remaining < 0
                                      ? Theme.of(context).colorScheme.error
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          20, 6, 20, 0,
                        ),
                        child: Text(
                          l10n.dashboard_after_fixed_help,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 20, end: 20, top: 20, bottom: 4,
                        ),
                        child: Text(
                          l10n.dashboard_recent,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 20,
                          ),
                          child: Text(
                            l10n.month_no_data,
                            style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        for (final transaction in list.take(5))
                          _RecentTile(
                          transaction: transaction,
                          label: label(
                            transaction.amountMinorUnits,
                            sign:
                                transaction.type == TransactionType.expense
                                    ? '-'
                                    : '+',
                          ),
                          categoryName: () {
                            final matches = categories
                                .where((c) => c.id == transaction.categoryId);
                            if (matches.isEmpty) return l10n.category;
                            return matches.first.localizedName(
                              Localizations.localeOf(context).languageCode,
                            );
                          }(),
                          memberName: () {
                            final matches = members
                                .where((m) => m.id == transaction.memberId);
                            return matches.isEmpty
                                ? l10n.person
                                : matches.first.name;
                          }(),
                          colorHex: () {
                            final matches = categories
                                .where((c) => c.id == transaction.categoryId);
                            return matches.isEmpty
                                ? '#78909C'
                                : matches.first.color;
                          }(),
                          icon: () {
                            final matches = categories
                                .where((c) => c.id == transaction.categoryId);
                            return matches.isEmpty
                                ? Icons.receipt_long_outlined
                                : iconFor(matches.first.icon);
                          }(),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    this.help,
  });

  final String title;
  final String value;
  final Color color;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (help != null) ...[
            const SizedBox(height: 4),
            Text(
              help!,
              style: TextStyle(
                fontSize: 10,
                height: 1.2,
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentTile extends ConsumerWidget {
  const _RecentTile({
    required this.transaction,
    required this.label,
    required this.categoryName,
    required this.memberName,
    required this.colorHex,
    required this.icon,
  });

  final Transaction transaction;
  final String label;
  final String categoryName;
  final String memberName;
  final String colorHex;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = colorFromHex(colorHex);
    final isExpense = transaction.type == TransactionType.expense;
    return Dismissible(
      key: Key('dashboard_${transaction.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        await _confirmAndDelete(context, ref);
        return false;
      },
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 16),
        child: Icon(Icons.delete_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(categoryName),
        subtitle: Text(memberName),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isExpense
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            IconButton(
              tooltip: context.l10n.delete_action,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmAndDelete(context, ref),
            ),
          ],
        ),
        onTap: () => context.push('/transactions/edit/${transaction.id}'),
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final fuelLinked = await isFuelLinkedTransaction(ref, transaction.id);
    if (!context.mounted) return;
    final locale = Localizations.localeOf(context).toString();
    final result = await showTransactionDeleteDialog(
      context,
      categoryName: categoryName,
      personLabel: memberName,
      dateLabel: DateFormat.yMMMd(locale).format(transaction.date),
      amountLabel: label,
      isExpense: transaction.type == TransactionType.expense,
      fromFixed: transaction.recurringRuleId != null,
      fuelLinked: fuelLinked,
      vehicleLinked: transaction.vehicleId != null,
    );
    if (result == null || !result.confirmed || !context.mounted) return;
    await _delete(context, ref, pauseRule: result.pauseRule);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref, {
    bool pauseRule = false,
  }) async {
    final l10n = context.l10n;
    try {
      await deleteTransactionCascade(
        ref: ref,
        transaction: transaction,
        pauseRule: pauseRule,
      );
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
