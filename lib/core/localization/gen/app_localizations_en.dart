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
  String get bookingNoQualifiedStaff =>
      'No staff assigned to this service yet — assign staff in Staff & Schedules.';

  @override
  String get bookingStaffCannotPerformService =>
      'This staff member doesn\'t offer the selected service. Please choose another.';

  @override
  String get bookingReviewTitle => 'Review your booking';

  @override
  String get bookingReviewBusiness => 'Business';

  @override
  String get bookingReviewTime => 'Time';

  @override
  String get bookingReviewPrice => 'Price';

  @override
  String get bookingChangeTime => 'Change time';

  @override
  String get bookingConfirmButton => 'Confirm booking';

  @override
  String get bookingSlotsLoadFailed => 'Could not load available times.';

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
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonName => 'Name';

  @override
  String get commonPhone => 'Phone';

  @override
  String get commonAddress => 'Address';

  @override
  String get commonClose => 'Close';

  @override
  String get commonOk => 'OK';

  @override
  String commonPage(int page) {
    return 'Page $page';
  }

  @override
  String get commonLoadMore => 'Load more';

  @override
  String get commonCustomerFallback => 'Customer';

  @override
  String get commonSignOut => 'Sign out';

  @override
  String commonConfirmDelete(String name) {
    return 'Remove \"$name\"? This cannot be undone.';
  }

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
  String get navMyOffers => 'Offers';

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

  @override
  String get offersEmpty =>
      'No offers right now — check back after your next visit!';

  @override
  String get offersForYou => 'For you';

  @override
  String get offersActiveCoupons => 'Active coupons';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusCheckedIn => 'Checked in';

  @override
  String get statusInService => 'In service';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusNoShow => 'No-show';

  @override
  String get statusWaiting => 'Waiting';

  @override
  String get statusCalled => 'Called';

  @override
  String get statusActive => 'Active';

  @override
  String get statusInactive => 'Inactive';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusSent => 'Sent';

  @override
  String get statusUndeliverable => 'Undeliverable';

  @override
  String get statusReversed => 'Reversed';

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusUsedUp => 'Used up';

  @override
  String get paymentMethodOther => 'Other';

  @override
  String get paymentTypeRefund => 'Refund';

  @override
  String get paymentTypeForfeit => 'Forfeit';

  @override
  String get paymentTypeAdjustment => 'Adjustment';

  @override
  String get apptCheckIn => 'Check in';

  @override
  String get apptStartService => 'Start service';

  @override
  String get apptComplete => 'Complete';

  @override
  String get apptNoShow => 'No-show';

  @override
  String get apptReschedule => 'Reschedule';

  @override
  String get apptTitleFallback => 'Appointment';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodCard => 'Card';

  @override
  String get paymentMethodTransfer => 'Transfer';

  @override
  String get paymentMethodOnline => 'Online';

  @override
  String get paymentTypePayment => 'Payment';

  @override
  String get paymentTypeDeposit => 'Deposit';

  @override
  String get paymentMethodLabel => 'Payment method';

  @override
  String get routerPageNotFound => 'This page could not be found.';

  @override
  String get routerGoHome => 'Go home';

  @override
  String get languageSwitcherTitle => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get themeSwitcherTitle => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String syncConflictsNeedReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes need your review.',
      one: '$count change needs your review.',
    );
    return '$_temp0';
  }

  @override
  String syncChangesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes could not be synced.',
      one: '$count change could not be synced.',
    );
    return '$_temp0';
  }

  @override
  String syncOfflinePendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Offline — $count changes will sync when you\'re back online.',
      one: 'Offline — $count change will sync when you\'re back online.',
    );
    return '$_temp0';
  }

  @override
  String get syncOffline => 'You are offline.';

  @override
  String syncChangesSyncing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes syncing…',
      one: '$count change syncing…',
    );
    return '$_temp0';
  }

  @override
  String get syncResolveConflictsTitle => 'Resolve conflicts';

  @override
  String get syncNothingToResolve => 'Nothing left to resolve.';

  @override
  String get syncResolve => 'Resolve';

  @override
  String get syncRetryNow => 'Retry now';

  @override
  String syncConflictChangedElsewhere(String entity) {
    return '$entity — this was changed elsewhere';
  }

  @override
  String syncYourEdit(String value) {
    return 'Your edit: $value';
  }

  @override
  String syncCurrentValue(String value) {
    return 'Current value: $value';
  }

  @override
  String get syncKeepTheirs => 'Keep theirs';

  @override
  String get syncKeepMine => 'Keep mine';

  @override
  String staffTodayStatusUpdateFailed(String error) {
    return 'Status update failed: $error';
  }

  @override
  String get blockedTimeAdd => 'Add blocked time';

  @override
  String get staffTimeOffAdded => 'Time off added.';

  @override
  String get staffTodayNoProfile =>
      'No staff profile is linked to your account yet. Ask your manager to assign you as staff.';

  @override
  String get privateNotesLabel => 'Private notes';

  @override
  String get privateNotesHint => 'Preferences, allergies, reminders…';

  @override
  String get nextRecommendationLabel => 'Next recommendation';

  @override
  String get nextRecommendationHint => 'What to suggest at the next visit…';

  @override
  String get staffAppointmentConflictMessage =>
      'This customer was changed elsewhere — resolve the conflict from the sync banner.';

  @override
  String get staffAppointmentOfflinePending =>
      'Offline — will sync when you\'re back online.';

  @override
  String get staffAppointmentNotesSaved => 'Notes saved.';

  @override
  String staffAppointmentSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String get orgSetupNameRequired => 'Business name is required.';

  @override
  String get orgSetupSlugInvalid =>
      'Slug must use 3-40 lowercase letters, numbers or hyphens.';

  @override
  String get orgSetupPageTitle => 'Set up your business';

  @override
  String get orgSetupHeading => 'Create your business';

  @override
  String get orgSetupBusinessNameLabel => 'Business name';

  @override
  String get orgSetupSlugLabel => 'Slug';

  @override
  String get orgSetupTimezoneLabel => 'Timezone';

  @override
  String get orgSetupCreateButton => 'Create business';

  @override
  String get orgSetupCreateDemoButton => 'Create demo business + test data';

  @override
  String get orgSetupWaitingForInvite =>
      'Waiting to be added to an existing team instead? Ask the owner to assign you a role, then sign out above and sign back in.';

  @override
  String get orgSuspendedMessage =>
      'Your Bookly business membership is suspended. Contact the business owner before creating or accessing another workspace.';

  @override
  String get orgSettingsTitle => 'Business settings';

  @override
  String get orgSettingsBusinessCodeLabel => 'Business code';

  @override
  String get orgSettingsBusinessCodeHelp =>
      'Customers enter this on the \"Book with a business\" screen to find you.';

  @override
  String get orgSettingsBookingLinkLabel => 'Direct booking link';

  @override
  String get orgSettingsCopied => 'Copied to clipboard.';

  @override
  String get commonCopy => 'Copy';

  @override
  String get authIncorrectCredentials => 'Incorrect email or password.';

  @override
  String authLoginFailed(String error) {
    return 'Login failed: $error';
  }

  @override
  String get authLoginFailedGeneric => 'Login failed.';

  @override
  String get authLoginSuccessful => 'Login successful!';

  @override
  String get authEmailConfirmRequired =>
      'Please confirm your email before logging in.';

  @override
  String get loginWelcomeTitle => 'Welcome to Bookly';

  @override
  String get loginTagline => 'Sign in to manage your business.';

  @override
  String get authAccountCreatedConfirmEmail =>
      'Account created. Check your email to confirm your account.';

  @override
  String get authAccountCreatedConfirmEmailShort =>
      'Account created. Check your email to confirm it.';

  @override
  String get authCheckEmailTitle => 'Check your email';

  @override
  String authCheckEmailBody(String email) {
    return 'We created the account for $email. Supabase has sent the confirmation email. Confirm it before signing in.';
  }

  @override
  String get authAccountCreatedSuccess => 'Account created successfully!';

  @override
  String get authEmailAlreadyRegistered =>
      'This email is already registered. Please sign in instead.';

  @override
  String get authEmailInvalidGeneric => 'Please enter a valid email address.';

  @override
  String get authPasswordRequirementsNotMet =>
      'Password does not meet the requirements.';

  @override
  String authSignupFailed(String error) {
    return 'Sign up failed: $error';
  }

  @override
  String get authNoUserReturned => 'Supabase did not return a user.';

  @override
  String get signupWelcomeTitle => 'Create your Bookly account';

  @override
  String get signupTagline => 'Manage your business with Bookly.';

  @override
  String get loginCustomerPrompt =>
      'Are you a customer? Book an appointment here';

  @override
  String get customerPortalBusinessPrompt => 'Are you a business? Sign in here';

  @override
  String get customerPortalNotACustomer =>
      'This account isn\'t set up as a customer. Sign in as a business below instead.';

  @override
  String get authForgotPasswordLink => 'Forgot password?';

  @override
  String get authForgotPasswordTitle => 'Reset your password';

  @override
  String get authForgotPasswordInstructions =>
      'Enter your email and we\'ll send you a link to reset your password.';

  @override
  String get authForgotPasswordSendButton => 'Send reset link';

  @override
  String get authForgotPasswordSent =>
      'If an account exists for that email, we\'ve sent a password reset link. Check your inbox.';

  @override
  String authForgotPasswordFailed(String error) {
    return 'Could not send reset link: $error';
  }

  @override
  String get authBackToLogin => 'Back to sign in';

  @override
  String get authResetPasswordTitle => 'Set a new password';

  @override
  String get authResetPasswordNewPasswordLabel => 'New password';

  @override
  String get authResetPasswordButton => 'Update password';

  @override
  String get authResetPasswordSuccess => 'Password updated. Please sign in.';

  @override
  String authResetPasswordFailed(String error) {
    return 'Could not update password: $error';
  }

  @override
  String get authResetPasswordInvalidSession =>
      'This password reset link is invalid or has expired. Request a new one.';

  @override
  String get authResetPasswordCancelSignOut => 'Cancel and sign out';

  @override
  String myApptStatusLine(String status) {
    return 'Status: $status';
  }

  @override
  String myApptStaffLine(String staff) {
    return 'Staff: $staff';
  }

  @override
  String myApptServicesLine(String services) {
    return 'Services: $services';
  }

  @override
  String myApptDepositLine(String paid, String required) {
    return 'Deposit: $paid of $required paid';
  }

  @override
  String loyaltyUntilDate(String date) {
    return 'Until $date';
  }

  @override
  String loyaltyUsesLeft(String count) {
    return '$count uses left';
  }

  @override
  String get customersAddDialogTitle => 'Add customer';

  @override
  String customersSubtitleNoShows(int count) {
    return 'no-shows $count';
  }

  @override
  String get customersWaitingToSync => 'Waiting to sync';

  @override
  String get locationsNewTitle => 'New location';

  @override
  String get locationsEditTitle => 'Edit location';

  @override
  String locationsSaveFailed(String error) {
    return 'Could not save location: $error';
  }

  @override
  String get locationsDeleteTitle => 'Delete location?';

  @override
  String locationsDeleteFailed(String error) {
    return 'Could not delete location: $error';
  }

  @override
  String get servicesAddTitle => 'Add service';

  @override
  String get servicesDurationLabel => 'Duration (min)';

  @override
  String get servicesBufferLabel => 'Buffer (min)';

  @override
  String get servicesPriceLabel => 'Price minor units';

  @override
  String get servicesDepositLabel => 'Deposit required (minor units, 0 = none)';

  @override
  String get servicesNumbersRequired =>
      'Duration, buffer and price must be whole numbers.';

  @override
  String servicesEditDescriptionTitle(String name) {
    return 'Edit description • $name';
  }

  @override
  String get servicesDescriptionLabel => 'Description';

  @override
  String get servicesDeleteTitle => 'Delete service?';

  @override
  String servicesDeleteFailed(String error) {
    return 'Could not delete service: $error';
  }

  @override
  String get servicesEditDescriptionTooltip => 'Edit description';

  @override
  String get staffAddTitle => 'Add staff';

  @override
  String get staffDisplayNameLabel => 'Display name';

  @override
  String get staffAssignRoleButton => 'Assign role';

  @override
  String staffLinkLoginTitle(String name) {
    return 'Link login for $name';
  }

  @override
  String get staffAlreadyLinkedWarning =>
      'This staff member is already linked to a login. Linking a new email will replace it.';

  @override
  String get staffAccountEmailLabel =>
      'Account email (must already have the Staff role)';

  @override
  String get staffLinkMoveWarning =>
      'If that account is already linked to a different staff row here (e.g. auto-linked when the Staff role was assigned), it will be moved to this one instead.';

  @override
  String get staffLinkButton => 'Link';

  @override
  String get staffLoginLinked => 'Login linked.';

  @override
  String staffLinkFailed(String error) {
    return 'Could not link login: $error';
  }

  @override
  String get staffAssignRoleTitle => 'Assign business role';

  @override
  String get staffExistingAccountEmailLabel => 'Existing account email';

  @override
  String get staffRoleLabel => 'Role';

  @override
  String get staffRoleManager => 'Manager';

  @override
  String get staffRoleReceptionist => 'Receptionist';

  @override
  String get staffRoleStaff => 'Staff';

  @override
  String get staffAssignButton => 'Assign';

  @override
  String get staffRoleAssigned => 'Role assigned.';

  @override
  String staffAssignRoleFailed(String error) {
    return 'Could not assign role: $error';
  }

  @override
  String get staffLinkLoginTooltip => 'Link login';

  @override
  String get staffChangeLoginTooltip => 'Change linked login';

  @override
  String get staffScheduleTooltip => 'Schedule';

  @override
  String staffNoLoginLinked(String status) {
    return '$status · no login linked';
  }

  @override
  String get staffServicesTooltip => 'Services';

  @override
  String staffServicesTitle(String name) {
    return 'Services for $name';
  }

  @override
  String get staffServicesEmpty => 'This business has no services yet.';

  @override
  String get staffServicesUpdated => 'Services updated.';

  @override
  String staffServicesUpdateFailed(String error) {
    return 'Could not update services: $error';
  }

  @override
  String scheduleTitle(String name) {
    return 'Schedule • $name';
  }

  @override
  String get scheduleWorkingHoursTab => 'Working hours';

  @override
  String get scheduleBreaksTab => 'Breaks';

  @override
  String get scheduleBlockedTimeTab => 'Blocked time';

  @override
  String get scheduleOff => 'Off';

  @override
  String get scheduleNoBreak => 'No break';

  @override
  String get scheduleNoBlockedTime => 'No blocked time scheduled.';

  @override
  String scheduleWorkingHoursDialogTitle(String weekday) {
    return 'Working hours • $weekday';
  }

  @override
  String scheduleBreakDialogTitle(String weekday) {
    return 'Break • $weekday';
  }

  @override
  String scheduleStartLabel(String time) {
    return 'Start: $time';
  }

  @override
  String scheduleEndLabel(String time) {
    return 'End: $time';
  }

  @override
  String get scheduleRemove => 'Remove';

  @override
  String get scheduleStartBeforeEnd => 'Start time must be before end time.';

  @override
  String scheduleSaveWorkingHoursFailed(String error) {
    return 'Could not save working hours: $error';
  }

  @override
  String scheduleSaveBreakFailed(String error) {
    return 'Could not save break: $error';
  }

  @override
  String scheduleRemoveBlockedTimeFailed(String error) {
    return 'Could not remove blocked time: $error';
  }

  @override
  String blockedTimeDateLabel(String date) {
    return 'Date: $date';
  }

  @override
  String blockedTimeStartLabel(String time) {
    return 'Start: $time';
  }

  @override
  String blockedTimeEndLabel(String time) {
    return 'End: $time';
  }

  @override
  String get blockedTimeReasonLabel => 'Reason (optional)';

  @override
  String get blockedTimeStartBeforeEnd => 'Start time must be before end time.';

  @override
  String blockedTimeAddFailed(String error) {
    return 'Could not add blocked time: $error';
  }

  @override
  String get crmSegmentAll => 'All';

  @override
  String get crmSegmentVip => 'VIP';

  @override
  String get crmSegmentInactive => 'Inactive 30d';

  @override
  String get crmSegmentNoShow => 'No-show risk';

  @override
  String get crmSegmentFirstVisit => 'First visit';

  @override
  String get crmSegmentBirthday => 'Birthday this month';

  @override
  String crmCustomerCount(int count) {
    return '$count customers';
  }

  @override
  String get crmCampaignsHeading => 'Campaigns';

  @override
  String crmCreateCampaignTitle(String segment) {
    return 'Create campaign • $segment segment';
  }

  @override
  String get crmCampaignNameLabel => 'Campaign name';

  @override
  String get crmMessageLabel => 'Message';

  @override
  String get crmChannelLabel => 'Channel';

  @override
  String get crmChannelPush => 'Push notification';

  @override
  String get crmChannelEmail => 'Email';

  @override
  String get crmChannelSms => 'SMS';

  @override
  String get crmChannelNoProviderWarning =>
      'Email/SMS delivery needs a provider that is not configured in this environment; the campaign will be recorded and its audience generated, but not actually delivered.';

  @override
  String get crmSaveDraft => 'Save draft';

  @override
  String get crmCampaignSavedDraft => 'Campaign saved as draft.';

  @override
  String crmCampaignSentPush(String count) {
    return 'Campaign sent to $count recipient(s).';
  }

  @override
  String crmCampaignSentNoProvider(String count, String channel) {
    return '$count recipient(s) generated, but $channel has no delivery provider configured — nothing was actually sent.';
  }

  @override
  String crmCampaignSendFailed(String error) {
    return 'Could not send campaign: $error';
  }

  @override
  String get crmUndeliverableTooltip =>
      'Recipients were generated, but this channel has no delivery provider configured — nothing was actually sent.';

  @override
  String get crmSend => 'Send';

  @override
  String crmPointsAbbrev(int points) {
    return '$points pts';
  }

  @override
  String get customerDetailRedeemPointsTitle => 'Redeem points';

  @override
  String customerDetailPointsBalanceLabel(int points) {
    return 'Points (balance: $points)';
  }

  @override
  String get customerDetailRedeem => 'Redeem';

  @override
  String customerDetailRedeemPointsFailed(String error) {
    return 'Could not redeem points: $error';
  }

  @override
  String get customerDetailUseOneVisitTitle => 'Use one visit';

  @override
  String customerDetailUseOneVisitBody(String name, String count) {
    return 'Use one visit from \"$name\"? $count remaining.';
  }

  @override
  String get customerDetailUse => 'Use';

  @override
  String customerDetailUsePackageFailed(String error) {
    return 'Could not use package visit: $error';
  }

  @override
  String get customerDetailSellPackageTitle => 'Sell package';

  @override
  String get customerDetailPackageLabel => 'Package';

  @override
  String get customerDetailSell => 'Sell';

  @override
  String customerDetailSellPackageFailed(String error) {
    return 'Could not sell package: $error';
  }

  @override
  String get customerDetailSellMembershipTitle => 'Sell membership';

  @override
  String get customerDetailMembershipLabel => 'Membership';

  @override
  String customerDetailSellMembershipFailed(String error) {
    return 'Could not sell membership: $error';
  }

  @override
  String get customerDetailCancelMembershipTitle => 'Cancel membership?';

  @override
  String customerDetailCancelMembershipBody(String name) {
    return 'Cancel \"$name\"? The customer loses its discount immediately.';
  }

  @override
  String get customerDetailBack => 'Back';

  @override
  String get customerDetailCancelMembershipButton => 'Cancel membership';

  @override
  String customerDetailCancelMembershipFailed(String error) {
    return 'Could not cancel membership: $error';
  }

  @override
  String customerDetailRenewTitle(String name) {
    return 'Renew $name';
  }

  @override
  String customerDetailPriceLabel(String price) {
    return 'Price: $price';
  }

  @override
  String get customerDetailRenew => 'Renew';

  @override
  String customerDetailRenewMembershipFailed(String error) {
    return 'Could not renew membership: $error';
  }

  @override
  String customerDetailCouponRedeemed(String discount) {
    return 'Coupon redeemed: $discount';
  }

  @override
  String customerDetailCouponOff(String percent) {
    return '$percent% off';
  }

  @override
  String customerDetailCouponAmountOff(String amount) {
    return '$amount off';
  }

  @override
  String get customerDetailCouponApplied => 'applied';

  @override
  String customerDetailRedeemCouponFailed(String error) {
    return 'Could not redeem coupon: $error';
  }

  @override
  String customerDetailSaveNotesFailed(String error) {
    return 'Could not save notes: $error';
  }

  @override
  String get customerDetailNotesConflict =>
      'These notes were changed elsewhere — resolve the conflict from the sync banner.';

  @override
  String get customerDetailNotesOfflinePending =>
      'Offline — notes will sync when you\'re back online.';

  @override
  String get customerDetailNotesSaved => 'Notes saved.';

  @override
  String get customerDetailTotalSpent => 'Total spent';

  @override
  String get customerDetailLastVisit => 'Last visit';

  @override
  String get customerDetailNever => 'Never';

  @override
  String get customerDetailLoyaltyPointsLabel => 'Loyalty points';

  @override
  String get customerDetailSaveNotesButton => 'Save notes';

  @override
  String get customerDetailLoyaltyHeading => 'Loyalty';

  @override
  String get customerDetailRedeemPointsButton => 'Redeem points';

  @override
  String get customerDetailPackagesHeading => 'Packages';

  @override
  String get customerDetailSellPackageButton => 'Sell package';

  @override
  String get customerDetailNoPackages => 'No packages owned.';

  @override
  String get customerDetailMembershipsHeading => 'Memberships';

  @override
  String get customerDetailSellMembershipButton => 'Sell membership';

  @override
  String get customerDetailNoMemberships => 'No memberships owned.';

  @override
  String get customerDetailUseOne => 'Use 1';

  @override
  String get customerDetailCouponHeading => 'Coupon';

  @override
  String get customerDetailCouponCodeHint => 'Coupon code';

  @override
  String get customerDetailFallbackPackageName => 'Package';

  @override
  String get customerDetailFallbackMembershipName => 'Membership';

  @override
  String customerDetailPackageUsesLeftStatus(String count, String status) {
    return '$count uses left • $status';
  }

  @override
  String customerDetailExpiresOn(String date) {
    return 'expires $date';
  }

  @override
  String customerDetailMembershipStatusUntil(String status, String date) {
    return '$status • until $date';
  }

  @override
  String get offersTabPackages => 'Packages';

  @override
  String get offersTabMemberships => 'Memberships';

  @override
  String get offersTabCoupons => 'Coupons';

  @override
  String get offersNewPackageTitle => 'New package';

  @override
  String get offersEditPackageTitle => 'Edit package';

  @override
  String get offersServiceLabel => 'Service';

  @override
  String get offersPriceMinorLabel => 'Price (minor units)';

  @override
  String get offersTotalUsesLabel => 'Total uses';

  @override
  String get offersExpiresAfterLabel => 'Expires after (days, optional)';

  @override
  String offersSavePackageFailed(String error) {
    return 'Could not save package: $error';
  }

  @override
  String offersUpdatePackageFailed(String error) {
    return 'Could not update package: $error';
  }

  @override
  String get offersNoPackagesYet => 'No packages yet.';

  @override
  String get offersAnyService => 'Any service';

  @override
  String offersUsesCount(int count) {
    return '$count uses';
  }

  @override
  String offersExpiresInDays(int days) {
    return 'expires in ${days}d';
  }

  @override
  String offersDiscountOffDuration(String percent, int days) {
    return '$percent% off • $days days';
  }

  @override
  String offersUsedCountLimited(int count, int limit) {
    return '$count/$limit used';
  }

  @override
  String offersUsedCountUnlimited(int count) {
    return '$count used';
  }

  @override
  String get offersDeactivate => 'Deactivate';

  @override
  String get offersReactivate => 'Reactivate';

  @override
  String get offersNewMembershipTitle => 'New membership';

  @override
  String get offersEditMembershipTitle => 'Edit membership';

  @override
  String get offersDiscountPercentLabel => 'Discount percent';

  @override
  String get offersDurationDaysLabel => 'Duration (days)';

  @override
  String offersSaveMembershipFailed(String error) {
    return 'Could not save membership: $error';
  }

  @override
  String offersUpdateMembershipFailed(String error) {
    return 'Could not update membership: $error';
  }

  @override
  String get offersNoMembershipsYet => 'No memberships yet.';

  @override
  String get offersNewCouponTitle => 'New coupon';

  @override
  String get offersEditCouponTitle => 'Edit coupon';

  @override
  String get offersCodeLabel => 'Code';

  @override
  String get offersUsageLimitLabel => 'Usage limit (optional)';

  @override
  String offersSaveCouponFailed(String error) {
    return 'Could not save coupon: $error';
  }

  @override
  String offersUpdateCouponFailed(String error) {
    return 'Could not update coupon: $error';
  }

  @override
  String get offersNoCouponsYet => 'No coupons yet.';

  @override
  String get paymentsRecordTitle => 'Record payment';

  @override
  String get paymentsAppointmentLabel => 'Appointment';

  @override
  String get paymentsAmountMinorLabel => 'Amount (minor units)';

  @override
  String get paymentsTypeLabel => 'Type';

  @override
  String get paymentsCouponOptionalLabel => 'Coupon code (optional)';

  @override
  String paymentsApplyMembershipDiscount(String percent) {
    return 'Apply active membership discount ($percent% off)';
  }

  @override
  String get paymentsChooseApptAndAmount =>
      'Choose an appointment and a valid amount.';

  @override
  String get paymentsDiscountedAmountZero =>
      'Discounted amount must be greater than zero.';

  @override
  String get paymentsPrintReceiptTooltip => 'Print / share receipt';

  @override
  String get reportsExportPdfTooltip => 'Export PDF';

  @override
  String get reportsThisWeek => 'This week';

  @override
  String get reportsThisMonth => 'This month';

  @override
  String get reportsOccupancyVolumeHeading => 'Occupancy & volume';

  @override
  String get reportsOccupancy => 'Occupancy';

  @override
  String get reportsAppointments => 'Appointments';

  @override
  String get reportsCompleted => 'Completed';

  @override
  String get reportsCancelled => 'Cancelled';

  @override
  String get reportsNoShows => 'No-shows';

  @override
  String get reportsRevenue => 'Revenue';

  @override
  String get reportsCustomersHeading => 'Customers';

  @override
  String get reportsNewCustomers => 'New customers';

  @override
  String get reportsRepeatCustomers => 'Repeat customers';

  @override
  String get reportsAverageSpend => 'Average spend';

  @override
  String get reportsCampaignsHeading => 'Campaigns';

  @override
  String get reportsCampaignsSent => 'Campaigns sent';

  @override
  String get reportsRecipients => 'Recipients';

  @override
  String get reportsOpened => 'Opened';

  @override
  String get reportsBooked => 'Booked';

  @override
  String get reportsStaffPerformanceHeading => 'Staff performance';

  @override
  String get reportsNoStaffYet => 'No staff yet.';

  @override
  String get reportsLoadMore => 'Load more';

  @override
  String reportsStaffCompletedNoShows(int completed, int noShow) {
    return '$completed completed • $noShow no-shows';
  }

  @override
  String get queueAddWalkInDialogTitle => 'Add walk-in';

  @override
  String get queueCustomerLabel => 'Customer';

  @override
  String get queueServiceLabel => 'Service';

  @override
  String get queueStaffOptionalLabel => 'Staff (optional)';

  @override
  String get queueAnyStaff => 'Any staff';

  @override
  String queueWalkInAdded(String reference) {
    return 'Walk-in added • $reference';
  }

  @override
  String queueAddWalkInFailed(String error) {
    return 'Could not add walk-in: $error';
  }

  @override
  String get queueCall => 'Call';

  @override
  String get queueStart => 'Start';

  @override
  String calendarWeekOf(String date) {
    return 'Week of $date';
  }

  @override
  String get calendarWeekView => 'Week view';

  @override
  String get calendarNoAppointments => 'No appointments for this period.';

  @override
  String calendarStatusUpdateFailed(String error) {
    return 'Status update failed: $error';
  }

  @override
  String calendarCancellationFailed(String error) {
    return 'Cancellation failed: $error';
  }

  @override
  String calendarRescheduleFailed(String error) {
    return 'Reschedule failed: $error';
  }

  @override
  String calendarDepositDue(String amount) {
    return 'deposit due $amount';
  }

  @override
  String dashboardGreetingDate(String date) {
    return 'Today • $date';
  }

  @override
  String get dashboardCardAppointments => 'Appointments';

  @override
  String get dashboardCardCompleted => 'Completed';

  @override
  String get dashboardCardNoShows => 'No-shows';

  @override
  String get dashboardCardRevenue => 'Revenue';

  @override
  String get dashboardHint =>
      'Use Calendar for day/week operations, Queue for walk-ins, and CRM for loyalty, packages and campaigns.';
}
