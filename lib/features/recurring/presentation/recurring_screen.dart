import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/l10n/l10n.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../categories/domain/entities.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../categories/presentation/providers.dart';
import '../../household/domain/entities.dart';
import '../../household/presentation/home_shell.dart';
import '../../household/presentation/providers.dart';
import '../../members/domain/entities.dart';
import '../../members/presentation/providers.dart';
import '../../receipts/presentation/providers.dart';
import '../../transactions/presentation/providers.dart';
import '../domain/entities.dart';
import '../domain/recurring_schedule.dart';
import 'providers.dart';
import 'recurring_delete.dart';
import 'recurring_visuals.dart';

/// Fixed commitments (rent, installments, subscriptions, salaries). Adults
/// only; due transactions are posted by the generator on app open.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final membership = ref.watch(membershipProvider).value;
    final canManage = switch (membership?.role) {
      MemberRole.owner || MemberRole.adult => true,
      _ => false,
    };
    final rules = ref.watch(recurringRulesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: ShellScope.maybeOf(context) == null
            ? null
            : const ShellMenuButton(),
        title: Text(l10n.recurring_title),
      ),
      body: rules.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(recurringRulesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.event_repeat_outlined,
              title: l10n.recurring_empty_title,
              body: l10n.recurring_empty_body,
            );
          }
          return ListView(
            padding: const EdgeInsetsDirectional.only(bottom: 96),
            children: [
              for (final rule in list) _RecurringTile(rule: rule),
            ],
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: const ValueKey('add-recurring-fab'),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.recurring_add),
              onPressed: () => context.push('/recurring/new'),
            )
          : null,
    );
  }
}

class _RecurringTile extends ConsumerWidget {
  const _RecurringTile({required this.rule});

  final RecurringRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final arabicDigits = ref.watch(settingsProvider).arabicDigits;
    final currency = ref.watch(membershipProvider).value?.household.currency;
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final members = ref.watch(membersProvider).value ?? const <Member>[];

    Category? category;
    for (final item in categories) {
      if (item.id == rule.categoryId) {
        category = item;
        break;
      }
    }
    String? memberName;
    for (final member in members) {
      if (member.id == rule.memberId) {
        memberName = member.name;
        break;
      }
    }

    final languageCode = Localizations.localeOf(context).languageCode;
    final isIncome = category?.group == CategoryGroup.income;
    final title = (rule.name != null && rule.name!.isNotEmpty)
        ? rule.name!
        : (category?.localizedName(languageCode) ?? l10n.recurring_title);

    final subtitleParts = <String>[
      '${isIncome ? '+' : '-'} ${Money.format(
        minorUnits: rule.amountMinorUnits,
        arabicDigits: arabicDigits,
        currencyCode: Currency.label(currency, locale: locale),
      )}',
      frequencyLabel(context, rule.frequency),
      ?memberName,
      l10n.recurring_next_due_line(
        DateFormat.yMMMd(locale).format(rule.nextDue),
      ),
    ];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            (category == null ? scheme.primary : colorFromHex(category.color))
                .withValues(alpha: 0.18),
        child: Icon(
          category == null ? Icons.event_repeat_outlined : iconFor(category.icon),
          color: category == null ? scheme.primary : colorFromHex(category.color),
          size: 20,
        ),
      ),
      title: Text(title),
      subtitle: Text(
        '${subtitleParts.join('  •  ')}'
        '${rule.isActive ? '' : '\n${l10n.recurring_inactive_hint}'}',
        style: TextStyle(
          color: rule.isActive ? null : scheme.onSurfaceVariant,
        ),
      ),
      isThreeLine: !rule.isActive,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'edit':
              context.push('/recurring/edit/${rule.id}');
            case 'toggle':
              _toggleActive(ref, context);
            case 'delete':
              _delete(ref, context);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'edit', child: Text(l10n.recurring_edit)),
          PopupMenuItem(
            value: 'toggle',
            child: Text(rule.isActive ? l10n.recurring_pause : l10n.recurring_resume),
          ),
          PopupMenuItem(value: 'delete', child: Text(l10n.recurring_delete)),
        ],
      ),
      onTap: () => context.push('/recurring/edit/${rule.id}'),
    );
  }

  Future<void> _toggleActive(WidgetRef ref, BuildContext context) async {
    final l10n = context.l10n;
    final resuming = !rule.isActive;
    try {
      final repo = ref.read(recurringRulesRepositoryProvider);
      if (resuming) {
        final next = nextOccurrenceOnOrAfter(
          frequency: rule.frequency,
          start: rule.startDate,
          dayOfMonth: rule.dayOfMonth,
          now: DateTime.now(),
        );
        await repo.setRuleActive(id: rule.id, isActive: true, nextDue: next);
      } else {
        await repo.setRuleActive(id: rule.id, isActive: false);
      }
      ref
        ..invalidate(recurringRulesProvider)
        ..invalidate(monthTransactionsProvider)
        ..invalidate(dashboardMonthTransactionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resuming ? l10n.recurring_resumed_message : l10n.recurring_paused_message,
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
      }
    }
  }

  Future<void> _delete(WidgetRef ref, BuildContext context) async {
    final l10n = context.l10n;
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    final transactions =
        await ref.read(dashboardMonthTransactionsProvider.future);
    final count = postedThisMonthCount(transactions, rule.id, month);
    if (!context.mounted) return;
    final choice = await showRecurringDeleteDialog(
      context,
      postedThisMonthCount: count,
    );
    if (choice == null || !context.mounted) return;
    try {
      final result = await ref.read(recurringRulesRepositoryProvider).archiveRule(
            id: rule.id,
            deleteMonthTransactions:
                choice == RecurringDeleteChoice.deleteMonth,
          );
      // Purged postings may have carried receipts - drop the objects too.
      if (result.receiptPaths.isNotEmpty) {
        await ref
            .read(receiptsRepositoryProvider)
            .deleteObjects(result.receiptPaths);
      }
      ref
        ..invalidate(recurringRulesProvider)
        ..invalidate(monthTransactionsProvider)
        ..invalidate(dashboardMonthTransactionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.recurring_deleted)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
      }
    }
  }
}
