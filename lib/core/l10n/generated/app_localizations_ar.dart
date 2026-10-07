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
  String get nav_people => 'الأشخاص';

  @override
  String get members_title => 'الأشخاص';

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
  String get group_fixed => 'التزامات ثابتة';

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
}
