# Copy & translation review

Text-only pass over `lib/core/l10n/app_en.arb` and `lib/core/l10n/app_ar.arb`. No behaviour, database or migration changes. Only changed/new strings are listed, grouped by screen; the English column shows the current (new) English.

**Glossary:** الإيرادات (income total) · مصروف/إيراد (expense/income type) · المصروفات (expenses) · الرصيد (balance) · المصروفات الثابتة (fixed expenses) · المسجَّل (posted) · مستحق لاحقًا (still due) · المتبقي بعد المصروفات الثابتة (left after fixed) · العائلة (family) · مالك/بالغ/طفل (owner/adult/child) · السيارات (vehicles) · الحيوانات الأليفة (pets) · وقود (fuel) · عدّاد الكيلومترات (odometer) · الصيانة (maintenance) · إيقاف مؤقت/استئناف (pause/resume) · تثبيت كمصروف شهري (make monthly fixed) · دعوة (invite) · الأسرة (household) · التصنيف (category) · الشخص (person).

## Auth

| key | English | old Arabic | new Arabic |
| --- | --- | --- | --- |
| `invalid_email` | Enter a valid email address | أدخل بريداً إلكترونياً صحيحاً | أدخل بريدًا إلكترونيًا صحيحًا |
| `password_too_short` | Password must be at least 6 characters | يجب أن تتكون كلمة المرور من ٦ أحرف على الأقل | يجب أن تتكون كلمة المرور من 6 أحرف على الأقل |
| `reset_email_sent` | We emailed you a link to reset your password. | تحقق من بريدك الإلكتروني لرابط إعادة تعيين كلمة المرور. | أرسلنا إلى بريدك الإلكتروني رابطًا لإعادة تعيين كلمة المرور. |
| `send_reset_link` | Send reset link | إرسال رابط الاستعادة | إرسال رابط إعادة التعيين |

## Setup

| key | English | old Arabic | new Arabic |
| --- | --- | --- | --- |
| `currency_name` | {code, select, SAR{Saudi Riyal} AED{UAE Dirham} EGP{Egyptian Pound} KWD{Kuwaiti Dinar} QAR{Qatari Riyal} OMR{Omani Rial} BHD{Bahraini Dinar} JOD{Jordanian Dinar} IQD{Iraqi Dinar} YER{Yemeni Rial} SDG{Sudanese Pound} MAD{Moroccan Dirham} TND{Tunisian Dinar} DZD{Algerian Dinar} LBP{Lebanese Pound} SYP{Syrian Pound} TRY{Turkish Lira} USD{US Dollar} EUR{Euro} GBP{British Pound} other{{code}}} | *(new)* | {code, select, SAR{ريال سعودي} AED{درهم إماراتي} EGP{جنيه مصري} KWD{دينار كويتي} QAR{ريال قطري} OMR{ريال عماني} BHD{دينار بحريني} JOD{دينار أردني} IQD{دينار عراقي} YER{ريال يمني} SDG{جنيه سوداني} MAD{درهم مغربي} TND{دينار تونسي} DZD{دينار جزائري} LBP{ليرة لبنانية} SYP{ليرة سورية} TRY{ليرة تركية} USD{دولار أمريكي} EUR{يورو} GBP{جنيه إسترليني} other{{code}}} |
| `invalid_invite_code` | Enter the 6-character invite code | أدخل رمز الدعوة المكوّن من ٦ خانات | أدخل رمز الدعوة المكوّن من 6 خانات |
| `invite_code_hint_share` | Share this code so someone can join your household. | شارك هذا الرمز ليتمكن أحد الانضمام إلى أسرتك. | شارك هذا الرمز مع من تريد دعوته إلى أسرتك. |
| `setup_subtitle` | Create a new household, or join one with an invite code. | أنشئ أسرة جديدة، أو انضم إلى أسرة موجودة برمز دعوة. | أنشئ أسرة جديدة أو انضم إلى أسرة موجودة برمز دعوة. |

