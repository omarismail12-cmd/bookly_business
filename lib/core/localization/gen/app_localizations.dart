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
/// import 'gen/app_localizations.dart';
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

  /// Application title shown in the app switcher and browser tab.
  ///
  /// In en, this message translates to:
  /// **'Bookly Business'**
  String get appTitle;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get navQueue;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navCustomers;

  /// No description provided for @navServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get navServices;

  /// No description provided for @navStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get navStaff;

  /// No description provided for @navPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get navPayments;

  /// No description provided for @navCrm.
  ///
  /// In en, this message translates to:
  /// **'CRM'**
  String get navCrm;

  /// No description provided for @navOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get navOffers;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navLocations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get navLocations;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @loginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSubmit;

  /// No description provided for @loginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Create one'**
  String get loginNoAccount;

  /// No description provided for @signupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signupTitle;

  /// No description provided for @signupFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get signupFullName;

  /// No description provided for @signupConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get signupConfirmPassword;

  /// No description provided for @signupSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signupSubmit;

  /// No description provided for @signupHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get signupHaveAccount;

  /// No description provided for @bookingTitleNew.
  ///
  /// In en, this message translates to:
  /// **'New Booking'**
  String get bookingTitleNew;

  /// No description provided for @bookingTitlePublic.
  ///
  /// In en, this message translates to:
  /// **'Book an appointment'**
  String get bookingTitlePublic;

  /// No description provided for @bookingChooseServiceStaffTime.
  ///
  /// In en, this message translates to:
  /// **'Choose a service, staff member and available time.'**
  String get bookingChooseServiceStaffTime;

  /// No description provided for @bookingService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get bookingService;

  /// No description provided for @bookingStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get bookingStaff;

  /// No description provided for @bookingCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get bookingCustomer;

  /// No description provided for @bookingLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get bookingLocation;

  /// No description provided for @bookingDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get bookingDate;

  /// No description provided for @bookingFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get bookingFullName;

  /// No description provided for @bookingEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get bookingEmail;

  /// No description provided for @bookingPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get bookingPhone;

  /// No description provided for @bookingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmed. Reference: {reference}'**
  String bookingConfirmed(String reference);

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get commonLogout;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get commonNoResults;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get commonPrevious;

  /// No description provided for @validationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get validationEmailRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get validationEmailInvalid;

  /// No description provided for @validationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get validationPasswordRequired;

  /// No description provided for @validationPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get validationPasswordTooShort;

  /// No description provided for @validationConfirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get validationConfirmPasswordRequired;

  /// No description provided for @validationPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get validationPasswordMismatch;

  /// No description provided for @validationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get validationNameRequired;

  /// No description provided for @validationNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get validationNameTooShort;

  /// No description provided for @pageTitlePayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get pageTitlePayments;

  /// No description provided for @pageTitleStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff & Schedules'**
  String get pageTitleStaff;

  /// No description provided for @pageTitleQueue.
  ///
  /// In en, this message translates to:
  /// **'Walk-in Queue'**
  String get pageTitleQueue;

  /// No description provided for @pageTitleServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get pageTitleServices;

  /// No description provided for @pageTitleCrm.
  ///
  /// In en, this message translates to:
  /// **'CRM • Loyalty • Campaigns'**
  String get pageTitleCrm;

  /// No description provided for @pageTitleReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get pageTitleReports;

  /// No description provided for @pageTitleOffers.
  ///
  /// In en, this message translates to:
  /// **'Packages, Memberships & Coupons'**
  String get pageTitleOffers;

  /// No description provided for @pageTitleCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get pageTitleCustomers;

  /// No description provided for @pageTitleLocations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get pageTitleLocations;

  /// No description provided for @staffPortalTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get staffPortalTitle;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No customers are waiting.'**
  String get queueEmpty;

  /// No description provided for @queueAddWalkIn.
  ///
  /// In en, this message translates to:
  /// **'Walk-in'**
  String get queueAddWalkIn;

  /// No description provided for @paymentsAddPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentsAddPayment;

  /// No description provided for @staffAddStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staffAddStaff;

  /// No description provided for @servicesAddService.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get servicesAddService;

  /// No description provided for @crmAddCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get crmAddCustomer;

  /// No description provided for @crmCreateCampaign.
  ///
  /// In en, this message translates to:
  /// **'Campaign'**
  String get crmCreateCampaign;

  /// No description provided for @locationsAddLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationsAddLocation;

  /// No description provided for @locationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No locations yet.'**
  String get locationsEmpty;

  /// No description provided for @staffPortalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No appointments today.'**
  String get staffPortalEmpty;

  /// No description provided for @customerPortalWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get customerPortalWelcome;

  /// No description provided for @customerPortalTagline.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your bookings.'**
  String get customerPortalTagline;

  /// No description provided for @customerPortalSignupTagline.
  ///
  /// In en, this message translates to:
  /// **'Book appointments and track your loyalty rewards.'**
  String get customerPortalSignupTagline;

  /// No description provided for @navMyAppointments.
  ///
  /// In en, this message translates to:
  /// **'My Appointments'**
  String get navMyAppointments;

  /// No description provided for @navFindBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get navFindBook;

  /// No description provided for @navLoyalty.
  ///
  /// In en, this message translates to:
  /// **'Loyalty'**
  String get navLoyalty;

  /// No description provided for @navMyOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get navMyOffers;

  /// No description provided for @findBusinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Book with a business'**
  String get findBusinessTitle;

  /// No description provided for @findBusinessHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the business code your business gave you'**
  String get findBusinessHint;

  /// No description provided for @findBusinessGo.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get findBusinessGo;

  /// No description provided for @findBusinessNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a business with that code.'**
  String get findBusinessNotFound;

  /// No description provided for @myAppointmentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any appointments yet.'**
  String get myAppointmentsEmpty;

  /// No description provided for @loyaltyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No loyalty rewards yet — book your first visit!'**
  String get loyaltyEmpty;

  /// No description provided for @loyaltyPoints.
  ///
  /// In en, this message translates to:
  /// **'{points} points'**
  String loyaltyPoints(String points);

  /// No description provided for @offersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No offers right now — check back after your next visit!'**
  String get offersEmpty;

  /// No description provided for @offersForYou.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get offersForYou;

  /// No description provided for @offersActiveCoupons.
  ///
  /// In en, this message translates to:
  /// **'Active coupons'**
  String get offersActiveCoupons;
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
