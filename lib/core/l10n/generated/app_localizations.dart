import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Application name shown in app bars and the OS task switcher
  ///
  /// In en, this message translates to:
  /// **'Family Finance'**
  String get appTitle;

  /// No description provided for @sign_in_title.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get sign_in_title;

  /// No description provided for @sign_up_title.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get sign_up_title;

  /// No description provided for @forgot_password_title.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgot_password_title;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirm_password.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirm_password;

  /// No description provided for @sign_in_action.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get sign_in_action;

  /// No description provided for @sign_up_action.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get sign_up_action;

  /// No description provided for @send_reset_link.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get send_reset_link;

  /// No description provided for @reset_email_sent.
  ///
  /// In en, this message translates to:
  /// **'Check your email for a password reset link.'**
  String get reset_email_sent;

  /// No description provided for @sign_up_email_sent.
  ///
  /// In en, this message translates to:
  /// **'Your account was created. Confirm your email address, then sign in.'**
  String get sign_up_email_sent;

  /// No description provided for @no_account_prompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get no_account_prompt;

  /// No description provided for @have_account_prompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get have_account_prompt;

  /// No description provided for @forgot_password_prompt.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgot_password_prompt;

  /// No description provided for @back_to_sign_in.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get back_to_sign_in;

  /// No description provided for @passwords_dont_match.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwords_dont_match;

  /// No description provided for @invalid_email.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get invalid_email;

  /// No description provided for @password_too_short.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get password_too_short;

  /// No description provided for @field_required.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get field_required;

  /// No description provided for @setup_title.
  ///
  /// In en, this message translates to:
  /// **'Set up your household'**
  String get setup_title;

  /// No description provided for @setup_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new household, or join an existing one with an invite code.'**
  String get setup_subtitle;

  /// No description provided for @create_household_action.
  ///
  /// In en, this message translates to:
  /// **'Create a household'**
  String get create_household_action;

  /// No description provided for @join_household_action.
  ///
  /// In en, this message translates to:
  /// **'Join with an invite code'**
  String get join_household_action;

  /// No description provided for @household_name.
  ///
  /// In en, this message translates to:
  /// **'Household name'**
  String get household_name;

  /// No description provided for @household_name_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Al-Ahmed family'**
  String get household_name_hint;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @invite_code.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get invite_code;

  /// No description provided for @invite_code_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. A1B2C3'**
  String get invite_code_hint;

  /// No description provided for @invalid_invite_code.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-character invite code'**
  String get invalid_invite_code;

  /// No description provided for @nav_dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get nav_dashboard;

  /// No description provided for @nav_transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get nav_transactions;

  /// No description provided for @nav_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get nav_settings;

  /// No description provided for @empty_dashboard_title.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get empty_dashboard_title;

  /// No description provided for @empty_dashboard_body.
  ///
  /// In en, this message translates to:
  /// **'Your monthly income, expenses and charts will appear here.'**
  String get empty_dashboard_body;

  /// No description provided for @empty_transactions_title.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get empty_transactions_title;

  /// No description provided for @empty_transactions_body.
  ///
  /// In en, this message translates to:
  /// **'Once you start recording income and expenses, they will be listed here.'**
  String get empty_transactions_body;

  /// No description provided for @settings_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_title;

  /// No description provided for @language_section.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language_section;

  /// No description provided for @language_system.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get language_system;

  /// No description provided for @language_english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get language_english;

  /// No description provided for @language_arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get language_arabic;

  /// No description provided for @theme_section.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme_section;

  /// No description provided for @theme_system.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get theme_system;

  /// No description provided for @theme_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get theme_light;

  /// No description provided for @theme_dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get theme_dark;

  /// No description provided for @digits_section.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get digits_section;

  /// No description provided for @arabic_digits_title.
  ///
  /// In en, this message translates to:
  /// **'Arabic-Indic digits'**
  String get arabic_digits_title;

  /// No description provided for @arabic_digits_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Show numbers as ٠١٢٣ instead of 0123'**
  String get arabic_digits_subtitle;

  /// No description provided for @household_section.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get household_section;

  /// No description provided for @household_currency_line.
  ///
  /// In en, this message translates to:
  /// **'Currency: {currency}'**
  String household_currency_line(String currency);

  /// No description provided for @your_role.
  ///
  /// In en, this message translates to:
  /// **'Your role: {role}'**
  String your_role(String role);

  /// No description provided for @role_owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get role_owner;

  /// No description provided for @role_adult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get role_adult;

  /// No description provided for @role_child.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get role_child;

  /// No description provided for @invites_section.
  ///
  /// In en, this message translates to:
  /// **'Invite codes'**
  String get invites_section;

  /// No description provided for @invites_empty.
  ///
  /// In en, this message translates to:
  /// **'No invite codes yet.'**
  String get invites_empty;

  /// No description provided for @create_invite_action.
  ///
  /// In en, this message translates to:
  /// **'Create invite code'**
  String get create_invite_action;

  /// No description provided for @invite_as.
  ///
  /// In en, this message translates to:
  /// **'Invite as'**
  String get invite_as;

  /// No description provided for @invite_created_title.
  ///
  /// In en, this message translates to:
  /// **'Invite code ready'**
  String get invite_created_title;

  /// No description provided for @invite_code_hint_share.
  ///
  /// In en, this message translates to:
  /// **'Share this code so someone can join your household.'**
  String get invite_code_hint_share;

  /// No description provided for @copy_code.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copy_code;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @invite_expires_on.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String invite_expires_on(String date);

  /// No description provided for @invite_status_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get invite_status_active;

  /// No description provided for @invite_status_used.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get invite_status_used;

  /// No description provided for @sign_out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get sign_out;

  /// No description provided for @sign_out_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get sign_out_confirm_title;

  /// No description provided for @sign_out_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'You will need your email and password to sign back in.'**
  String get sign_out_confirm_body;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @error_title.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get error_title;

  /// No description provided for @error_network.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please try again.'**
  String get error_network;

  /// No description provided for @error_timeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get error_timeout;

  /// No description provided for @error_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error. Please try again.'**
  String get error_unknown;

  /// No description provided for @error_invalid_credentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get error_invalid_credentials;

  /// No description provided for @error_email_exists.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get error_email_exists;

  /// No description provided for @error_email_not_confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email address first.'**
  String get error_email_not_confirmed;

  /// No description provided for @error_weak_password.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Use at least 6 characters.'**
  String get error_weak_password;

  /// No description provided for @error_invalid_email.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get error_invalid_email;

  /// No description provided for @error_too_many_requests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get error_too_many_requests;

  /// No description provided for @error_invite_not_found.
  ///
  /// In en, this message translates to:
  /// **'That invite code doesn\'t exist.'**
  String get error_invite_not_found;

  /// No description provided for @error_invite_used.
  ///
  /// In en, this message translates to:
  /// **'That invite code was already used.'**
  String get error_invite_used;

  /// No description provided for @error_invite_expired.
  ///
  /// In en, this message translates to:
  /// **'That invite code has expired.'**
  String get error_invite_expired;

  /// No description provided for @error_already_member.
  ///
  /// In en, this message translates to:
  /// **'You\'re already part of that household.'**
  String get error_already_member;

  /// No description provided for @error_not_member.
  ///
  /// In en, this message translates to:
  /// **'You don\'t belong to that household.'**
  String get error_not_member;

  /// No description provided for @error_forbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do that.'**
  String get error_forbidden;

  /// No description provided for @error_invalid_name.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid name.'**
  String get error_invalid_name;

  /// No description provided for @error_invalid_currency.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid currency.'**
  String get error_invalid_currency;

  /// No description provided for @error_invalid_role.
  ///
  /// In en, this message translates to:
  /// **'That invite role is not allowed.'**
  String get error_invalid_role;

  /// No description provided for @error_membership_immutable.
  ///
  /// In en, this message translates to:
  /// **'Membership details can\'t be changed here.'**
  String get error_membership_immutable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
