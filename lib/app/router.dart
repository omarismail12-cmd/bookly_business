import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/localization/gen/app_localizations.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/signup_page.dart';
import '../features/customer_portal/presentation/customer_login_page.dart';
import '../features/customer_portal/presentation/customer_shell.dart';
import '../features/customer_portal/presentation/customer_signup_page.dart';
import '../features/organisations/presentation/business_shell.dart';
import '../features/appointments/presentation/booking_page.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (_, state) {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    final loc = state.matchedLocation;
    final businessAuth = loc == '/login' || loc == '/signup';
    final customerAuth = loc == '/customer/login' || loc == '/customer/signup';
    final customerRoute = loc.startsWith('/customer');
    final publicBooking = loc.startsWith('/book/');
    if (!loggedIn) {
      if (customerRoute && !customerAuth) return '/customer/login';
      if (!businessAuth && !customerAuth && !publicBooking) return '/login';
      return null;
    }
    if (businessAuth) return '/home';
    if (customerAuth) return '/customer';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(path: '/signup', builder: (_, _) => const SignupPage()),
    GoRoute(path: '/home', builder: (_, _) => const BusinessShell()),
    GoRoute(
      path: '/customer/login',
      builder: (_, _) => const CustomerLoginPage(),
    ),
    GoRoute(
      path: '/customer/signup',
      builder: (_, _) => const CustomerSignupPage(),
    ),
    GoRoute(path: '/customer', builder: (_, _) => const CustomerShell()),
    GoRoute(
      path: '/book/:slug',
      builder: (_, state) =>
          BookingPage(publicSlug: state.pathParameters['slug']),
    ),
    GoRoute(path: '/book', builder: (_, _) => const BookingPage()),
  ],
  errorBuilder: (context, state) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 48),
              const SizedBox(height: 12),
              Text(l10n.routerPageNotFound),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: Text(l10n.routerGoHome),
              ),
            ],
          ),
        ),
      ),
    );
  },
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final dynamic _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
