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

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get commonPhone;

  /// No description provided for @commonAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get commonAddress;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String commonPage(int page);

  /// No description provided for @commonLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get commonLoadMore;

  /// No description provided for @commonCustomerFallback.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get commonCustomerFallback;

  /// No description provided for @commonSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get commonSignOut;

  /// No description provided for @commonConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"? This cannot be undone.'**
  String commonConfirmDelete(String name);

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

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get statusCheckedIn;

  /// No description provided for @statusInService.
  ///
  /// In en, this message translates to:
  /// **'In service'**
  String get statusInService;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get statusNoShow;

  /// No description provided for @statusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get statusWaiting;

  /// No description provided for @statusCalled.
  ///
  /// In en, this message translates to:
  /// **'Called'**
  String get statusCalled;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get statusInactive;

  /// No description provided for @statusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraft;

  /// No description provided for @statusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get statusSent;

  /// No description provided for @statusUndeliverable.
  ///
  /// In en, this message translates to:
  /// **'Undeliverable'**
  String get statusUndeliverable;

  /// No description provided for @statusReversed.
  ///
  /// In en, this message translates to:
  /// **'Reversed'**
  String get statusReversed;

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @statusUsedUp.
  ///
  /// In en, this message translates to:
  /// **'Used up'**
  String get statusUsedUp;

  /// No description provided for @paymentMethodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get paymentMethodOther;

  /// No description provided for @paymentTypeRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get paymentTypeRefund;

  /// No description provided for @paymentTypeForfeit.
  ///
  /// In en, this message translates to:
  /// **'Forfeit'**
  String get paymentTypeForfeit;

  /// No description provided for @paymentTypeAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get paymentTypeAdjustment;

  /// No description provided for @apptCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get apptCheckIn;

  /// No description provided for @apptStartService.
  ///
  /// In en, this message translates to:
  /// **'Start service'**
  String get apptStartService;

  /// No description provided for @apptComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get apptComplete;

  /// No description provided for @apptNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get apptNoShow;

  /// No description provided for @apptReschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get apptReschedule;

  /// No description provided for @apptTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get apptTitleFallback;

  /// No description provided for @paymentMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethodCash;

  /// No description provided for @paymentMethodCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentMethodCard;

  /// No description provided for @paymentMethodTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get paymentMethodTransfer;

  /// No description provided for @paymentMethodOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get paymentMethodOnline;

  /// No description provided for @paymentTypePayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentTypePayment;

  /// No description provided for @paymentTypeDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get paymentTypeDeposit;

  /// No description provided for @paymentMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethodLabel;

  /// No description provided for @routerPageNotFound.
  ///
  /// In en, this message translates to:
  /// **'This page could not be found.'**
  String get routerPageNotFound;

  /// No description provided for @routerGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get routerGoHome;

  /// No description provided for @languageSwitcherTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSwitcherTitle;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @themeSwitcherTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSwitcherTitle;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @syncConflictsNeedReview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} change needs your review.} other{{count} changes need your review.}}'**
  String syncConflictsNeedReview(int count);

  /// No description provided for @syncChangesFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} change could not be synced.} other{{count} changes could not be synced.}}'**
  String syncChangesFailed(int count);

  /// No description provided for @syncOfflinePendingChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Offline — {count} change will sync when you\'re back online.} other{Offline — {count} changes will sync when you\'re back online.}}'**
  String syncOfflinePendingChanges(int count);

  /// No description provided for @syncOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline.'**
  String get syncOffline;

  /// No description provided for @syncChangesSyncing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} change syncing…} other{{count} changes syncing…}}'**
  String syncChangesSyncing(int count);

  /// No description provided for @syncResolveConflictsTitle.
  ///
  /// In en, this message translates to:
  /// **'Resolve conflicts'**
  String get syncResolveConflictsTitle;

  /// No description provided for @syncNothingToResolve.
  ///
  /// In en, this message translates to:
  /// **'Nothing left to resolve.'**
  String get syncNothingToResolve;

  /// No description provided for @syncResolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get syncResolve;

  /// No description provided for @syncRetryNow.
  ///
  /// In en, this message translates to:
  /// **'Retry now'**
  String get syncRetryNow;

  /// No description provided for @syncConflictChangedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'{entity} — this was changed elsewhere'**
  String syncConflictChangedElsewhere(String entity);

  /// No description provided for @syncYourEdit.
  ///
  /// In en, this message translates to:
  /// **'Your edit: {value}'**
  String syncYourEdit(String value);

  /// No description provided for @syncCurrentValue.
  ///
  /// In en, this message translates to:
  /// **'Current value: {value}'**
  String syncCurrentValue(String value);

  /// No description provided for @syncKeepTheirs.
  ///
  /// In en, this message translates to:
  /// **'Keep theirs'**
  String get syncKeepTheirs;

  /// No description provided for @syncKeepMine.
  ///
  /// In en, this message translates to:
  /// **'Keep mine'**
  String get syncKeepMine;

  /// No description provided for @staffTodayStatusUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Status update failed: {error}'**
  String staffTodayStatusUpdateFailed(String error);

  /// No description provided for @blockedTimeAdd.
  ///
  /// In en, this message translates to:
  /// **'Add blocked time'**
  String get blockedTimeAdd;

  /// No description provided for @staffTimeOffAdded.
  ///
  /// In en, this message translates to:
  /// **'Time off added.'**
  String get staffTimeOffAdded;

  /// No description provided for @staffTodayNoProfile.
  ///
  /// In en, this message translates to:
  /// **'No staff profile is linked to your account yet. Ask your manager to assign you as staff.'**
  String get staffTodayNoProfile;

  /// No description provided for @privateNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Private notes'**
  String get privateNotesLabel;

  /// No description provided for @privateNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Preferences, allergies, reminders…'**
  String get privateNotesHint;

  /// No description provided for @nextRecommendationLabel.
  ///
  /// In en, this message translates to:
  /// **'Next recommendation'**
  String get nextRecommendationLabel;

  /// No description provided for @nextRecommendationHint.
  ///
  /// In en, this message translates to:
  /// **'What to suggest at the next visit…'**
  String get nextRecommendationHint;

  /// No description provided for @staffAppointmentConflictMessage.
  ///
  /// In en, this message translates to:
  /// **'This customer was changed elsewhere — resolve the conflict from the sync banner.'**
  String get staffAppointmentConflictMessage;

  /// No description provided for @staffAppointmentOfflinePending.
  ///
  /// In en, this message translates to:
  /// **'Offline — will sync when you\'re back online.'**
  String get staffAppointmentOfflinePending;

  /// No description provided for @staffAppointmentNotesSaved.
  ///
  /// In en, this message translates to:
  /// **'Notes saved.'**
  String get staffAppointmentNotesSaved;

  /// No description provided for @staffAppointmentSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String staffAppointmentSaveFailed(String error);

  /// No description provided for @orgSetupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Business name is required.'**
  String get orgSetupNameRequired;

  /// No description provided for @orgSetupSlugInvalid.
  ///
  /// In en, this message translates to:
  /// **'Slug must use 3-40 lowercase letters, numbers or hyphens.'**
  String get orgSetupSlugInvalid;

  /// No description provided for @orgSetupPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your business'**
  String get orgSetupPageTitle;

  /// No description provided for @orgSetupHeading.
  ///
  /// In en, this message translates to:
  /// **'Create your business'**
  String get orgSetupHeading;

  /// No description provided for @orgSetupBusinessNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get orgSetupBusinessNameLabel;

  /// No description provided for @orgSetupSlugLabel.
  ///
  /// In en, this message translates to:
  /// **'Slug'**
  String get orgSetupSlugLabel;

  /// No description provided for @orgSetupTimezoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get orgSetupTimezoneLabel;

  /// No description provided for @orgSetupCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create business'**
  String get orgSetupCreateButton;

  /// No description provided for @orgSetupCreateDemoButton.
  ///
  /// In en, this message translates to:
  /// **'Create demo business + test data'**
  String get orgSetupCreateDemoButton;

  /// No description provided for @orgSetupWaitingForInvite.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be added to an existing team instead? Ask the owner to assign you a role, then sign out above and sign back in.'**
  String get orgSetupWaitingForInvite;

  /// No description provided for @orgSuspendedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your Bookly business membership is suspended. Contact the business owner before creating or accessing another workspace.'**
  String get orgSuspendedMessage;

  /// No description provided for @orgSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Business settings'**
  String get orgSettingsTitle;

  /// No description provided for @authIncorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get authIncorrectCredentials;

  /// No description provided for @authLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String authLoginFailed(String error);

  /// No description provided for @authLoginFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Login failed.'**
  String get authLoginFailedGeneric;

  /// No description provided for @authLoginSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Login successful!'**
  String get authLoginSuccessful;

  /// No description provided for @authEmailConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email before logging in.'**
  String get authEmailConfirmRequired;

  /// No description provided for @loginWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Bookly'**
  String get loginWelcomeTitle;

  /// No description provided for @loginTagline.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your business.'**
  String get loginTagline;

  /// No description provided for @authAccountCreatedConfirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Account created. Check your email to confirm your account.'**
  String get authAccountCreatedConfirmEmail;

  /// No description provided for @authAccountCreatedConfirmEmailShort.
  ///
  /// In en, this message translates to:
  /// **'Account created. Check your email to confirm it.'**
  String get authAccountCreatedConfirmEmailShort;

  /// No description provided for @authCheckEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get authCheckEmailTitle;

  /// No description provided for @authCheckEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We created the account for {email}. Supabase has sent the confirmation email. Confirm it before signing in.'**
  String authCheckEmailBody(String email);

  /// No description provided for @authAccountCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully!'**
  String get authAccountCreatedSuccess;

  /// No description provided for @authEmailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Please sign in instead.'**
  String get authEmailAlreadyRegistered;

  /// No description provided for @authEmailInvalidGeneric.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get authEmailInvalidGeneric;

  /// No description provided for @authPasswordRequirementsNotMet.
  ///
  /// In en, this message translates to:
  /// **'Password does not meet the requirements.'**
  String get authPasswordRequirementsNotMet;

  /// No description provided for @authSignupFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed: {error}'**
  String authSignupFailed(String error);

  /// No description provided for @authNoUserReturned.
  ///
  /// In en, this message translates to:
  /// **'Supabase did not return a user.'**
  String get authNoUserReturned;

  /// No description provided for @signupWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your Bookly account'**
  String get signupWelcomeTitle;

  /// No description provided for @signupTagline.
  ///
  /// In en, this message translates to:
  /// **'Manage your business with Bookly.'**
  String get signupTagline;

  /// No description provided for @myApptStatusLine.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String myApptStatusLine(String status);

  /// No description provided for @myApptStaffLine.
  ///
  /// In en, this message translates to:
  /// **'Staff: {staff}'**
  String myApptStaffLine(String staff);

  /// No description provided for @myApptServicesLine.
  ///
  /// In en, this message translates to:
  /// **'Services: {services}'**
  String myApptServicesLine(String services);

  /// No description provided for @myApptDepositLine.
  ///
  /// In en, this message translates to:
  /// **'Deposit: {paid} of {required} paid'**
  String myApptDepositLine(String paid, String required);

  /// No description provided for @loyaltyUntilDate.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String loyaltyUntilDate(String date);

  /// No description provided for @loyaltyUsesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} uses left'**
  String loyaltyUsesLeft(String count);

  /// No description provided for @customersAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get customersAddDialogTitle;

  /// No description provided for @customersSubtitleNoShows.
  ///
  /// In en, this message translates to:
  /// **'no-shows {count}'**
  String customersSubtitleNoShows(int count);

  /// No description provided for @customersWaitingToSync.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get customersWaitingToSync;

  /// No description provided for @locationsNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New location'**
  String get locationsNewTitle;

  /// No description provided for @locationsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit location'**
  String get locationsEditTitle;

  /// No description provided for @locationsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save location: {error}'**
  String locationsSaveFailed(String error);

  /// No description provided for @locationsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete location?'**
  String get locationsDeleteTitle;

  /// No description provided for @locationsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete location: {error}'**
  String locationsDeleteFailed(String error);

  /// No description provided for @servicesAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add service'**
  String get servicesAddTitle;

  /// No description provided for @servicesDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration (min)'**
  String get servicesDurationLabel;

  /// No description provided for @servicesBufferLabel.
  ///
  /// In en, this message translates to:
  /// **'Buffer (min)'**
  String get servicesBufferLabel;

  /// No description provided for @servicesPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price minor units'**
  String get servicesPriceLabel;

  /// No description provided for @servicesDepositLabel.
  ///
  /// In en, this message translates to:
  /// **'Deposit required (minor units, 0 = none)'**
  String get servicesDepositLabel;

  /// No description provided for @servicesNumbersRequired.
  ///
  /// In en, this message translates to:
  /// **'Duration, buffer and price must be whole numbers.'**
  String get servicesNumbersRequired;

  /// No description provided for @servicesEditDescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit description • {name}'**
  String servicesEditDescriptionTitle(String name);

  /// No description provided for @servicesDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get servicesDescriptionLabel;

  /// No description provided for @servicesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete service?'**
  String get servicesDeleteTitle;

  /// No description provided for @servicesDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete service: {error}'**
  String servicesDeleteFailed(String error);

  /// No description provided for @servicesEditDescriptionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit description'**
  String get servicesEditDescriptionTooltip;

  /// No description provided for @staffAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add staff'**
  String get staffAddTitle;

  /// No description provided for @staffDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get staffDisplayNameLabel;

  /// No description provided for @staffAssignRoleButton.
  ///
  /// In en, this message translates to:
  /// **'Assign role'**
  String get staffAssignRoleButton;

  /// No description provided for @staffLinkLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Link login for {name}'**
  String staffLinkLoginTitle(String name);

  /// No description provided for @staffAlreadyLinkedWarning.
  ///
  /// In en, this message translates to:
  /// **'This staff member is already linked to a login. Linking a new email will replace it.'**
  String get staffAlreadyLinkedWarning;

  /// No description provided for @staffAccountEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Account email (must already have the Staff role)'**
  String get staffAccountEmailLabel;

  /// No description provided for @staffLinkMoveWarning.
  ///
  /// In en, this message translates to:
  /// **'If that account is already linked to a different staff row here (e.g. auto-linked when the Staff role was assigned), it will be moved to this one instead.'**
  String get staffLinkMoveWarning;

  /// No description provided for @staffLinkButton.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get staffLinkButton;

  /// No description provided for @staffLoginLinked.
  ///
  /// In en, this message translates to:
  /// **'Login linked.'**
  String get staffLoginLinked;

  /// No description provided for @staffLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not link login: {error}'**
  String staffLinkFailed(String error);

  /// No description provided for @staffAssignRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign business role'**
  String get staffAssignRoleTitle;

  /// No description provided for @staffExistingAccountEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Existing account email'**
  String get staffExistingAccountEmailLabel;

  /// No description provided for @staffRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get staffRoleLabel;

  /// No description provided for @staffRoleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get staffRoleManager;

  /// No description provided for @staffRoleReceptionist.
  ///
  /// In en, this message translates to:
  /// **'Receptionist'**
  String get staffRoleReceptionist;

  /// No description provided for @staffRoleStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staffRoleStaff;

  /// No description provided for @staffAssignButton.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get staffAssignButton;

  /// No description provided for @staffRoleAssigned.
  ///
  /// In en, this message translates to:
  /// **'Role assigned.'**
  String get staffRoleAssigned;

  /// No description provided for @staffAssignRoleFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not assign role: {error}'**
  String staffAssignRoleFailed(String error);

  /// No description provided for @staffLinkLoginTooltip.
  ///
  /// In en, this message translates to:
  /// **'Link login'**
  String get staffLinkLoginTooltip;

  /// No description provided for @staffChangeLoginTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change linked login'**
  String get staffChangeLoginTooltip;

  /// No description provided for @staffScheduleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get staffScheduleTooltip;

  /// No description provided for @staffNoLoginLinked.
  ///
  /// In en, this message translates to:
  /// **'{status} · no login linked'**
  String staffNoLoginLinked(String status);

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule • {name}'**
  String scheduleTitle(String name);

  /// No description provided for @scheduleWorkingHoursTab.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get scheduleWorkingHoursTab;

  /// No description provided for @scheduleBreaksTab.
  ///
  /// In en, this message translates to:
  /// **'Breaks'**
  String get scheduleBreaksTab;

  /// No description provided for @scheduleBlockedTimeTab.
  ///
  /// In en, this message translates to:
  /// **'Blocked time'**
  String get scheduleBlockedTimeTab;

  /// No description provided for @scheduleOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get scheduleOff;

  /// No description provided for @scheduleNoBreak.
  ///
  /// In en, this message translates to:
  /// **'No break'**
  String get scheduleNoBreak;

  /// No description provided for @scheduleNoBlockedTime.
  ///
  /// In en, this message translates to:
  /// **'No blocked time scheduled.'**
  String get scheduleNoBlockedTime;

  /// No description provided for @scheduleWorkingHoursDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Working hours • {weekday}'**
  String scheduleWorkingHoursDialogTitle(String weekday);

  /// No description provided for @scheduleBreakDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Break • {weekday}'**
  String scheduleBreakDialogTitle(String weekday);

  /// No description provided for @scheduleStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Start: {time}'**
  String scheduleStartLabel(String time);

  /// No description provided for @scheduleEndLabel.
  ///
  /// In en, this message translates to:
  /// **'End: {time}'**
  String scheduleEndLabel(String time);

  /// No description provided for @scheduleRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get scheduleRemove;

  /// No description provided for @scheduleStartBeforeEnd.
  ///
  /// In en, this message translates to:
  /// **'Start time must be before end time.'**
  String get scheduleStartBeforeEnd;

  /// No description provided for @scheduleSaveWorkingHoursFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save working hours: {error}'**
  String scheduleSaveWorkingHoursFailed(String error);

  /// No description provided for @scheduleSaveBreakFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save break: {error}'**
  String scheduleSaveBreakFailed(String error);

  /// No description provided for @scheduleRemoveBlockedTimeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove blocked time: {error}'**
  String scheduleRemoveBlockedTimeFailed(String error);

  /// No description provided for @blockedTimeDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String blockedTimeDateLabel(String date);

  /// No description provided for @blockedTimeStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Start: {time}'**
  String blockedTimeStartLabel(String time);

  /// No description provided for @blockedTimeEndLabel.
  ///
  /// In en, this message translates to:
  /// **'End: {time}'**
  String blockedTimeEndLabel(String time);

  /// No description provided for @blockedTimeReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get blockedTimeReasonLabel;

  /// No description provided for @blockedTimeStartBeforeEnd.
  ///
  /// In en, this message translates to:
  /// **'Start time must be before end time.'**
  String get blockedTimeStartBeforeEnd;

  /// No description provided for @blockedTimeAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add blocked time: {error}'**
  String blockedTimeAddFailed(String error);

  /// No description provided for @crmSegmentAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get crmSegmentAll;

  /// No description provided for @crmSegmentVip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get crmSegmentVip;

  /// No description provided for @crmSegmentInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive 30d'**
  String get crmSegmentInactive;

  /// No description provided for @crmSegmentNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show risk'**
  String get crmSegmentNoShow;

  /// No description provided for @crmSegmentFirstVisit.
  ///
  /// In en, this message translates to:
  /// **'First visit'**
  String get crmSegmentFirstVisit;

  /// No description provided for @crmSegmentBirthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday this month'**
  String get crmSegmentBirthday;

  /// No description provided for @crmCustomerCount.
  ///
  /// In en, this message translates to:
  /// **'{count} customers'**
  String crmCustomerCount(int count);

  /// No description provided for @crmCampaignsHeading.
  ///
  /// In en, this message translates to:
  /// **'Campaigns'**
  String get crmCampaignsHeading;

  /// No description provided for @crmCreateCampaignTitle.
  ///
  /// In en, this message translates to:
  /// **'Create campaign • {segment} segment'**
  String crmCreateCampaignTitle(String segment);

  /// No description provided for @crmCampaignNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Campaign name'**
  String get crmCampaignNameLabel;

  /// No description provided for @crmMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get crmMessageLabel;

  /// No description provided for @crmChannelLabel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get crmChannelLabel;

  /// No description provided for @crmChannelPush.
  ///
  /// In en, this message translates to:
  /// **'Push notification'**
  String get crmChannelPush;

  /// No description provided for @crmChannelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get crmChannelEmail;

  /// No description provided for @crmChannelSms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get crmChannelSms;

  /// No description provided for @crmChannelNoProviderWarning.
  ///
  /// In en, this message translates to:
  /// **'Email/SMS delivery needs a provider that is not configured in this environment; the campaign will be recorded and its audience generated, but not actually delivered.'**
  String get crmChannelNoProviderWarning;

  /// No description provided for @crmSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get crmSaveDraft;

  /// No description provided for @crmCampaignSavedDraft.
  ///
  /// In en, this message translates to:
  /// **'Campaign saved as draft.'**
  String get crmCampaignSavedDraft;

  /// No description provided for @crmCampaignSentPush.
  ///
  /// In en, this message translates to:
  /// **'Campaign sent to {count} recipient(s).'**
  String crmCampaignSentPush(String count);

  /// No description provided for @crmCampaignSentNoProvider.
  ///
  /// In en, this message translates to:
  /// **'{count} recipient(s) generated, but {channel} has no delivery provider configured — nothing was actually sent.'**
  String crmCampaignSentNoProvider(String count, String channel);

  /// No description provided for @crmCampaignSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send campaign: {error}'**
  String crmCampaignSendFailed(String error);

  /// No description provided for @crmUndeliverableTooltip.
  ///
  /// In en, this message translates to:
  /// **'Recipients were generated, but this channel has no delivery provider configured — nothing was actually sent.'**
  String get crmUndeliverableTooltip;

  /// No description provided for @crmSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get crmSend;

  /// No description provided for @crmPointsAbbrev.
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String crmPointsAbbrev(int points);

  /// No description provided for @customerDetailRedeemPointsTitle.
  ///
  /// In en, this message translates to:
  /// **'Redeem points'**
  String get customerDetailRedeemPointsTitle;

  /// No description provided for @customerDetailPointsBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Points (balance: {points})'**
  String customerDetailPointsBalanceLabel(int points);

  /// No description provided for @customerDetailRedeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get customerDetailRedeem;

  /// No description provided for @customerDetailRedeemPointsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not redeem points: {error}'**
  String customerDetailRedeemPointsFailed(String error);

  /// No description provided for @customerDetailUseOneVisitTitle.
  ///
  /// In en, this message translates to:
  /// **'Use one visit'**
  String get customerDetailUseOneVisitTitle;

  /// No description provided for @customerDetailUseOneVisitBody.
  ///
  /// In en, this message translates to:
  /// **'Use one visit from \"{name}\"? {count} remaining.'**
  String customerDetailUseOneVisitBody(String name, String count);

  /// No description provided for @customerDetailUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get customerDetailUse;

  /// No description provided for @customerDetailUsePackageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not use package visit: {error}'**
  String customerDetailUsePackageFailed(String error);

  /// No description provided for @customerDetailSellPackageTitle.
  ///
  /// In en, this message translates to:
  /// **'Sell package'**
  String get customerDetailSellPackageTitle;

  /// No description provided for @customerDetailPackageLabel.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get customerDetailPackageLabel;

  /// No description provided for @customerDetailSell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get customerDetailSell;

  /// No description provided for @customerDetailSellPackageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sell package: {error}'**
  String customerDetailSellPackageFailed(String error);

  /// No description provided for @customerDetailSellMembershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Sell membership'**
  String get customerDetailSellMembershipTitle;

  /// No description provided for @customerDetailMembershipLabel.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get customerDetailMembershipLabel;

  /// No description provided for @customerDetailSellMembershipFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sell membership: {error}'**
  String customerDetailSellMembershipFailed(String error);

  /// No description provided for @customerDetailCancelMembershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel membership?'**
  String get customerDetailCancelMembershipTitle;

  /// No description provided for @customerDetailCancelMembershipBody.
  ///
  /// In en, this message translates to:
  /// **'Cancel \"{name}\"? The customer loses its discount immediately.'**
  String customerDetailCancelMembershipBody(String name);

  /// No description provided for @customerDetailBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get customerDetailBack;

  /// No description provided for @customerDetailCancelMembershipButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel membership'**
  String get customerDetailCancelMembershipButton;

  /// No description provided for @customerDetailCancelMembershipFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel membership: {error}'**
  String customerDetailCancelMembershipFailed(String error);

  /// No description provided for @customerDetailRenewTitle.
  ///
  /// In en, this message translates to:
  /// **'Renew {name}'**
  String customerDetailRenewTitle(String name);

  /// No description provided for @customerDetailPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price: {price}'**
  String customerDetailPriceLabel(String price);

  /// No description provided for @customerDetailRenew.
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get customerDetailRenew;

  /// No description provided for @customerDetailRenewMembershipFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not renew membership: {error}'**
  String customerDetailRenewMembershipFailed(String error);

  /// No description provided for @customerDetailCouponRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Coupon redeemed: {discount}'**
  String customerDetailCouponRedeemed(String discount);

  /// No description provided for @customerDetailCouponOff.
  ///
  /// In en, this message translates to:
  /// **'{percent}% off'**
  String customerDetailCouponOff(String percent);

  /// No description provided for @customerDetailCouponAmountOff.
  ///
  /// In en, this message translates to:
  /// **'{amount} off'**
  String customerDetailCouponAmountOff(String amount);

  /// No description provided for @customerDetailCouponApplied.
  ///
  /// In en, this message translates to:
  /// **'applied'**
  String get customerDetailCouponApplied;

  /// No description provided for @customerDetailRedeemCouponFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not redeem coupon: {error}'**
  String customerDetailRedeemCouponFailed(String error);

  /// No description provided for @customerDetailSaveNotesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save notes: {error}'**
  String customerDetailSaveNotesFailed(String error);

  /// No description provided for @customerDetailNotesConflict.
  ///
  /// In en, this message translates to:
  /// **'These notes were changed elsewhere — resolve the conflict from the sync banner.'**
  String get customerDetailNotesConflict;

  /// No description provided for @customerDetailNotesOfflinePending.
  ///
  /// In en, this message translates to:
  /// **'Offline — notes will sync when you\'re back online.'**
  String get customerDetailNotesOfflinePending;

  /// No description provided for @customerDetailNotesSaved.
  ///
  /// In en, this message translates to:
  /// **'Notes saved.'**
  String get customerDetailNotesSaved;

  /// No description provided for @customerDetailTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get customerDetailTotalSpent;

  /// No description provided for @customerDetailLastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit'**
  String get customerDetailLastVisit;

  /// No description provided for @customerDetailNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get customerDetailNever;

  /// No description provided for @customerDetailLoyaltyPointsLabel.
  ///
  /// In en, this message translates to:
  /// **'Loyalty points'**
  String get customerDetailLoyaltyPointsLabel;

  /// No description provided for @customerDetailSaveNotesButton.
  ///
  /// In en, this message translates to:
  /// **'Save notes'**
  String get customerDetailSaveNotesButton;

  /// No description provided for @customerDetailLoyaltyHeading.
  ///
  /// In en, this message translates to:
  /// **'Loyalty'**
  String get customerDetailLoyaltyHeading;

  /// No description provided for @customerDetailRedeemPointsButton.
  ///
  /// In en, this message translates to:
  /// **'Redeem points'**
  String get customerDetailRedeemPointsButton;

  /// No description provided for @customerDetailPackagesHeading.
  ///
  /// In en, this message translates to:
  /// **'Packages'**
  String get customerDetailPackagesHeading;

  /// No description provided for @customerDetailSellPackageButton.
  ///
  /// In en, this message translates to:
  /// **'Sell package'**
  String get customerDetailSellPackageButton;

  /// No description provided for @customerDetailNoPackages.
  ///
  /// In en, this message translates to:
  /// **'No packages owned.'**
  String get customerDetailNoPackages;

  /// No description provided for @customerDetailMembershipsHeading.
  ///
  /// In en, this message translates to:
  /// **'Memberships'**
  String get customerDetailMembershipsHeading;

  /// No description provided for @customerDetailSellMembershipButton.
  ///
  /// In en, this message translates to:
  /// **'Sell membership'**
  String get customerDetailSellMembershipButton;

  /// No description provided for @customerDetailNoMemberships.
  ///
  /// In en, this message translates to:
  /// **'No memberships owned.'**
  String get customerDetailNoMemberships;

  /// No description provided for @customerDetailUseOne.
  ///
  /// In en, this message translates to:
  /// **'Use 1'**
  String get customerDetailUseOne;

  /// No description provided for @customerDetailCouponHeading.
  ///
  /// In en, this message translates to:
  /// **'Coupon'**
  String get customerDetailCouponHeading;

  /// No description provided for @customerDetailCouponCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Coupon code'**
  String get customerDetailCouponCodeHint;

  /// No description provided for @customerDetailFallbackPackageName.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get customerDetailFallbackPackageName;

  /// No description provided for @customerDetailFallbackMembershipName.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get customerDetailFallbackMembershipName;

  /// No description provided for @customerDetailPackageUsesLeftStatus.
  ///
  /// In en, this message translates to:
  /// **'{count} uses left • {status}'**
  String customerDetailPackageUsesLeftStatus(String count, String status);

  /// No description provided for @customerDetailExpiresOn.
  ///
  /// In en, this message translates to:
  /// **'expires {date}'**
  String customerDetailExpiresOn(String date);

  /// No description provided for @customerDetailMembershipStatusUntil.
  ///
  /// In en, this message translates to:
  /// **'{status} • until {date}'**
  String customerDetailMembershipStatusUntil(String status, String date);

  /// No description provided for @offersTabPackages.
  ///
  /// In en, this message translates to:
  /// **'Packages'**
  String get offersTabPackages;

  /// No description provided for @offersTabMemberships.
  ///
  /// In en, this message translates to:
  /// **'Memberships'**
  String get offersTabMemberships;

  /// No description provided for @offersTabCoupons.
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get offersTabCoupons;

  /// No description provided for @offersNewPackageTitle.
  ///
  /// In en, this message translates to:
  /// **'New package'**
  String get offersNewPackageTitle;

  /// No description provided for @offersEditPackageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit package'**
  String get offersEditPackageTitle;

  /// No description provided for @offersServiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get offersServiceLabel;

  /// No description provided for @offersPriceMinorLabel.
  ///
  /// In en, this message translates to:
  /// **'Price (minor units)'**
  String get offersPriceMinorLabel;

  /// No description provided for @offersTotalUsesLabel.
  ///
  /// In en, this message translates to:
  /// **'Total uses'**
  String get offersTotalUsesLabel;

  /// No description provided for @offersExpiresAfterLabel.
  ///
  /// In en, this message translates to:
  /// **'Expires after (days, optional)'**
  String get offersExpiresAfterLabel;

  /// No description provided for @offersSavePackageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save package: {error}'**
  String offersSavePackageFailed(String error);

  /// No description provided for @offersUpdatePackageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update package: {error}'**
  String offersUpdatePackageFailed(String error);

  /// No description provided for @offersNoPackagesYet.
  ///
  /// In en, this message translates to:
  /// **'No packages yet.'**
  String get offersNoPackagesYet;

  /// No description provided for @offersAnyService.
  ///
  /// In en, this message translates to:
  /// **'Any service'**
  String get offersAnyService;

  /// No description provided for @offersUsesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} uses'**
  String offersUsesCount(int count);

  /// No description provided for @offersExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'expires in {days}d'**
  String offersExpiresInDays(int days);

  /// No description provided for @offersDiscountOffDuration.
  ///
  /// In en, this message translates to:
  /// **'{percent}% off • {days} days'**
  String offersDiscountOffDuration(String percent, int days);

  /// No description provided for @offersUsedCountLimited.
  ///
  /// In en, this message translates to:
  /// **'{count}/{limit} used'**
  String offersUsedCountLimited(int count, int limit);

  /// No description provided for @offersUsedCountUnlimited.
  ///
  /// In en, this message translates to:
  /// **'{count} used'**
  String offersUsedCountUnlimited(int count);

  /// No description provided for @offersDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get offersDeactivate;

  /// No description provided for @offersReactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get offersReactivate;

  /// No description provided for @offersNewMembershipTitle.
  ///
  /// In en, this message translates to:
  /// **'New membership'**
  String get offersNewMembershipTitle;

  /// No description provided for @offersEditMembershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit membership'**
  String get offersEditMembershipTitle;

  /// No description provided for @offersDiscountPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Discount percent'**
  String get offersDiscountPercentLabel;

  /// No description provided for @offersDurationDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration (days)'**
  String get offersDurationDaysLabel;

  /// No description provided for @offersSaveMembershipFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save membership: {error}'**
  String offersSaveMembershipFailed(String error);

  /// No description provided for @offersUpdateMembershipFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update membership: {error}'**
  String offersUpdateMembershipFailed(String error);

  /// No description provided for @offersNoMembershipsYet.
  ///
  /// In en, this message translates to:
  /// **'No memberships yet.'**
  String get offersNoMembershipsYet;

  /// No description provided for @offersNewCouponTitle.
  ///
  /// In en, this message translates to:
  /// **'New coupon'**
  String get offersNewCouponTitle;

  /// No description provided for @offersEditCouponTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit coupon'**
  String get offersEditCouponTitle;

  /// No description provided for @offersCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get offersCodeLabel;

  /// No description provided for @offersUsageLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Usage limit (optional)'**
  String get offersUsageLimitLabel;

  /// No description provided for @offersSaveCouponFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save coupon: {error}'**
  String offersSaveCouponFailed(String error);

  /// No description provided for @offersUpdateCouponFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update coupon: {error}'**
  String offersUpdateCouponFailed(String error);

  /// No description provided for @offersNoCouponsYet.
  ///
  /// In en, this message translates to:
  /// **'No coupons yet.'**
  String get offersNoCouponsYet;

  /// No description provided for @paymentsRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get paymentsRecordTitle;

  /// No description provided for @paymentsAppointmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get paymentsAppointmentLabel;

  /// No description provided for @paymentsAmountMinorLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (minor units)'**
  String get paymentsAmountMinorLabel;

  /// No description provided for @paymentsTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get paymentsTypeLabel;

  /// No description provided for @paymentsCouponOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Coupon code (optional)'**
  String get paymentsCouponOptionalLabel;

  /// No description provided for @paymentsApplyMembershipDiscount.
  ///
  /// In en, this message translates to:
  /// **'Apply active membership discount ({percent}% off)'**
  String paymentsApplyMembershipDiscount(String percent);

  /// No description provided for @paymentsChooseApptAndAmount.
  ///
  /// In en, this message translates to:
  /// **'Choose an appointment and a valid amount.'**
  String get paymentsChooseApptAndAmount;

  /// No description provided for @paymentsDiscountedAmountZero.
  ///
  /// In en, this message translates to:
  /// **'Discounted amount must be greater than zero.'**
  String get paymentsDiscountedAmountZero;

  /// No description provided for @paymentsPrintReceiptTooltip.
  ///
  /// In en, this message translates to:
  /// **'Print / share receipt'**
  String get paymentsPrintReceiptTooltip;

  /// No description provided for @reportsExportPdfTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get reportsExportPdfTooltip;

  /// No description provided for @reportsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get reportsThisWeek;

  /// No description provided for @reportsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get reportsThisMonth;

  /// No description provided for @reportsOccupancyVolumeHeading.
  ///
  /// In en, this message translates to:
  /// **'Occupancy & volume'**
  String get reportsOccupancyVolumeHeading;

  /// No description provided for @reportsOccupancy.
  ///
  /// In en, this message translates to:
  /// **'Occupancy'**
  String get reportsOccupancy;

  /// No description provided for @reportsAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get reportsAppointments;

  /// No description provided for @reportsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get reportsCompleted;

  /// No description provided for @reportsCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get reportsCancelled;

  /// No description provided for @reportsNoShows.
  ///
  /// In en, this message translates to:
  /// **'No-shows'**
  String get reportsNoShows;

  /// No description provided for @reportsRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get reportsRevenue;

  /// No description provided for @reportsCustomersHeading.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get reportsCustomersHeading;

  /// No description provided for @reportsNewCustomers.
  ///
  /// In en, this message translates to:
  /// **'New customers'**
  String get reportsNewCustomers;

  /// No description provided for @reportsRepeatCustomers.
  ///
  /// In en, this message translates to:
  /// **'Repeat customers'**
  String get reportsRepeatCustomers;

  /// No description provided for @reportsAverageSpend.
  ///
  /// In en, this message translates to:
  /// **'Average spend'**
  String get reportsAverageSpend;

  /// No description provided for @reportsCampaignsHeading.
  ///
  /// In en, this message translates to:
  /// **'Campaigns'**
  String get reportsCampaignsHeading;

  /// No description provided for @reportsCampaignsSent.
  ///
  /// In en, this message translates to:
  /// **'Campaigns sent'**
  String get reportsCampaignsSent;

  /// No description provided for @reportsRecipients.
  ///
  /// In en, this message translates to:
  /// **'Recipients'**
  String get reportsRecipients;

  /// No description provided for @reportsOpened.
  ///
  /// In en, this message translates to:
  /// **'Opened'**
  String get reportsOpened;

  /// No description provided for @reportsBooked.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get reportsBooked;

  /// No description provided for @reportsStaffPerformanceHeading.
  ///
  /// In en, this message translates to:
  /// **'Staff performance'**
  String get reportsStaffPerformanceHeading;

  /// No description provided for @reportsNoStaffYet.
  ///
  /// In en, this message translates to:
  /// **'No staff yet.'**
  String get reportsNoStaffYet;

  /// No description provided for @reportsLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get reportsLoadMore;

  /// No description provided for @reportsStaffCompletedNoShows.
  ///
  /// In en, this message translates to:
  /// **'{completed} completed • {noShow} no-shows'**
  String reportsStaffCompletedNoShows(int completed, int noShow);

  /// No description provided for @queueAddWalkInDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add walk-in'**
  String get queueAddWalkInDialogTitle;

  /// No description provided for @queueCustomerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get queueCustomerLabel;

  /// No description provided for @queueServiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get queueServiceLabel;

  /// No description provided for @queueStaffOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Staff (optional)'**
  String get queueStaffOptionalLabel;

  /// No description provided for @queueAnyStaff.
  ///
  /// In en, this message translates to:
  /// **'Any staff'**
  String get queueAnyStaff;

  /// No description provided for @queueWalkInAdded.
  ///
  /// In en, this message translates to:
  /// **'Walk-in added • {reference}'**
  String queueWalkInAdded(String reference);

  /// No description provided for @queueAddWalkInFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add walk-in: {error}'**
  String queueAddWalkInFailed(String error);

  /// No description provided for @queueCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get queueCall;

  /// No description provided for @queueStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get queueStart;

  /// No description provided for @calendarWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String calendarWeekOf(String date);

  /// No description provided for @calendarWeekView.
  ///
  /// In en, this message translates to:
  /// **'Week view'**
  String get calendarWeekView;

  /// No description provided for @calendarNoAppointments.
  ///
  /// In en, this message translates to:
  /// **'No appointments for this period.'**
  String get calendarNoAppointments;

  /// No description provided for @calendarStatusUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Status update failed: {error}'**
  String calendarStatusUpdateFailed(String error);

  /// No description provided for @calendarCancellationFailed.
  ///
  /// In en, this message translates to:
  /// **'Cancellation failed: {error}'**
  String calendarCancellationFailed(String error);

  /// No description provided for @calendarRescheduleFailed.
  ///
  /// In en, this message translates to:
  /// **'Reschedule failed: {error}'**
  String calendarRescheduleFailed(String error);

  /// No description provided for @calendarDepositDue.
  ///
  /// In en, this message translates to:
  /// **'deposit due {amount}'**
  String calendarDepositDue(String amount);

  /// No description provided for @dashboardGreetingDate.
  ///
  /// In en, this message translates to:
  /// **'Today • {date}'**
  String dashboardGreetingDate(String date);

  /// No description provided for @dashboardCardAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get dashboardCardAppointments;

  /// No description provided for @dashboardCardCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get dashboardCardCompleted;

  /// No description provided for @dashboardCardNoShows.
  ///
  /// In en, this message translates to:
  /// **'No-shows'**
  String get dashboardCardNoShows;

  /// No description provided for @dashboardCardRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get dashboardCardRevenue;

  /// No description provided for @dashboardHint.
  ///
  /// In en, this message translates to:
  /// **'Use Calendar for day/week operations, Queue for walk-ins, and CRM for loyalty, packages and campaigns.'**
  String get dashboardHint;
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
