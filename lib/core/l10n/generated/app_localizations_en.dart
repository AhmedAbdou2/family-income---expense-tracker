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
  String get reset_email_sent =>
      'We emailed you a link to reset your password.';

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
      'Create a new household, or join one with an invite code.';

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
  String currency_name(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'SAR': 'Saudi Riyal',
      'AED': 'UAE Dirham',
      'EGP': 'Egyptian Pound',
      'KWD': 'Kuwaiti Dinar',
      'QAR': 'Qatari Riyal',
      'OMR': 'Omani Rial',
      'BHD': 'Bahraini Dinar',
      'JOD': 'Jordanian Dinar',
      'IQD': 'Iraqi Dinar',
      'YER': 'Yemeni Rial',
      'SDG': 'Sudanese Pound',
      'MAD': 'Moroccan Dirham',
      'TND': 'Tunisian Dinar',
      'DZD': 'Algerian Dinar',
      'LBP': 'Lebanese Pound',
      'SYP': 'Syrian Pound',
      'TRY': 'Turkish Lira',
      'USD': 'US Dollar',
      'EUR': 'Euro',
      'GBP': 'British Pound',
      'other': '$code',
    });
    return '$_temp0';
  }

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
      'Your monthly income and expenses will appear here.';

  @override
  String get empty_transactions_title => 'No transactions yet';

  @override
  String get empty_transactions_body =>
      'Income and expenses you record will be listed here.';

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
  String get invite_status_expired => 'Expired';

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
  String get next => 'Next';

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
  String get nav_people => 'Family';

  @override
  String get nav_vehicles => 'Vehicles';

  @override
  String get members_title => 'Family members';

  @override
  String get family_invite_someone => 'Invite someone new';

  @override
  String get role_no_login => 'No login';

  @override
  String get member_connect_login => 'Connect a login';

  @override
  String member_connect_hint(String name) {
    return 'Create an invite code for $name. When it\'s accepted, that login becomes this person\'s account.';
  }

  @override
  String get member_archive => 'Archive';

  @override
  String get member_restore => 'Restore';

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
      'Only people with no transactions can be deleted.';

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
      'Only categories with no transactions can be deleted.';

  @override
  String get group_general => 'General expenses';

  @override
  String get group_car => 'Car expenses';

  @override
  String get group_fixed => 'Fixed expenses';

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
  String get transaction_delete_from_fixed =>
      'This came from a fixed expense. Deleting it won\'t make it post again.';

  @override
  String get transaction_delete_fuel_note =>
      'The linked fuel log will also be deleted.';

  @override
  String get transaction_delete_maintenance_note =>
      'If this expense came from completing a maintenance reminder, deleting it won\'t make the reminder due again.';

  @override
  String get transaction_delete_pause_rule => 'Also pause this fixed expense';

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
  String get dashboard_income => 'Income';

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

  @override
  String get error_already_linked =>
      'That person was already linked to another account.';

  @override
  String get error_last_owner =>
      'You\'re the last owner. Make another member an owner first.';

  @override
  String get error_cannot_change_own_role =>
      'You can\'t change your own role. Ask another owner.';

  @override
  String get error_cannot_remove_self =>
      'To leave, use Leave household instead.';

  @override
  String get error_child_requires_member =>
      'A child role needs an account linked to a person.';

  @override
  String get claim_title => 'Finish setting up your account';

  @override
  String get claim_body =>
      'Your account joined the household but isn\'t linked to a person yet. Choose the name your family will see.';

  @override
  String get claim_action => 'Continue';

  @override
  String get join_name_hint =>
      'If the owner already named you, this name isn\'t used.';

  @override
  String get household_members_title => 'Household members';

  @override
  String get login_no_person => 'No person linked';

  @override
  String get login_change_role => 'Change role';

  @override
  String get login_remove => 'Remove account';

  @override
  String get login_remove_confirm_title => 'Remove this account?';

  @override
  String get login_remove_confirm_body =>
      'The person and their transactions stay; the account only loses access.';

  @override
  String get leave_household => 'Leave household';

  @override
  String get leave_confirm_title => 'Leave this household?';

  @override
  String get leave_confirm_body =>
      'You\'ll lose access. Your person and transactions stay with the family.';

  @override
  String get leave_last_owner_hint => 'Make another member an owner first.';

  @override
  String get invite_target_title => 'Who will join?';

  @override
  String get invite_new_person => 'New person (chooses their own name)';

  @override
  String get quick_add_no_person =>
      'This account isn\'t linked to a person yet.';

  @override
  String get vehicles_section => 'Vehicles';

  @override
  String get vehicles_title => 'Vehicles';

  @override
  String get vehicles_empty_title => 'No vehicles yet';

  @override
  String get vehicles_empty_body =>
      'Add a vehicle to track fuel and maintenance.';

  @override
  String get vehicle_add => 'Add vehicle';

  @override
  String get vehicle_edit => 'Edit vehicle';

  @override
  String get vehicle_name => 'Vehicle name';

  @override
  String get vehicle_name_hint => 'e.g. White Corolla';

  @override
  String get vehicle_plate => 'Plate (optional)';

  @override
  String get vehicle_plate_hint => 'e.g. ABC 123';

  @override
  String get vehicle_fuel_type => 'Fuel type';

  @override
  String get vehicle_odometer => 'Current odometer (km)';

  @override
  String get vehicle_odometer_hint => 'e.g. 45000';

  @override
  String get vehicle_archive => 'Archive';

  @override
  String get vehicle_restore => 'Restore';

  @override
  String get vehicle_archived => 'Archived';

  @override
  String vehicle_odometer_value(String km) {
    return 'Odometer: $km km';
  }

  @override
  String get vehicle_saved => 'Vehicle saved.';

  @override
  String get vehicle_archive_confirm_title => 'Archive this vehicle?';

  @override
  String get vehicle_archive_confirm_body =>
      'It stays in history but is hidden from pickers.';

  @override
  String get fuel_type_petrol => 'Petrol';

  @override
  String get fuel_type_diesel => 'Diesel';

  @override
  String get fuel_type_electric => 'Electric';

  @override
  String get fuel_type_hybrid => 'Hybrid';

  @override
  String get fuel_logs_title => 'Fuel log';

  @override
  String get fuel_log_add => 'Add fill-up';

  @override
  String get fuel_log_odometer => 'Odometer (km)';

  @override
  String get fuel_log_liters => 'Liters';

  @override
  String get fuel_log_cost => 'Total cost';

  @override
  String get fuel_log_full_tank => 'Full tank';

  @override
  String get fuel_log_full_badge => 'Full';

  @override
  String get fuel_log_electric_hint =>
      'Electric vehicle: liters aren\'t recorded.';

  @override
  String get fuel_log_saved => 'Fill-up saved.';

  @override
  String get fuel_logs_empty => 'No fill-ups recorded yet.';

  @override
  String get fuel_log_delete => 'Delete fill-up';

  @override
  String get fuel_log_delete_confirm_title => 'Delete this fill-up?';

  @override
  String get fuel_log_delete_confirm_body =>
      'The linked fuel expense is deleted too.';

  @override
  String get fuel_log_deleted => 'Fill-up deleted.';

  @override
  String get fuel_stats_title => 'Economy';

  @override
  String get fuel_stats_l_per_100km => 'L/100km';

  @override
  String get fuel_stats_cost_per_km => 'Cost/km';

  @override
  String get fuel_stats_no_data =>
      'Add at least two full fill-ups to see consumption.';

  @override
  String get maintenance_title => 'Maintenance';

  @override
  String get maintenance_add => 'Add reminder';

  @override
  String get maintenance_edit => 'Edit reminder';

  @override
  String get maintenance_name => 'Item name';

  @override
  String get maintenance_name_hint => 'e.g. Oil change';

  @override
  String get maintenance_due_date => 'Due date';

  @override
  String get maintenance_due_odometer => 'Due odometer (km)';

  @override
  String get maintenance_interval_days => 'Repeat every (days)';

  @override
  String get maintenance_interval_km => 'Repeat every (km)';

  @override
  String get maintenance_interval_hint =>
      'Optional: leaves a new reminder after completion.';

  @override
  String get maintenance_need_one_due => 'Enter a due date or a due odometer.';

  @override
  String get maintenance_status_overdue => 'Overdue';

  @override
  String get maintenance_status_due_soon => 'Due soon';

  @override
  String get maintenance_empty => 'No maintenance reminders yet.';

  @override
  String maintenance_due_date_line(String date) {
    return 'Due $date';
  }

  @override
  String maintenance_due_odo_line(String km) {
    return 'At $km km';
  }

  @override
  String get maintenance_complete => 'Mark done';

  @override
  String get maintenance_complete_title => 'Complete maintenance';

  @override
  String get maintenance_complete_cost => 'Add cost (optional)';

  @override
  String get maintenance_completed => 'Maintenance completed.';

  @override
  String get maintenance_delete => 'Delete reminder';

  @override
  String get maintenance_delete_confirm_title => 'Delete this reminder?';

  @override
  String get maintenance_delete_confirm_body => 'This can\'t be undone.';

  @override
  String get maintenance_saved => 'Reminder saved.';

  @override
  String get recurring_section => 'Fixed expenses';

  @override
  String get recurring_title => 'Fixed expenses';

  @override
  String get recurring_empty_title => 'No fixed expenses yet';

  @override
  String get recurring_empty_body => 'Fixed expenses will appear here.';

  @override
  String get recurring_add => 'Add fixed expense';

  @override
  String get recurring_edit => 'Edit fixed expense';

  @override
  String get recurring_name => 'Name (optional)';

  @override
  String get recurring_name_hint => 'e.g. Apartment rent';

  @override
  String get recurring_amount => 'Amount';

  @override
  String get recurring_frequency => 'Repeats';

  @override
  String get frequency_weekly => 'Weekly';

  @override
  String get frequency_monthly => 'Monthly';

  @override
  String get frequency_yearly => 'Yearly';

  @override
  String get recurring_day_of_month => 'Day of month';

  @override
  String get recurring_start_date => 'Start date';

  @override
  String get recurring_end_date => 'End date (optional)';

  @override
  String recurring_next_due_line(String date) {
    return 'Next: $date';
  }

  @override
  String get recurring_active => 'Active';

  @override
  String get recurring_paused => 'Paused';

  @override
  String get recurring_pause => 'Pause';

  @override
  String get recurring_resume => 'Resume';

  @override
  String get recurring_saved => 'Commitment saved.';

  @override
  String get recurring_delete => 'Delete fixed expense';

  @override
  String get recurring_delete_confirm_title => 'Delete this fixed expense?';

  @override
  String get recurring_delete_confirm_body =>
      'It stops posting and leaves the list. Choose what happens to the transactions it already posted.';

  @override
  String get recurring_delete_option_keep =>
      'Posted transactions stay and keep counting as fixed expenses';

  @override
  String recurring_delete_option_delete_month(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This month\'s $count posted transactions are deleted too',
      one: 'This month\'s 1 posted transaction is deleted too',
      zero: 'No posted transactions this month to delete',
    );
    return '$_temp0';
  }

  @override
  String get recurring_deleted => 'Fixed expense deleted.';

  @override
  String recurring_generated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Posted $count recurring transactions.',
      one: 'Posted 1 recurring transaction.',
    );
    return '$_temp0';
  }

  @override
  String get recurring_type_income => 'Income';

  @override
  String get recurring_type_expense => 'Expense';

  @override
  String get recurring_inactive_hint => 'Paused commitments don\'t post.';

  @override
  String get recurring_paused_message =>
      'Paused. Transactions already posted this month stay; delete them separately if needed.';

  @override
  String get recurring_resumed_message =>
      'Resumed. It continues from the next due date; the missed period isn\'t posted.';

  @override
  String get error_invalid_vehicle =>
      'That vehicle doesn\'t belong to this household.';

  @override
  String get error_invalid_item => 'That maintenance reminder doesn\'t exist.';

  @override
  String get error_invalid_log => 'That fill-up doesn\'t exist.';

  @override
  String get error_invalid_value => 'Enter valid values.';

  @override
  String get error_odometer_backwards =>
      'The odometer can\'t be lower than an earlier fill-up.';

  @override
  String get error_no_car_category => 'Add a car category first.';

  @override
  String get error_no_linked_person => 'Link this account to a person first.';

  @override
  String get nav_fixed => 'Fixed expenses';

  @override
  String get nav_fixed_short => 'Fixed';

  @override
  String get nav_pets => 'Pets';

  @override
  String get account_fallback => 'My account';

  @override
  String get profile_title => 'Profile';

  @override
  String get profile_month => 'This month';

  @override
  String get group_pet => 'Pets';

  @override
  String get pets_section => 'Pets';

  @override
  String get pets_title => 'Pets';

  @override
  String get pets_empty_title => 'No pets yet';

  @override
  String get pets_empty_body =>
      'Add your cats, dogs and other companions to track their costs.';

  @override
  String get pet_add => 'Add pet';

  @override
  String get pet_edit => 'Edit pet';

  @override
  String get pet_name => 'Name';

  @override
  String get pet_name_hint => 'e.g. Simba';

  @override
  String get pet_type => 'Type';

  @override
  String get pet_type_cat => 'Cat';

  @override
  String get pet_type_dog => 'Dog';

  @override
  String get pet_type_bird => 'Bird';

  @override
  String get pet_type_fish => 'Fish';

  @override
  String get pet_type_other => 'Other';

  @override
  String get pet_birth_date => 'Birth date (optional)';

  @override
  String get pet_notes => 'Notes (optional)';

  @override
  String get pet_notes_hint => 'Allergies, vet, food…';

  @override
  String get pet_archive => 'Archive';

  @override
  String get pet_restore => 'Restore';

  @override
  String get pet_archived => 'Archived';

  @override
  String get pet_saved => 'Pet saved.';

  @override
  String get pet_archive_confirm_title => 'Archive this pet?';

  @override
  String get pet_archive_confirm_body =>
      'It stays under Archived and keeps its expenses.';

  @override
  String pet_monthly_total(String amount) {
    return 'This month: $amount';
  }

  @override
  String get pet_expenses_title => 'Expenses';

  @override
  String get pet_expenses_empty => 'No expenses this month.';

  @override
  String get pet_add_expense => 'Add expense';

  @override
  String get transaction_none => 'None';

  @override
  String get transaction_pet => 'Pet';

  @override
  String get transaction_pin_fixed => 'Make a monthly fixed expense';

  @override
  String get transaction_pin_fixed_confirm_title =>
      'Make this a monthly fixed expense?';

  @override
  String get transaction_pin_fixed_confirm_body =>
      'A monthly commitment will be created and posted automatically.';

  @override
  String get transaction_pinned_fixed => 'Added to fixed commitments.';

  @override
  String get recurring_link_none => 'None';

  @override
  String get recurring_link_vehicle => 'Vehicle (optional)';

  @override
  String get recurring_link_pet => 'Pet (optional)';

  @override
  String get dashboard_fixed_header => 'Fixed expenses this month';

  @override
  String get dashboard_fixed_posted => 'Posted';

  @override
  String get dashboard_fixed_due => 'Still due';

  @override
  String get dashboard_after_fixed => 'Left after fixed';

  @override
  String get dashboard_expenses_help =>
      'All expenses this month, including posted fixed ones.';

  @override
  String get dashboard_fixed_posted_help =>
      'Fixed commitments already posted this month.';

  @override
  String get dashboard_fixed_due_help =>
      'Fixed commitments still due later this month.';

  @override
  String get dashboard_after_fixed_help =>
      'Income minus posted and still-due fixed commitments.';

  @override
  String get error_invalid_pet => 'That pet doesn\'t belong to this household.';

  @override
  String get error_invalid_rule => 'That fixed expense doesn\'t exist.';

  @override
  String get error_already_archived =>
      'That fixed expense was already removed.';
}
