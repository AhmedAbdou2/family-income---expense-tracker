import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/providers.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../categories/presentation/providers.dart';
import '../../household/presentation/providers.dart';
import '../../transactions/domain/entities.dart';
import '../../transactions/presentation/providers.dart';
import '../domain/entities.dart';
import 'providers.dart';

/// One person's profile: name, badges, this month's income / expenses /
/// balance and their recent rows. Reachable from the People tab and the
/// navigation drawer header.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final arabicDigits = ref.watch(settingsProvider).arabicDigits;
    final currency = ref.watch(membershipProvider).value?.household.currency;
    final members = ref.watch(membersProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile_title)),
      body: members.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(membersProvider),
        ),
        data: (list) {
          final me = ref.watch(authStateProvider).value;
          final effectiveId = memberId == 'me'
              ? () {
                  for (final item in list) {
                    if (item.isLinked && item.userId == me) return item.id;
                  }
                  return list.isEmpty ? null : list.first.id;
                }()
              : memberId;
          Member? member;
          for (final item in list) {
            if (item.id == effectiveId) {
              member = item;
              break;
            }
          }
          if (member == null) {
            return ErrorView(error: StateError(l10n.error_invalid_member));
          }
          final person = member;
          final isMe = person.isLinked && person.userId == me;
          final transactions = ref.watch(
            memberMonthTransactionsProvider(person.id),
          );

          return transactions.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(
                memberMonthTransactionsProvider(person.id),
              ),
            ),
            data: (rows) {
              var income = 0;
              var expense = 0;
              for (final transaction in rows) {
                if (transaction.type == TransactionType.income) {
                  income += transaction.amountMinorUnits;
                } else {
                  expense += transaction.amountMinorUnits;
                }
              }
              final balance = income - expense;

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
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: scheme.primaryContainer,
                          child: Text(
                            person.name.isEmpty
                                ? '?'
                                : person.name.characters.first.toUpperCase(),
                            style: TextStyle(
                              color: scheme.onPrimaryContainer,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                person.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (isMe)
                                Text(
                                  l10n.member_you,
                                  style: TextStyle(color: scheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 20, end: 20, top: 12, bottom: 4,
                    ),
                    child: Text(
                      l10n.profile_month,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: l10n.type_income,
                            value: label(income),
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            title: l10n.dashboard_expenses,
                            value: label(expense),
                            color: scheme.error,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            title: l10n.dashboard_balance,
                            value: label(balance, sign: balance < 0 ? '-' : null),
                            color: balance < 0 ? scheme.error : scheme.primary,
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
                  if (rows.isEmpty)
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.symmetric(horizontal: 20),
                      child: Text(
                        l10n.month_no_data,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else
                    for (final transaction in rows.take(10))
                      _RecentTile(
                        transaction: transaction,
                        label: label(
                          transaction.amountMinorUnits,
                          sign: transaction.type == TransactionType.expense
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
          );
        },
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
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
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
    required this.colorHex,
    required this.icon,
  });

  final Transaction transaction;
  final String label;
  final String categoryName;
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
