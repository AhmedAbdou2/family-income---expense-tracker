import 'package:family_income_expense_tracker/core/l10n/generated/app_localizations_ar.dart';
import 'package:family_income_expense_tracker/core/l10n/generated/app_localizations_en.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/settings/presentation/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// An expired invite used to be shown with the "Active" badge (the expired
/// branch reused the active label). These tests pin the three invite states to
/// their own labels in both languages.
Invite _invite({String? usedBy, DateTime? expiresAt}) => Invite(
      id: 'i1',
      code: 'ABC123',
      role: MemberRole.adult,
      usedBy: usedBy,
      expiresAt: expiresAt,
    );

void main() {
  test('an expired invite is labelled Expired, never Active', () {
    final expired = _invite(
      expiresAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
    );

    expect(expired.isActive, isFalse);
    expect(expired.isExpired, isTrue);
    expect(inviteStatusLabel(AppLocalizationsEn(), expired), 'Expired');
    expect(inviteStatusLabel(AppLocalizationsAr(), expired), 'منتهي');
  });

  test('an in-date invite is labelled Active', () {
    final active = _invite(
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
    );

    expect(inviteStatusLabel(AppLocalizationsEn(), active), 'Active');
    expect(inviteStatusLabel(AppLocalizationsAr(), active), 'نشط');
  });

  test('an invite with no expiry is labelled Active', () {
    final noExpiry = _invite();

    expect(inviteStatusLabel(AppLocalizationsEn(), noExpiry), 'Active');
    expect(inviteStatusLabel(AppLocalizationsAr(), noExpiry), 'نشط');
  });

  test('a used invite is labelled Used even if it also expired', () {
    final used = _invite(
      usedBy: 'u9',
      expiresAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
    );

    expect(inviteStatusLabel(AppLocalizationsEn(), used), 'Used');
    expect(inviteStatusLabel(AppLocalizationsAr(), used), 'مُستخدَم');
  });
}
