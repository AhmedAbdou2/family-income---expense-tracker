// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Family Finance';

  @override
  String get sign_in_title => 'Sign in';

  @override
  String get sign_up_title => 'Create account';

  @override
  String get forgot_password_title => 'Reset password';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirm_password => 'Confirm password';

  @override
  String get sign_in_action => 'Sign in';

  @override
  String get sign_up_action => 'Create account';

  @override
  String get send_reset_link => 'Send reset link';

  @override
  String get reset_email_sent => 'Check your email for a password reset link.';

  @override
  String get sign_up_email_sent =>
      'Your account was created. Confirm your email address, then sign in.';

  @override
  String get no_account_prompt => 'Don\'t have an account?';

  @override
  String get have_account_prompt => 'Already have an account?';

  @override
  String get forgot_password_prompt => 'Forgot password?';

  @override
  String get back_to_sign_in => 'Back to sign in';

  @override
  String get passwords_dont_match => 'Passwords don\'t match';

  @override
  String get invalid_email => 'Enter a valid email address';

  @override
  String get password_too_short => 'Password must be at least 6 characters';

  @override
  String get field_required => 'This field is required';

  @override
  String get setup_title => 'Set up your household';

  @override
  String get setup_subtitle =>
      'Create a new household, or join an existing one with an invite code.';

  @override
  String get create_household_action => 'Create a household';

  @override
  String get join_household_action => 'Join with an invite code';

  @override
  String get household_name => 'Household name';

  @override
  String get household_name_hint => 'e.g. Al-Ahmed family';

  @override
  String get currency => 'Currency';

  @override
  String get invite_code => 'Invite code';

  @override
  String get invite_code_hint => 'e.g. A1B2C3';

  @override
  String get invalid_invite_code => 'Enter the 6-character invite code';

  @override
  String get nav_dashboard => 'Dashboard';

  @override
  String get nav_transactions => 'Transactions';

  @override
  String get nav_settings => 'Settings';

  @override
  String get empty_dashboard_title => 'Nothing here yet';

  @override
  String get empty_dashboard_body =>
      'Your monthly income, expenses and charts will appear here.';

  @override
  String get empty_transactions_title => 'No transactions yet';

  @override
  String get empty_transactions_body =>
      'Once you start recording income and expenses, they will be listed here.';

  @override
  String get settings_title => 'Settings';

  @override
  String get language_section => 'Language';

  @override
  String get language_system => 'System default';

  @override
  String get language_english => 'English';

  @override
  String get language_arabic => 'Arabic';

  @override
  String get theme_section => 'Theme';

  @override
  String get theme_system => 'System default';

  @override
  String get theme_light => 'Light';

  @override
  String get theme_dark => 'Dark';

  @override
  String get digits_section => 'Numbers';

  @override
  String get arabic_digits_title => 'Arabic-Indic digits';

  @override
  String get arabic_digits_subtitle => 'Show numbers as ٠١٢٣ instead of 0123';

  @override
  String get household_section => 'Household';

  @override
  String household_currency_line(String currency) {
    return 'Currency: $currency';
  }

  @override
  String your_role(String role) {
    return 'Your role: $role';
  }

  @override
  String get role_owner => 'Owner';

  @override
  String get role_adult => 'Adult';

  @override
  String get role_child => 'Child';

  @override
  String get invites_section => 'Invite codes';

  @override
  String get invites_empty => 'No invite codes yet.';

  @override
  String get create_invite_action => 'Create invite code';

  @override
  String get invite_as => 'Invite as';

  @override
  String get invite_created_title => 'Invite code ready';

  @override
  String get invite_code_hint_share =>
      'Share this code so someone can join your household.';

  @override
  String get copy_code => 'Copy code';

  @override
  String get copied => 'Copied';

  @override
  String invite_expires_on(String date) {
    return 'Expires $date';
  }

  @override
  String get invite_status_active => 'Active';

  @override
  String get invite_status_used => 'Used';

  @override
  String get sign_out => 'Sign out';

  @override
  String get sign_out_confirm_title => 'Sign out?';

  @override
  String get sign_out_confirm_body =>
      'You will need your email and password to sign back in.';

  @override
  String get loading => 'Loading...';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get error_title => 'Something went wrong';

  @override
  String get error_network => 'No internet connection. Please try again.';

  @override
  String get error_timeout => 'The request timed out. Please try again.';

  @override
  String get error_unknown => 'Unexpected error. Please try again.';

  @override
  String get error_invalid_credentials => 'Wrong email or password.';

  @override
  String get error_email_exists => 'An account with this email already exists.';

  @override
  String get error_email_not_confirmed => 'Confirm your email address first.';

  @override
  String get error_weak_password =>
      'Password is too weak. Use at least 6 characters.';

  @override
  String get error_invalid_email => 'Enter a valid email address.';

  @override
  String get error_too_many_requests =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get error_invite_not_found => 'That invite code doesn\'t exist.';

  @override
  String get error_invite_used => 'That invite code was already used.';

  @override
  String get error_invite_expired => 'That invite code has expired.';

  @override
  String get error_already_member => 'You\'re already part of that household.';

  @override
  String get error_not_member => 'You don\'t belong to that household.';

  @override
  String get error_forbidden => 'You don\'t have permission to do that.';

  @override
  String get error_invalid_name => 'Enter a valid name.';

  @override
  String get error_invalid_currency => 'Enter a valid currency.';

  @override
  String get error_invalid_role => 'That invite role is not allowed.';

  @override
  String get error_membership_immutable =>
      'Membership details can\'t be changed here.';

  @override
  String get nav_people => 'People';

  @override
  String get members_title => 'People';

  @override
  String get member_add => 'Add person';

  @override
  String get member_name => 'Person name';

  @override
  String get member_name_hint => 'e.g. Sara';

  @override
  String get member_rename => 'Rename';

  @override
  String get member_delete => 'Delete person';

  @override
  String get member_delete_confirm_title => 'Delete this person?';

  @override
  String get member_delete_confirm_body =>
      'You can only delete people who have no transactions.';

  @override
  String get delete_action => 'Delete';

  @override
  String get member_active => 'Active';

  @override
  String get member_inactive => 'Inactive';

  @override
  String get member_linked_badge => 'Linked';

  @override
  String get member_you => 'You';

  @override
  String get member_empty_title => 'No people yet';

  @override
  String get member_empty_body =>
      'Add the people in your family so spending can be tracked per person.';

  @override
  String get member_in_use =>
      'This person has transactions and can\'t be deleted.';

  @override
  String get categories_title => 'Categories';

  @override
  String get manage_categories => 'Manage categories';

  @override
  String get category_add => 'Add category';

  @override
  String get category_edit => 'Edit category';

  @override
  String get category_name_en => 'Name (English)';

  @override
  String get category_name_ar => 'Name (Arabic)';

  @override
  String get category_group => 'Group';

  @override
  String get category_icon => 'Icon';

  @override
  String get category_color => 'Color';

  @override
  String get category_delete_confirm_title => 'Delete this category?';

  @override
  String get category_delete_confirm_body =>
      'You can only delete categories that have no transactions.';

  @override
  String get group_general => 'General expenses';

  @override
  String get group_car => 'Car expenses';

  @override
  String get group_fixed => 'Fixed commitments';

  @override
  String get group_income => 'Income';

  @override
  String get type_expense => 'Expense';

  @override
  String get type_income => 'Income';

  @override
  String get amount => 'Amount';

  @override
  String get amount_invalid => 'Enter a valid amount.';

  @override
  String get amount_zero => 'The amount must be greater than zero.';

  @override
  String get category => 'Category';

  @override
  String get person => 'Person';

  @override
  String get date => 'Date';

  @override
  String get note => 'Note (optional)';

  @override
  String get save => 'Save';

  @override
  String get transaction_new_title => 'New transaction';

  @override
  String get transaction_edit_title => 'Edit transaction';

  @override
  String get transaction_saved => 'Transaction saved.';

  @override
  String get transaction_delete => 'Delete transaction';

  @override
  String get transaction_delete_confirm_title => 'Delete this transaction?';

  @override
  String get transaction_delete_confirm_body => 'This can\'t be undone.';

  @override
  String get transaction_deleted => 'Transaction deleted.';

  @override
  String get month_no_data => 'No transactions this month.';

  @override
  String get month_prev => 'Previous month';

  @override
  String get month_next => 'Next month';

  @override
  String get filter_everyone => 'Everyone';

  @override
  String get select_category => 'Select a category';

  @override
  String get select_person => 'Select a person';

  @override
  String get quick_add_title => 'Quick add';

  @override
  String get quick_add_more => 'More options';

  @override
  String get dashboard_expenses => 'Expenses';

  @override
  String get dashboard_balance => 'Balance';

  @override
  String get dashboard_recent => 'Recent';

  @override
  String get invite_link_title => 'Link to a person';

  @override
  String get invite_link_none => 'Join only (no link)';

  @override
  String get invite_link_hint =>
      'When someone accepts, their login becomes this person\'s account.';

  @override
  String get error_member_linked =>
      'That person is already linked to an account.';

  @override
  String get error_login_linked =>
      'This account is already linked to a person.';

  @override
  String get error_invalid_member =>
      'That person doesn\'t belong to this household.';

  @override
  String get error_category_in_use =>
      'That category has transactions and can\'t be deleted.';

  @override
  String get error_member_in_use =>
      'That person has transactions and can\'t be deleted.';
}
