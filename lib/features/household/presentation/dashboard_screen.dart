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
import '../../members/presentation/providers.dart';
import '../../transactions/domain/entities.dart';
import '../../transactions/presentation/providers.dart';
import 'providers.dart';

/// Month summary (income / expenses / balance) + the latest rows.
/// All sums happen on integer minor units - never on doubles.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final membership = ref.watch(membershipProvider);
    final month = ref.watch(dashboardMonthProvider);
    final transactions = ref.watch(dashboardMonthTransactionsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final members = ref.watch(membersProvider).value ?? const [];
    final arabicDigits = ref.watch(settingsProvider).arabicDigits;
    final currency = membership.value?.household.currency;
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(
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

                  if (list.isEmpty) {
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
                          l10n.dashboard_recent,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
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
  });

  final String title;
  final String value;
  final Color color;

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
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = colorFromHex(colorHex);
    final isExpense = transaction.type == TransactionType.expense;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.18),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(categoryName),
      subtitle: Text(memberName),
      trailing: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isExpense
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
      ),
      onTap: () => context.push('/transactions/edit/${transaction.id}'),
    );
  }
}
