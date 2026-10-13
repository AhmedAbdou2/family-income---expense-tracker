import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/features/auth/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/domain/household_repository.dart';
import 'package:family_income_expense_tracker/features/household/presentation/family_members_screen.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/members/domain/entities.dart';
import 'package:family_income_expense_tracker/features/members/domain/members_repository.dart';
import 'package:family_income_expense_tracker/features/members/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The merged "Add family member" dialog: one entry point that either creates
/// a person (no login) or creates the person AND a person-bound invite.
///
/// These tests drive the real screen against fake repositories, so they pin
/// which calls the flow makes - the DB rules (adult-only person insert, an
/// invite never carrying the owner role, a child login always having a
/// person) stay untouched and are exercised by the RPCs in production.
const _household = Household(id: 'h1', name: 'Home', currency: 'EGP');

const _me = Member(
  id: 'm1',
  householdId: 'h1',
  name: 'Me Person',
  isActive: true,
  userId: 'u1',
);

class _FakeMembersRepository implements MembersRepository {
  final created = <({String householdId, String name})>[];
  var _seq = 0;

  @override
  Future<Member> createMember({
    required String householdId,
    required String name,
  }) async {
    created.add((householdId: householdId, name: name));
    return Member(
      id: 'new-${++_seq}',
      householdId: householdId,
      name: name,
      isActive: true,
    );
  }

  @override
  Future<List<Member>> listMembers({required String householdId}) async =>
      const <Member>[];

  @override
  Future<void> renameMember({
    required String memberId,
    required String name,
  }) async {}

  @override
  Future<bool> hasLinkedPerson({required String householdId}) async => true;

  @override
  Future<void> setMemberActive({
    required String memberId,
    required bool isActive,
  }) async {}

  @override
  Future<void> deleteMember({required String memberId}) async {}
}

class _FakeHouseholdRepository implements HouseholdRepository {
  final invites = <({String householdId, MemberRole role, String? memberId})>[];
  var _seq = 0;

  @override
  Future<String> createInvite({
    required String householdId,
    required MemberRole role,
    int ttlDays = 7,
    String? memberId,
  }) async {
    invites.add((householdId: householdId, role: role, memberId: memberId));
    const codes = ['ABC123', 'DEF456', 'GHI789'];
    return codes[_seq++ % codes.length];
  }

  @override
  Future<Membership?> currentMembership() async =>
      const Membership(household: _household, role: MemberRole.owner);

  @override
  Future<List<Invite>> listInvites({required String householdId}) async =>
      const <Invite>[];

  @override
  Future<void> createHousehold({
    required String name,
    required String currency,
    required String displayName,
  }) async {}

  @override
  Future<void> acceptInvite({required String code, String? displayName}) async {}

  @override
  Future<void> claimMember({required String displayName}) async {}

  @override
  Future<List<HouseholdLogin>> listLogins({required String householdId}) async =>
      const <HouseholdLogin>[];

  @override
  Future<void> updateHouseholdRole({
    required String householdId,
    required String userId,
    required MemberRole role,
  }) async {}

  @override
  Future<void> removeHouseholdLogin({
    required String householdId,
    required String userId,
  }) async {}

  @override
  Future<void> leaveHousehold() async {}
}

Widget _app({
  required MemberRole role,
  required _FakeMembersRepository members,
  required _FakeHouseholdRepository household,
}) =>
    ProviderScope(
      overrides: [
        membershipProvider.overrideWith(
          (ref) async => Membership(household: _household, role: role),
        ),
        authStateProvider.overrideWith((ref) => Stream.value('u1')),
        membersProvider.overrideWith((ref) async => const [_me]),
        householdLoginsProvider.overrideWith(
          (ref) async => [
            HouseholdLogin(
              userId: 'u1',
              role: role,
              joinedAt: DateTime(2026, 1, 1),
            ),
          ],
        ),
        membersRepositoryProvider.overrideWith((ref) => members),
        householdRepositoryProvider.overrideWith((ref) => household),
      ],
      child: const MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: FamilyMembersScreen(),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.person_add_alt_1_outlined));
  await tester.pumpAndSettle();
}

Future<void> _pickLogin(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Create invite code'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Add'));
  await tester.pumpAndSettle();
}

void main() {
  late _FakeMembersRepository members;
  late _FakeHouseholdRepository household;

  setUp(() {
    members = _FakeMembersRepository();
    household = _FakeHouseholdRepository();
  });

  testWidgets('owner: no login creates the person only', (tester) async {
    await _pump(
      tester,
      _app(role: MemberRole.owner, members: members, household: household),
    );

    await _openDialog(tester);
    await tester.enterText(find.byType(TextField), '  Layla  ');
    await tester.pumpAndSettle();
    await _submit(tester);

    expect(members.created, hasLength(1));
    expect(members.created.single.name, 'Layla'); // trimmed
    expect(members.created.single.householdId, 'h1');
    expect(household.invites, isEmpty);
    // No code dialog for the no-login path.
    expect(find.text('ABC123'), findsNothing);
  });

  testWidgets('owner: with login creates the person then a bound invite',
      (tester) async {
    await _pump(
      tester,
      _app(role: MemberRole.owner, members: members, household: household),
    );

    await _openDialog(tester);
    await tester.enterText(find.byType(TextField), 'Omar');
    await tester.pumpAndSettle();
    await _pickLogin(tester);
    await _submit(tester);

    expect(members.created.single.name, 'Omar');
    expect(household.invites, hasLength(1));
    // The invite is bound to the freshly created person (id new-1).
    expect(household.invites.single.memberId, 'new-1');
    expect(household.invites.single.householdId, 'h1');
    expect(household.invites.single.role, MemberRole.adult); // default
    // The code is shown with a copy action.
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('Copy code'), findsOneWidget);
  });

  testWidgets('owner: with login + child role passes child to the invite',
      (tester) async {
    await _pump(
      tester,
      _app(role: MemberRole.owner, members: members, household: household),
    );

    await _openDialog(tester);
    await tester.enterText(find.byType(TextField), 'Kid');
    await tester.pumpAndSettle();
    await _pickLogin(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Child'),
      ),
    );
    await tester.pumpAndSettle();
    await _submit(tester);

    expect(household.invites.single.role, MemberRole.child);
    expect(household.invites.single.memberId, 'new-1');
  });

  testWidgets('adult: can add, and the dialog never offers the owner role',
      (tester) async {
    await _pump(
      tester,
      _app(role: MemberRole.adult, members: members, household: household),
    );

    await _openDialog(tester);
    await _pickLogin(tester);

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

    await tester.enterText(find.byType(TextField), 'Nour');
    await tester.pumpAndSettle();
    await _submit(tester);

    expect(members.created.single.name, 'Nour');
    expect(household.invites.single.role, MemberRole.adult);
  });

  testWidgets('child: the add action is not offered', (tester) async {
    await _pump(
      tester,
      _app(role: MemberRole.child, members: members, household: household),
    );

    expect(find.byIcon(Icons.person_add_alt_1_outlined), findsNothing);
  });

  testWidgets('an empty name keeps the Add button disabled', (tester) async {
    await _pump(
      tester,
      _app(role: MemberRole.owner, members: members, household: household),
    );

    await _openDialog(tester);

    final addButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add'),
    );
    expect(addButton.onPressed, isNull);
    // The role choice only appears on the login path.
    expect(find.text('Invite as'), findsNothing);
  });
}
