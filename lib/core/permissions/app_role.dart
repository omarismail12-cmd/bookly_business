/// Every role the app recognizes for a signed-in session.
///
/// `owner`/`manager`/`receptionist`/`staff` are business roles, sourced from
/// `organization_members.role` (see `activeRoleProvider` in
/// core/security/org_context.dart) — a session only has one of these if
/// it's a member of at least one organization.
///
/// `customer` is the customer-portal counterpart: a signed-in user who is
/// never an organization member, whose own data is scoped purely via
/// `customers.profile_id = auth.uid()` RLS policies (see
/// 0013_customer_portal.sql, 0029_customer_offers_access.sql). It exists so
/// role-aware code has exactly one enum to check instead of an ad hoc
/// "customer or business" signal — CustomerShell's own tabs are still
/// unconditional (every customer sees the same three-then-four tabs; see
/// its class doc), so nothing gates on `AppRole.customer` today, but the
/// [Permission] system below is safe against it existing.
enum AppRole { owner, manager, receptionist, staff, customer }

extension AppRoleX on AppRole {
  String get value => name;

  bool get canManageSettings =>
      this == AppRole.owner || this == AppRole.manager;

  bool get canTakePayments => switch (this) {
    AppRole.owner || AppRole.manager || AppRole.receptionist => true,
    AppRole.staff || AppRole.customer => false,
  };

  bool get canViewReports => this == AppRole.owner || this == AppRole.manager;
}