## Navigation

| key | English | old Arabic | new Arabic |
| --- | --- | --- | --- |
| `nav_pets` | Pets | الحيوانات | الحيوانات الأليفة |
| `nav_vehicles` | Vehicles | المركبات | السيارات |

## Settings

| key | English | old Arabic | new Arabic |
| --- | --- | --- | --- |
| `arabic_digits_subtitle` | Show numbers as ٠١٢٣ instead of 0123 | عرض الأرقام كـ ٠١٢٣ بدلاً من 0123 | عرض الأرقام كـ ٠١٢٣ بدلًا من 0123 |
| `invite_expires_on` | Expires {date} | ينتهي {date} | ينتهي في {date} |
| `invite_status_expired` | Expired | *(new)* | منتهي |
| `invite_status_used` | Used | مستخدم | مُستخدَم |

## Empty states

| key | English | old Arabic | new Arabic |
| --- | --- | --- | --- |
| `empty_dashboard_body` | Your monthly income and expenses will appear here. | ستظهر هنا دخل الشهر ومصروفاته والرسوم البيانية. | ستظهر هنا الإيرادات والمصروفات الشهرية. |
| `empty_transactions_body` | Income and expenses you record will be listed here. | عندما تبدأ بتسجيل الدخل والمصروفات ستظهر هنا. | ستظهر هنا الإيرادات والمصروفات التي تسجّلها. |

## Common

| key | English | old Arabic | new Arabic |
| --- | --- | --- | --- |
| `error_title` | Something went wrong | حدث خطأ ما | حدث خطأ |
| `sign_out_confirm_body` | You will need your email and password to sign back in. | ستحتاج بريدك وكلمة المرور لتسجيل الدخول مرة أخرى. | ستحتاج إلى بريدك الإلكتروني وكلمة المرور لتسجيل الدخول مرة أخرى. |

## Errors

