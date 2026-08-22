enum AppRole { owner, manager, receptionist, staff }

extension AppRoleX on AppRole {
  String get value => name;
  bool get canManageSettings =>
      this == AppRole.owner || this == AppRole.manager;
  bool get canTakePayments => this != AppRole.staff;
  bool get canViewReports => this == AppRole.owner || this == AppRole.manager;
}
