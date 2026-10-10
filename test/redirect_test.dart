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

    test('signed in with a household keeps Phase 2 routes', () {
      for (final location in [
        '/members',
        '/transactions',
        '/transactions/new',
        '/transactions/edit/00000000-0000-0000-0000-000000000000',
        '/categories',
        '/household-members',
      ]) {
        expect(
          appRedirect(
            authLoading: false,
            signedIn: true,
            membershipLoading: false,
            hasMembership: true,
            location: location,
          ),
          isNull,
          reason: location,
        );
        expect(
          appRedirect(
            authLoading: false,
            signedIn: false,
            membershipLoading: false,
            hasMembership: false,
            location: location,
          ),
          '/sign-in',
          reason: 'signed out: $location',
        );
      }
    });

    test('linked-person check keeps the user on splash while resolving', () {
      expect(
        appRedirect(
          authLoading: false,
          signedIn: true,
          membershipLoading: false,
          hasMembership: true,
          memberLoading: true,
          hasLinkedMember: false,
          location: '/',
        ),
        splashRoute,
      );
      expect(
        appRedirect(
          authLoading: false,
          signedIn: true,
          membershipLoading: false,
          hasMembership: true,
          memberLoading: true,
          hasLinkedMember: false,
          location: splashRoute,
        ),
        isNull,
      );
    });

    test('household login without a linked person goes to /claim', () {
      for (final location in ['/', '/transactions', '/settings', splashRoute]) {
        expect(
          appRedirect(
            authLoading: false,
            signedIn: true,
            membershipLoading: false,
            hasMembership: true,
            memberLoading: false,
            hasLinkedMember: false,
            location: location,
          ),
          claimRoute,
          reason: location,
        );
      }
      expect(
        appRedirect(
          authLoading: false,
          signedIn: true,
          membershipLoading: false,
          hasMembership: true,
          memberLoading: false,
          hasLinkedMember: false,
          location: claimRoute,
        ),
        isNull,
        reason: 'stays on /claim',
      );
      // Signed out or household-less logins never see the claim screen.
      expect(
        appRedirect(
          authLoading: false,
          signedIn: false,
          membershipLoading: false,
          hasMembership: false,
          hasLinkedMember: false,
          location: claimRoute,
        ),
        '/sign-in',
      );
      expect(
        appRedirect(
          authLoading: false,
          signedIn: true,
          membershipLoading: false,
          hasMembership: false,
          hasLinkedMember: false,
          location: claimRoute,
        ),
        '/setup',
      );
    });

    test('claim screen returns to the shell once the person is linked', () {
      for (final location in [claimRoute, splashRoute, '/setup']) {
        expect(
          appRedirect(
            authLoading: false,
            signedIn: true,
            membershipLoading: false,
            hasMembership: true,
            memberLoading: false,
            hasLinkedMember: true,
            location: location,
          ),
          '/',
          reason: location,
        );
      }
    });

    test('children are redirected away from adult-only routes', () {
      for (final location in [
        '/vehicles',
        '/vehicles/new',
        '/vehicles/v1',
        '/vehicles/v1/fuel/new',
        '/recurring',
        '/recurring/new',
      ]) {
        expect(
          appRedirect(
            authLoading: false,
            signedIn: true,
            membershipLoading: false,
            hasMembership: true,
            location: location,
            isAdult: false,
          ),
          '/',
          reason: 'child: $location',
        );
      }
    });

    test('adults may open adult-only routes', () {
      for (final location in ['/vehicles', '/vehicles/v1', '/recurring']) {
        expect(
          appRedirect(
            authLoading: false,
            signedIn: true,
            membershipLoading: false,
            hasMembership: true,
            location: location,
            isAdult: true,
          ),
          isNull,
          reason: 'adult: $location',
        );
      }
    });
  });
}
