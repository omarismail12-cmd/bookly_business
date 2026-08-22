// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bookly Business';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navQueue => 'Queue';

  @override
  String get navCustomers => 'Customers';

  @override
  String get navServices => 'Services';

  @override
  String get navStaff => 'Staff';

  @override
  String get navPayments => 'Payments';

  @override
  String get navCrm => 'CRM';

  @override
  String get navOffers => 'Offers';

  @override
  String get navReports => 'Reports';

  @override
  String get navLocations => 'Locations';

  @override
  String get navToday => 'Today';

  @override
  String get navMore => 'More';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginNoAccount => 'Don\'t have an account? Create one';

  @override
  String get signupTitle => 'Create your account';

  @override
  String get signupFullName => 'Full name';

  @override
  String get signupConfirmPassword => 'Confirm password';

  @override
  String get signupSubmit => 'Create account';

  @override
  String get signupHaveAccount => 'Already have an account? Sign in';

  @override
  String get bookingTitleNew => 'New Booking';

  @override
  String get bookingTitlePublic => 'Book an appointment';

  @override
  String get bookingChooseServiceStaffTime =>
      'Choose a service, staff member and available time.';

  @override
  String get bookingService => 'Service';

  @override
  String get bookingStaff => 'Staff';

  @override
  String get bookingCustomer => 'Customer';

  @override
  String get bookingLocation => 'Location';

  @override
  String get bookingDate => 'Date';

  @override
  String get bookingFullName => 'Full name';

  @override
  String get bookingEmail => 'Email';

  @override
  String get bookingPhone => 'Phone';

  @override
  String bookingConfirmed(String reference) {
    return 'Booking confirmed. Reference: $reference';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonLogout => 'Log out';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonNoResults => 'No results found.';

  @override
  String get commonToday => 'Today';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get validationEmailRequired => 'Email is required';

  @override
  String get validationEmailInvalid => 'Enter a valid email address';

  @override
  String get validationPasswordRequired => 'Password is required';

  @override
  String get validationPasswordTooShort =>
      'Password must be at least 8 characters';

  @override
  String get validationConfirmPasswordRequired =>
      'Please confirm your password';

  @override
  String get validationPasswordMismatch => 'Passwords do not match';

  @override
  String get validationNameRequired => 'Name is required';

  @override
  String get validationNameTooShort => 'Name must be at least 2 characters';

  @override
  String get pageTitlePayments => 'Payments';

  @override
  String get pageTitleStaff => 'Staff & Schedules';

  @override
  String get pageTitleQueue => 'Walk-in Queue';

  @override
  String get pageTitleServices => 'Services';

  @override
  String get pageTitleCrm => 'CRM • Loyalty • Campaigns';

  @override
  String get pageTitleReports => 'Reports';

  @override
  String get pageTitleOffers => 'Packages, Memberships & Coupons';

  @override
  String get pageTitleCustomers => 'Customers';

  @override
  String get pageTitleLocations => 'Locations';

  @override
  String get staffPortalTitle => 'Today';

  @override
  String get queueEmpty => 'No customers are waiting.';

  @override
  String get queueAddWalkIn => 'Walk-in';

  @override
  String get paymentsAddPayment => 'Payment';

  @override
  String get staffAddStaff => 'Staff';

  @override
  String get servicesAddService => 'Add';

  @override
  String get crmAddCustomer => 'Customer';

  @override
  String get crmCreateCampaign => 'Campaign';

  @override
  String get locationsAddLocation => 'Location';

  @override
  String get locationsEmpty => 'No locations yet.';

  @override
  String get staffPortalEmpty => 'No appointments today.';

  @override
  String get customerPortalWelcome => 'Welcome back';

  @override
  String get customerPortalTagline => 'Sign in to manage your bookings.';

  @override
  String get customerPortalSignupTagline =>
      'Book appointments and track your loyalty rewards.';

  @override
  String get navMyAppointments => 'My Appointments';

  @override
  String get navFindBook => 'Book';

  @override
  String get navLoyalty => 'Loyalty';

  @override
  String get findBusinessTitle => 'Book with a business';

  @override
  String get findBusinessHint =>
      'Enter the business code your business gave you';

  @override
  String get findBusinessGo => 'Continue';

  @override
  String get findBusinessNotFound =>
      'We couldn\'t find a business with that code.';

  @override
  String get myAppointmentsEmpty => 'You don\'t have any appointments yet.';

  @override
  String get loyaltyEmpty => 'No loyalty rewards yet — book your first visit!';

  @override
  String loyaltyPoints(String points) {
    return '$points points';
  }
}
