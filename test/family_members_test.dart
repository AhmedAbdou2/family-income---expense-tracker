import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/features/auth/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/family_members_screen.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/members/domain/entities.dart';
import 'package:family_income_expense_tracker/features/members/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The merged Family screen must expose exactly the actions each role is
/// allowed to perform - and, crucially, an invite can never carry the owner
/// role (matching the DB CHECK + `create_invite`).
const _household = Household(id: 'h1', name: 'Home', currency: 'EGP');

const _me = Member(
  id: 'm1',
  householdId: 'h1',
  name: 'Me Person',
  isActive: true,
  userId: 'u1',
);
const _other = Member(
  id: 'm2',
  householdId: 'h1',
  name: 'Other Adult',
  isActive: true,
  userId: 'u2',
);
const _unlinked = Member(
  id: 'm3',
  householdId: 'h1',
  name: 'No Login Kid',
  isActive: true,
);

HouseholdLogin _login(String userId, MemberRole role) => HouseholdLogin(
      userId: userId,
      role: role,
      joinedAt: DateTime(2026, 1, 1),
    );

Widget _app({
  required MemberRole role,
  required List<Member> members,
  List<HouseholdLogin>? logins,
}) =>
    ProviderScope(
      overrides: [
        membershipProvider.overrideWith(
          (ref) async =>
              Membership(household: _household, role: role),
        ),
        authStateProvider.overrideWith((ref) => Stream.value('u1')),
        membersProvider.overrideWith((ref) async => members),
        householdLoginsProvider.overrideWith(
          (ref) async => logins ?? [_login('u1', role)],
        ),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const FamilyMembersScreen(),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _openMenu(WidgetTester tester, int rowIndex) async {
  await tester.tap(find.byType(PopupMenuButton<String>).at(rowIndex));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('owner sees add-person and invite actions', (tester) async {
    await _pump(
      tester,
      _app(role: MemberRole.owner, members: const [_me, _other]),
    );

    expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
  });

  testWidgets('child sees no add/invite actions', (tester) async {
    await _pump(
      tester,
      _app(role: MemberRole.child, members: const [_me]),
    );

    expect(find.byIcon(Icons.person_add_alt_1_outlined), findsNothing);
    expect(find.byIcon(Icons.person_add_outlined), findsNothing);
  });

  testWidgets('owner: linked other person offers role/remove, not delete',
      (tester) async {
    await _pump(
      tester,
      _app(
        role: MemberRole.owner,
        members: const [_me, _other],
        logins: [_login('u1', MemberRole.owner), _login('u2', MemberRole.adult)],
      ),
    );

    await _openMenu(tester, 1);

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Change role'), findsOneWidget);
    expect(find.text('Remove account'), findsOneWidget);
    expect(find.text('Delete person'), findsNothing);
    expect(find.text('Connect a login'), findsNothing);
  });

  testWidgets('owner: unlinked person offers connect + delete, not role',
      (tester) async {
    await _pump(
      tester,
      _app(role: MemberRole.owner, members: const [_me, _unlinked]),
    );

    await _openMenu(tester, 1);

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Connect a login'), findsOneWidget);
    expect(find.text('Delete person'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Change role'), findsNothing);
    expect(find.text('Remove account'), findsNothing);
  });

  testWidgets('adult: cannot rename or change role of others, can invite',
      (tester) async {
    await _pump(
      tester,
      _app(
        role: MemberRole.adult,
        members: const [_me, _other, _unlinked],
        logins: [
          _login('u1', MemberRole.adult),
          _login('u2', MemberRole.child),
        ],
      ),
    );

    // The adult's own row can be renamed and left.
    await _openMenu(tester, 0);
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Leave household'), findsOneWidget);
    expect(find.text('Change role'), findsNothing);
    expect(find.text('Remove account'), findsNothing);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // A linked other person is fully read-only for an adult.
    await _openMenu(tester, 1);
    expect(find.text('Change role'), findsNothing);
    expect(find.text('Remove account'), findsNothing);
    expect(find.text('Rename'), findsNothing);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // An unlinked person can be connected and deleted by an adult.
    await _openMenu(tester, 2);
    expect(find.text('Connect a login'), findsOneWidget);
    expect(find.text('Delete person'), findsOneWidget);
  });

  testWidgets('child: only own row, can rename self and leave',
      (tester) async {
    await _pump(
      tester,
      _app(role: MemberRole.child, members: const [_me]),
    );

    await _openMenu(tester, 0);

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Leave household'), findsOneWidget);
    expect(find.text('Change role'), findsNothing);
    expect(find.text('Remove account'), findsNothing);
    expect(find.text('Connect a login'), findsNothing);
    expect(find.text('Delete person'), findsNothing);
  });

  testWidgets('invite role picker never offers the owner role',
      (tester) async {
    await _pump(
      tester,
      _app(role: MemberRole.owner, members: const [_me]),
    );

    await tester.tap(find.byIcon(Icons.person_add_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Invite as'), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Adult')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Child')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Owner')),
      findsNothing,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
