import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/utils/money.dart';
import '../../domain/report_data.dart';

/// One slice of the category donut: a display label, its exact integer
/// minor-unit amount and a colour.
class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.amountMinorUnits,
    required this.color,
  });

  final String label;
  final int amountMinorUnits;
  final Color color;
}

/// This month's expenses by category: a donut plus a legend that always
/// carries the name, the amount and the share - so the numbers are never
/// only conveyed by colour. Tapping a slice (or a legend row) highlights it
/// and shows its details in the middle. RTL safe (no hard-coded alignment).
class CategoryDonut extends StatefulWidget {
  const CategoryDonut({
    super.key,
    required this.slices,
    required this.totalMinorUnits,
    required this.arabicDigits,
    required this.currencyCode,
  });

  final List<DonutSlice> slices;
  final int totalMinorUnits;
  final bool arabicDigits;
  final String currencyCode;

  @override
  State<CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<CategoryDonut> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final selected = _touchedIndex >= 0 && _touchedIndex < widget.slices.length
        ? widget.slices[_touchedIndex]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 46,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      final index = response?.touchedSection?.touchedSectionIndex;
                      final next = (index == null || index < 0)
                          ? -1
                          : (index == _touchedIndex ? -1 : index);
                      if (next != _touchedIndex) {
                        setState(() => _touchedIndex = next);
                      }
                    },
                  ),
                  sections: [
                    for (var i = 0; i < widget.slices.length; i++)
                      PieChartSectionData(
                        value: widget.slices[i].amountMinorUnits.toDouble(),
                        color: widget.slices[i].color,
                        radius: i == _touchedIndex ? 30 : 24,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 54),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selected?.label ?? l10n.report_total,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Money.format(
                        minorUnits: selected?.amountMinorUnits ??
                            widget.totalMinorUnits,
                        arabicDigits: widget.arabicDigits,
                        currencyCode: widget.currencyCode,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < widget.slices.length; i++)
          _LegendRow(
            slice: widget.slices[i],
            sharePercent: sharePercent(
              widget.slices[i].amountMinorUnits,
              widget.totalMinorUnits,
            ),
            selected: i == _touchedIndex,
            arabicDigits: widget.arabicDigits,
            currencyCode: widget.currencyCode,
            onTap: () => setState(
              () => _touchedIndex = i == _touchedIndex ? -1 : i,
            ),
          ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.slice,
    required this.sharePercent,
    required this.selected,
    required this.arabicDigits,
    required this.currencyCode,
    required this.onTap,
  });

  final DonutSlice slice;
  final int sharePercent;
  final bool selected;
  final bool arabicDigits;
  final String currencyCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? slice.color.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: slice.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                slice.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              l10n.report_share(sharePercent),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                Money.format(
                  minorUnits: slice.amountMinorUnits,
                  arabicDigits: arabicDigits,
                  currencyCode: currencyCode,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
