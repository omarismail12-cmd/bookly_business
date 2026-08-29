import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import 'package:bookly_business/core/security/org_membership_query.dart';

import 'test_helpers.dart';

/// Regression test for the recurring dashboard `FORBIDDEN` bug
/// (report_dashboard / P0001) — see lib/core/security/org_context.dart's
/// doc comment on `activeMembershipProvider` for the full incident writeup.
///
/// Real-world shape of the bug: one browser tab, one Riverpod
/// ProviderContainer, two different accounts signed in one after another
/// (sign up as A / seed a demo org, sign out, sign in as B). A page reading
/// the cached membership provider right after that switch got A's org back
/// under B's now-valid session — report_dashboard's own has_org_role check
/// caught the mismatch and raised FORBIDDEN (no data leaked), but the
/// dashboard was broken for B regardless. Two earlier fixes narrowed when
/// this could happen (a missing `.order()`, then making the provider
/// react to auth-state-change events) without closing the underlying
/// race: a *kept-alive* provider that's merely invalidated *eventually*
/// can always be read in the gap between "auth changed" and "invalidation
/// observed". The actual fix makes `activeMembershipProvider` and its
/// derived providers `FutureProvider.autoDispose` — every call site reads
/// them via a one-off `ref.read(...future)`, so nothing keeps them alive
/// between reads, and each read is structurally guaranteed to hit
/// `fetchActiveMembershipFor()` fresh rather than a cached Future that
/// might belong to a different account's session.
///
/// This test can't drive the real `activeMembershipProvider` (it lives in
/// org_context.dart, which imports supabase_flutter/flutter_riverpod —
/// neither compiles under plain `dart test`, which is what this suite runs
/// under; see test_helpers.dart's doc comment for why). Instead it builds
/// a `FutureProvider.autoDispose` with the exact same shape directly
/// against org_membership_query.dart's `fetchActiveMembershipFor()` — the
/// real query function org_context.dart's provider wraps unchanged — using
/// the real, non-Flutter `riverpod` package. That's enough to exercise the
/// actual contract this bug lives or dies on: does a provider read
/// immediately following an account switch, on one shared
/// ProviderContainer, ever return the previous account's cached org.
void main() {
  late final client = ensureSupabaseInitialized();

  // Mirrors what org_context.dart's activeMembershipProvider actually is —
  // FutureProvider.autoDispose wrapping fetchActiveMembershipFor() — using
  // the single shared test client the way the app uses its single
  // Supabase.instance.client across an in-tab account switch.
  final membershipProvider = FutureProvider.autoDispose<
    OrganizationMembership?
  >((ref) => fetchActiveMembershipFor(client));

  test(
    'switching accounts in one session never serves the previous '
    "account's cached org (dashboard FORBIDDEN regression)",
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Account A: sign up, seed an org, confirm the provider resolves to
      // A's own org — this is "sign in, load the dashboard, confirm
      // success" for the first account.
      final userA = await signUpTestUser();
      final orgA = await createTestOrgWithService();

      final membershipA = await container.read(membershipProvider.future);
      expect(
        membershipA?.organizationId,
        orgA.orgId,
        reason: 'account A should resolve to its own freshly-created org',
      );

      // Account B: a second, different throwaway account with its own,
      // different org — created and signed into on the SAME client/session
      // the way a real browser tab reuses one Supabase client across a
      // sign-out/sign-in.
      await client.auth.signOut();
      final userB = await signUpTestUser();
      final orgB = await createTestOrgWithService();
      expect(orgB.orgId, isNot(orgA.orgId));
      expect(userB.userId, isNot(userA.userId));

      // The actual regression check: read the membership provider again,
      // immediately after the switch, same as a page's first post-navigation
      // read. Under the bug, activeMembershipProvider (kept-alive, only
      // eventually invalidated) could still be holding A's resolved
      // Future here. Under the fix (autoDispose), the provider was torn
      // down the instant the read above completed, so this call has
      // nothing cached to reuse and must resolve fresh.
      final membershipB = await container.read(membershipProvider.future);
      expect(
        membershipB?.organizationId,
        orgB.orgId,
        reason:
            "account B's dashboard must load B's own org, not A's stale "
            'cached one — this is the exact bug: report_dashboard would '
            "reject A's org under B's session with FORBIDDEN",
      );
      expect(membershipB?.organizationId, isNot(orgA.orgId));

      // End-to-end confirmation, not just the provider's own return value:
      // the org this resolves to must actually be usable by B, the same
      // way DashboardPage feeds activeOrganizationProvider's result
      // straight into the report_dashboard RPC.
      final now = DateTime.now().toUtc();
      final report = await client.rpc(
        'report_dashboard',
        params: {
          'p_org': membershipB!.organizationId,
          'p_from': now.subtract(const Duration(days: 1)).toIso8601String(),
          'p_to': now.toIso8601String(),
        },
      );
      expect(report, isA<Map>());
    },
  );
}
