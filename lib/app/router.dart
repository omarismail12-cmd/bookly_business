import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/signup_page.dart';
import '../features/organisations/presentation/business_shell.dart';
import '../features/appointments/presentation/booking_page.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (_, state) {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    final auth =
        state.matchedLocation == '/login' || state.matchedLocation == '/signup';
    final publicBooking = state.matchedLocation.startsWith('/book/');
    if (!loggedIn && !auth && !publicBooking) return '/login';
    if (loggedIn && auth) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/signup', builder: (_, __) => const SignupPage()),
    GoRoute(path: '/home', builder: (_, __) => const BusinessShell()),
    GoRoute(
      path: '/book/:slug',
      builder: (_, state) =>
          BookingPage(publicSlug: state.pathParameters['slug']),
    ),
    GoRoute(path: '/book', builder: (_, __) => const BookingPage()),
  ],
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
