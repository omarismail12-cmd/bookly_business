// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'بوكلي بيزنس';

  @override
  String get navDashboard => 'الرئيسية';

  @override
  String get navCalendar => 'التقويم';

  @override
  String get navQueue => 'الانتظار';

  @override
  String get navCustomers => 'العملاء';

  @override
  String get navServices => 'الخدمات';

  @override
  String get navStaff => 'الموظفون';

  @override
  String get navPayments => 'المدفوعات';

  @override
  String get navCrm => 'إدارة العملاء';

  @override
  String get navOffers => 'العروض';

  @override
  String get navReports => 'التقارير';

  @override
  String get navLocations => 'الفروع';

  @override
  String get navToday => 'اليوم';

  @override
  String get navMore => 'المزيد';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get loginEmail => 'البريد الإلكتروني';

  @override
  String get loginPassword => 'كلمة المرور';

  @override
  String get loginSubmit => 'تسجيل الدخول';

  @override
  String get loginNoAccount => 'ليس لديك حساب؟ أنشئ حسابًا';

  @override
  String get signupTitle => 'أنشئ حسابك';

  @override
  String get signupFullName => 'الاسم الكامل';

  @override
  String get signupConfirmPassword => 'تأكيد كلمة المرور';

  @override
  String get signupSubmit => 'إنشاء حساب';

  @override
  String get signupHaveAccount => 'لديك حساب بالفعل؟ سجّل الدخول';

  @override
  String get bookingTitleNew => 'حجز جديد';

  @override
  String get bookingTitlePublic => 'احجز موعدًا';

  @override
  String get bookingChooseServiceStaffTime =>
      'اختر الخدمة والموظف والوقت المتاح.';

  @override
  String get bookingService => 'الخدمة';

  @override
  String get bookingStaff => 'الموظف';

  @override
  String get bookingCustomer => 'العميل';

  @override
  String get bookingLocation => 'الفرع';

  @override
  String get bookingDate => 'التاريخ';

  @override
  String get bookingFullName => 'الاسم الكامل';

  @override
  String get bookingEmail => 'البريد الإلكتروني';

  @override
  String get bookingPhone => 'رقم الهاتف';

  @override
  String bookingConfirmed(String reference) {
    return 'تم تأكيد الحجز. الرقم المرجعي: $reference';
  }

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonAdd => 'إضافة';

  @override
  String get commonSearch => 'بحث';

  @override
  String get commonLogout => 'تسجيل الخروج';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonNoResults => 'لا توجد نتائج.';

  @override
  String get commonToday => 'اليوم';

  @override
  String get commonNext => 'التالي';

  @override
  String get commonPrevious => 'السابق';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get commonName => 'الاسم';

  @override
  String get commonPhone => 'الهاتف';

  @override
  String get commonAddress => 'العنوان';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonOk => 'موافق';

  @override
  String commonPage(int page) {
    return 'صفحة $page';
  }

  @override
  String get commonLoadMore => 'تحميل المزيد';

  @override
  String get commonCustomerFallback => 'عميل';

  @override
  String get commonSignOut => 'تسجيل الخروج';

  @override
  String commonConfirmDelete(String name) {
    return 'إزالة \"$name\"؟ لا يمكن التراجع عن هذا.';
  }

  @override
  String get validationEmailRequired => 'البريد الإلكتروني مطلوب';

  @override
  String get validationEmailInvalid => 'أدخل بريدًا إلكترونيًا صحيحًا';

  @override
  String get validationPasswordRequired => 'كلمة المرور مطلوبة';

  @override
  String get validationPasswordTooShort => 'يجب ألا تقل كلمة المرور عن 8 أحرف';

  @override
  String get validationConfirmPasswordRequired => 'يرجى تأكيد كلمة المرور';

  @override
  String get validationPasswordMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get validationNameRequired => 'الاسم مطلوب';

  @override
  String get validationNameTooShort => 'يجب ألا يقل الاسم عن حرفين';

  @override
  String get pageTitlePayments => 'المدفوعات';

  @override
  String get pageTitleStaff => 'الموظفون والجداول';

  @override
  String get pageTitleQueue => 'قائمة الانتظار';

  @override
  String get pageTitleServices => 'الخدمات';

  @override
  String get pageTitleCrm => 'إدارة العملاء • الولاء • الحملات';

  @override
  String get pageTitleReports => 'التقارير';

  @override
  String get pageTitleOffers => 'الباقات والعضويات والكوبونات';

  @override
  String get pageTitleCustomers => 'العملاء';

  @override
  String get pageTitleLocations => 'الفروع';

  @override
  String get staffPortalTitle => 'اليوم';

  @override
  String get queueEmpty => 'لا يوجد عملاء في الانتظار.';

  @override
  String get queueAddWalkIn => 'عميل بدون حجز';

  @override
  String get paymentsAddPayment => 'دفعة';

  @override
  String get staffAddStaff => 'موظف';

  @override
  String get servicesAddService => 'إضافة';

  @override
  String get crmAddCustomer => 'عميل';

  @override
  String get crmCreateCampaign => 'حملة';

  @override
  String get locationsAddLocation => 'فرع';

  @override
  String get locationsEmpty => 'لا توجد فروع بعد.';

  @override
  String get staffPortalEmpty => 'لا توجد مواعيد اليوم.';

  @override
  String get customerPortalWelcome => 'مرحبًا بعودتك';

  @override
  String get customerPortalTagline => 'سجّل الدخول لإدارة حجوزاتك.';

  @override
  String get customerPortalSignupTagline =>
      'احجز المواعيد وتابع مكافآت الولاء الخاصة بك.';

  @override
  String get navMyAppointments => 'مواعيدي';

  @override
  String get navFindBook => 'حجز';

  @override
  String get navLoyalty => 'الولاء';

  @override
  String get navMyOffers => 'العروض';

  @override
  String get findBusinessTitle => 'احجز مع نشاط تجاري';

  @override
  String get findBusinessHint => 'أدخل رمز النشاط التجاري الذي حصلت عليه';

  @override
  String get findBusinessGo => 'متابعة';

  @override
  String get findBusinessNotFound =>
      'لم نتمكن من العثور على نشاط تجاري بهذا الرمز.';

  @override
  String get myAppointmentsEmpty => 'ليس لديك أي مواعيد بعد.';

  @override
  String get loyaltyEmpty => 'لا توجد مكافآت ولاء بعد — احجز زيارتك الأولى!';

  @override
  String loyaltyPoints(String points) {
    return '$points نقطة';
  }

  @override
  String get offersEmpty =>
      'لا توجد عروض حاليًا — تحقق مرة أخرى بعد زيارتك القادمة!';

  @override
  String get offersForYou => 'لك خصيصًا';

  @override
  String get offersActiveCoupons => 'كوبونات نشطة';

  @override
  String get statusPending => 'قيد الانتظار';

  @override
  String get statusConfirmed => 'مؤكد';

  @override
  String get statusCheckedIn => 'تم تسجيل الوصول';

  @override
  String get statusInService => 'قيد الخدمة';

  @override
  String get statusCompleted => 'مكتمل';

  @override
  String get statusCancelled => 'ملغى';

  @override
  String get statusNoShow => 'لم يحضر';

  @override
  String get statusWaiting => 'في الانتظار';

  @override
  String get statusCalled => 'تم النداء';

  @override
  String get statusActive => 'نشط';

  @override
  String get statusInactive => 'غير نشط';

  @override
  String get statusDraft => 'مسودة';

  @override
  String get statusSent => 'تم الإرسال';

  @override
  String get statusUndeliverable => 'تعذر التسليم';

  @override
  String get statusReversed => 'تم الاسترجاع';

  @override
  String get statusExpired => 'منتهية';

  @override
  String get statusUsedUp => 'مستنفدة';

  @override
  String get paymentMethodOther => 'أخرى';

  @override
  String get paymentTypeRefund => 'استرداد';

  @override
  String get paymentTypeForfeit => 'مصادرة';

  @override
  String get paymentTypeAdjustment => 'تسوية';

  @override
  String get apptCheckIn => 'تسجيل الوصول';

  @override
  String get apptStartService => 'بدء الخدمة';

  @override
  String get apptComplete => 'إكمال';

  @override
  String get apptNoShow => 'لم يحضر';

  @override
  String get apptReschedule => 'إعادة الجدولة';

  @override
  String get apptTitleFallback => 'الموعد';

  @override
  String get paymentMethodCash => 'نقدًا';

  @override
  String get paymentMethodCard => 'بطاقة';

  @override
  String get paymentMethodTransfer => 'تحويل';

  @override
  String get paymentMethodOnline => 'عبر الإنترنت';

  @override
  String get paymentTypePayment => 'دفعة';

  @override
  String get paymentTypeDeposit => 'عربون';

  @override
  String get paymentMethodLabel => 'طريقة الدفع';

  @override
  String get routerPageNotFound => 'تعذر العثور على هذه الصفحة.';

  @override
  String get routerGoHome => 'العودة للرئيسية';

  @override
  String get languageSwitcherTitle => 'اللغة';

  @override
  String get languageSystemDefault => 'افتراضي النظام';

  @override
  String get themeSwitcherTitle => 'المظهر';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeSystem => 'النظام';

  @override
  String syncConflictsNeedReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يحتاج $count تغيير إلى مراجعتك.',
      many: 'يحتاج $count تغييرًا إلى مراجعتك.',
      few: 'تحتاج $count تغييرات إلى مراجعتك.',
      two: 'يحتاج تغييران إلى مراجعتك.',
      one: 'يحتاج تغيير واحد إلى مراجعتك.',
    );
    return '$_temp0';
  }

  @override
  String syncChangesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذرت مزامنة $count تغيير.',
      many: 'تعذرت مزامنة $count تغييرًا.',
      few: 'تعذرت مزامنة $count تغييرات.',
      two: 'تعذرت مزامنة تغييرين.',
      one: 'تعذرت مزامنة تغيير واحد.',
    );
    return '$_temp0';
  }

  @override
  String syncOfflinePendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غير متصل — سيتم مزامنة $count تغيير عند عودة الاتصال.',
      many: 'غير متصل — سيتم مزامنة $count تغييرًا عند عودة الاتصال.',
      few: 'غير متصل — سيتم مزامنة $count تغييرات عند عودة الاتصال.',
      two: 'غير متصل — سيتم مزامنة تغييرين عند عودة الاتصال.',
      one: 'غير متصل — سيتم مزامنة تغيير واحد عند عودة الاتصال.',
    );
    return '$_temp0';
  }

  @override
  String get syncOffline => 'أنت غير متصل بالإنترنت.';

  @override
  String syncChangesSyncing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تتم مزامنة $count تغيير…',
      many: 'تتم مزامنة $count تغييرًا…',
      few: 'تتم مزامنة $count تغييرات…',
      two: 'تتم مزامنة تغييرين…',
      one: 'تتم مزامنة تغيير واحد…',
    );
    return '$_temp0';
  }

  @override
  String get syncResolveConflictsTitle => 'حل التعارضات';

  @override
  String get syncNothingToResolve => 'لا يوجد شيء لحله.';

  @override
  String get syncResolve => 'حل';

  @override
  String get syncRetryNow => 'إعادة المحاولة الآن';

  @override
  String syncConflictChangedElsewhere(String entity) {
    return '$entity — تم تغييره في مكان آخر';
  }

  @override
  String syncYourEdit(String value) {
    return 'تعديلك: $value';
  }

  @override
  String syncCurrentValue(String value) {
    return 'القيمة الحالية: $value';
  }

  @override
  String get syncKeepTheirs => 'الاحتفاظ بالنسخة الأخرى';

  @override
  String get syncKeepMine => 'الاحتفاظ بنسختي';

  @override
  String staffTodayStatusUpdateFailed(String error) {
    return 'فشل تحديث الحالة: $error';
  }

  @override
  String get blockedTimeAdd => 'إضافة وقت محظور';

  @override
  String get staffTimeOffAdded => 'تمت إضافة الإجازة.';

  @override
  String get staffTodayNoProfile =>
      'لا يوجد ملف موظف مرتبط بحسابك بعد. اطلب من مديرك تعيينك كموظف.';

  @override
  String get privateNotesLabel => 'ملاحظات خاصة';

  @override
  String get privateNotesHint => 'التفضيلات، الحساسية، التذكيرات…';

  @override
  String get nextRecommendationLabel => 'التوصية القادمة';

  @override
  String get nextRecommendationHint =>
      'ما الذي يجب اقتراحه في الزيارة القادمة…';

  @override
  String get staffAppointmentConflictMessage =>
      'تم تغيير بيانات هذا العميل في مكان آخر — احلّ التعارض من شريط المزامنة.';

  @override
  String get staffAppointmentOfflinePending =>
      'غير متصل — ستتم المزامنة عند عودة الاتصال.';

  @override
  String get staffAppointmentNotesSaved => 'تم حفظ الملاحظات.';

  @override
  String staffAppointmentSaveFailed(String error) {
    return 'تعذر الحفظ: $error';
  }

  @override
  String get orgSetupNameRequired => 'اسم النشاط التجاري مطلوب.';

  @override
  String get orgSetupSlugInvalid =>
      'يجب أن يتكون الرمز من 3 إلى 40 حرفًا صغيرًا أو رقمًا أو شرطة.';

  @override
  String get orgSetupPageTitle => 'إعداد نشاطك التجاري';

  @override
  String get orgSetupHeading => 'أنشئ نشاطك التجاري';

  @override
  String get orgSetupBusinessNameLabel => 'اسم النشاط التجاري';

  @override
  String get orgSetupSlugLabel => 'الرمز';

  @override
  String get orgSetupTimezoneLabel => 'المنطقة الزمنية';

  @override
  String get orgSetupCreateButton => 'إنشاء النشاط التجاري';

  @override
  String get orgSetupCreateDemoButton => 'إنشاء نشاط تجريبي + بيانات اختبار';

  @override
  String get orgSetupWaitingForInvite =>
      'هل تنتظر الانضمام إلى فريق حالي بدلًا من ذلك؟ اطلب من المالك تعيين دور لك، ثم سجّل الخروج أعلاه وسجّل الدخول مرة أخرى.';

  @override
  String get orgSuspendedMessage =>
      'عضويتك في نشاط Bookly التجاري موقوفة. تواصل مع مالك النشاط قبل إنشاء مساحة عمل أخرى أو الوصول إليها.';

  @override
  String get orgSettingsTitle => 'إعدادات النشاط التجاري';

  @override
  String get authIncorrectCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String authLoginFailed(String error) {
    return 'فشل تسجيل الدخول: $error';
  }

  @override
  String get authLoginFailedGeneric => 'فشل تسجيل الدخول.';

  @override
  String get authLoginSuccessful => 'تم تسجيل الدخول بنجاح!';

  @override
  String get authEmailConfirmRequired =>
      'يرجى تأكيد بريدك الإلكتروني قبل تسجيل الدخول.';

  @override
  String get loginWelcomeTitle => 'مرحبًا بك في بوكلي';

  @override
  String get loginTagline => 'سجّل الدخول لإدارة نشاطك التجاري.';

  @override
  String get authAccountCreatedConfirmEmail =>
      'تم إنشاء الحساب. تحقق من بريدك الإلكتروني لتأكيد حسابك.';

  @override
  String get authAccountCreatedConfirmEmailShort =>
      'تم إنشاء الحساب. تحقق من بريدك الإلكتروني لتأكيده.';

  @override
  String get authCheckEmailTitle => 'تحقق من بريدك الإلكتروني';

  @override
  String authCheckEmailBody(String email) {
    return 'لقد أنشأنا الحساب لـ $email. أرسل Supabase رسالة تأكيد إلى بريدك الإلكتروني. أكّدها قبل تسجيل الدخول.';
  }

  @override
  String get authAccountCreatedSuccess => 'تم إنشاء الحساب بنجاح!';

  @override
  String get authEmailAlreadyRegistered =>
      'هذا البريد الإلكتروني مسجَّل بالفعل. يرجى تسجيل الدخول بدلًا من ذلك.';

  @override
  String get authEmailInvalidGeneric => 'يرجى إدخال بريد إلكتروني صحيح.';

  @override
  String get authPasswordRequirementsNotMet =>
      'كلمة المرور لا تستوفي المتطلبات.';

  @override
  String authSignupFailed(String error) {
    return 'فشل إنشاء الحساب: $error';
  }

  @override
  String get authNoUserReturned => 'لم يُرجع Supabase أي مستخدم.';

  @override
  String get signupWelcomeTitle => 'أنشئ حساب بوكلي الخاص بك';

  @override
  String get signupTagline => 'أدر نشاطك التجاري باستخدام بوكلي.';

  @override
  String myApptStatusLine(String status) {
    return 'الحالة: $status';
  }

  @override
  String myApptStaffLine(String staff) {
    return 'الموظف: $staff';
  }

  @override
  String myApptServicesLine(String services) {
    return 'الخدمات: $services';
  }

  @override
  String myApptDepositLine(String paid, String required) {
    return 'العربون: تم دفع $paid من أصل $required';
  }

  @override
  String loyaltyUntilDate(String date) {
    return 'حتى $date';
  }

  @override
  String loyaltyUsesLeft(String count) {
    return '$count استخدام متبقٍ';
  }

  @override
  String get customersAddDialogTitle => 'إضافة عميل';

  @override
  String customersSubtitleNoShows(int count) {
    return 'عدد مرات عدم الحضور $count';
  }

  @override
  String get customersWaitingToSync => 'بانتظار المزامنة';

  @override
  String get locationsNewTitle => 'فرع جديد';

  @override
  String get locationsEditTitle => 'تعديل الفرع';

  @override
  String locationsSaveFailed(String error) {
    return 'تعذر حفظ الفرع: $error';
  }

  @override
  String get locationsDeleteTitle => 'حذف الفرع؟';

  @override
  String locationsDeleteFailed(String error) {
    return 'تعذر حذف الفرع: $error';
  }

  @override
  String get servicesAddTitle => 'إضافة خدمة';

  @override
  String get servicesDurationLabel => 'المدة (دقيقة)';

  @override
  String get servicesBufferLabel => 'الفاصل الزمني (دقيقة)';

  @override
  String get servicesPriceLabel => 'السعر (بالوحدات الصغرى)';

  @override
  String get servicesDepositLabel =>
      'العربون المطلوب (بالوحدات الصغرى، 0 = بلا عربون)';

  @override
  String get servicesNumbersRequired =>
      'يجب أن تكون المدة والفاصل الزمني والسعر أرقامًا صحيحة.';

  @override
  String servicesEditDescriptionTitle(String name) {
    return 'تعديل الوصف • $name';
  }

  @override
  String get servicesDescriptionLabel => 'الوصف';

  @override
  String get servicesDeleteTitle => 'حذف الخدمة؟';

  @override
  String servicesDeleteFailed(String error) {
    return 'تعذر حذف الخدمة: $error';
  }

  @override
  String get servicesEditDescriptionTooltip => 'تعديل الوصف';

  @override
  String get staffAddTitle => 'إضافة موظف';

  @override
  String get staffDisplayNameLabel => 'اسم العرض';

  @override
  String get staffAssignRoleButton => 'تعيين دور';

  @override
  String staffLinkLoginTitle(String name) {
    return 'ربط تسجيل الدخول لـ $name';
  }

  @override
  String get staffAlreadyLinkedWarning =>
      'هذا الموظف مرتبط بالفعل بحساب دخول. ربط بريد إلكتروني جديد سيستبدله.';

  @override
  String get staffAccountEmailLabel =>
      'البريد الإلكتروني للحساب (يجب أن يكون لديه دور الموظف بالفعل)';

  @override
  String get staffLinkMoveWarning =>
      'إذا كان ذلك الحساب مرتبطًا بالفعل بصف موظف مختلف هنا (مثلًا تم ربطه تلقائيًا عند تعيين دور الموظف)، فسيتم نقله إلى هذا الصف بدلًا من ذلك.';

  @override
  String get staffLinkButton => 'ربط';

  @override
  String get staffLoginLinked => 'تم ربط تسجيل الدخول.';

  @override
  String staffLinkFailed(String error) {
    return 'تعذر ربط تسجيل الدخول: $error';
  }

  @override
  String get staffAssignRoleTitle => 'تعيين دور في النشاط التجاري';

  @override
  String get staffExistingAccountEmailLabel => 'البريد الإلكتروني لحساب موجود';

  @override
  String get staffRoleLabel => 'الدور';

  @override
  String get staffRoleManager => 'مدير';

  @override
  String get staffRoleReceptionist => 'موظف استقبال';

  @override
  String get staffRoleStaff => 'موظف';

  @override
  String get staffAssignButton => 'تعيين';

  @override
  String get staffRoleAssigned => 'تم تعيين الدور.';

  @override
  String staffAssignRoleFailed(String error) {
    return 'تعذر تعيين الدور: $error';
  }

  @override
  String get staffLinkLoginTooltip => 'ربط تسجيل الدخول';

  @override
  String get staffChangeLoginTooltip => 'تغيير تسجيل الدخول المرتبط';

  @override
  String get staffScheduleTooltip => 'الجدول';

  @override
  String staffNoLoginLinked(String status) {
    return '$status · لا يوجد تسجيل دخول مرتبط';
  }

  @override
  String scheduleTitle(String name) {
    return 'الجدول • $name';
  }

  @override
  String get scheduleWorkingHoursTab => 'ساعات العمل';

  @override
  String get scheduleBreaksTab => 'الاستراحات';

  @override
  String get scheduleBlockedTimeTab => 'الوقت المحظور';

  @override
  String get scheduleOff => 'إجازة';

  @override
  String get scheduleNoBreak => 'بلا استراحة';

  @override
  String get scheduleNoBlockedTime => 'لا يوجد وقت محظور مجدول.';

  @override
  String scheduleWorkingHoursDialogTitle(String weekday) {
    return 'ساعات العمل • $weekday';
  }

  @override
  String scheduleBreakDialogTitle(String weekday) {
    return 'استراحة • $weekday';
  }

  @override
  String scheduleStartLabel(String time) {
    return 'البداية: $time';
  }

  @override
  String scheduleEndLabel(String time) {
    return 'النهاية: $time';
  }

  @override
  String get scheduleRemove => 'إزالة';

  @override
  String get scheduleStartBeforeEnd =>
      'يجب أن يكون وقت البداية قبل وقت النهاية.';

  @override
  String scheduleSaveWorkingHoursFailed(String error) {
    return 'تعذر حفظ ساعات العمل: $error';
  }

  @override
  String scheduleSaveBreakFailed(String error) {
    return 'تعذر حفظ الاستراحة: $error';
  }

  @override
  String scheduleRemoveBlockedTimeFailed(String error) {
    return 'تعذرت إزالة الوقت المحظور: $error';
  }

  @override
  String blockedTimeDateLabel(String date) {
    return 'التاريخ: $date';
  }

  @override
  String blockedTimeStartLabel(String time) {
    return 'البداية: $time';
  }

  @override
  String blockedTimeEndLabel(String time) {
    return 'النهاية: $time';
  }

  @override
  String get blockedTimeReasonLabel => 'السبب (اختياري)';

  @override
  String get blockedTimeStartBeforeEnd =>
      'يجب أن يكون وقت البداية قبل وقت النهاية.';

  @override
  String blockedTimeAddFailed(String error) {
    return 'تعذرت إضافة الوقت المحظور: $error';
  }

  @override
  String get crmSegmentAll => 'الكل';

  @override
  String get crmSegmentVip => 'كبار العملاء';

  @override
  String get crmSegmentInactive => 'غير نشط منذ 30 يومًا';

  @override
  String get crmSegmentNoShow => 'خطر عدم الحضور';

  @override
  String get crmSegmentFirstVisit => 'الزيارة الأولى';

  @override
  String get crmSegmentBirthday => 'عيد ميلاده هذا الشهر';

  @override
  String crmCustomerCount(int count) {
    return '$count عميل';
  }

  @override
  String get crmCampaignsHeading => 'الحملات';

  @override
  String crmCreateCampaignTitle(String segment) {
    return 'إنشاء حملة • فئة $segment';
  }

  @override
  String get crmCampaignNameLabel => 'اسم الحملة';

  @override
  String get crmMessageLabel => 'الرسالة';

  @override
  String get crmChannelLabel => 'القناة';

  @override
  String get crmChannelPush => 'إشعار فوري';

  @override
  String get crmChannelEmail => 'بريد إلكتروني';

  @override
  String get crmChannelSms => 'رسالة نصية';

  @override
  String get crmChannelNoProviderWarning =>
      'يحتاج التسليم عبر البريد الإلكتروني أو الرسائل النصية إلى مزوّد غير مُعد في هذه البيئة؛ سيتم تسجيل الحملة وإنشاء جمهورها، لكن لن يتم تسليمها فعليًا.';

  @override
  String get crmSaveDraft => 'حفظ كمسودة';

  @override
  String get crmCampaignSavedDraft => 'تم حفظ الحملة كمسودة.';

  @override
  String crmCampaignSentPush(String count) {
    return 'تم إرسال الحملة إلى $count مستلم.';
  }

  @override
  String crmCampaignSentNoProvider(String count, String channel) {
    return 'تم إنشاء $count مستلم، لكن $channel ليس له مزوّد تسليم مُعد — لم يتم إرسال شيء فعليًا.';
  }

  @override
  String crmCampaignSendFailed(String error) {
    return 'تعذر إرسال الحملة: $error';
  }

  @override
  String get crmUndeliverableTooltip =>
      'تم إنشاء المستلمين، لكن هذه القناة ليس لها مزوّد تسليم مُعد — لم يتم إرسال شيء فعليًا.';

  @override
  String get crmSend => 'إرسال';

  @override
  String crmPointsAbbrev(int points) {
    return '$points نقطة';
  }

  @override
  String get customerDetailRedeemPointsTitle => 'استبدال النقاط';

  @override
  String customerDetailPointsBalanceLabel(int points) {
    return 'النقاط (الرصيد: $points)';
  }

  @override
  String get customerDetailRedeem => 'استبدال';

  @override
  String customerDetailRedeemPointsFailed(String error) {
    return 'تعذر استبدال النقاط: $error';
  }

  @override
  String get customerDetailUseOneVisitTitle => 'استخدام زيارة واحدة';

  @override
  String customerDetailUseOneVisitBody(String name, String count) {
    return 'استخدام زيارة واحدة من \"$name\"؟ المتبقي $count.';
  }

  @override
  String get customerDetailUse => 'استخدام';

  @override
  String customerDetailUsePackageFailed(String error) {
    return 'تعذر استخدام زيارة الباقة: $error';
  }

  @override
  String get customerDetailSellPackageTitle => 'بيع باقة';

  @override
  String get customerDetailPackageLabel => 'الباقة';

  @override
  String get customerDetailSell => 'بيع';

  @override
  String customerDetailSellPackageFailed(String error) {
    return 'تعذر بيع الباقة: $error';
  }

  @override
  String get customerDetailSellMembershipTitle => 'بيع عضوية';

  @override
  String get customerDetailMembershipLabel => 'العضوية';

  @override
  String customerDetailSellMembershipFailed(String error) {
    return 'تعذر بيع العضوية: $error';
  }

  @override
  String get customerDetailCancelMembershipTitle => 'إلغاء العضوية؟';

  @override
  String customerDetailCancelMembershipBody(String name) {
    return 'إلغاء \"$name\"؟ سيفقد العميل خصمها فورًا.';
  }

  @override
  String get customerDetailBack => 'رجوع';

  @override
  String get customerDetailCancelMembershipButton => 'إلغاء العضوية';

  @override
  String customerDetailCancelMembershipFailed(String error) {
    return 'تعذر إلغاء العضوية: $error';
  }

  @override
  String customerDetailRenewTitle(String name) {
    return 'تجديد $name';
  }

  @override
  String customerDetailPriceLabel(String price) {
    return 'السعر: $price';
  }

  @override
  String get customerDetailRenew => 'تجديد';

  @override
  String customerDetailRenewMembershipFailed(String error) {
    return 'تعذر تجديد العضوية: $error';
  }

  @override
  String customerDetailCouponRedeemed(String discount) {
    return 'تم استبدال الكوبون: $discount';
  }

  @override
  String customerDetailCouponOff(String percent) {
    return 'خصم $percent%';
  }

  @override
  String customerDetailCouponAmountOff(String amount) {
    return 'خصم $amount';
  }

  @override
  String get customerDetailCouponApplied => 'تم التطبيق';

  @override
  String customerDetailRedeemCouponFailed(String error) {
    return 'تعذر استبدال الكوبون: $error';
  }

  @override
  String customerDetailSaveNotesFailed(String error) {
    return 'تعذر حفظ الملاحظات: $error';
  }

  @override
  String get customerDetailNotesConflict =>
      'تم تغيير هذه الملاحظات في مكان آخر — احلّ التعارض من شريط المزامنة.';

  @override
  String get customerDetailNotesOfflinePending =>
      'غير متصل — ستتم مزامنة الملاحظات عند عودة الاتصال.';

  @override
  String get customerDetailNotesSaved => 'تم حفظ الملاحظات.';

  @override
  String get customerDetailTotalSpent => 'إجمالي الإنفاق';

  @override
  String get customerDetailLastVisit => 'آخر زيارة';

  @override
  String get customerDetailNever => 'أبدًا';

  @override
  String get customerDetailLoyaltyPointsLabel => 'نقاط الولاء';

  @override
  String get customerDetailSaveNotesButton => 'حفظ الملاحظات';

  @override
  String get customerDetailLoyaltyHeading => 'الولاء';

  @override
  String get customerDetailRedeemPointsButton => 'استبدال النقاط';

  @override
  String get customerDetailPackagesHeading => 'الباقات';

  @override
  String get customerDetailSellPackageButton => 'بيع باقة';

  @override
  String get customerDetailNoPackages => 'لا توجد باقات مملوكة.';

  @override
  String get customerDetailMembershipsHeading => 'العضويات';

  @override
  String get customerDetailSellMembershipButton => 'بيع عضوية';

  @override
  String get customerDetailNoMemberships => 'لا توجد عضويات مملوكة.';

  @override
  String get customerDetailUseOne => 'استخدام 1';

  @override
  String get customerDetailCouponHeading => 'الكوبون';

  @override
  String get customerDetailCouponCodeHint => 'رمز الكوبون';

  @override
  String get customerDetailFallbackPackageName => 'باقة';

  @override
  String get customerDetailFallbackMembershipName => 'عضوية';

  @override
  String customerDetailPackageUsesLeftStatus(String count, String status) {
    return '$count استخدام متبقٍ • $status';
  }

  @override
  String customerDetailExpiresOn(String date) {
    return 'تنتهي في $date';
  }

  @override
  String customerDetailMembershipStatusUntil(String status, String date) {
    return '$status • حتى $date';
  }

  @override
  String get offersTabPackages => 'الباقات';

  @override
  String get offersTabMemberships => 'العضويات';

  @override
  String get offersTabCoupons => 'الكوبونات';

  @override
  String get offersNewPackageTitle => 'باقة جديدة';

  @override
  String get offersEditPackageTitle => 'تعديل الباقة';

  @override
  String get offersServiceLabel => 'الخدمة';

  @override
  String get offersPriceMinorLabel => 'السعر (بالوحدات الصغرى)';

  @override
  String get offersTotalUsesLabel => 'إجمالي مرات الاستخدام';

  @override
  String get offersExpiresAfterLabel => 'تنتهي بعد (أيام، اختياري)';

  @override
  String offersSavePackageFailed(String error) {
    return 'تعذر حفظ الباقة: $error';
  }

  @override
  String offersUpdatePackageFailed(String error) {
    return 'تعذر تحديث الباقة: $error';
  }

  @override
  String get offersNoPackagesYet => 'لا توجد باقات بعد.';

  @override
  String get offersAnyService => 'أي خدمة';

  @override
  String offersUsesCount(int count) {
    return '$count استخدام';
  }

  @override
  String offersExpiresInDays(int days) {
    return 'تنتهي خلال $days يوم';
  }

  @override
  String offersDiscountOffDuration(String percent, int days) {
    return 'خصم $percent% • $days يوم';
  }

  @override
  String offersUsedCountLimited(int count, int limit) {
    return 'استُخدم $count/$limit';
  }

  @override
  String offersUsedCountUnlimited(int count) {
    return 'استُخدم $count مرة';
  }

  @override
  String get offersDeactivate => 'تعطيل';

  @override
  String get offersReactivate => 'إعادة التفعيل';

  @override
  String get offersNewMembershipTitle => 'عضوية جديدة';

  @override
  String get offersEditMembershipTitle => 'تعديل العضوية';

  @override
  String get offersDiscountPercentLabel => 'نسبة الخصم';

  @override
  String get offersDurationDaysLabel => 'المدة (أيام)';

  @override
  String offersSaveMembershipFailed(String error) {
    return 'تعذر حفظ العضوية: $error';
  }

  @override
  String offersUpdateMembershipFailed(String error) {
    return 'تعذر تحديث العضوية: $error';
  }

  @override
  String get offersNoMembershipsYet => 'لا توجد عضويات بعد.';

  @override
  String get offersNewCouponTitle => 'كوبون جديد';

  @override
  String get offersEditCouponTitle => 'تعديل الكوبون';

  @override
  String get offersCodeLabel => 'الرمز';

  @override
  String get offersUsageLimitLabel => 'حد الاستخدام (اختياري)';

  @override
  String offersSaveCouponFailed(String error) {
    return 'تعذر حفظ الكوبون: $error';
  }

  @override
  String offersUpdateCouponFailed(String error) {
    return 'تعذر تحديث الكوبون: $error';
  }

  @override
  String get offersNoCouponsYet => 'لا توجد كوبونات بعد.';

  @override
  String get paymentsRecordTitle => 'تسجيل دفعة';

  @override
  String get paymentsAppointmentLabel => 'الموعد';

  @override
  String get paymentsAmountMinorLabel => 'المبلغ (بالوحدات الصغرى)';

  @override
  String get paymentsTypeLabel => 'النوع';

  @override
  String get paymentsCouponOptionalLabel => 'رمز الكوبون (اختياري)';

  @override
  String paymentsApplyMembershipDiscount(String percent) {
    return 'تطبيق خصم العضوية النشطة (خصم $percent%)';
  }

  @override
  String get paymentsChooseApptAndAmount => 'اختر موعدًا ومبلغًا صحيحًا.';

  @override
  String get paymentsDiscountedAmountZero =>
      'يجب أن يكون المبلغ بعد الخصم أكبر من صفر.';

  @override
  String get paymentsPrintReceiptTooltip => 'طباعة / مشاركة الإيصال';

  @override
  String get reportsExportPdfTooltip => 'تصدير PDF';

  @override
  String get reportsThisWeek => 'هذا الأسبوع';

  @override
  String get reportsThisMonth => 'هذا الشهر';

  @override
  String get reportsOccupancyVolumeHeading => 'الإشغال والحجم';

  @override
  String get reportsOccupancy => 'الإشغال';

  @override
  String get reportsAppointments => 'المواعيد';

  @override
  String get reportsCompleted => 'مكتمل';

  @override
  String get reportsCancelled => 'ملغى';

  @override
  String get reportsNoShows => 'عدم الحضور';

  @override
  String get reportsRevenue => 'الإيرادات';

  @override
  String get reportsCustomersHeading => 'العملاء';

  @override
  String get reportsNewCustomers => 'عملاء جدد';

  @override
  String get reportsRepeatCustomers => 'عملاء متكررون';

  @override
  String get reportsAverageSpend => 'متوسط الإنفاق';

  @override
  String get reportsCampaignsHeading => 'الحملات';

  @override
  String get reportsCampaignsSent => 'الحملات المرسلة';

  @override
  String get reportsRecipients => 'المستلمون';

  @override
  String get reportsOpened => 'تم الفتح';

  @override
  String get reportsBooked => 'تم الحجز';

  @override
  String get reportsStaffPerformanceHeading => 'أداء الموظفين';

  @override
  String get reportsNoStaffYet => 'لا يوجد موظفون بعد.';

  @override
  String get reportsLoadMore => 'تحميل المزيد';

  @override
  String reportsStaffCompletedNoShows(int completed, int noShow) {
    return '$completed مكتمل • $noShow عدم حضور';
  }

  @override
  String get queueAddWalkInDialogTitle => 'إضافة عميل بدون حجز';

  @override
  String get queueCustomerLabel => 'العميل';

  @override
  String get queueServiceLabel => 'الخدمة';

  @override
  String get queueStaffOptionalLabel => 'الموظف (اختياري)';

  @override
  String get queueAnyStaff => 'أي موظف';

  @override
  String queueWalkInAdded(String reference) {
    return 'تمت إضافة العميل • $reference';
  }

  @override
  String queueAddWalkInFailed(String error) {
    return 'تعذرت إضافة العميل: $error';
  }

  @override
  String get queueCall => 'نداء';

  @override
  String get queueStart => 'بدء';

  @override
  String calendarWeekOf(String date) {
    return 'أسبوع $date';
  }

  @override
  String get calendarWeekView => 'عرض الأسبوع';

  @override
  String get calendarNoAppointments => 'لا توجد مواعيد لهذه الفترة.';

  @override
  String calendarStatusUpdateFailed(String error) {
    return 'فشل تحديث الحالة: $error';
  }

  @override
  String calendarCancellationFailed(String error) {
    return 'فشل الإلغاء: $error';
  }

  @override
  String calendarRescheduleFailed(String error) {
    return 'فشلت إعادة الجدولة: $error';
  }

  @override
  String calendarDepositDue(String amount) {
    return 'عربون مستحق $amount';
  }

  @override
  String dashboardGreetingDate(String date) {
    return 'اليوم • $date';
  }

  @override
  String get dashboardCardAppointments => 'المواعيد';

  @override
  String get dashboardCardCompleted => 'مكتمل';

  @override
  String get dashboardCardNoShows => 'عدم الحضور';

  @override
  String get dashboardCardRevenue => 'الإيرادات';

  @override
  String get dashboardHint =>
      'استخدم التقويم لعمليات اليوم/الأسبوع، وقائمة الانتظار للعملاء بدون حجز، وإدارة العملاء للولاء والباقات والحملات.';
}