| key | English | old Arabic | new Arabic |
| --- | --- | --- | --- |
| `error_already_linked` | That person was already linked to another account. | ذلك الشخص مرتبط بحساب آخر بالفعل. | هذا الشخص مرتبط بحساب آخر بالفعل. |
| `error_category_in_use` | That category has transactions and can't be deleted. | ذلك التصنيف له معاملات ولا يمكن حذفه. | لهذا التصنيف معاملات ولا يمكن حذفه. |
| `error_child_requires_member` | A child role needs an account linked to a person. | دور الطفل يتطلب حساباً مرتبطاً بشخص. | دور الطفل يتطلب حسابًا مرتبطًا بشخص. |
| `error_email_not_confirmed` | Confirm your email address first. | أكّد بريدك الإلكتروني أولاً. | أكّد بريدك الإلكتروني أولًا. |
| `error_forbidden` | You don't have permission to do that. | لا تملك صلاحية لفعل ذلك. | لا تملك صلاحية للقيام بذلك. |
| `error_invalid_credentials` | Wrong email or password. | بريد إلكتروني أو كلمة مرور غير صحيحة. | البريد الإلكتروني أو كلمة المرور غير صحيحة. |
| `error_invalid_email` | Enter a valid email address. | أدخل بريداً إلكترونياً صحيحاً. | أدخل بريدًا إلكترونيًا صحيحًا. |
| `error_invalid_member` | That person doesn't belong to this household. | ذلك الشخص ليس من هذه الأسرة. | هذا الشخص ليس من أفراد هذه الأسرة. |
| `error_invalid_name` | Enter a valid name. | أدخل اسماً صحيحاً. | أدخل اسمًا صحيحًا. |
| `error_invalid_pet` | That pet doesn't belong to this household. | هذا الحيوان لا ينتمي إلى هذا المنزل. | هذا الحيوان ليس من حيوانات هذه الأسرة. |
| `error_invalid_role` | That invite role is not allowed. | دور الدعوة هذا غير مسموح. | هذه الصفة غير مسموح بها في الدعوة. |
| `error_invalid_vehicle` | That vehicle doesn't belong to this household. | هذه السيارة لا تنتمي إلى هذا المنزل. | هذه السيارة ليست من سيارات هذه الأسرة. |
| `error_invite_used` | That invite code was already used. | رمز الدعوة مستخدم بالفعل. | تم استخدام رمز الدعوة من قبل. |
| `error_last_owner` | You're the last owner. Make another member an owner first. | أنت آخر مالك. اجعل عضواً آخر مالكاً أولاً. | أنت المالك الأخير. اجعل عضوًا آخر مالكًا أولًا. |
| `error_member_in_use` | That person has transactions and can't be deleted. | ذلك الشخص له معاملات ولا يمكن حذفه. | لهذا الشخص معاملات ولا يمكن حذفه. |
| `error_member_linked` | That person is already linked to an account. | ذلك الشخص مرتبط بحساب بالفعل. | هذا الشخص مرتبط بحساب بالفعل. |
| `error_membership_immutable` | Membership details can't be changed here. | لا يمكن تغيير بيانات العضوية من هنا. | لا يمكن تعديل بيانات العضوية من هنا. |
| `error_no_car_category` | Add a car category first. | أضف فئة سيارة أولًا. | أضف تصنيفًا للسيارة أولًا. |
| `error_not_member` | You don't belong to that household. | أنت لست منتمياً إلى هذه الأسرة. | أنت لست عضوًا في هذه الأسرة. |
| `error_odometer_backwards` | The odometer can't be lower than an earlier fill-up. | لا يمكن أن يكون العداد أقل من تعبئة سابقة. | لا يمكن أن تكون قراءة العدّاد أقل من تعبئة سابقة. |
| `error_too_many_requests` | Too many attempts. Wait a moment and try again. | محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً. | محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى. |
| `error_unknown` | Unexpected error. Please try again. | خطأ غير متوقع. حاول مرة أخرى. | حدث خطأ غير متوقع. حاول مرة أخرى. |
| `error_weak_password` | Password is too weak. Use at least 6 characters. | كلمة المرور ضعيفة. استخدم ٦ أحرف على الأقل. | كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل. |

## Family & people

| key | English | old Arabic | new Arabic |
| --- | --- | --- | --- |
| `claim_title` | Finish setting up your account | أنهِ إعداد حسابك | أكمِل إعداد حسابك |
| `invite_link_hint` | When someone accepts, their login becomes this person's account. | عند قبول الدعوة يصبح حساب المقبول هو حساب هذا الشخص. | عند قبول الدعوة يصبح حساب المقبول حساب هذا الشخص. |
| `join_name_hint` | If the owner already named you, this name isn't used. | إذا كان المالك قد سمّاك مسبقاً فهذا الاسم لن يُستخدم. | إذا كان المالك قد اختار لك اسمًا مسبقًا فلن يُستخدم هذا الاسم. |
| `leave_confirm_body` | You'll lose access. Your person and transactions stay with the family. | ستفقد صلاحيتك للدخول. يبقى شخصك وسجل معاملاتك لدى العائلة. | ستفقد صلاحية الدخول، ويبقى شخصك ومعاملاتك لدى العائلة. |
| `leave_last_owner_hint` | Make another member an owner first. | اجعل عضواً آخر مالكاً أولاً. | اجعل عضوًا آخر مالكًا أولًا. |
| `login_no_person` | No person linked | لا يوجد شخص مرتبط | بدون شخص مرتبط |
| `login_remove_confirm_body` | The person and their transactions stay; the account only loses access. | سيبقى الشخص وسجل معاملاته، ويفقد الحساب صلاحيته فقط. | سيبقى الشخص ومعاملاته، ويفقد الحساب صلاحية الدخول فقط. |
| `member_connect_hint` | Create an invite code for {name}. When it's accepted, that login becomes this person's account. | أنشئ رمز دعوة لـ {name}. عند القبول يصبح ذلك الحساب هو حساب هذا الشخص. | أنشئ رمز دعوة لـ {name}. عند قبوله يصبح ذلك الحساب حساب هذا الشخص. |
| `member_delete_confirm_body` | Only people with no transactions can be deleted. | يمكنك حذف الأشخاص الذين ليس لديهم معاملات فقط. | لا يمكن حذف إلا الأشخاص الذين ليس لديهم معاملات. |
| `member_empty_body` | Add the people in your family so spending can be tracked per person. | أضف أفراد أسرتك حتى يتسنى تسجيل المصروفات لكل شخص. | أضف أفراد عائلتك حتى يمكن تسجيل المصروفات لكل شخص. |
| `member_in_use` | This person has transactions and can't be deleted. | لهذا الشخص معاملات مسجّلة ولا يمكن حذفه. | لهذا الشخص معاملات ولا يمكن حذفه. |
| `member_rename` | Rename | إعادة التسمية | تعديل الاسم |
| `members_title` | Family members | العائلة | أفراد العائلة |

