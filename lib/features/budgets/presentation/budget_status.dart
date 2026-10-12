import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../domain/budget_progress.dart';

/// Status of a limit. Always an icon PLUS text - never colour alone.
class BudgetStatusChip extends StatelessWidget {
  const BudgetStatusChip({
    super.key,
    required this.status,
    required this.paused,
  });

  final BudgetStatus status;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    late final IconData icon;
    late final Color color;
    late final String label;
    if (paused) {
      icon = Icons.pause_circle_outline_rounded;
      color = scheme.onSurfaceVariant;
      label = l10n.budget_paused;
    } else {
      switch (status) {
        case BudgetStatus.over:
          icon = Icons.error_rounded;
          color = scheme.error;
          label = l10n.budget_status_over;
        case BudgetStatus.near:
          icon = Icons.warning_amber_rounded;
          color = scheme.tertiary;
          label = l10n.budget_status_near;
        case BudgetStatus.ok:
          icon = Icons.check_circle_rounded;
          color = scheme.primary;
          label = l10n.budget_status_ok;
      }
    }

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A directional (RTL-safe) progress bar: fills from the start edge.
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({super.key, required this.status, required this.value});

  final BudgetStatus status;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      BudgetStatus.over => scheme.error,
      BudgetStatus.near => scheme.tertiary,
      BudgetStatus.ok => scheme.primary,
    };
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 8,
        color: scheme.surfaceContainerHighest,
        child: FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: clamped,
          child: Container(color: color),
        ),
      ),
    );
  }
}
