import 'package:flutter/material.dart';

import '../errors/app_exception.dart';
import '../l10n/l10n.dart';

/// Localizes any thrown object into a user-facing message.
String errorMessage(BuildContext context, Object error) {
  final mapped = ExceptionMapper.map(error);
  final l10n = context.l10n;
  return switch (mapped.code) {
    AppErrorCode.network => l10n.error_network,
    AppErrorCode.timeout => l10n.error_timeout,
    AppErrorCode.invalidCredentials => l10n.error_invalid_credentials,
    AppErrorCode.emailExists => l10n.error_email_exists,
    AppErrorCode.emailNotConfirmed => l10n.error_email_not_confirmed,
    AppErrorCode.weakPassword => l10n.error_weak_password,
    AppErrorCode.invalidEmail => l10n.error_invalid_email,
    AppErrorCode.tooManyRequests => l10n.error_too_many_requests,
    AppErrorCode.inviteNotFound => l10n.error_invite_not_found,
    AppErrorCode.inviteUsed => l10n.error_invite_used,
    AppErrorCode.inviteExpired => l10n.error_invite_expired,
    AppErrorCode.alreadyMember => l10n.error_already_member,
    AppErrorCode.notMember => l10n.error_not_member,
    AppErrorCode.forbidden => l10n.error_forbidden,
    AppErrorCode.invalidName => l10n.error_invalid_name,
    AppErrorCode.invalidCurrency => l10n.error_invalid_currency,
    AppErrorCode.invalidRole => l10n.error_invalid_role,
    AppErrorCode.membershipImmutable => l10n.error_membership_immutable,
    AppErrorCode.memberLinked => l10n.error_member_linked,
    AppErrorCode.loginLinked => l10n.error_login_linked,
    AppErrorCode.invalidMember => l10n.error_invalid_member,
    AppErrorCode.alreadyLinked => l10n.error_already_linked,
    AppErrorCode.lastOwner => l10n.error_last_owner,
    AppErrorCode.cannotChangeOwnRole => l10n.error_cannot_change_own_role,
    AppErrorCode.cannotRemoveSelf => l10n.error_cannot_remove_self,
    AppErrorCode.childRequiresMember => l10n.error_child_requires_member,
    AppErrorCode.categoryInUse => l10n.error_category_in_use,
    AppErrorCode.memberInUse => l10n.error_member_in_use,
    AppErrorCode.invalidVehicle => l10n.error_invalid_vehicle,
    AppErrorCode.invalidItem => l10n.error_invalid_item,
    AppErrorCode.invalidLog => l10n.error_invalid_log,
    AppErrorCode.invalidValue => l10n.error_invalid_value,
    AppErrorCode.odometerBackwards => l10n.error_odometer_backwards,
    AppErrorCode.noCarCategory => l10n.error_no_car_category,
    AppErrorCode.noLinkedPerson => l10n.error_no_linked_person,
    AppErrorCode.invalidPet => l10n.error_invalid_pet,
    AppErrorCode.invalidRule => l10n.error_invalid_rule,
    AppErrorCode.alreadyArchived => l10n.error_already_archived,
    AppErrorCode.invalidCategory => l10n.error_invalid_category,
    AppErrorCode.invalidBudget => l10n.error_invalid_budget,
    AppErrorCode.invalidTransaction => l10n.error_invalid_transaction,
    AppErrorCode.invalidReceipt => l10n.error_invalid_receipt,
    AppErrorCode.invalidMime => l10n.error_invalid_mime,
    AppErrorCode.limitReached => l10n.error_limit_reached,
    AppErrorCode.invalidReminder => l10n.error_invalid_reminder,
    AppErrorCode.noPetCategory => l10n.error_no_pet_category,
    AppErrorCode.backupTooLarge => l10n.error_backup_too_large,
    AppErrorCode.unknown => l10n.error_unknown,
  };
}

/// Full-screen error state with an optional retry action.
class ErrorView extends StatelessWidget {  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(
              errorMessage(context, error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(onPressed: onRetry, child: Text(context.l10n.retry)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline banner used at the top of forms.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage(context, error),
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
