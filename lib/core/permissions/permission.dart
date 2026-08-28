import 'app_role.dart';

enum Permission {
  viewDashboard,
  manageCalendar,
  manageQueue,
  manageCustomers,
  manageServices,
  manageStaff,
  takePayments,
  viewReports,
  manageCrm,
  manageSettings,
}

extension PermissionX on Permission {
  /// Every [Permission] here is a business-app concern — none of them apply
  /// to [AppRole.customer], which has no business-app UI to gate at all
  /// (CustomerShell's tabs are unconditional; a customer's actual
  /// capabilities — read their own appointments/loyalty/profile, create
  /// bookings for themselves — are enforced directly by RLS `*_self_select`
  /// policies and the booking RPCs, not by this permission system). Handled
  /// as an explicit early return, not folded into each case below: several
  /// cases return bare `true`/`role != AppRole.staff`, which would silently
  /// include `AppRole.customer` too if it weren't excluded first.
  bool allowedFor(AppRole role) {
    if (role == AppRole.customer) return false;
    switch (this) {
      case Permission.viewDashboard:
      case Permission.manageCustomers:
        return true;
      case Permission.manageQueue:
      case Permission.manageCalendar:
        return role != AppRole.staff;
      case Permission.manageServices:
      case Permission.manageStaff:
      case Permission.manageSettings:
        return role == AppRole.owner || role == AppRole.manager;
      case Permission.takePayments:
        return role == AppRole.owner ||
            role == AppRole.manager ||
            role == AppRole.receptionist;
      case Permission.viewReports:
      case Permission.manageCrm:
        return role == AppRole.owner || role == AppRole.manager;
    }
  }
}
