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

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

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

  /// No description provided for @nav_people.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get nav_people;

  /// No description provided for @nav_vehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get nav_vehicles;

  /// No description provided for @members_title.
  ///
  /// In en, this message translates to:
  /// **'Family members'**
  String get members_title;

  /// No description provided for @family_invite_someone.
  ///
  /// In en, this message translates to:
  /// **'Invite someone new'**
  String get family_invite_someone;

  /// No description provided for @role_no_login.
  ///
  /// In en, this message translates to:
  /// **'No login'**
  String get role_no_login;

  /// No description provided for @member_connect_login.
  ///
  /// In en, this message translates to:
  /// **'Connect a login'**
  String get member_connect_login;

  /// No description provided for @member_connect_hint.
  ///
  /// In en, this message translates to:
  /// **'Create an invite code for {name}. When it\'s accepted, that login becomes this person\'s account.'**
  String member_connect_hint(String name);

  /// No description provided for @member_archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get member_archive;

  /// No description provided for @member_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get member_restore;

  /// No description provided for @member_add.
  ///
  /// In en, this message translates to:
  /// **'Add person'**
  String get member_add;

  /// No description provided for @member_name.
  ///
  /// In en, this message translates to:
  /// **'Person name'**
  String get member_name;

  /// No description provided for @member_name_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sara'**
  String get member_name_hint;

  /// No description provided for @member_rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get member_rename;

  /// No description provided for @member_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete person'**
  String get member_delete;

  /// No description provided for @member_delete_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Delete this person?'**
  String get member_delete_confirm_title;

  /// No description provided for @member_delete_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'You can only delete people who have no transactions.'**
  String get member_delete_confirm_body;

  /// No description provided for @delete_action.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete_action;

  /// No description provided for @member_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get member_active;

  /// No description provided for @member_inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get member_inactive;

  /// No description provided for @member_linked_badge.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get member_linked_badge;

  /// No description provided for @member_you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get member_you;

  /// No description provided for @member_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No people yet'**
  String get member_empty_title;

  /// No description provided for @member_empty_body.
  ///
  /// In en, this message translates to:
  /// **'Add the people in your family so spending can be tracked per person.'**
  String get member_empty_body;

  /// No description provided for @member_in_use.
  ///
  /// In en, this message translates to:
  /// **'This person has transactions and can\'t be deleted.'**
  String get member_in_use;

  /// No description provided for @categories_title.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories_title;

  /// No description provided for @manage_categories.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get manage_categories;

  /// No description provided for @category_add.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get category_add;

  /// No description provided for @category_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get category_edit;

  /// No description provided for @category_name_en.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get category_name_en;

  /// No description provided for @category_name_ar.
  ///
  /// In en, this message translates to:
  /// **'Name (Arabic)'**
  String get category_name_ar;

  /// No description provided for @category_group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get category_group;

  /// No description provided for @category_icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get category_icon;

  /// No description provided for @category_color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get category_color;

  /// No description provided for @category_delete_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Delete this category?'**
  String get category_delete_confirm_title;

  /// No description provided for @category_delete_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'You can only delete categories that have no transactions.'**
  String get category_delete_confirm_body;

  /// No description provided for @group_general.
  ///
  /// In en, this message translates to:
  /// **'General expenses'**
  String get group_general;

  /// No description provided for @group_car.
  ///
  /// In en, this message translates to:
  /// **'Car expenses'**
  String get group_car;

  /// No description provided for @group_fixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed expenses'**
  String get group_fixed;

  /// No description provided for @group_income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get group_income;

  /// No description provided for @type_expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get type_expense;

  /// No description provided for @type_income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get type_income;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @amount_invalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get amount_invalid;

  /// No description provided for @amount_zero.
  ///
  /// In en, this message translates to:
  /// **'The amount must be greater than zero.'**
  String get amount_zero;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @person.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get person;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get note;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @transaction_new_title.
  ///
  /// In en, this message translates to:
  /// **'New transaction'**
  String get transaction_new_title;

  /// No description provided for @transaction_edit_title.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get transaction_edit_title;

  /// No description provided for @transaction_saved.
  ///
  /// In en, this message translates to:
  /// **'Transaction saved.'**
  String get transaction_saved;

  /// No description provided for @transaction_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete transaction'**
  String get transaction_delete;

  /// No description provided for @transaction_delete_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Delete this transaction?'**
  String get transaction_delete_confirm_title;

  /// No description provided for @transaction_delete_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get transaction_delete_confirm_body;

  /// No description provided for @transaction_delete_from_fixed.
  ///
  /// In en, this message translates to:
  /// **'This transaction came from a fixed expense. Deleting it will not cause regeneration.'**
  String get transaction_delete_from_fixed;

  /// No description provided for @transaction_delete_fuel_note.
  ///
  /// In en, this message translates to:
  /// **'The linked fuel log will also be deleted.'**
  String get transaction_delete_fuel_note;

  /// No description provided for @transaction_delete_maintenance_note.
  ///
  /// In en, this message translates to:
  /// **'If this expense came from completing a maintenance reminder, deleting it won\'t make the reminder due again.'**
  String get transaction_delete_maintenance_note;

  /// No description provided for @transaction_delete_pause_rule.
  ///
  /// In en, this message translates to:
  /// **'Also pause this fixed expense'**
  String get transaction_delete_pause_rule;

  /// No description provided for @transaction_deleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted.'**
  String get transaction_deleted;

  /// No description provided for @month_no_data.
  ///
  /// In en, this message translates to:
  /// **'No transactions this month.'**
  String get month_no_data;

  /// No description provided for @month_prev.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get month_prev;

  /// No description provided for @month_next.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get month_next;

  /// No description provided for @filter_everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get filter_everyone;

  /// No description provided for @select_category.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get select_category;

  /// No description provided for @select_person.
  ///
  /// In en, this message translates to:
  /// **'Select a person'**
  String get select_person;

  /// No description provided for @quick_add_title.
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get quick_add_title;

  /// No description provided for @quick_add_more.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get quick_add_more;

  /// No description provided for @dashboard_expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get dashboard_expenses;

  /// No description provided for @dashboard_balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get dashboard_balance;

  /// No description provided for @dashboard_recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get dashboard_recent;

  /// No description provided for @invite_link_title.
  ///
  /// In en, this message translates to:
  /// **'Link to a person'**
  String get invite_link_title;

  /// No description provided for @invite_link_none.
  ///
  /// In en, this message translates to:
  /// **'Join only (no link)'**
  String get invite_link_none;

  /// No description provided for @invite_link_hint.
  ///
  /// In en, this message translates to:
  /// **'When someone accepts, their login becomes this person\'s account.'**
  String get invite_link_hint;

  /// No description provided for @error_member_linked.
  ///
  /// In en, this message translates to:
  /// **'That person is already linked to an account.'**
  String get error_member_linked;

  /// No description provided for @error_login_linked.
  ///
  /// In en, this message translates to:
  /// **'This account is already linked to a person.'**
  String get error_login_linked;

  /// No description provided for @error_invalid_member.
  ///
  /// In en, this message translates to:
  /// **'That person doesn\'t belong to this household.'**
  String get error_invalid_member;

  /// No description provided for @error_category_in_use.
  ///
  /// In en, this message translates to:
  /// **'That category has transactions and can\'t be deleted.'**
  String get error_category_in_use;

  /// No description provided for @error_member_in_use.
  ///
  /// In en, this message translates to:
  /// **'That person has transactions and can\'t be deleted.'**
  String get error_member_in_use;

  /// No description provided for @error_already_linked.
  ///
  /// In en, this message translates to:
  /// **'That person was already linked to another account.'**
  String get error_already_linked;

  /// No description provided for @error_last_owner.
  ///
  /// In en, this message translates to:
  /// **'You\'re the last owner. Make another member an owner first.'**
  String get error_last_owner;

  /// No description provided for @error_cannot_change_own_role.
  ///
  /// In en, this message translates to:
  /// **'You can\'t change your own role. Ask another owner.'**
  String get error_cannot_change_own_role;

  /// No description provided for @error_cannot_remove_self.
  ///
  /// In en, this message translates to:
  /// **'To leave, use Leave household instead.'**
  String get error_cannot_remove_self;

  /// No description provided for @error_child_requires_member.
  ///
  /// In en, this message translates to:
  /// **'A child role needs an account linked to a person.'**
  String get error_child_requires_member;

  /// No description provided for @claim_title.
  ///
  /// In en, this message translates to:
  /// **'Finish setting up your account'**
  String get claim_title;

  /// No description provided for @claim_body.
  ///
  /// In en, this message translates to:
  /// **'Your account joined the household but isn\'t linked to a person yet. Choose the name your family will see.'**
  String get claim_body;

  /// No description provided for @claim_action.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get claim_action;

  /// No description provided for @join_name_hint.
  ///
  /// In en, this message translates to:
  /// **'If the owner already named you, this name isn\'t used.'**
  String get join_name_hint;

  /// No description provided for @household_members_title.
  ///
  /// In en, this message translates to:
  /// **'Household members'**
  String get household_members_title;

  /// No description provided for @login_no_person.
  ///
  /// In en, this message translates to:
  /// **'No person linked'**
  String get login_no_person;

  /// No description provided for @login_change_role.
  ///
  /// In en, this message translates to:
  /// **'Change role'**
  String get login_change_role;

  /// No description provided for @login_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove account'**
  String get login_remove;

  /// No description provided for @login_remove_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Remove this account?'**
  String get login_remove_confirm_title;

  /// No description provided for @login_remove_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'The person and their transactions stay; the account only loses access.'**
  String get login_remove_confirm_body;

  /// No description provided for @leave_household.
  ///
  /// In en, this message translates to:
  /// **'Leave household'**
  String get leave_household;

  /// No description provided for @leave_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Leave this household?'**
  String get leave_confirm_title;

  /// No description provided for @leave_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'You\'ll lose access. Your person and transactions stay with the family.'**
  String get leave_confirm_body;

  /// No description provided for @leave_last_owner_hint.
  ///
  /// In en, this message translates to:
  /// **'Make another member an owner first.'**
  String get leave_last_owner_hint;

  /// No description provided for @invite_target_title.
  ///
  /// In en, this message translates to:
  /// **'Who will join?'**
  String get invite_target_title;

  /// No description provided for @invite_new_person.
  ///
  /// In en, this message translates to:
  /// **'New person (chooses their own name)'**
  String get invite_new_person;

  /// No description provided for @quick_add_no_person.
  ///
  /// In en, this message translates to:
  /// **'This account isn\'t linked to a person yet.'**
  String get quick_add_no_person;

  /// No description provided for @vehicles_section.
  ///
  /// In en, this message translates to:
  /// **'Vehicles & car'**
  String get vehicles_section;

  /// No description provided for @vehicles_title.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get vehicles_title;

  /// No description provided for @vehicles_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No vehicles yet'**
  String get vehicles_empty_title;

  /// No description provided for @vehicles_empty_body.
  ///
  /// In en, this message translates to:
  /// **'Add a vehicle to track fuel and maintenance.'**
  String get vehicles_empty_body;

  /// No description provided for @vehicle_add.
  ///
  /// In en, this message translates to:
  /// **'Add vehicle'**
  String get vehicle_add;

  /// No description provided for @vehicle_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit vehicle'**
  String get vehicle_edit;

  /// No description provided for @vehicle_name.
  ///
  /// In en, this message translates to:
  /// **'Vehicle name'**
  String get vehicle_name;

  /// No description provided for @vehicle_name_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. White Corolla'**
  String get vehicle_name_hint;

  /// No description provided for @vehicle_plate.
  ///
  /// In en, this message translates to:
  /// **'Plate (optional)'**
  String get vehicle_plate;

  /// No description provided for @vehicle_plate_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. ABC 123'**
  String get vehicle_plate_hint;

  /// No description provided for @vehicle_fuel_type.
  ///
  /// In en, this message translates to:
  /// **'Fuel type'**
  String get vehicle_fuel_type;

  /// No description provided for @vehicle_odometer.
  ///
  /// In en, this message translates to:
  /// **'Current odometer (km)'**
  String get vehicle_odometer;

  /// No description provided for @vehicle_odometer_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 45000'**
  String get vehicle_odometer_hint;

  /// No description provided for @vehicle_archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get vehicle_archive;

  /// No description provided for @vehicle_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get vehicle_restore;

  /// No description provided for @vehicle_archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get vehicle_archived;

  /// No description provided for @vehicle_odometer_value.
  ///
  /// In en, this message translates to:
  /// **'Odometer: {km} km'**
  String vehicle_odometer_value(String km);

  /// No description provided for @vehicle_saved.
  ///
  /// In en, this message translates to:
  /// **'Vehicle saved.'**
  String get vehicle_saved;

  /// No description provided for @vehicle_archive_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Archive this vehicle?'**
  String get vehicle_archive_confirm_title;

  /// No description provided for @vehicle_archive_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'It stays in history but is hidden from pickers.'**
  String get vehicle_archive_confirm_body;

  /// No description provided for @fuel_type_petrol.
  ///
  /// In en, this message translates to:
  /// **'Petrol'**
  String get fuel_type_petrol;

  /// No description provided for @fuel_type_diesel.
  ///
  /// In en, this message translates to:
  /// **'Diesel'**
  String get fuel_type_diesel;

  /// No description provided for @fuel_type_electric.
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get fuel_type_electric;

  /// No description provided for @fuel_type_hybrid.
  ///
  /// In en, this message translates to:
  /// **'Hybrid'**
  String get fuel_type_hybrid;

  /// No description provided for @fuel_logs_title.
  ///
  /// In en, this message translates to:
  /// **'Fuel log'**
  String get fuel_logs_title;

  /// No description provided for @fuel_log_add.
  ///
  /// In en, this message translates to:
  /// **'Add fill-up'**
  String get fuel_log_add;

  /// No description provided for @fuel_log_odometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer (km)'**
  String get fuel_log_odometer;

  /// No description provided for @fuel_log_liters.
  ///
  /// In en, this message translates to:
  /// **'Liters'**
  String get fuel_log_liters;

  /// No description provided for @fuel_log_cost.
  ///
  /// In en, this message translates to:
  /// **'Total cost'**
  String get fuel_log_cost;

  /// No description provided for @fuel_log_full_tank.
  ///
  /// In en, this message translates to:
  /// **'Full tank'**
  String get fuel_log_full_tank;

  /// No description provided for @fuel_log_full_badge.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get fuel_log_full_badge;

  /// No description provided for @fuel_log_electric_hint.
  ///
  /// In en, this message translates to:
  /// **'Electric vehicle: liters aren\'t recorded.'**
  String get fuel_log_electric_hint;

  /// No description provided for @fuel_log_saved.
  ///
  /// In en, this message translates to:
  /// **'Fill-up saved.'**
  String get fuel_log_saved;

  /// No description provided for @fuel_logs_empty.
  ///
  /// In en, this message translates to:
  /// **'No fill-ups recorded yet.'**
  String get fuel_logs_empty;

  /// No description provided for @fuel_log_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete fill-up'**
  String get fuel_log_delete;

  /// No description provided for @fuel_log_delete_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Delete this fill-up?'**
  String get fuel_log_delete_confirm_title;

  /// No description provided for @fuel_log_delete_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'The linked fuel expense is deleted too.'**
  String get fuel_log_delete_confirm_body;

  /// No description provided for @fuel_log_deleted.
  ///
  /// In en, this message translates to:
  /// **'Fill-up deleted.'**
  String get fuel_log_deleted;

  /// No description provided for @fuel_stats_title.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get fuel_stats_title;

  /// No description provided for @fuel_stats_l_per_100km.
  ///
  /// In en, this message translates to:
  /// **'L/100km'**
  String get fuel_stats_l_per_100km;

  /// No description provided for @fuel_stats_cost_per_km.
  ///
  /// In en, this message translates to:
  /// **'Cost/km'**
  String get fuel_stats_cost_per_km;

  /// No description provided for @fuel_stats_no_data.
  ///
  /// In en, this message translates to:
  /// **'Add at least two full fill-ups to see consumption.'**
  String get fuel_stats_no_data;

  /// No description provided for @maintenance_title.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenance_title;

  /// No description provided for @maintenance_add.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get maintenance_add;

  /// No description provided for @maintenance_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit reminder'**
  String get maintenance_edit;

  /// No description provided for @maintenance_name.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get maintenance_name;

  /// No description provided for @maintenance_name_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Oil change'**
  String get maintenance_name_hint;

  /// No description provided for @maintenance_due_date.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get maintenance_due_date;

  /// No description provided for @maintenance_due_odometer.
  ///
  /// In en, this message translates to:
  /// **'Due odometer (km)'**
  String get maintenance_due_odometer;

  /// No description provided for @maintenance_interval_days.
  ///
  /// In en, this message translates to:
  /// **'Repeat every (days)'**
  String get maintenance_interval_days;

  /// No description provided for @maintenance_interval_km.
  ///
  /// In en, this message translates to:
  /// **'Repeat every (km)'**
  String get maintenance_interval_km;

  /// No description provided for @maintenance_interval_hint.
  ///
  /// In en, this message translates to:
  /// **'Optional: leaves a new reminder after completion.'**
  String get maintenance_interval_hint;

  /// No description provided for @maintenance_need_one_due.
  ///
  /// In en, this message translates to:
  /// **'Enter a due date or a due odometer.'**
  String get maintenance_need_one_due;

  /// No description provided for @maintenance_status_overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get maintenance_status_overdue;

  /// No description provided for @maintenance_status_due_soon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get maintenance_status_due_soon;

  /// No description provided for @maintenance_empty.
  ///
  /// In en, this message translates to:
  /// **'No maintenance reminders yet.'**
  String get maintenance_empty;

  /// No description provided for @maintenance_due_date_line.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String maintenance_due_date_line(String date);

  /// No description provided for @maintenance_due_odo_line.
  ///
  /// In en, this message translates to:
  /// **'At {km} km'**
  String maintenance_due_odo_line(String km);

  /// No description provided for @maintenance_complete.
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get maintenance_complete;

  /// No description provided for @maintenance_complete_title.
  ///
  /// In en, this message translates to:
  /// **'Complete maintenance'**
  String get maintenance_complete_title;

  /// No description provided for @maintenance_complete_cost.
  ///
  /// In en, this message translates to:
  /// **'Add cost (optional)'**
  String get maintenance_complete_cost;

  /// No description provided for @maintenance_completed.
  ///
  /// In en, this message translates to:
  /// **'Maintenance completed.'**
  String get maintenance_completed;

  /// No description provided for @maintenance_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete reminder'**
  String get maintenance_delete;

  /// No description provided for @maintenance_delete_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Delete this reminder?'**
  String get maintenance_delete_confirm_title;

  /// No description provided for @maintenance_delete_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get maintenance_delete_confirm_body;

  /// No description provided for @maintenance_saved.
  ///
  /// In en, this message translates to:
  /// **'Reminder saved.'**
  String get maintenance_saved;

  /// No description provided for @recurring_section.
  ///
  /// In en, this message translates to:
  /// **'Fixed expenses'**
  String get recurring_section;

  /// No description provided for @recurring_title.
  ///
  /// In en, this message translates to:
  /// **'Fixed expenses'**
  String get recurring_title;

  /// No description provided for @recurring_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No fixed expenses yet'**
  String get recurring_empty_title;

  /// No description provided for @recurring_empty_body.
  ///
  /// In en, this message translates to:
  /// **'Fixed expenses will appear here.'**
  String get recurring_empty_body;

  /// No description provided for @recurring_add.
  ///
  /// In en, this message translates to:
  /// **'Add fixed expense'**
  String get recurring_add;

  /// No description provided for @recurring_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit fixed expense'**
  String get recurring_edit;

  /// No description provided for @recurring_name.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get recurring_name;

  /// No description provided for @recurring_name_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Apartment rent'**
  String get recurring_name_hint;

  /// No description provided for @recurring_amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get recurring_amount;

  /// No description provided for @recurring_frequency.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get recurring_frequency;

  /// No description provided for @frequency_weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get frequency_weekly;

  /// No description provided for @frequency_monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get frequency_monthly;

  /// No description provided for @frequency_yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get frequency_yearly;

  /// No description provided for @recurring_day_of_month.
  ///
  /// In en, this message translates to:
  /// **'Day of month'**
  String get recurring_day_of_month;

  /// No description provided for @recurring_start_date.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get recurring_start_date;

  /// No description provided for @recurring_end_date.
  ///
  /// In en, this message translates to:
  /// **'End date (optional)'**
  String get recurring_end_date;

  /// No description provided for @recurring_next_due_line.
  ///
  /// In en, this message translates to:
  /// **'Next: {date}'**
  String recurring_next_due_line(String date);

  /// No description provided for @recurring_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get recurring_active;

  /// No description provided for @recurring_paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get recurring_paused;

  /// No description provided for @recurring_pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get recurring_pause;

  /// No description provided for @recurring_resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get recurring_resume;

  /// No description provided for @recurring_saved.
  ///
  /// In en, this message translates to:
  /// **'Commitment saved.'**
  String get recurring_saved;

  /// No description provided for @recurring_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete commitment'**
  String get recurring_delete;

  /// No description provided for @recurring_delete_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Delete this commitment?'**
  String get recurring_delete_confirm_title;

  /// No description provided for @recurring_delete_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'Choose what to do with transactions posted from this rule.'**
  String get recurring_delete_confirm_body;

  /// No description provided for @recurring_delete_option_keep.
  ///
  /// In en, this message translates to:
  /// **'Keep already posted transactions'**
  String get recurring_delete_option_keep;

  /// No description provided for @recurring_delete_option_delete_month.
  ///
  /// In en, this message translates to:
  /// **'Also delete the transactions posted from this rule this month'**
  String get recurring_delete_option_delete_month;

  /// No description provided for @recurring_delete_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No transactions will be deleted} =1{1 transaction will be deleted} other{{count} transactions will be deleted}}'**
  String recurring_delete_count(int count);

  /// No description provided for @recurring_deleted.
  ///
  /// In en, this message translates to:
  /// **'Commitment deleted.'**
  String get recurring_deleted;

  /// No description provided for @recurring_generated.
  ///
  /// In en, this message translates to:
  /// **'Posted {count} recurring transactions.'**
  String recurring_generated(int count);

  /// No description provided for @recurring_type_income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get recurring_type_income;

  /// No description provided for @recurring_type_expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get recurring_type_expense;

  /// No description provided for @recurring_inactive_hint.
  ///
  /// In en, this message translates to:
  /// **'Paused commitments don\'t post.'**
  String get recurring_inactive_hint;

  /// No description provided for @recurring_paused_message.
  ///
  /// In en, this message translates to:
  /// **'Paused. Transactions already posted this month stay; delete them separately if needed.'**
  String get recurring_paused_message;

  /// No description provided for @recurring_resumed_message.
  ///
  /// In en, this message translates to:
  /// **'Resumed. The next occurrence is the upcoming one; the paused period isn\'t backfilled.'**
  String get recurring_resumed_message;

  /// No description provided for @error_invalid_vehicle.
  ///
  /// In en, this message translates to:
  /// **'That vehicle doesn\'t belong to this household.'**
  String get error_invalid_vehicle;

  /// No description provided for @error_invalid_item.
  ///
  /// In en, this message translates to:
  /// **'That maintenance reminder doesn\'t exist.'**
  String get error_invalid_item;

  /// No description provided for @error_invalid_log.
  ///
  /// In en, this message translates to:
  /// **'That fill-up doesn\'t exist.'**
  String get error_invalid_log;

  /// No description provided for @error_invalid_value.
  ///
  /// In en, this message translates to:
  /// **'Enter valid values.'**
  String get error_invalid_value;

  /// No description provided for @error_odometer_backwards.
  ///
  /// In en, this message translates to:
  /// **'The odometer can\'t be lower than an earlier fill-up.'**
  String get error_odometer_backwards;

  /// No description provided for @error_no_car_category.
  ///
  /// In en, this message translates to:
  /// **'Add a car category first.'**
  String get error_no_car_category;

  /// No description provided for @error_no_linked_person.
  ///
  /// In en, this message translates to:
  /// **'Link this account to a person first.'**
  String get error_no_linked_person;

  /// No description provided for @nav_fixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed expenses'**
  String get nav_fixed;

  /// No description provided for @nav_fixed_short.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get nav_fixed_short;

  /// No description provided for @nav_pets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get nav_pets;

  /// No description provided for @account_fallback.
  ///
  /// In en, this message translates to:
  /// **'My account'**
  String get account_fallback;

  /// No description provided for @profile_title.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile_title;

  /// No description provided for @profile_month.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get profile_month;

  /// No description provided for @group_pet.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get group_pet;

  /// No description provided for @pets_section.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get pets_section;

  /// No description provided for @pets_title.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get pets_title;

  /// No description provided for @pets_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No pets yet'**
  String get pets_empty_title;

  /// No description provided for @pets_empty_body.
  ///
  /// In en, this message translates to:
  /// **'Add your cats, dogs and other companions to track their costs.'**
  String get pets_empty_body;

  /// No description provided for @pet_add.
  ///
  /// In en, this message translates to:
  /// **'Add pet'**
  String get pet_add;

  /// No description provided for @pet_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit pet'**
  String get pet_edit;

  /// No description provided for @pet_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get pet_name;

  /// No description provided for @pet_name_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Simba'**
  String get pet_name_hint;

  /// No description provided for @pet_type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get pet_type;

  /// No description provided for @pet_type_cat.
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get pet_type_cat;

  /// No description provided for @pet_type_dog.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get pet_type_dog;

  /// No description provided for @pet_type_bird.
  ///
  /// In en, this message translates to:
  /// **'Bird'**
  String get pet_type_bird;

  /// No description provided for @pet_type_fish.
  ///
  /// In en, this message translates to:
  /// **'Fish'**
  String get pet_type_fish;

  /// No description provided for @pet_type_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get pet_type_other;

  /// No description provided for @pet_birth_date.
  ///
  /// In en, this message translates to:
  /// **'Birth date (optional)'**
  String get pet_birth_date;

  /// No description provided for @pet_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get pet_notes;

  /// No description provided for @pet_notes_hint.
  ///
  /// In en, this message translates to:
  /// **'Allergies, vet, food…'**
  String get pet_notes_hint;

  /// No description provided for @pet_archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get pet_archive;

  /// No description provided for @pet_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get pet_restore;

  /// No description provided for @pet_archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get pet_archived;

  /// No description provided for @pet_saved.
  ///
  /// In en, this message translates to:
  /// **'Pet saved.'**
  String get pet_saved;

  /// No description provided for @pet_archive_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Archive this pet?'**
  String get pet_archive_confirm_title;

  /// No description provided for @pet_archive_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'It stays under Archived and keeps its expenses.'**
  String get pet_archive_confirm_body;

  /// No description provided for @pet_monthly_total.
  ///
  /// In en, this message translates to:
  /// **'This month: {amount}'**
  String pet_monthly_total(String amount);

  /// No description provided for @pet_expenses_title.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get pet_expenses_title;

  /// No description provided for @pet_expenses_empty.
  ///
  /// In en, this message translates to:
  /// **'No expenses this month.'**
  String get pet_expenses_empty;

  /// No description provided for @pet_add_expense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get pet_add_expense;

  /// No description provided for @transaction_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get transaction_none;

  /// No description provided for @transaction_pet.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get transaction_pet;

  /// No description provided for @transaction_pin_fixed.
  ///
  /// In en, this message translates to:
  /// **'Make a monthly fixed expense'**
  String get transaction_pin_fixed;

  /// No description provided for @transaction_pin_fixed_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Make this a monthly fixed expense?'**
  String get transaction_pin_fixed_confirm_title;

  /// No description provided for @transaction_pin_fixed_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'A monthly commitment will be created and posted automatically.'**
  String get transaction_pin_fixed_confirm_body;

  /// No description provided for @transaction_pinned_fixed.
  ///
  /// In en, this message translates to:
  /// **'Added to fixed commitments.'**
  String get transaction_pinned_fixed;

  /// No description provided for @recurring_link_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get recurring_link_none;

  /// No description provided for @recurring_link_vehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle (optional)'**
  String get recurring_link_vehicle;

  /// No description provided for @recurring_link_pet.
  ///
  /// In en, this message translates to:
  /// **'Pet (optional)'**
  String get recurring_link_pet;

  /// No description provided for @dashboard_fixed_header.
  ///
  /// In en, this message translates to:
  /// **'Fixed expenses this month'**
  String get dashboard_fixed_header;

  /// No description provided for @dashboard_fixed_posted.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get dashboard_fixed_posted;

  /// No description provided for @dashboard_fixed_due.
  ///
  /// In en, this message translates to:
  /// **'Still due'**
  String get dashboard_fixed_due;

  /// No description provided for @dashboard_after_fixed.
  ///
  /// In en, this message translates to:
  /// **'Left after fixed'**
  String get dashboard_after_fixed;

  /// No description provided for @dashboard_expenses_help.
  ///
  /// In en, this message translates to:
  /// **'All expenses this month, including posted fixed ones.'**
  String get dashboard_expenses_help;

  /// No description provided for @dashboard_fixed_posted_help.
  ///
  /// In en, this message translates to:
  /// **'Fixed commitments already posted this month.'**
  String get dashboard_fixed_posted_help;

  /// No description provided for @dashboard_fixed_due_help.
  ///
  /// In en, this message translates to:
  /// **'Fixed commitments still to post later this month.'**
  String get dashboard_fixed_due_help;

  /// No description provided for @dashboard_after_fixed_help.
  ///
  /// In en, this message translates to:
  /// **'Income minus posted and still-due fixed commitments.'**
  String get dashboard_after_fixed_help;

  /// No description provided for @error_invalid_pet.
  ///
  /// In en, this message translates to:
  /// **'That pet doesn\'t belong to this household.'**
  String get error_invalid_pet;
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