## Categories

| key | English | old Arabic | new Arabic |
| --- | --- | --- | --- |
| `category_delete_confirm_body` | Only categories with no transactions can be deleted. | يمكنك حذف التصنيفات التي ليس لها معاملات فقط. | لا يمكن حذف إلا التصنيفات التي ليس لها معاملات. |
| `group_income` | Income | الدخل | الإيرادات |
| `group_pet` | Pets | الحيوانات | الحيوانات الأليفة |

## Transactions & dashboard

| key | English | old Arabic | new Arabic |
| --- | --- | --- | --- |
| `amount_invalid` | Enter a valid amount. | أدخل مبلغاً صحيحاً. | أدخل مبلغًا صحيحًا. |
| `dashboard_after_fixed` | Left after fixed | المتبقي بعد الثابتة | المتبقي بعد المصروفات الثابتة |
| `dashboard_after_fixed_help` | Income minus posted and still-due fixed commitments. | الدخل ناقص الالتزامات الثابتة المُرحَّلة والمتبقية. | الإيرادات ناقص المصروفات الثابتة المسجّلة والمستحقة لاحقًا. |
| `dashboard_expenses_help` | All expenses this month, including posted fixed ones. | كل مصروفات الشهر، بما فيها الثابتة المُرحَّلة. | كل مصروفات الشهر، بما فيها المصروفات الثابتة المسجّلة. |
| `dashboard_fixed_due` | Still due | المتبقي | مستحق لاحقًا |
| `dashboard_fixed_due_help` | Fixed commitments still due later this month. | الالتزامات الثابتة التي ستُرحَّل لاحقًا هذا الشهر. | المصروفات الثابتة المستحقة لاحقًا هذا الشهر. |
| `dashboard_fixed_posted` | Posted | المُرحَّل | المسجَّل |
| `dashboard_fixed_posted_help` | Fixed commitments already posted this month. | الالتزامات الثابتة التي رُحِّلت هذا الشهر. | المصروفات الثابتة المسجّلة هذا الشهر. |
| `dashboard_income` | Income | *(new)* | الإيرادات |
| `select_category` | Select a category | اختر تصنيفاً | اختر تصنيفًا |
| `select_person` | Select a person | اختر شخصاً | اختر شخصًا |
| `transaction_delete_from_fixed` | This came from a fixed expense. Deleting it won't make it post again. | نشأت هذه المعاملة من مصروف ثابت. الحذف لن يؤدي إلى إعادة إنشائها. | نشأت هذه المعاملة من مصروف ثابت. حذفها لن يجعلها تُسجَّل مرة أخرى. |
| `transaction_delete_fuel_note` | The linked fuel log will also be deleted. | سيتم حذف سجل التزود بالوقود المرتبط أيضًا. | سيُحذف سجل الوقود المرتبط بها أيضًا. |
| `transaction_delete_maintenance_note` | If this expense came from completing a maintenance reminder, deleting it won't make the reminder due again. | إذا نشأ هذا المصروف من إكمال تذكير صيانة، فحذفه لن يُعيد التذكير كمستحق. | إذا نشأ هذا المصروف عن إتمام تذكير صيانة، فلن يعود التذكير مستحقًا بعد حذفه. |
| `transaction_delete_pause_rule` | Also pause this fixed expense | أوقف هذا المصروف الثابت أيضًا | إيقاف هذا المصروف الثابت مؤقتًا أيضًا |
| `transaction_pet` | Pet | الحيوان | الحيوان الأليف |
| `transaction_pin_fixed` | Make a monthly fixed expense | اجعله مصروفًا ثابتًا شهريًا | تثبيت كمصروف شهري |
| `transaction_pin_fixed_confirm_body` | A monthly commitment will be created and posted automatically. | سيتم إنشاء التزام شهري وترحيله تلقائيًا. | سيُنشأ مصروف ثابت شهري يُسجَّل تلقائيًا. |
| `transaction_pin_fixed_confirm_title` | Make this a monthly fixed expense? | تحويل هذا إلى مصروف ثابت شهري؟ | تثبيت هذه المعاملة كمصروف شهري؟ |
| `transaction_pinned_fixed` | Added to fixed commitments. | أُضيف إلى الالتزامات الثابتة. | تمت الإضافة إلى المصروفات الثابتة. |
| `type_income` | Income | دخل | إيراد |

