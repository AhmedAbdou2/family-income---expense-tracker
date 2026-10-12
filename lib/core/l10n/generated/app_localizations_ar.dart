// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'المالية العائلية';

  @override
  String get sign_in_title => 'تسجيل الدخول';

  @override
  String get sign_up_title => 'إنشاء حساب';

  @override
  String get forgot_password_title => 'إعادة تعيين كلمة المرور';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get confirm_password => 'تأكيد كلمة المرور';

  @override
  String get sign_in_action => 'تسجيل الدخول';

  @override
  String get sign_up_action => 'إنشاء الحساب';

  @override
  String get send_reset_link => 'إرسال رابط الاستعادة';

  @override
  String get reset_email_sent =>
      'تحقق من بريدك الإلكتروني لرابط إعادة تعيين كلمة المرور.';

  @override
  String get sign_up_email_sent =>
      'تم إنشاء حسابك. أكّد بريدك الإلكتروني ثم سجّل الدخول.';

  @override
  String get no_account_prompt => 'ليس لديك حساب؟';

  @override
  String get have_account_prompt => 'لديك حساب بالفعل؟';

  @override
  String get forgot_password_prompt => 'نسيت كلمة المرور؟';

  @override
  String get back_to_sign_in => 'العودة إلى تسجيل الدخول';

  @override
  String get passwords_dont_match => 'كلمتا المرور غير متطابقتين';

  @override
  String get invalid_email => 'أدخل بريداً إلكترونياً صحيحاً';

  @override
  String get password_too_short =>
      'يجب أن تتكون كلمة المرور من ٦ أحرف على الأقل';

  @override
  String get field_required => 'هذا الحقل مطلوب';

  @override
  String get setup_title => 'إعداد أسرتك';

  @override
  String get setup_subtitle =>
      'أنشئ أسرة جديدة، أو انضم إلى أسرة موجودة برمز دعوة.';

  @override
  String get create_household_action => 'إنشاء أسرة';

  @override
  String get join_household_action => 'الانضمام برمز دعوة';

  @override
  String get household_name => 'اسم الأسرة';

  @override
  String get household_name_hint => 'مثال: آل أحمد';

  @override
  String get currency => 'العملة';

  @override
  String get invite_code => 'رمز الدعوة';

  @override
  String get invite_code_hint => 'مثال: A1B2C3';

  @override
  String get invalid_invite_code => 'أدخل رمز الدعوة المكوّن من ٦ خانات';

  @override
  String get nav_dashboard => 'الرئيسية';

  @override
  String get nav_transactions => 'المعاملات';

  @override
  String get nav_settings => 'الإعدادات';

  @override
  String get empty_dashboard_title => 'لا يوجد شيء بعد';

  @override
  String get empty_dashboard_body =>
      'ستظهر هنا دخل الشهر ومصروفاته والرسوم البيانية.';

  @override
  String get empty_transactions_title => 'لا توجد معاملات بعد';

  @override
  String get empty_transactions_body =>
      'عندما تبدأ بتسجيل الدخل والمصروفات ستظهر هنا.';

  @override
  String get settings_title => 'الإعدادات';

  @override
  String get language_section => 'اللغة';

  @override
  String get language_system => 'حسب النظام';

  @override
  String get language_english => 'الإنجليزية';

  @override
  String get language_arabic => 'العربية';

  @override
  String get theme_section => 'المظهر';

  @override
  String get theme_system => 'حسب النظام';

  @override
  String get theme_light => 'فاتح';

  @override
  String get theme_dark => 'داكن';

  @override
  String get digits_section => 'الأرقام';

  @override
  String get arabic_digits_title => 'الأرقام العربية الهندية';

  @override
  String get arabic_digits_subtitle => 'عرض الأرقام كـ ٠١٢٣ بدلاً من 0123';

  @override
  String get household_section => 'الأسرة';

  @override
  String household_currency_line(String currency) {
    return 'العملة: $currency';
  }

  @override
  String your_role(String role) {
    return 'دورك: $role';
  }

  @override
  String get role_owner => 'مالك';

  @override
  String get role_adult => 'بالغ';

  @override
  String get role_child => 'طفل';

  @override
  String get invites_section => 'أكواد الدعوة';

  @override
  String get invites_empty => 'لا توجد أكواد دعوة بعد.';

  @override
  String get create_invite_action => 'إنشاء رمز دعوة';

  @override
  String get invite_as => 'الدعوة بصفة';

  @override
  String get invite_created_title => 'رمز الدعوة جاهز';

  @override
  String get invite_code_hint_share =>
      'شارك هذا الرمز ليتمكن أحد الانضمام إلى أسرتك.';

  @override
  String get copy_code => 'نسخ الرمز';

  @override
  String get copied => 'تم النسخ';

  @override
  String invite_expires_on(String date) {
    return 'ينتهي $date';
  }

  @override
  String get invite_status_active => 'نشط';

  @override
  String get invite_status_used => 'مستخدم';

  @override
  String get sign_out => 'تسجيل الخروج';

  @override
  String get sign_out_confirm_title => 'تسجيل الخروج؟';

  @override
  String get sign_out_confirm_body =>
      'ستحتاج بريدك وكلمة المرور لتسجيل الدخول مرة أخرى.';

  @override
  String get loading => 'جارٍ التحميل...';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get next => 'التالي';

  @override
  String get close => 'إغلاق';

  @override
  String get error_title => 'حدث خطأ ما';

  @override
  String get error_network => 'لا يوجد اتصال بالإنترنت. حاول مرة أخرى.';

  @override
  String get error_timeout => 'انتهت مهلة الطلب. حاول مرة أخرى.';

  @override
  String get error_unknown => 'خطأ غير متوقع. حاول مرة أخرى.';

  @override
  String get error_invalid_credentials =>
      'بريد إلكتروني أو كلمة مرور غير صحيحة.';

  @override
  String get error_email_exists => 'يوجد حساب بهذا البريد الإلكتروني بالفعل.';

  @override
  String get error_email_not_confirmed => 'أكّد بريدك الإلكتروني أولاً.';

  @override
  String get error_weak_password =>
      'كلمة المرور ضعيفة. استخدم ٦ أحرف على الأقل.';

  @override
  String get error_invalid_email => 'أدخل بريداً إلكترونياً صحيحاً.';

  @override
  String get error_too_many_requests =>
      'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.';

  @override
  String get error_invite_not_found => 'رمز الدعوة غير موجود.';

  @override
  String get error_invite_used => 'رمز الدعوة مستخدم بالفعل.';

  @override
  String get error_invite_expired => 'انتهت صلاحية رمز الدعوة.';

  @override
  String get error_already_member => 'أنت عضو في هذه الأسرة بالفعل.';

  @override
  String get error_not_member => 'أنت لست منتمياً إلى هذه الأسرة.';

  @override
  String get error_forbidden => 'لا تملك صلاحية لفعل ذلك.';

  @override
  String get error_invalid_name => 'أدخل اسماً صحيحاً.';

  @override
  String get error_invalid_currency => 'أدخل عملة صحيحة.';

  @override
  String get error_invalid_role => 'دور الدعوة هذا غير مسموح.';

  @override
  String get error_membership_immutable =>
      'لا يمكن تغيير بيانات العضوية من هنا.';

  @override
  String get nav_people => 'العائلة';

  @override
  String get nav_vehicles => 'المركبات';

  @override
  String get members_title => 'العائلة';

  @override
  String get family_invite_someone => 'دعوة شخص جديد';

  @override
  String get role_no_login => 'بدون حساب';

  @override
  String get member_connect_login => 'ربط حساب';

  @override
  String member_connect_hint(String name) {
    return 'أنشئ رمز دعوة لـ $name. عند القبول يصبح ذلك الحساب هو حساب هذا الشخص.';
  }

  @override
  String get member_archive => 'أرشفة';

  @override
  String get member_restore => 'استعادة';

  @override
  String get member_add => 'إضافة شخص';

  @override
  String get member_name => 'اسم الشخص';

  @override
  String get member_name_hint => 'مثال: سارة';

  @override
  String get member_rename => 'إعادة التسمية';

  @override
  String get member_delete => 'حذف الشخص';

  @override
  String get member_delete_confirm_title => 'حذف هذا الشخص؟';

  @override
  String get member_delete_confirm_body =>
      'يمكنك حذف الأشخاص الذين ليس لديهم معاملات فقط.';

  @override
  String get delete_action => 'حذف';

  @override
  String get member_active => 'نشط';

  @override
  String get member_inactive => 'غير نشط';

  @override
  String get member_linked_badge => 'مرتبط';

  @override
  String get member_you => 'أنت';

  @override
  String get member_empty_title => 'لا يوجد أشخاص بعد';

  @override
  String get member_empty_body =>
      'أضف أفراد أسرتك حتى يتسنى تسجيل المصروفات لكل شخص.';

  @override
  String get member_in_use => 'لهذا الشخص معاملات مسجّلة ولا يمكن حذفه.';

  @override
  String get categories_title => 'التصنيفات';

  @override
  String get manage_categories => 'إدارة التصنيفات';

  @override
  String get category_add => 'إضافة تصنيف';

  @override
  String get category_edit => 'تعديل التصنيف';

  @override
  String get category_name_en => 'الاسم بالإنجليزية';

  @override
  String get category_name_ar => 'الاسم بالعربية';

  @override
  String get category_group => 'المجموعة';

  @override
  String get category_icon => 'الأيقونة';

  @override
  String get category_color => 'اللون';

  @override
  String get category_delete_confirm_title => 'حذف هذا التصنيف؟';

  @override
  String get category_delete_confirm_body =>
      'يمكنك حذف التصنيفات التي ليس لها معاملات فقط.';

  @override
  String get group_general => 'مصروفات عامة';

  @override
  String get group_car => 'مصروفات السيارة';

  @override
  String get group_fixed => 'المصروفات الثابتة';

  @override
  String get group_income => 'الدخل';

  @override
  String get type_expense => 'مصروف';

  @override
  String get type_income => 'دخل';

  @override
  String get amount => 'المبلغ';

  @override
  String get amount_invalid => 'أدخل مبلغاً صحيحاً.';

  @override
  String get amount_zero => 'يجب أن يكون المبلغ أكبر من صفر.';

  @override
  String get category => 'التصنيف';

  @override
  String get person => 'الشخص';

  @override
  String get date => 'التاريخ';

  @override
  String get note => 'ملاحظة (اختياري)';

  @override
  String get save => 'حفظ';

  @override
  String get transaction_new_title => 'معاملة جديدة';

  @override
  String get transaction_edit_title => 'تعديل المعاملة';

  @override
  String get transaction_saved => 'تم حفظ المعاملة.';

  @override
  String get transaction_delete => 'حذف المعاملة';

  @override
  String get transaction_delete_confirm_title => 'حذف هذه المعاملة؟';

  @override
  String get transaction_delete_confirm_body =>
      'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get transaction_delete_from_fixed =>
      'نشأت هذه المعاملة من مصروف ثابت. الحذف لن يؤدي إلى إعادة إنشائها.';

  @override
  String get transaction_delete_fuel_note =>
      'سيتم حذف سجل التزود بالوقود المرتبط أيضًا.';

  @override
  String get transaction_delete_maintenance_note =>
      'إذا نشأ هذا المصروف من إكمال تذكير صيانة، فحذفه لن يُعيد التذكير كمستحق.';

  @override
  String get transaction_delete_pause_rule => 'أوقف هذا المصروف الثابت أيضًا';

  @override
  String get transaction_deleted => 'تم حذف المعاملة.';

  @override
  String get month_no_data => 'لا توجد معاملات في هذا الشهر.';

  @override
  String get month_prev => 'الشهر السابق';

  @override
  String get month_next => 'الشهر التالي';

  @override
  String get filter_everyone => 'الجميع';

  @override
  String get select_category => 'اختر تصنيفاً';

  @override
  String get select_person => 'اختر شخصاً';

  @override
  String get quick_add_title => 'إضافة سريعة';

  @override
  String get quick_add_more => 'خيارات إضافية';

  @override
  String get dashboard_expenses => 'المصروفات';

  @override
  String get dashboard_balance => 'الرصيد';

  @override
  String get dashboard_recent => 'الأحدث';

  @override
  String get invite_link_title => 'ربط بشخص';

  @override
  String get invite_link_none => 'انضمام فقط (بدون ربط)';

  @override
  String get invite_link_hint =>
      'عند قبول الدعوة يصبح حساب المقبول هو حساب هذا الشخص.';

  @override
  String get error_member_linked => 'ذلك الشخص مرتبط بحساب بالفعل.';

  @override
  String get error_login_linked => 'هذا الحساب مرتبط بشخص بالفعل.';

  @override
  String get error_invalid_member => 'ذلك الشخص ليس من هذه الأسرة.';

  @override
  String get error_category_in_use => 'ذلك التصنيف له معاملات ولا يمكن حذفه.';

  @override
  String get error_member_in_use => 'ذلك الشخص له معاملات ولا يمكن حذفه.';

  @override
  String get error_already_linked => 'ذلك الشخص مرتبط بحساب آخر بالفعل.';

  @override
  String get error_last_owner => 'أنت آخر مالك. اجعل عضواً آخر مالكاً أولاً.';

  @override
  String get error_cannot_change_own_role =>
      'لا يمكنك تغيير دورك بنفسك. اطلب من مالك آخر.';

  @override
  String get error_cannot_remove_self => 'للخروج استخدم خيار مغادرة الأسرة.';

  @override
  String get error_child_requires_member =>
      'دور الطفل يتطلب حساباً مرتبطاً بشخص.';

  @override
  String get claim_title => 'أنهِ إعداد حسابك';

  @override
  String get claim_body =>
      'انضم حسابك إلى الأسرة لكنه غير مرتبط بشخص بعد. اختر الاسم الذي ستراه عائلتك.';

  @override
  String get claim_action => 'متابعة';

  @override
  String get join_name_hint =>
      'إذا كان المالك قد سمّاك مسبقاً فهذا الاسم لن يُستخدم.';

  @override
  String get household_members_title => 'أعضاء الأسرة';

  @override
  String get login_no_person => 'لا يوجد شخص مرتبط';

  @override
  String get login_change_role => 'تغيير الدور';

  @override
  String get login_remove => 'إزالة الحساب';

  @override
  String get login_remove_confirm_title => 'إزالة هذا الحساب؟';

  @override
  String get login_remove_confirm_body =>
      'سيبقى الشخص وسجل معاملاته، ويفقد الحساب صلاحيته فقط.';

  @override
  String get leave_household => 'مغادرة الأسرة';

  @override
  String get leave_confirm_title => 'مغادرة هذه الأسرة؟';

  @override
  String get leave_confirm_body =>
      'ستفقد صلاحيتك للدخول. يبقى شخصك وسجل معاملاتك لدى العائلة.';

  @override
  String get leave_last_owner_hint => 'اجعل عضواً آخر مالكاً أولاً.';

  @override
  String get invite_target_title => 'من سينضم؟';

  @override
  String get invite_new_person => 'شخص جديد (يختار اسمه بنفسه)';

  @override
  String get quick_add_no_person => 'هذا الحساب غير مرتبط بشخص بعد.';

  @override
  String get vehicles_section => 'السيارات والمصروفات';

  @override
  String get vehicles_title => 'السيارات';

  @override
  String get vehicles_empty_title => 'لا توجد سيارات بعد';

  @override
  String get vehicles_empty_body => 'أضف سيارة لتتبّع الوقود والصيانة.';

  @override
  String get vehicle_add => 'إضافة سيارة';

  @override
  String get vehicle_edit => 'تعديل السيارة';

  @override
  String get vehicle_name => 'اسم السيارة';

  @override
  String get vehicle_name_hint => 'مثال: كورولا البيضاء';

  @override
  String get vehicle_plate => 'اللوحة (اختياري)';

  @override
  String get vehicle_plate_hint => 'مثال: أ ب ج ١٢٣';

  @override
  String get vehicle_fuel_type => 'نوع الوقود';

  @override
  String get vehicle_odometer => 'قراءة العداد الحالية (كم)';

  @override
  String get vehicle_odometer_hint => 'مثال: ٤٥٠٠٠';

  @override
  String get vehicle_archive => 'أرشفة';

  @override
  String get vehicle_restore => 'استعادة';

  @override
  String get vehicle_archived => 'مؤرشفة';

  @override
  String vehicle_odometer_value(String km) {
    return 'العداد: $km كم';
  }

  @override
  String get vehicle_saved => 'تم حفظ السيارة.';

  @override
  String get vehicle_archive_confirm_title => 'أرشفة هذه السيارة؟';

  @override
  String get vehicle_archive_confirm_body =>
      'تبقى في السجل لكن تُخفى من القوائم.';

  @override
  String get fuel_type_petrol => 'بنزين';

  @override
  String get fuel_type_diesel => 'ديزل';

  @override
  String get fuel_type_electric => 'كهربائية';

  @override
  String get fuel_type_hybrid => 'هجينة';

  @override
  String get fuel_logs_title => 'سجل الوقود';

  @override
  String get fuel_log_add => 'تسجيل تعبئة';

  @override
  String get fuel_log_odometer => 'العداد (كم)';

  @override
  String get fuel_log_liters => 'اللترات';

  @override
  String get fuel_log_cost => 'التكلفة الإجمالية';

  @override
  String get fuel_log_full_tank => 'خزان ممتلئ';

  @override
  String get fuel_log_full_badge => 'ممتلئ';

  @override
  String get fuel_log_electric_hint => 'سيارة كهربائية: لا تُسجَّل اللترات.';

  @override
  String get fuel_log_saved => 'تم تسجيل التعبئة.';

  @override
  String get fuel_logs_empty => 'لم تُسجَّل أي تعبئة بعد.';

  @override
  String get fuel_log_delete => 'حذف التعبئة';

  @override
  String get fuel_log_delete_confirm_title => 'حذف هذه التعبئة؟';

  @override
  String get fuel_log_delete_confirm_body =>
      'سيُحذف مصروف الوقود المرتبط أيضًا.';

  @override
  String get fuel_log_deleted => 'تم حذف التعبئة.';

  @override
  String get fuel_stats_title => 'الاستهلاك';

  @override
  String get fuel_stats_l_per_100km => 'لتر/١٠٠كم';

  @override
  String get fuel_stats_cost_per_km => 'التكلفة/كم';

  @override
  String get fuel_stats_no_data =>
      'أضف تعبئتين ممتلئتين على الأقل لعرض الاستهلاك.';

  @override
  String get maintenance_title => 'الصيانة';

  @override
  String get maintenance_add => 'إضافة تذكير';

  @override
  String get maintenance_edit => 'تعديل التذكير';

  @override
  String get maintenance_name => 'اسم البند';

  @override
  String get maintenance_name_hint => 'مثال: تغيير الزيت';

  @override
  String get maintenance_due_date => 'تاريخ الاستحقاق';

  @override
  String get maintenance_due_odometer => 'عداد الاستحقاق (كم)';

  @override
  String get maintenance_interval_days => 'يتكرر كل (أيام)';

  @override
  String get maintenance_interval_km => 'يتكرر كل (كم)';

  @override
  String get maintenance_interval_hint =>
      'اختياري: ينشئ تذكيرًا جديدًا بعد الإتمام.';

  @override
  String get maintenance_need_one_due => 'أدخل تاريخ استحقاق أو قراءة عداد.';

  @override
  String get maintenance_status_overdue => 'متأخر';

  @override
  String get maintenance_status_due_soon => 'قريب';

  @override
  String get maintenance_empty => 'لا توجد تذكيرات صيانة بعد.';

  @override
  String maintenance_due_date_line(String date) {
    return 'الاستحقاق $date';
  }

  @override
  String maintenance_due_odo_line(String km) {
    return 'عند $km كم';
  }

  @override
  String get maintenance_complete => 'تم الإنجاز';

  @override
  String get maintenance_complete_title => 'إتمام الصيانة';

  @override
  String get maintenance_complete_cost => 'إضافة تكلفة (اختياري)';

  @override
  String get maintenance_completed => 'تمت الصيانة.';

  @override
  String get maintenance_delete => 'حذف التذكير';

  @override
  String get maintenance_delete_confirm_title => 'حذف هذا التذكير؟';

  @override
  String get maintenance_delete_confirm_body => 'لا يمكن التراجع عن ذلك.';

  @override
  String get maintenance_saved => 'تم حفظ التذكير.';

  @override
  String get recurring_section => 'المصروفات الثابتة';

  @override
  String get recurring_title => 'المصروفات الثابتة';

  @override
  String get recurring_empty_title => 'لا توجد مصروفات ثابتة بعد';

  @override
  String get recurring_empty_body => 'ستظهر المصروفات الثابتة هنا.';

  @override
  String get recurring_add => 'إضافة مصروف ثابت';

  @override
  String get recurring_edit => 'تعديل المصروف الثابت';

  @override
  String get recurring_name => 'الاسم (اختياري)';

  @override
  String get recurring_name_hint => 'مثال: إيجار الشقة';

  @override
  String get recurring_amount => 'المبلغ';

  @override
  String get recurring_frequency => 'التكرار';

  @override
  String get frequency_weekly => 'أسبوعي';

  @override
  String get frequency_monthly => 'شهري';

  @override
  String get frequency_yearly => 'سنوي';

  @override
  String get recurring_day_of_month => 'يوم الشهر';

  @override
  String get recurring_start_date => 'تاريخ البدء';

  @override
  String get recurring_end_date => 'تاريخ الانتهاء (اختياري)';

  @override
  String recurring_next_due_line(String date) {
    return 'التالي: $date';
  }

  @override
  String get recurring_active => 'نشط';

  @override
  String get recurring_paused => 'موقوف';

  @override
  String get recurring_pause => 'إيقاف';

  @override
  String get recurring_resume => 'تشغيل';

  @override
  String get recurring_saved => 'تم حفظ الالتزام.';

  @override
  String get recurring_delete => 'حذف المصروف الثابت';

  @override
  String get recurring_delete_confirm_title => 'حذف هذا المصروف الثابت؟';

  @override
  String get recurring_delete_confirm_body =>
      'سيتوقف عن الترحيل ويختفي من القائمة. اختر ما سيحدث للمعاملات التي رحّلها بالفعل.';

  @override
  String get recurring_delete_option_keep =>
      'تبقى المعاملات المرحّلة وتستمر في احتسابها كمصروفات ثابتة';

  @override
  String recurring_delete_option_delete_month(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تُحذف أيضًا $count معاملات مرحّلة هذا الشهر',
      one: 'تُحذف أيضًا معاملة هذا الشهر المرحّلة',
      zero: 'لا توجد معاملات مرحّلة هذا الشهر لحذفها',
    );
    return '$_temp0';
  }

  @override
  String get recurring_deleted => 'تم حذف المصروف الثابت.';

  @override
  String recurring_generated(int count) {
    return 'تم ترحيل $count حركة دورية.';
  }

  @override
  String get recurring_type_income => 'دخل';

  @override
  String get recurring_type_expense => 'مصروف';

  @override
  String get recurring_inactive_hint => 'الالتزامات الموقوفة لا تُرحَّل.';

  @override
  String get recurring_paused_message =>
      'تم الإيقاف. تبقى المعاملات المُدرجة هذا الشهر؛ احذفها منفصلة عند الحاجة.';

  @override
  String get recurring_resumed_message =>
      'تم التشغيل. ستكون الحركة القادمة هي التالية؛ لن يتم ترحيل فترة الإيقاف.';

  @override
  String get error_invalid_vehicle => 'هذه السيارة لا تنتمي إلى هذا المنزل.';

  @override
  String get error_invalid_item => 'تذكير الصيانة هذا غير موجود.';

  @override
  String get error_invalid_log => 'تعبئة الوقود هذه غير موجودة.';

  @override
  String get error_invalid_value => 'أدخل قيمًا صحيحة.';

  @override
  String get error_odometer_backwards =>
      'لا يمكن أن يكون العداد أقل من تعبئة سابقة.';

  @override
  String get error_no_car_category => 'أضف فئة سيارة أولًا.';

  @override
  String get error_no_linked_person => 'اربط هذا الحساب بشخص أولًا.';

  @override
  String get nav_fixed => 'المصروفات الثابتة';

  @override
  String get nav_fixed_short => 'الثابتة';

  @override
  String get nav_pets => 'الحيوانات';

  @override
  String get account_fallback => 'حسابي';

  @override
  String get profile_title => 'الملف الشخصي';

  @override
  String get profile_month => 'هذا الشهر';

  @override
  String get group_pet => 'الحيوانات';

  @override
  String get pets_section => 'الحيوانات';

  @override
  String get pets_title => 'الحيوانات';

  @override
  String get pets_empty_title => 'لا توجد حيوانات بعد';

  @override
  String get pets_empty_body =>
      'أضف قططك وكلابك ورفاقك الآخرين لتتبع تكاليفهم.';

  @override
  String get pet_add => 'إضافة حيوان';

  @override
  String get pet_edit => 'تعديل الحيوان';

  @override
  String get pet_name => 'الاسم';

  @override
  String get pet_name_hint => 'مثال: سيمبا';

  @override
  String get pet_type => 'النوع';

  @override
  String get pet_type_cat => 'قطة';

  @override
  String get pet_type_dog => 'كلب';

  @override
  String get pet_type_bird => 'طائر';

  @override
  String get pet_type_fish => 'سمكة';

  @override
  String get pet_type_other => 'أخرى';

  @override
  String get pet_birth_date => 'تاريخ الميلاد (اختياري)';

  @override
  String get pet_notes => 'ملاحظات (اختياري)';

  @override
  String get pet_notes_hint => 'حساسية، طبيب بيطري، طعام…';

  @override
  String get pet_archive => 'أرشفة';

  @override
  String get pet_restore => 'استعادة';

  @override
  String get pet_archived => 'مؤرشف';

  @override
  String get pet_saved => 'تم حفظ الحيوان.';

  @override
  String get pet_archive_confirm_title => 'أرشفة هذا الحيوان؟';

  @override
  String get pet_archive_confirm_body => 'سيبقى ضمن المؤرشفة مع مصروفاته.';

  @override
  String pet_monthly_total(String amount) {
    return 'هذا الشهر: $amount';
  }

  @override
  String get pet_expenses_title => 'المصروفات';

  @override
  String get pet_expenses_empty => 'لا مصروفات هذا الشهر.';

  @override
  String get pet_add_expense => 'إضافة مصروف';

  @override
  String get transaction_none => 'بدون';

  @override
  String get transaction_pet => 'الحيوان';

  @override
  String get transaction_pin_fixed => 'اجعله مصروفًا ثابتًا شهريًا';

  @override
  String get transaction_pin_fixed_confirm_title =>
      'تحويل هذا إلى مصروف ثابت شهري؟';

  @override
  String get transaction_pin_fixed_confirm_body =>
      'سيتم إنشاء التزام شهري وترحيله تلقائيًا.';

  @override
  String get transaction_pinned_fixed => 'أُضيف إلى الالتزامات الثابتة.';

  @override
  String get recurring_link_none => 'بدون';

  @override
  String get recurring_link_vehicle => 'السيارة (اختياري)';

  @override
  String get recurring_link_pet => 'الحيوان (اختياري)';

  @override
  String get dashboard_fixed_header => 'المصروفات الثابتة هذا الشهر';

  @override
  String get dashboard_fixed_posted => 'المُرحَّل';

  @override
  String get dashboard_fixed_due => 'المتبقي';

  @override
  String get dashboard_after_fixed => 'المتبقي بعد الثابتة';

  @override
  String get dashboard_expenses_help =>
      'كل مصروفات الشهر، بما فيها الثابتة المُرحَّلة.';

  @override
  String get dashboard_fixed_posted_help =>
      'الالتزامات الثابتة التي رُحِّلت هذا الشهر.';

  @override
  String get dashboard_fixed_due_help =>
      'الالتزامات الثابتة التي ستُرحَّل لاحقًا هذا الشهر.';

  @override
  String get dashboard_after_fixed_help =>
      'الدخل ناقص الالتزامات الثابتة المُرحَّلة والمتبقية.';

  @override
  String get error_invalid_pet => 'هذا الحيوان لا ينتمي إلى هذا المنزل.';

  @override
  String get error_invalid_rule => 'هذا المصروف الثابت غير موجود.';

  @override
  String get error_already_archived => 'تمت إزالة هذا المصروف الثابت بالفعل.';
}
