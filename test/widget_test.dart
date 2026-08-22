import 'package:flutter_test/flutter_test.dart';

import 'package:bookly_business/core/localization/gen/app_localizations_ar.dart';
import 'package:bookly_business/core/localization/gen/app_localizations_en.dart';
import 'package:bookly_business/core/permissions/app_role.dart';
import 'package:bookly_business/core/permissions/permission.dart';
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

    test('dashboard and calendar are visible to every role', () {
      for (final role in AppRole.values) {
        expect(Permission.viewDashboard.allowedFor(role), isTrue);
        expect(Permission.manageCalendar.allowedFor(role), isTrue);
      }
    });
  });
}