## Vehicles, fuel & maintenance

| key | English | old Arabic | new Arabic |
| --- | --- | --- | --- |
| `fuel_log_delete_confirm_body` | The linked fuel expense is deleted too. | سيُحذف مصروف الوقود المرتبط أيضًا. | سيُحذف مصروف الوقود المرتبط بها أيضًا. |
| `fuel_log_liters` | Liters | اللترات | عدد اللترات |
| `fuel_log_odometer` | Odometer (km) | العداد (كم) | عدّاد الكيلومترات (كم) |
| `fuel_stats_cost_per_km` | Cost/km | التكلفة/كم | تكلفة/كم |
| `fuel_stats_l_per_100km` | L/100km | لتر/١٠٠كم | لتر/100 كم |
| `fuel_stats_no_data` | Add at least two full fill-ups to see consumption. | أضف تعبئتين ممتلئتين على الأقل لعرض الاستهلاك. | سجّل تعبئتين ممتلئتين على الأقل لحساب معدل الاستهلاك. |
| `fuel_stats_title` | Economy | الاستهلاك | معدل الاستهلاك |
| `maintenance_complete` | Mark done | تم الإنجاز | إتمام |
| `maintenance_delete_confirm_body` | This can't be undone. | لا يمكن التراجع عن ذلك. | لا يمكن التراجع عن هذا الإجراء. |
| `maintenance_due_date_line` | Due {date} | الاستحقاق {date} | الاستحقاق في {date} |
| `maintenance_due_odometer` | Due odometer (km) | عداد الاستحقاق (كم) | عدّاد الاستحقاق (كم) |
| `maintenance_need_one_due` | Enter a due date or a due odometer. | أدخل تاريخ استحقاق أو قراءة عداد. | أدخل تاريخ استحقاق أو قراءة عدّاد. |
| `maintenance_status_due_soon` | Due soon | قريب | قريب الاستحقاق |
| `vehicle_archive_confirm_body` | It stays in history but is hidden from pickers. | تبقى في السجل لكن تُخفى من القوائم. | ستبقى في السجل لكنها لن تظهر في القوائم. |
| `vehicle_odometer` | Current odometer (km) | قراءة العداد الحالية (كم) | قراءة عدّاد الكيلومترات الحالية |
| `vehicle_odometer_hint` | e.g. 45000 | مثال: ٤٥٠٠٠ | مثال: 45000 |
| `vehicle_odometer_value` | Odometer: {km} km | العداد: {km} كم | عدّاد الكيلومترات: {km} كم |
| `vehicle_plate` | Plate (optional) | اللوحة (اختياري) | رقم اللوحة (اختياري) |
| `vehicle_plate_hint` | e.g. ABC 123 | مثال: أ ب ج ١٢٣ | مثال: أ ب ج 123 |
| `vehicles_section` | Vehicles | السيارات والمصروفات | السيارات |

