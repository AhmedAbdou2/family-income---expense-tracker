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
import '../../members/presentation/providers.dart';
import '../../transactions/presentation/providers.dart';
import 'charts/category_donut.dart';
import 'charts/month_trend_chart.dart';
import 'charts/person_bars.dart';
import 'providers.dart';

/// Reports: this-month expenses by category, income vs expenses over the
/// last 6 months, and this-month spending per person. Owner/adult only.
///
/// Every figure is built from the same month rows the dashboard sums, so
/// the totals reconcile exactly with the dashboard's expense card.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final month = ref.watch(dashboardMonthProvider);
    final report = ref.watch(reportDataProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final members = ref.watch(membersProvider).value ?? const [];
    final arabicDigits = ref.watch(settingsProvider).arabicDigits;
    final currency = ref.watch(membershipProvider).value?.household.currency;
    final locale = Localizations.localeOf(context).toString();
    final languageCode = Localizations.localeOf(context).languageCode;
    final currencyLabel = Currency.label(currency, locale: locale);

    String amountLabel(int minorUnits) => Money.format(
          minorUnits: minorUnits,
          arabicDigits: arabicDigits,
          currencyCode: currencyLabel,
        );

    String categoryName(String id) {
      for (final category in categories) {
        if (category.id == id) return category.localizedName(languageCode);
      }
      return l10n.category;
    }

    Color categoryColor(String id, int index) {
      for (final category in categories) {
        if (category.id == id) return colorFromHex(category.color);
      }
      return colorFromHex(kCategoryColors[index % kCategoryColors.length]);
    }

    String personName(String id) {
      for (final member in members) {
        if (member.id == id) return member.name;
      }
      return l10n.person;
    }

    return Scaffold(
      appBar: AppBar(
        leading: ShellScope.maybeOf(context) == null
            ? null
            : const ShellMenuButton(),
        title: Text(l10n.reports_title),
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
            child: report.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref
                  ..invalidate(monthlyTotalsProvider)
                  ..invalidate(reportDataProvider),
              ),
              data: (data) {
                final trendHasData = data.trend.any(
                  (total) => total.incomeMinor > 0 || total.expenseMinor > 0,
                );
                if (data.isEmpty && !trendHasData) {
                  return EmptyState(
                    icon: Icons.bar_chart_rounded,
                    title: l10n.report_empty_title,
                    body: l10n.report_empty_body,
                  );
                }

                return ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    16, 4, 16, 96,
                  ),
                  children: [
                    _ReportCard(
                      title: l10n.report_by_category,
                      subtitle: l10n.report_expenses_total(
                        amountLabel(data.totalExpensesMinor),
                      ),
                      child: data.hasCategoryData
                          ? CategoryDonut(
                              slices: [
                                for (var i = 0; i < data.byCategory.length; i++)
                                  DonutSlice(
                                    label: categoryName(data.byCategory[i].id),
                                    amountMinorUnits:
                                        data.byCategory[i].amountMinorUnits,
                                    color: categoryColor(
                                      data.byCategory[i].id,
                                      i,
                                    ),
                                  ),
                              ],
                              totalMinorUnits: data.totalExpensesMinor,
                              arabicDigits: arabicDigits,
                              currencyCode: currencyLabel,
                            )
                          : _EmptySection(text: l10n.report_by_category_empty),
                    ),
                    const SizedBox(height: 12),
                    _ReportCard(
                      title: l10n.report_income_vs_expenses,
                      subtitle: l10n.report_last_six_months,
                      child: MonthTrendChart(
                        trend: data.trend,
                        arabicDigits: arabicDigits,
                        currencyCode: currencyLabel,
                        locale: locale,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ReportCard(
                      title: l10n.report_by_person,
                      child: data.hasPersonData
                          ? PersonBars(
                              slices: [
                                for (var i = 0; i < data.byPerson.length; i++)
                                  PersonBarSlice(
                                    label: personName(data.byPerson[i].id),
                                    amountMinorUnits:
                                        data.byPerson[i].amountMinorUnits,
                                    color: colorFromHex(
                                      kCategoryColors[
                                          i % kCategoryColors.length],
                                    ),
                                  ),
                              ],
                              arabicDigits: arabicDigits,
                              currencyCode: currencyLabel,
                            )
                          : _EmptySection(text: l10n.report_by_person_empty),
                    ),
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

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
