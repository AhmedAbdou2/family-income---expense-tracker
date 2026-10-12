import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/l10n/l10n.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities.dart';

/// Income vs expenses for the last 6 months, ending at the selected month.
/// Two bars per month; tapping a bar shows the exact amount for that month
/// (tooltips are always on). Legend carries both colours plus a text label,
/// so nothing depends on colour alone.
class MonthTrendChart extends StatelessWidget {
  const MonthTrendChart({
    super.key,
    required this.trend,
    required this.arabicDigits,
    required this.currencyCode,
    required this.locale,
  });

  final List<MonthlyTotal> trend;
  final bool arabicDigits;
  final String currencyCode;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final incomeColor = scheme.primary;
    final expenseColor = scheme.error;

    var maxValue = 0;
    for (final total in trend) {
      if (total.incomeMinor > maxValue) maxValue = total.incomeMinor;
      if (total.expenseMinor > maxValue) maxValue = total.expenseMinor;
    }
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.25;
    final monthLabels = [
      for (final total in trend) DateFormat.MMM(locale).format(total.month),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _LegendDot(color: incomeColor, label: l10n.report_legend_income),
            const SizedBox(width: 16),
            _LegendDot(color: expenseColor, label: l10n.dashboard_expenses),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= monthLabels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsetsDirectional.only(top: 6),
                        child: Text(
                          arabicDigits
                              ? Money.toArabicIndic(monthLabels[index])
                              : monthLabels[index],
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => scheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final total = trend[groupIndex];
                    final isIncome = rodIndex == 0;
                    final minorUnits =
                        isIncome ? total.incomeMinor : total.expenseMinor;
                    final month = DateFormat.yMMM(locale).format(total.month);
                    return BarTooltipItem(
                      '$month\n'
                      '${isIncome ? l10n.report_legend_income : l10n.dashboard_expenses}: '
                      '${Money.format(minorUnits: minorUnits, arabicDigits: arabicDigits, currencyCode: currencyCode)}',
                      TextStyle(
                        color: scheme.onInverseSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < trend.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 3,
                    barRods: [
                      BarChartRodData(
                        toY: trend[i].incomeMinor.toDouble(),
                        color: incomeColor,
                        width: 7,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      BarChartRodData(
                        toY: trend[i].expenseMinor.toDouble(),
                        color: expenseColor,
                        width: 7,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