## Fixed expenses

| key | English | old Arabic | new Arabic |
| --- | --- | --- | --- |
| `recurring_delete_confirm_body` | It stops posting and leaves the list. Choose what happens to the transactions it already posted. | سيتوقف عن الترحيل ويختفي من القائمة. اختر ما سيحدث للمعاملات التي رحّلها بالفعل. | سيتوقف عن التسجيل ويختفي من القائمة. اختر ما سيحدث للمعاملات التي سجّلها بالفعل. |
| `recurring_delete_option_delete_month` | {count, plural, =0{No posted transactions this month to delete} =1{This month's 1 posted transaction is deleted too} other{This month's {count} posted transactions are deleted too}} | {count, plural, =0{لا توجد معاملات مرحّلة هذا الشهر لحذفها} =1{تُحذف أيضًا معاملة هذا الشهر المرحّلة} other{تُحذف أيضًا {count} معاملات مرحّلة هذا الشهر}} | {count, plural, zero{لا توجد معاملات مسجّلة هذا الشهر لحذفها} one{تُحذف أيضًا المعاملة المسجّلة هذا الشهر} two{تُحذف أيضًا المعاملتان المسجّلتان هذا الشهر} few{تُحذف أيضًا {count} معاملات مسجّلة هذا الشهر} many{تُحذف أيضًا {count} معاملة مسجّلة هذا الشهر} other{تُحذف أيضًا {count} معاملة مسجّلة هذا الشهر}} |
| `recurring_delete_option_keep` | Posted transactions stay and keep counting as fixed expenses | تبقى المعاملات المرحّلة وتستمر في احتسابها كمصروفات ثابتة | تبقى المعاملات المسجّلة وتحسب كمصروف ثابت |
| `recurring_generated` | {count, plural, =1{Posted 1 recurring transaction.} other{Posted {count} recurring transactions.}} | تم ترحيل {count} حركة دورية. | {count, plural, one{تم تسجيل معاملة ثابتة واحدة.} two{تم تسجيل معاملتين ثابتتين.} few{تم تسجيل {count} معاملات ثابتة.} many{تم تسجيل {count} معاملة ثابتة.} other{تم تسجيل {count} معاملة ثابتة.}} |
| `recurring_inactive_hint` | Paused commitments don't post. | الالتزامات الموقوفة لا تُرحَّل. | المصروفات الثابتة الموقوفة لا تُسجَّل. |
| `recurring_link_pet` | Pet (optional) | الحيوان (اختياري) | ربط بحيوان أليف (اختياري) |
| `recurring_link_vehicle` | Vehicle (optional) | السيارة (اختياري) | ربط بسيارة (اختياري) |
| `recurring_pause` | Pause | إيقاف | إيقاف مؤقت |
| `recurring_paused` | Paused | موقوف | موقوف مؤقتًا |
| `recurring_paused_message` | Paused. Transactions already posted this month stay; delete them separately if needed. | تم الإيقاف. تبقى المعاملات المُدرجة هذا الشهر؛ احذفها منفصلة عند الحاجة. | تم الإيقاف مؤقتًا. تبقى المعاملات المسجّلة هذا الشهر، ويمكنك حذفها على حدة. |
| `recurring_resume` | Resume | تشغيل | استئناف |
| `recurring_resumed_message` | Resumed. It continues from the next due date; the missed period isn't posted. | تم التشغيل. ستكون الحركة القادمة هي التالية؛ لن يتم ترحيل فترة الإيقاف. | تم الاستئناف. سيُسجَّل الموعد القادم فقط، ولن تُسجَّل الفترة الموقوفة. |
| `recurring_saved` | Commitment saved. | تم حفظ الالتزام. | تم حفظ المصروف الثابت. |
| `recurring_type_income` | Income | دخل | إيراد |

