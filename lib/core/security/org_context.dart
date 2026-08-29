import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_provider.dart';
import 'org_membership_query.dart';

export 'org_membership_query.dart' show OrganizationMembership;

/// Single source of truth for "what is the current user's active business
/// membership" — used both by [activeMembershipProvider] (Riverpod call
/// sites) and directly by widgets that aren't ConsumerWidgets (e.g.
/// BusinessShell), so the query only lives in one place. Thin wrapper
/// around org_membership_query.dart's client-agnostic version, defaulting
/// to the app's real Supabase.instance.client — see that file's doc
/// comment for why the actual query logic lives there instead of here.
Future<OrganizationMembership?> fetchActiveMembership() =>
    fetchActiveMembershipFor(Supabase.instance.client);

/// `autoDispose` is load-bearing here, not a style choice — see the class
/// doc below for why a plain (kept-alive) FutureProvider is unsafe for
/// this value even with stream-based invalidation wired up.
final activeMembershipProvider =
    FutureProvider.autoDispose<OrganizationMembership?>((ref) {
      return fetchActiveMembershipFor(ref.watch(supabaseProvider));
    });

/// Second fix for the recurring dashboard FORBIDDEN bug (see
/// org_context.dart git history for the first). That fix made
/// [activeMembershipProvider] a *reactive* FutureProvider — it re-ran
/// fetchActiveMembership() whenever Supabase's auth-change stream fired,
/// instead of caching one account's result forever. That closed the
/// original repro (switch accounts, revisit a page, see the old
/// account's org) but not the underlying bug class: reactive-via-watch
/// only guarantees the *next* read after invalidation is fresh, not that
/// invalidation has finished by the time a read triggered by the very
/// same auth event happens to run. Confirmed live: sign up as account A,
/// seed a demo org, sign out, sign in as account B — GoRouter's own
/// listener on that same auth-change stream fires fast enough to
/// navigate to Dashboard and mount it before this provider's
/// ref.watch(_authStateProvider) dependency had actually recomputed, so
/// Dashboard's first load() read A's still-cached org and sent it under
/// B's now-valid JWT. B's owner role on their own (different) org made
/// this fail loud (report_dashboard's has_org_role check rejected the
/// mismatch — no data leaked, just a FORBIDDEN) rather than silently
/// showing B account A's data, but it's still broken.
///
/// A kept-alive provider being *eventually* invalidated can never close
/// this: there is always some event ordering where a consumer reads it
/// between "auth changed" and "invalidation observed". `autoDispose`
/// sidesteps the race entirely instead of trying to win it: every call
/// site below reads this via `ref.read(...future)`, a one-off read that
/// holds no lasting subscription, so the provider has zero listeners the
/// instant that read completes and Riverpod tears it down. The *next*
/// read anywhere — regardless of whether an auth event fired, and
/// regardless of whether any invalidation logic ran — has no cached
/// instance to reuse and must call fetchActiveMembership() fresh. This
/// is exactly the pattern BusinessShell's own chrome already used (calls
/// fetchActiveMembership() directly, never through a cached provider),
/// which is exactly why BusinessShell's chrome never showed this bug
/// while every page reading these providers could. Regression-tested
/// against the real backend by
/// integration_test/dashboard_org_isolation_test.dart (see its doc
/// comment for why that test targets org_membership_query.dart's
/// fetchActiveMembershipFor() + a locally-built equivalent provider
/// rather than this file directly).
final activeOrganizationProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  return (await ref.watch(activeMembershipProvider.future))?.organizationId;
});

final activeRoleProvider = FutureProvider.autoDispose<String?>((ref) async {
  return (await ref.watch(activeMembershipProvider.future))?.role;
});

final activeCurrencyProvider = FutureProvider.autoDispose<String>((ref) async {
  return (await ref.watch(activeMembershipProvider.future))?.currency ??
      'USD';
});

/// Whether the current session belongs to a business account (has any
/// active `organization_members` row, for any org) rather than a pure
/// customer. Used by router.dart's redirect as the race-free gate for
/// entry into the customer portal — see its call site for why this can't
/// live only in CustomerLoginPage's own post-sign-in check: GoTrue's
/// signInWithPassword() broadcasts AuthChangeEvent.signedIn (which
/// GoRouterRefreshStream reacts to, triggering an immediate redirect
/// re-evaluation) *before* its own Future resolves, so a page-level async
/// check after `await signIn(...)` can lose the race to the router's own
/// redirect deciding `/customer/login` -> `/customer` first.
Future<bool> hasBusinessMembership() async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return false;
  final rows = await Supabase.instance.client
      .from('organization_members')
      .select('id')
      .eq('user_id', uid)
      .eq('status', 'active')
      .limit(1);
  return rows.isNotEmpty;
}
