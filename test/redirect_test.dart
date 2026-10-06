import 'package:family_income_expense_tracker/core/router/redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appRedirect', () {
    test('stays on splash while auth is resolving', () {
      expect(
        appRedirect(
          authLoading: true,
          signedIn: false,
          membershipLoading: false,
          hasMembership: false,
          location: splashRoute,
        ),
        isNull,
      );
      expect(
        appRedirect(
          authLoading: true,
          signedIn: false,
          membershipLoading: false,
          hasMembership: false,
          location: '/sign-in',
        ),
        splashRoute,
      );
    });

    test('signed out users always go to /sign-in', () {
      expect(
        appRedirect(
          authLoading: false,
          signedIn: false,
          membershipLoading: false,
          hasMembership: false,
          location: '/',
        ),
        '/sign-in',
      );
      expect(
        appRedirect(
          authLoading: false,
          signedIn: false,
          membershipLoading: false,
          hasMembership: false,
          location: '/settings',
        ),
        '/sign-in',
      );
    });

    test('signed out users can stay on auth screens', () {
      for (final location in authRoutes) {
        expect(
          appRedirect(
            authLoading: false,
            signedIn: false,
            membershipLoading: false,
            hasMembership: false,
            location: location,
          ),
          isNull,
          reason: location,
        );
      }
    });

    test('signed in but membership still loading goes to splash', () {
      expect(
        appRedirect(
          authLoading: false,
          signedIn: true,
          membershipLoading: true,
          hasMembership: false,
          location: '/',
        ),
        splashRoute,
      );
      expect(
        appRedirect(
          authLoading: false,
          signedIn: true,
          membershipLoading: true,
          hasMembership: false,
          location: splashRoute,
        ),
        isNull,
      );
    });

    test('signed in without a household goes to /setup', () {
      expect(
        appRedirect(
          authLoading: false,
          signedIn: true,
          membershipLoading: false,
          hasMembership: false,
          location: '/',
        ),
        '/setup',
      );
      expect(
        appRedirect(
          authLoading: false,
          signedIn: true,
          membershipLoading: false,
          hasMembership: false,
          location: '/setup/create',
        ),
        isNull,
      );
      expect(
        appRedirect(
          authLoading: false,
          signedIn: true,
          membershipLoading: false,
          hasMembership: false,
          location: '/setup/join',
        ),
        isNull,
      );
    });

    test('signed in with a household lands in the shell', () {
      expect(
        appRedirect(
          authLoading: false,
          signedIn: true,
          membershipLoading: false,
          hasMembership: true,
          location: splashRoute,
        ),
        '/',
      );
      expect(
        appRedirect(
          authLoading: false,
          signedIn: true,
          membershipLoading: false,
          hasMembership: true,
          location: '/setup',
        ),
        '/',
      );
      for (final location in authRoutes) {
        expect(
          appRedirect(
            authLoading: false,
            signedIn: true,
            membershipLoading: false,
            hasMembership: true,
            location: location,
          ),
          '/',
        );
      }
      expect(
        appRedirect(
          authLoading: false,
          signedIn: true,
          membershipLoading: false,
          hasMembership: true,
          location: '/transactions',
        ),
        isNull,
      );
      expect(
        appRedirect(
          authLoading: false,
          signedIn: true,
          membershipLoading: false,
          hasMembership: true,
          location: '/settings',
        ),
        isNull,
      );
    });
  });
}
