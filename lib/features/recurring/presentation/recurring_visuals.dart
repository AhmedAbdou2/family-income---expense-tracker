import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../domain/entities.dart';

String frequencyLabel(BuildContext context, RecurrenceFrequency frequency) {
  final l10n = context.l10n;
  return switch (frequency) {
    RecurrenceFrequency.weekly => l10n.frequency_weekly,
    RecurrenceFrequency.monthly => l10n.frequency_monthly,
    RecurrenceFrequency.yearly => l10n.frequency_yearly,
  };
}
