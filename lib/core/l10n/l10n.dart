import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Shorthand for `AppLocalizations.of(context)` used all over the UI:
/// `context.l10n.sign_in_title`.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
