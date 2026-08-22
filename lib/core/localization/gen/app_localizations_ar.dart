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
}
