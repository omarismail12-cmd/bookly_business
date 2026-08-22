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
  bool allowedFor(AppRole role) {
    switch (this) {
      case Permission.viewDashboard:
      case Permission.manageCalendar:
      case Permission.manageCustomers:
        return true;
      case Permission.manageQueue:
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