## Pets & profile

| key | English | old Arabic | new Arabic |
| --- | --- | --- | --- |
| `pet_add` | Add pet | إضافة حيوان | إضافة حيوان أليف |
| `pet_edit` | Edit pet | تعديل الحيوان | تعديل بيانات الحيوان |
| `pet_expenses_empty` | No expenses this month. | لا مصروفات هذا الشهر. | لا توجد مصروفات هذا الشهر. |
| `pet_monthly_total` | This month: {amount} | هذا الشهر: {amount} | مصروفات هذا الشهر: {amount} |
| `pets_empty_body` | Add your cats, dogs and other companions to track their costs. | أضف قططك وكلابك ورفاقك الآخرين لتتبع تكاليفهم. | أضف قططك وكلابك ورفاقك لتتبّع تكاليفهم. |
| `pets_empty_title` | No pets yet | لا توجد حيوانات بعد | لا توجد حيوانات أليفة بعد |
| `pets_section` | Pets | الحيوانات | الحيوانات الأليفة |
| `pets_title` | Pets | الحيوانات | الحيوانات الأليفة |

## Phase 4a: Budgets & Reports (new strings)

New screens, so every string below is new (there is no "old Arabic" column).
Glossary additions: **الميزانيات** (budgets), **الحد الشهري** (monthly limit),
**الحد الإجمالي** (overall limit), **التقارير** (reports — **never** الرؤى),
**المسجَّل** (posted, unchanged from the fixed-expenses cards).

Decisions worth noting:

- The dashboard alert card counts **categories** only, so its "nothing to
  worry about" line reads `No category is near or over its limit.` rather than
  "all budgets are on track" (the overall limit is surfaced on its own line,
  with a status word beside it when it is near/over).
- Amounts keep the copy-pass rules: `ج.م` in Arabic / `EGP` in English via
  `Currency.label`, Western digits 0-9 in the strings (the Arabic-Indic toggle
  still converts displayed numbers), and ICU plural categories in Arabic.

