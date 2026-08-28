import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookly_business/core/config/app_config.dart';
import 'package:bookly_business/core/localization/gen/app_localizations.dart';
import 'package:bookly_business/core/localization/gen/app_localizations_ar.dart';
import 'package:bookly_business/core/localization/gen/app_localizations_en.dart';
import 'package:bookly_business/core/permissions/app_role.dart';
import 'package:bookly_business/core/permissions/permission.dart';
import 'package:bookly_business/features/appointments/presentation/booking_page.dart';
import 'package:bookly_business/main.dart';
import 'package:bookly_business/shared/formatters/currency.dart';
import 'package:bookly_business/shared/validators/validators.dart';

final _en = AppLocalizationsEn();
final _ar = AppLocalizationsAr();

void main() {
  group('formatMinor', () {
    test('formats whole-dollar minor units with default currency', () {
      expect(formatMinor(2500), 'USD 25.00');
    });

    test('formats zero', () {
      expect(formatMinor(0), 'USD 0.00');
    });

    test('honors a custom currency code', () {
      expect(formatMinor(1099, currency: 'EUR'), 'EUR 10.99');
    });
  });

  group('Validators.email', () {
    test('rejects empty input', () {
      expect(Validators.email('', _en), isNotNull);
      expect(Validators.email(null, _en), isNotNull);
    });

    test('rejects a malformed address', () {
      expect(Validators.email('not-an-email', _en), isNotNull);
    });

    test('accepts a well-formed address', () {
      expect(Validators.email('owner@bookly.test', _en), isNull);
    });

    test('messages are actually localized, not just present', () {
      expect(Validators.email('', _en), 'Email is required');
      expect(Validators.email('', _ar), 'البريد الإلكتروني مطلوب');
    });
  });

  group('Validators.password', () {
    test('rejects empty input', () {
      expect(Validators.password('', _en), isNotNull);
    });

    test('rejects passwords shorter than 8 characters', () {
      expect(Validators.password('short1', _en), isNotNull);
    });

    test('accepts an 8+ character password', () {
      expect(Validators.password('longenoughpassword', _en), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('rejects a mismatch', () {
      expect(Validators.confirmPassword('abc', 'xyz', _en), isNotNull);
    });

    test('accepts a match', () {
      expect(
        Validators.confirmPassword('abc123456', 'abc123456', _en),
        isNull,
      );
    });
  });

  group('Validators.name', () {
    test('rejects a single character', () {
      expect(Validators.name('a', _en), isNotNull);
    });

    test('accepts a normal name', () {
      expect(Validators.name('Maya', _en), isNull);
    });
  });

  group('PermissionX.allowedFor', () {
    test('staff cannot manage the queue, other roles can', () {
      expect(Permission.manageQueue.allowedFor(AppRole.staff), isFalse);
      expect(Permission.manageQueue.allowedFor(AppRole.receptionist), isTrue);
      expect(Permission.manageQueue.allowedFor(AppRole.manager), isTrue);
      expect(Permission.manageQueue.allowedFor(AppRole.owner), isTrue);
    });

    test('only owner/manager can manage staff and settings', () {
      for (final p in [Permission.manageStaff, Permission.manageSettings]) {
        expect(p.allowedFor(AppRole.owner), isTrue);
        expect(p.allowedFor(AppRole.manager), isTrue);
        expect(p.allowedFor(AppRole.receptionist), isFalse);
        expect(p.allowedFor(AppRole.staff), isFalse);
      }
    });

    test('only owner/manager/receptionist can take payments', () {
      expect(Permission.takePayments.allowedFor(AppRole.owner), isTrue);
      expect(Permission.takePayments.allowedFor(AppRole.manager), isTrue);
      expect(Permission.takePayments.allowedFor(AppRole.receptionist), isTrue);
      expect(Permission.takePayments.allowedFor(AppRole.staff), isFalse);
    });

    test('dashboard is visible to every business role', () {
      const businessRoles = [
        AppRole.owner,
        AppRole.manager,
        AppRole.receptionist,
        AppRole.staff,
      ];
      for (final role in businessRoles) {
        expect(Permission.viewDashboard.allowedFor(role), isTrue);
      }
    });

    test('only non-staff business roles can manage the full org calendar', () {
      expect(Permission.manageCalendar.allowedFor(AppRole.owner), isTrue);
      expect(Permission.manageCalendar.allowedFor(AppRole.manager), isTrue);
      expect(Permission.manageCalendar.allowedFor(AppRole.receptionist), isTrue);
      expect(Permission.manageCalendar.allowedFor(AppRole.staff), isFalse);
    });

    test(
      'AppRole.customer gets no business permission, even ones every '
      'business role has',
      () {
        for (final permission in Permission.values) {
          expect(
            permission.allowedFor(AppRole.customer),
            isFalse,
            reason:
                '${permission.name} must be false for AppRole.customer — '
                'the customer portal has no business-app UI to gate; a '
                "customer's real capabilities are enforced by RLS "
                '*_self_select policies, not this permission system.',
          );
        }
      },
    );
  });

  group('App smoke test', () {
    testWidgets(
      'renders the config-missing fallback without throwing when Supabase '
      'is not configured',
      (tester) async {
        // A plain `flutter test` run has no --dart-define, so this is
        // exactly the path main() takes by default — and the one most
        // likely to silently break if ProviderScope/localization wiring
        // around it breaks. Pumps the real widget from lib/main.dart, not a
        // reconstruction of it.
        expect(AppConfig.isConfigured, isFalse);
        await tester.pumpWidget(
          const ProviderScope(child: ConfigMissingApp()),
        );
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(
          find.textContaining('Supabase configuration is missing'),
          findsOneWidget,
        );
      },
    );
  });

  group('Booking flow localization', () {
    testWidgets(
      'renders RTL with real Arabic strings when the ar locale is active',
      (tester) async {
        // BookingPage can't be pumped against live data under `flutter
        // test` — it depends on Supabase.instance.client, and this
        // project's test setup deliberately has no Supabase mocking (see
        // integration_test/test_helpers.dart's doc comment for why real
        // network needs `dart test`, not `flutter test`). But
        // Supabase.instance throwing (never initialized here) is caught by
        // BookingPage's own try/catch in load(), which still flips
        // `loading` to false and renders the full localized form with
        // empty service/staff/location lists — exactly the real frame this
        // test needs, using the real widget and its real l10n getters.
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              locale: Locale('ar'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: BookingPage(publicSlug: 'test-salon'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(BookingPage));
        expect(
          Localizations.localeOf(context).languageCode,
          'ar',
          reason: 'MaterialApp.locale was forced to ar; falling back to en '
              'would mean the ar delegate failed to load.',
        );
        expect(
          Directionality.of(context),
          TextDirection.rtl,
          reason: 'Arabic must resolve to RTL layout direction.',
        );

        expect(find.text(_ar.bookingTitlePublic), findsOneWidget);
        expect(find.text(_ar.bookingService), findsOneWidget);
        expect(find.text(_ar.bookingStaff), findsOneWidget);
        expect(find.text(_ar.bookingFullName), findsOneWidget);
        // The actual regression this test guards against: falling back to
        // English instead of actually rendering the Arabic strings.
        expect(find.text(_en.bookingTitlePublic), findsNothing);
        expect(find.text(_en.bookingService), findsNothing);
      },
    );
  });
}
