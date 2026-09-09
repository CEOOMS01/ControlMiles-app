// Olympus Mont Systems LLC - ControlMiles
// lib/i18n/ar.dart - Arabic (ARA) - IMPROVED VERSION

const Map<String, String> arTexts = {
  // ============================================================
  // APPLICATION GENERAL
  // ============================================================
  'app_name': 'ControlMiles',
  'splash': 'شاشة الترحيب',
  'not_found': 'غير موجود',
  'error': 'خطأ',
  'system_error': 'خطأ في النظام',
  'loading': 'جاري التحميل...',
  'please_wait': 'يرجى الانتظار...',

  // ============================================================
  // AUTHENTICATION
  // ============================================================
  'login': 'تسجيل الدخول',
  'register': 'تسجيل',
  'signup': 'إنشاء حساب',
  'logout': 'تسجيل الخروج',
  'forgot_password': 'هل نسيت كلمة السر؟',
  'reset_password': 'إعادة تعيين كلمة السر',
  'auth_session_expired': 'انتهت صلاحية جلسة المصادقة',
  'email': 'البريد الإلكتروني',
  'password': 'كلمة المرور',
  'confirm_password': 'تأكيد كلمة المرور',
  'sign_in': 'تسجيل الدخول',
  'sign_up': 'إنشاء حساب',
  'sign_out': 'تسجيل الخروج',
  'active_activity': 'النشاط الحالي',
  'start_tracking_tooltip': 'بدء التتبع',
  'configuration_updated': 'تم تحديث الإعدادات',


 // ============================================================
  // USER PROFILE
  // ============================================================
  'name': 'Nombre',
  'edit_name': 'Editar nombre',
  'Last_name': 'Apellidos',
  'Adress': 'Direccion',
  'Number':'Numero de contacto',
  'dark_mode': 'الوضع الداكن',
     'dark_mode_description': 'التبديل بين المظهر الفاتح والداكن',
    'profile_updated_success': 'تم تحديث الملف الشخصي بنجاح',

  // ============================================================
  // NAVIGATION
  // ============================================================
  'dashboard': 'لوحة التحكم',
  'home': 'الرئيسية',
  'profile': 'الملف الشخصي',
  'settings': 'الإعدادات',
  'help': 'المساعدة',
  'about': 'حول التطبيق',
  'support': 'الدعم الفني',

  // ============================================================
  // TRACKING
  // ============================================================
  'tracking': 'التتبع',
  'tracking_active': 'التتبع نشط',
  'tracking_paused': 'التتبع متوقف مؤقتاً',
  'tracking_stopped': 'التتبع متوقف',
  'start_tracking': 'بدء التتبع',
  'stop_tracking': 'إيقاف التتبع',
  'pause_tracking': 'إيقاف مؤقت',
  'resume_tracking': 'استئناف التتبع',
  'trip_details': 'تفاصيل الرحلة',
  'trip_history': 'سجل الرحلات',
  'trip_ended': 'انتهت الرحلة',
  'miles': 'أميال',
  'kilometers': 'كيلومترات',
  'speed': 'السرعة',
  'duration': 'المدة',
  'distance': 'المسافة',
  'start_time': 'وقت البدء',
  'end_time': 'وقت الانتهاء',
  'select_an_activity_before_starting_tracking': 'اختر نشاطاً قبل بدء التتبع',

  // ============================================================
  // ODOMETER
  // ============================================================
  'odometer': 'عداد المسافات',
  'odometer_capture': 'تصوير العداد',
  'start_odometer_capture': 'تصوير العداد عند البدء',
  'end_odometer_capture': 'تصوير العداد عند الانتهاء',
  'capture_photo': 'التقاط صورة',
  'retry_camera': 'إعادة محاولة الكاميرا',
  'camera_error': 'خطأ في الكاميرا',
  'odometer_not_detected': 'لم يتم اكتشاف العداد',
  'center_odometer_numbers': 'ضع أرقام العداد في المنتصف',
  'ai_processing': 'معالجة الذكاء الاصطناعي',
  'validating_mileage_gps_hash': 'التحقق من المسافة، الموقع والهاش',

  // ============================================================
  // GPS / LOCATION
  // ============================================================
  'gps': 'نظام الموقع (GPS)',
  'gps_enabled': 'تم تفعيل GPS',
  'gps_disabled': 'تم تعطيل GPS',
  'location_permission_required': 'إذن الموقع مطلوب',
  'location_permission_denied': 'تم رفض إذن الموقع',

  // ============================================================
  // HISTORY & REPORTS
  // ============================================================
  'history': 'السجل',
  'reports': 'التقارير',
  'audit_logs': 'سجلات التدقيق',
  'statistics': 'الإحصائيات',
  'summary': 'ملخص',
  'total_miles': 'إجمالي الأميال',
  'total_trips': 'إجمالي الرحلات',
  'average_speed': 'متوسط السرعة',
  'RECENT_TRIPS': 'الرحلات الأخيرة',
  'SEE_ALL': 'عرض الكل',
  'not_trips_yet': 'لم تكن رحلات بعد',


   // ============================================================
  // TRIP PURPOSES & IRS
  // ============================================================
  'select_trip_purpose': 'اختر الغرض من الرحلة',
    'irs_deduction_note': 'لأغراض الخصم -- هذا التطبيق لا يضمن ذلك',
  'business_purpose': 'عمل / تجارة',
  'work_commute': 'التنقل للعمل',
  'medical': 'طبي',
  'moving': 'انتقال / سكن',
  'charitable': 'عمل خيري / تطوع',
  'education_study': 'تعليم / دراسة',
  'personal_other': 'شخصي / آخر',

  // ============================================================
  // SETTINGS
  // ============================================================
  'preferences': 'التفضيلات',
  'language': 'اللغة',
  'language_description': 'اختر لغتك المفضلة',
  'language_changed': 'تم تغيير اللغة إلى',
  'notifications': 'الإشعارات',
  'notifications_description': 'تلقي إشعارات التطبيق',
  'notifications_enabled': 'الإشعارات مفعلة',
  'notifications_disabled': 'الإشعارات معطلة',
  'analytics': 'التحليلات',
  'analytics_description': 'مشاركة بيانات الاستخدام',

  // ============================================================
  // PRIVACY & SECURITY
  // ============================================================
  'privacy_security': 'الخصوصية والأمان',
  'privacy_policy': 'سياسة الخصوصية',
  'terms_conditions': 'الشروط والأحكام',
  'data_security': 'أمن البيانات',
  'security_audit': 'تدقيق أمني',

  // ============================================================
  // ABOUT
  // ============================================================
  'about_app': 'حول التطبيق',
  'app_version': 'إصدار التطبيق',
  'build_number': 'رقم البناء',
  'company': 'الشركة',
  'copyright': 'جميع الحقوق محفوظة',
  'developer': 'المطور',

  // ============================================================
  // BUTTONS
  // ============================================================
  'ok': 'موافق',
  'cancel': 'إلغاء',
  'save': 'حفظ',
  'delete': 'حذف',
  'edit': 'تعديل',
  'close': 'إغلاق',
  'refresh': 'تحديث',
  'retry': 'إعادة المحاولة',
  'next': 'التالي',
  'previous': 'السابق',
  'done': 'تم',
  'submit': 'إرسال',
  'continue': 'متابعة',
  'back': 'رجوع',
  'start': 'بدء',
  'stop': 'إيقاف',
  'pause': 'إيقاف مؤقت',
  'resume': 'استئناف',
  'end_trip': 'إنهاء الرحلة',
  'skip': 'تخطي',
  'confirm': 'تأكيد',

  // ============================================================
  // MESSAGES
  // ============================================================
  'success': 'نجاح',
  'failed': 'فشل',
  'warning': 'تحذير',
  'info': 'معلومات',
  'no_data': 'لا توجد بيانات',
  'no_results': 'لم يتم العثور على نتائج',
  'something_went_wrong': 'حدث خطأ ما',
  'please_try_again': 'يرجى المحاولة مرة أخرى',
  'network_error': 'خطأ في الشبكة',
  'internet_required': 'مطلوب اتصال بالإنترنت',
  'offline_mode': 'وضع العمل دون اتصال',
  'syncing': 'جاري المزامنة...',
  'synced': 'تمت المزامنة',
  'feature_coming_soon': 'الميزة ستتوفر قريباً',

  // ============================================================
  // CLOUD STATUS
  // ============================================================
  'cloud_status': 'حالة السحابة',
  'cloud_connected': 'متصل بالسحابة',
  'cloud_disconnected': 'غير متصل بالسحابة',
  'audit_chain_healthy': 'سلسلة التدقيق سليمة',
  'audit_chain_compromised': 'سلسلة التدقيق معرضة للخطر',

  // ============================================================
  // TIME
  // ============================================================
  'today': 'اليوم',
  'yesterday': 'أمس',
  'this_week': 'هذا الأسبوع',
  'this_month': 'هذا الشهر',
  'this_year': 'هذه السنة',
  'all_time': 'كل الأوقات',
  'january': 'يناير',
  'february': 'فبراير',
  'march': 'مارس',
  'april': 'أبريل',
  'may': 'مايو',
  'june': 'يونيو',
  'july': 'يوليو',
  'august': 'أغسطس',
  'september': 'سبتمبر',
  'october': 'أكتوبر',
  'november': 'نوفمبر',
  'december': 'ديسمبر',
  'monday': 'الإثنين',
  'tuesday': 'الثلاثاء',
  'wednesday': 'الأربعاء',
  'thursday': 'الخميس',
  'friday': 'الجمعة',
  'saturday': 'السبت',
  'sunday': 'الأحد',

  // ============================================================
  // UNITS
  // ============================================================
  'meter': 'متر',
  'meter_short': 'م',
  'kilometer': 'كيلومتر',
  'kilometer_short': 'كم',
  'mile': 'ميل',
  'mile_short': 'ميل',
  'hour': 'ساعة',
  'minute': 'دقيقة',
  'second': 'ثانية',
  'kmh': 'كم/س',
  'mph': 'ميل/س',

  // ============================================================
  // VALIDATION
  // ============================================================
  'field_required': 'هذا الحقل مطلوب',
  'powered_by_footer': 'بدعم من',
  'invalid_email': 'البريد الإلكتروني غير صحيح',
  'password_too_short': 'كلمة المرور قصيرة جداً',
  'passwords_do_not_match': 'كلمات المرور غير متطابقة',
  'invalid_input': 'إدخال غير صحيح',

  // ============================================================
  // PERMISSIONS
  // ============================================================
  'permissions_required': 'الأذونات مطلوبة',
  'camera_permission': 'إذن الكاميرا',
  'location_permission': 'إذن الموقع',
  'storage_permission': 'إذن التخزين',
  'grant_permission': 'منح الإذن',
  'deny_permission': 'رفض الإذن',

  // ============================================================
  // SPECIFIC FEATURES
  // ============================================================
  'evidence': 'دليل',
  'evidence_photo': 'صورة دليل',
  'hash_verification': 'التحقق من الهاش',
  'verified': 'تم التحقق',
  'unverified': 'غير موثق',
  'blockchain_status': 'حالة البلوكشين',
  'integrity_check': 'فحص السلامة',
  'anomaly_detection': 'كشف الأنشطة غير الطبيعية',
  'fraud_alert': 'تنبيه احتيال',
  'suspicious_activity': 'تم رصد نشاط مشبوه',

  // ============================================================
  // VEHICLES
  // ============================================================
  'vehicle': 'المركبة',
  'vehicles': 'المركبات',
  'add_vehicle': 'إضافة مركبة',
  'edit_vehicle': 'تعديل مركبة',
  'delete_vehicle': 'حذف مركبة',
  'vehicle_make': 'العلامة التجارية',
  'vehicle_model': 'الموديل',
  'vehicle_color': 'اللون',
  'vehicle_year': 'السنة',
  'vehicle_mileage': 'المسافة المقطوعة',
  'vehicle_information': 'معلومات المركبة',
  'no_vehicle_registered': 'لا توجد مركبة مسجلة',

  // ============================================================
  // SUBSCRIPTION
  // ============================================================
  'subscription': 'الاشتراك',
  'plan': 'الباقة',
  'basic_plan': 'الباقة الأساسية',
  'premium_plan': 'الباقة المميزة',
  'pro_plan': 'الباقة الاحترافية',
  'upgrade_plan': 'ترقية الباقة',
  'manage_subscription': 'إدارة الاشتراك',
  'trial_period': 'فترة تجريبية',
  'trial_expired': 'انتهت الفترة التجريبية',
  'subscription_active': 'الاشتراك نشط',
  'subscription_required': 'الاشتراك مطلوب',

  // ============================================================
  // FLEET
  // ============================================================
  'fleet_management': 'إدارة الأسطول',
  'fleet_vehicle': 'مركبة أسطول',
  'fleet_dashboard': 'لوحة تحكم الأسطول',
  'driver_management': 'إدارة السائقين',
  'company_account': 'حساب الشركة',

  // ============================================================
  // REPORT EXTENSIONS
  // ============================================================
  'report_generated': 'تم إنشاء التقرير',
  'report_download': 'تحميل التقرير',
  'report_verification': 'التحقق من التقرير',
  'report_qr_verification': 'التحقق عبر QR',
  'report_integrity': 'سلامة التقرير',

  // ============================================================
  // TAX / IRS
  // ============================================================
  'tax_deduction': 'الخصم الضريبي',
  'irs_rate': 'معدل IRS للأميال',
  'estimated_deduction': 'الخصم المقدر',
  'tax_summary': 'ملخص الضرائب',

  // ============================================================
  // QR VERIFICATION
  // ============================================================
  'verification_page': 'صفحة التحقق',
  'scan_qr': 'مسح رمز QR',
  'verify_report': 'تحقق من التقرير',
  'session_hash': 'هاش الجلسة',
  'section_hash': 'هاش القسم',

  // ============================================================
  // VEHICLE FORM
  // ============================================================
  'enter_vehicle_make': 'أدخل علامة المركبة',
  'enter_vehicle_model': 'أدخل موديل المركبة',
  'enter_vehicle_color': 'أدخل لون المركبة',
  'enter_vehicle_year': 'أدخل سنة المركبة',
  'enter_vehicle_mileage': 'أدخل المسافة المقطوعة',

  // ============================================================
  // SUCCESS / ALERTS
  // ============================================================
  'vehicle_added_success': 'تمت إضافة المركبة بنجاح',
  'vehicle_deleted_success': 'تم حذف المركبة',
  'vehicle_saved': 'تم حفظ المركبة',
  'vehicle_required': 'المركبة مطلوبة',

  'end_shift': 'إنهاء الوردية',
  'end_shift_tooltip': 'اضغط لإغلاق وردية العمل',
  'end_shift_failed': 'تعذّر إنهاء الوردية — التتبع لا يزال نشطاً. حاول مجدداً.',
  'session_already_closed': 'هذه الجلسة مغلقة بالفعل ولا يمكن تعديلها.',
  'session_not_found': 'خطأ فادح: لم يتم العثور على الجلسة النشطة.',
  'session_already_finalized': 'تم إنهاء هذه الجلسة مسبقاً.',
  'duplicate_capture': 'يوجد بالفعل تسجيل لهذا الحدث.',
  'photo_size_out_of_range': 'حجم الصورة خارج النطاق المسموح ({min}KB–{max}MB). حاول مجدداً.',
  'photo_format_not_supported': 'صيغة الصورة غير مدعومة. الصيغ المسموحة: {formats}.',

  // ============================================================
  // VEHICLE PROFILE (شاشة تفاصيل للقراءة فقط) + الأميال في الصيانة
  // ============================================================
  'vehicle_profile_title': 'ملف المركبة',
  'tracked_miles_gps': 'الأميال المسجلة (GPS)',
  'odometer_checkpoints_title': 'إغلاقات عداد المسافة الأسبوعية',
  'no_odometer_checkpoints': 'لا توجد إغلاقات لعداد المسافة بعد',
  'checkpoint_week_label': 'أسبوع {date}',
  'checkpoint_start': 'البداية',
  'checkpoint_end': 'الإغلاق',
  'checkpoint_pending_close': 'بانتظار الإغلاق',
  'current_odometer': 'عداد المسافة الحالي',
  'miles_since_service': 'الأميال منذ آخر صيانة',
  'no_service_recorded': 'لا توجد صيانة مسجلة بعد',
  'next_service_due_miles': 'الصيانة القادمة عند {miles}',
  'service_overdue_miles': 'متأخر بمقدار {miles}',
  'service_recommended_interval': 'موصى به: كل {miles}',

  // ============================================================
  // تدقيق المفاتيح المفقودة (2026-09-03)
  // ============================================================
  'auth_error': 'خطأ في المصادقة. حاول مرة أخرى.',
  'invalid_credentials': 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
  'email_already_exists': 'هذا البريد الإلكتروني مسجل بالفعل.',
  'end': 'إنهاء',
  'navigation_error_title': 'خطأ في التنقل',
  'route_not_found_message': 'المسار {route} غير موجود.\nتواصل مع Olympus Mont Systems.',
  'switched_label': 'تم التبديل',
  'trip_number_label': 'الرحلة {number}',
  'trip_end_time_label': 'النهاية: {time}',
  'sections_label': 'الأقسام',
  'vin_label': 'رقم الهيكل',
  'system_initializing_redirecting': 'جارٍ تهيئة النظام. جارِ التحويل...',
  'error_all_fields_required': 'جميع الحقول مطلوبة.',
  'error_invalid_vehicle_year': 'سنة المركبة غير صالحة.',
  'error_odometer_negative_or_empty': 'لا يمكن أن يكون عداد المسافة سالباً أو فارغاً.',
  'error_invalid_maintenance_type': 'نوع الصيانة غير صالح.',
  'error_service_date_required': 'تاريخ الخدمة مطلوب.',
  'sections_count_label': '{count} أقسام',
  'vehicle_make_other': 'أخرى',
  'email_not_linked_to_controlmiles': 'هذا البريد الإلكتروني غير مرتبط بأي حساب في ControlMiles.',

  'free_trial_expired_title': 'انتهت فترتك التجريبية المجانية',
  'free_trial_expired_body': 'انتهت فترتك التجريبية المجانية البالغة 30 يومًا. اشترك في Basic أو Premium لمواصلة تسجيل الرحلات.',
  'vehicle_limit_reached_title': 'تم الوصول إلى حد المركبات',
  'vehicle_limit_reached_body': 'تسمح خطتك بحد أقصى {max} مركبة/مركبات. قم بالترقية لإضافة المزيد.',
  'export_limit_reached_title': 'تم الوصول إلى حد التصدير',
  'export_limit_reached_body': 'تشمل خطة Basic تصديرين لملف PDF شهريًا. قم بالترقية إلى Premium للتصدير غير المحدود.',

  // Weekly odometer checkpoint (2026-09-03), added 2026-09-08 -- was
  // missing entirely for this language (dialog fell back to raw keys).
  'weekly_odometer_close_title': 'إغلاق عداد المسافات الأسبوعي',
  'weekly_odometer_close_body': 'هل تريد التقاط صورة إغلاق عداد المسافات لهذا الأسبوع الآن؟',
  'weekly_odometer_close_title_mandatory': 'الإغلاق الأسبوعي إلزامي',
  'weekly_odometer_close_body_mandatory': 'التقط صورة إغلاق عداد المسافات لهذا الأسبوع للمتابعة -- لا يمكن تأجيل هذا يوم الأحد.',
  'later': 'لاحقًا',
  'take_photo': 'التقاط صورة',
  'odometer_evidence_label': 'صور عداد المسافات (دليل)',
  'gps_vs_odometer_disclaimer': 'قد لا تتطابق هذه الأرقام دائمًا تمامًا -- الأميال الشخصية (غير المتعقبة) لا يحسبها GPS، لذا من الطبيعي وجود بعض الفرق.',

  // رابط دعوة الأسطول (إغلاق Sprint 1، 2026-09-09)
  'invite_landing_title': '{org} دعتك للانضمام',
  'invite_confirm_body': 'دعتك {org} للانضمام إلى أسطولها. هل تقبل؟',
  'invite_login_prompt': 'أدخل كلمة المرور لقبول هذه الدعوة.',
  'invite_signup_prompt': 'أنشئ حسابك للانضمام إلى هذا الأسطول.',
  'invite_accept_button': 'قبول الدعوة',
  'invite_invalid_title': 'دعوة غير صالحة أو منتهية الصلاحية',
  'invite_invalid_body': 'رابط الدعوة هذا لم يعد صالحًا. اطلب من مسؤول الأسطول إرسال رابط جديد.',
  'invite_confirm_email_first': 'تحقق من بريدك الإلكتروني لتأكيد حسابك، ثم افتح رابط الدعوة هذا مرة أخرى.',

  // محول السياق المزدوج (Fleet Sprint 2، 2026-09-09)
  'org_mode_personal': 'شخصي',
  'org_mode_company': 'الشركة: {org}',

  // شاشة قفل انتهاء المناوبة (Fleet Sprint 3، 2026-09-09)
  'shift_ended_title': 'انتهت المناوبة',
  'shift_ended_body': 'ليس لديك وصول إلى التطبيق حتى تبدأ مناوبتك التالية.',
  'shift_ended_start_next': 'بدء المناوبة التالية',

  // إلغاء الوصول (Fleet Sprint 3، 2026-09-09)
  'org_access_revoked_title': 'تمت إزالة الوصول إلى الأسطول',
  'org_access_revoked_body': 'قام مسؤول أسطولك بإزالة وصولك إلى هذه المؤسسة. سجّل الخروج للمتابعة.',

  // تخصيص مركبة مفتوح/دوّار (Fleet Sprint 4، 2026-09-09)
  'fleet_select_vehicle_button': 'اختر مركبة',
  'fleet_vehicle_picker_title': 'اختر مركبة',
  'fleet_vehicle_picker_empty': 'لا توجد مركبات متاحة الآن -- جميع مركبات الأسطول قيد الاستخدام حاليًا.',

  // رمز الوصول لبوابة التقارير، الآن يُنشأ داخل التطبيق (2026-09-09)
  'copy': 'نسخ',
  'copied_to_clipboard': 'تم النسخ إلى الحافظة',
  'generate_report_code_title': 'رمز الوصول إلى التقرير',
  'generate_report_code_body': 'أنشئ رمزًا لمرة واحدة لنطاق زمني من رحلاتك. يقوم محاسب الضرائب الخاص بك بإدخاله في controlmiles.com/portal/verify لعرض ملخص أميال للقراءة فقط -- بدون تسجيل دخول أو حساب من جانبه.',
  'generate_report_code_button': 'إنشاء رمز',
  'generate_report_code_your_code': 'شارك هذا الرمز مع محاسب الضرائب الخاص بك',
  'generate_report_code_expires_in': 'تنتهي الصلاحية خلال {mmss}',
  'generate_report_code_expired': 'انتهت صلاحية هذا الرمز.',
  'generate_report_code_disclaimer': 'قابل للاستخدام حتى مرتين. غير مضمون من قبل هذا التطبيق -- لأغراض الخصم.',
  'report_portal_section': 'بوابة التقارير',
  'report_portal_section_subtitle': 'أنشئ رمزًا لمحاسب الضرائب الخاص بك',
};