import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';

/// Translates the codes returned by [Validators] into localized messages.
String? fieldError(BuildContext context, String? code) {
  if (code == null) return null;
  final l10n = context.l10n;
  return switch (code) {
    'required' => l10n.field_required,
    'invalid_email' => l10n.invalid_email,
    'too_short' => l10n.password_too_short,
    'too_long' => l10n.error_invalid_name,
    'invalid_code' => l10n.invalid_invite_code,
    'mismatch' => l10n.passwords_dont_match,
    _ => l10n.error_unknown,
  };
}
