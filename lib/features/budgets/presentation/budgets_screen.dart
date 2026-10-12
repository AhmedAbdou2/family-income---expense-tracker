import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/l10n/l10n.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../categories/presentation/providers.dart';
import '../../household/presentation/home_shell.dart';
import '../../household/presentation/providers.dart';
import '../../transactions/presentation/providers.dart';
import '../domain/budget_progress.dart';
import '../domain/entities.dart';
import 'budget_editor.dart';
import 'budget_status.dart';
import 'providers.dart';

/// Budgets: one monthly limit per category + one optional overall limit,
/// with spent/projected progress and near/over alerts. Owner/adult only.
///
/// Follows the SHARED dashboard month, and derives every figure from the
/// same month rows, so it reconciles exactly with the dashboard.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final month = ref.watch(dashboardMonthProvider);
    final overview = ref.watch(budgetOverviewProvider);
    final membership = ref.watch(membershipProvider).value;
    final householdId = membership?.household.id;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final arabicDigits = ref.watch(settingsProvider).arabicDigits;
    final locale = Localizations.localeOf(context).toString();
    final languageCode = Localizations.localeOf(context).languageCode;
    final currencyLabel = Currency.label(
      membership?.household.currency,
      locale: locale,
    );

    String amountLabel(int minorUnits) => Money.format(
          minorUnits: minorUnits,
          arabicDigits: arabicDigits,
          currencyCode: currencyLabel,
        );

    String categoryName(BudgetProgress row) {
      for (final category in categories) {
        if (category.id == row.budget.categoryId) {
          return category.localizedName(languageCode);
        }
      }
      return l10n.category;
    }

    IconData categoryIcon(BudgetProgress row) {
      for (final category in categories) {
        if (category.id == row.budget.categoryId) return iconFor(category.icon);
      }
      return Icons.category_rounded;
    }

    Color categoryColor(BudgetProgress row) {
      for (final category in categories) {
        if (category.id == row.budget.categoryId) {
          return colorFromHex(category.color);
        }
      }
      return colorFromHex('#78909C');
    }

    return Scaffold(
      appBar: AppBar(
        leading: ShellScope.maybeOf(context) == null
            ? null
            : const ShellMenuButton(),
        title: Text(l10n.budgets_title),
        actions: [
          if (householdId != null)
            IconButton(
              tooltip: l10n.budget_add,
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _openEditor(
                context,
                ref,
                householdId,
                mode: BudgetEditorMode.category,
              ),
            ),
        ],
      ),
      body: Column(
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
            child: overview.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(budgetOverviewProvider),
              ),
              data: (data) {
                if (householdId == null) return const SizedBox.shrink();
                if (!data.hasBudgets) {
                  return EmptyState(
                    icon: Icons.savings_outlined,
                    title: l10n.budget_empty_title,
                    body: l10n.budget_empty_body,
                    action: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _openEditor(
                            context,
                            ref,
                            householdId,
                            mode: BudgetEditorMode.category,
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(l10n.budget_add),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _openEditor(
                            context,
                            ref,
                            householdId,
                            mode: BudgetEditorMode.overall,
                          ),
                          child: Text(l10n.budget_add_overall),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    16, 4, 16, 96,
                  ),
                  children: [
                    if (data.overall != null)
                      _BudgetCard(
                        row: data.overall!,
                        title: l10n.budget_overall_title,
                        help: l10n.budget_overall_hint,
                        amountLabel: amountLabel,
                        onEdit: () => _openEditor(
                          context,
                          ref,
                          householdId,
                          mode: BudgetEditorMode.overall,
                          existing: data.overall!.budget,
                        ),
                        onToggle: () =>
                            _toggleActive(context, ref, data.overall!.budget),
                        onDelete: () =>
                            _delete(context, ref, data.overall!.budget),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () => _openEditor(
                          context,
                          ref,
                          householdId,
                          mode: BudgetEditorMode.overall,
                        ),
                        icon: const Icon(Icons.savings_outlined),
                        label: Text(l10n.budget_add_overall),
                      ),
                    const SizedBox(height: 12),
                    for (final row in data.categories) ...[
                      _BudgetCard(
                        row: row,
                        title: categoryName(row),
                        icon: categoryIcon(row),
                        color: categoryColor(row),
                        help: l10n.budget_help_spent,
                        amountLabel: amountLabel,
                        onEdit: () => _openEditor(
                          context,
                          ref,
                          householdId,
                          mode: BudgetEditorMode.category,
                          existing: row.budget,
                        ),
                        onToggle: () => _toggleActive(context, ref, row.budget),
                        onDelete: () => _delete(context, ref, row.budget),
                      ),
                      const SizedBox(height: 12),
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

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    String householdId, {
    required BudgetEditorMode mode,
    Budget? existing,
  }) async {
    final saved = await showBudgetEditor(
      context,
      householdId: householdId,
      mode: mode,
      existing: existing,
    );
    if (saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.budget_saved)),
      );
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    Budget budget,
  ) async {
    try {
      await ref.read(budgetsRepositoryProvider).setActive(
            budgetId: budget.id,
            isActive: !budget.isActive,
          );
      ref.invalidate(budgetsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(context, error))),
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Budget budget,
  ) async {
    final confirmed = await confirmDeleteBudget(context);
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(budgetsRepositoryProvider).deleteBudget(budgetId: budget.id);
      ref.invalidate(budgetsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.budget_deleted)),
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

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.row,
    required this.title,
    required this.help,
    required this.amountLabel,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    this.icon,
    this.color,
  });

  final BudgetProgress row;
  final String title;
  final String help;
  final String Function(int minorUnits) amountLabel;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: accent.withValues(alpha: 0.18),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              BudgetStatusChip(status: row.status, paused: !row.isActive),
              PopupMenuButton<String>(
                tooltip: l10n.budget_edit,
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'toggle':
                      onToggle();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text(l10n.budget_edit)),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      row.isActive ? l10n.budget_pause : l10n.budget_resume,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l10n.budget_delete),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          BudgetProgressBar(
            status: row.status,
            value: row.limitMinor <= 0
                ? 0
                : row.spentMinor / row.limitMinor,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.budget_spent_of(
                    amountLabel(row.spentMinor),
                    amountLabel(row.limitMinor),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.budget_percent(row.percent),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: row.isOver ? scheme.error : scheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.budget_remaining_value(
                    amountLabel(row.remainingMinor),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.budget_projected_value(
                    amountLabel(row.projectedMinor),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
          if (row.isActive && row.projectedExceeds) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.trending_up_rounded, size: 16, color: scheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.budget_projected_note,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            row.isActive ? help : l10n.budget_paused_hint,
            style: TextStyle(
              fontSize: 11,
              height: 1.25,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
