import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/utils/money.dart';
import '../../domain/report_data.dart';

/// One row of the "spending by person" chart.
class PersonBarSlice {
  const PersonBarSlice({
    required this.label,
    required this.amountMinorUnits,
    required this.color,
  });

  final String label;
  final int amountMinorUnits;
  final Color color;
}

/// This month's total expense per person: a labelled proportional bar per
/// person, with the exact amount and the share next to it. Built from plain
/// widgets (no chart engine) so it can never overflow at 360px and stays
/// RTL-correct via directional alignment.
class PersonBars extends StatelessWidget {
  const PersonBars({
    super.key,
    required this.slices,
    required this.arabicDigits,
    required this.currencyCode,
  });

  final List<PersonBarSlice> slices;
  final bool arabicDigits;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final total = slices.fold(0, (sum, slice) => sum + slice.amountMinorUnits);
    final maxAmount = slices.isEmpty
        ? 0
        : slices
            .map((slice) => slice.amountMinorUnits)
            .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slice in slices) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    slice.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.report_share(sharePercent(slice.amountMinorUnits, total)),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(width: 10),
                Text(
                  Money.format(
                    minorUnits: slice.amountMinorUnits,
                    arabicDigits: arabicDigits,
                    currencyCode: currencyCode,
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 8,
              color: scheme.surfaceContainerHighest,
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: maxAmount <= 0
                    ? 0
                    : slice.amountMinorUnits / maxAmount,
                child: Container(color: slice.color),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