| key | English | old Arabic | new Arabic |
| --- | --- | --- | --- |
| `error_invalid_category` | That category doesn't belong to this household. | *(new)* | هذا التصنيف ليس من تصنيفات هذه الأسرة. |
| `error_invalid_budget` | That limit doesn't exist. | *(new)* | هذا الحد غير موجود. |
| `nav_budgets` | Budgets | *(new)* | الميزانيات |
| `nav_reports` | Reports | *(new)* | التقارير |
| `budgets_title` | Budgets | *(new)* | الميزانيات |
| `budget_overall_title` | Overall monthly limit | *(new)* | الحد الشهري الإجمالي |
| `budget_overall_hint` | Covers ALL expenses this month, including categories without a limit and posted fixed expenses. | *(new)* | يشمل كل مصروفات الشهر، بما فيها التصنيفات بلا حد والمصروفات الثابتة المسجّلة. |
| `budget_projected_note` | Projected to exceed the limit | *(new)* | متوقع تجاوز الحد |
| `budget_help_spent` | Includes posted fixed expenses. | *(new)* | يشمل المصروفات الثابتة المسجّلة. |
| `budget_status_ok` | Within limit | *(new)* | ضمن الحد |
| `budget_status_near` | Near limit | *(new)* | قريب من الحد |
| `budget_status_over` | Over budget | *(new)* | تجاوز الميزانية |
| `budget_percent` | {percent}% used | *(new)* | استُخدم {percent}% |
| `budget_add` | Set a limit | *(new)* | تحديد حد |
| `budget_add_overall` | Set overall limit | *(new)* | تحديد الحد الإجمالي |
| `budget_edit` | Edit limit | *(new)* | تعديل الحد |
| `budget_pause` | Pause | *(new)* | إيقاف مؤقت |
| `budget_resume` | Resume | *(new)* | استئناف |
| `budget_delete` | Delete limit | *(new)* | حذف الحد |
| `budget_paused` | Paused | *(new)* | موقوف مؤقتًا |
| `budget_paused_hint` | Paused — not counted in alerts. | *(new)* | موقوف مؤقتًا — لا يُحتسب في التنبيهات. |
| `budget_amount_label` | Monthly limit | *(new)* | الحد الشهري |
| `budget_amount_hint` | e.g. 1000 | *(new)* | مثال: 1000 |
| `budget_saved` | Limit saved. | *(new)* | تم حفظ الحد. |
| `budget_deleted` | Limit deleted. | *(new)* | تم حذف الحد. |
| `budget_delete_confirm_title` | Delete this limit? | *(new)* | حذف هذا الحد؟ |
| `budget_delete_confirm_body` | The spending stays; only the limit is removed. | *(new)* | تبقى المصروفات كما هي، ويُحذف الحد فقط. |
| `budget_empty_title` | No limits yet | *(new)* | لا توجد حدود بعد |
| `budget_empty_body` | Set a monthly limit for a category, or one overall limit for the whole household. | *(new)* | حدّد حدًا شهريًا لتصنيف، أو حدًا إجماليًا واحدًا للأسرة. |
| `budget_spent_of` | {spent} of {limit} | *(new)* | {spent} من {limit} |
| `budget_remaining_value` | Remaining: {amount} | *(new)* | المتبقي: {amount} |
| `budget_projected_value` | Projected: {amount} | *(new)* | المتوقع: {amount} |
| `budget_alert_title` | Budgets | *(new)* | الميزانيات |
| `budget_alert_all_ok` | No category is near or over its limit. | *(new)* | لا يوجد تصنيف قريب من حده أو متجاوز له. |
| `budget_alert_count` | {count, plural, =1{1 category near or over its limit} other{{count} categories near or over their limits}} | *(new)* | {count, plural, zero{لا توجد تصنيفات قريبة من الحد} one{تصنيف واحد قريب من الحد أو متجاوز} two{تصنيفان قريبان من الحد أو متجاوزان} few{{count} تصنيفات قريبة من الحد أو متجاوزة} many{{count} تصنيفًا قريبًا من الحد أو متجاوزًا} other{{count} تصنيف قريب من الحد أو متجاوز}} |
| `budget_alert_overall` | Overall limit: {amount} | *(new)* | الحد الإجمالي: {amount} |
| `reports_title` | Reports | *(new)* | التقارير |
| `report_by_category` | Expenses by category | *(new)* | المصروفات حسب التصنيف |
| `report_income_vs_expenses` | Income vs expenses | *(new)* | الإيرادات مقابل المصروفات |
| `report_by_person` | Spending by person | *(new)* | الإنفاق حسب الشخص |
| `report_last_six_months` | Last 6 months | *(new)* | آخر 6 أشهر |
| `report_total` | Total | *(new)* | الإجمالي |
| `report_expenses_total` | Total expenses: {amount} | *(new)* | إجمالي المصروفات: {amount} |
| `report_share` | {percent}% | *(new)* | {percent}% |
| `report_legend_income` | Income | *(new)* | الإيرادات |
| `report_empty_title` | No data yet | *(new)* | لا توجد بيانات بعد |
| `report_empty_body` | Add some transactions and the charts will appear here. | *(new)* | أضف بعض المعاملات وستظهر الرسوم هنا. |
| `report_by_category_empty` | No expenses this month to chart. | *(new)* | لا توجد مصروفات هذا الشهر لعرضها. |
| `report_by_person_empty` | No spending this month to chart. | *(new)* | لا يوجد إنفاق هذا الشهر لعرضه. |
