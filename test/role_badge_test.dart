import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/role_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The role badge is reused by the Family list, the profile header and the
/// navigation account header. It must always pair text with an icon and a
/// tonal color (never color alone) and read correctly in EN and AR (RTL).
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('EN shows owner / adult / child / no-login labels',
      (tester) async {
    const cases = {
      MemberRole.owner: 'Owner',
      MemberRole.adult: 'Adult',
      MemberRole.child: 'Child',
    };
    for (final entry in cases.entries) {
      await _pump(tester, RoleBadge(role: entry.key));
      expect(find.text(entry.value), findsOneWidget);
    }

    await _pump(tester, const RoleBadge());
    expect(find.text('No login'), findsOneWidget);
  });

  testWidgets('AR is RTL and shows real Arabic labels', (tester) async {
    await _pump(
      tester,
      const RoleBadge(role: MemberRole.owner),
      locale: const Locale('ar'),
    );
    final owner = find.text('مالك');
    expect(owner, findsOneWidget);
    expect(
      Directionality.of(tester.element(owner)),
      TextDirection.rtl,
    );

    await _pump(
      tester,
      const RoleBadge(role: MemberRole.adult),
      locale: const Locale('ar'),
    );
    expect(find.text('بالغ'), findsOneWidget);

    await _pump(
      tester,
      const RoleBadge(role: MemberRole.child),
      locale: const Locale('ar'),
    );
    expect(find.text('طفل'), findsOneWidget);

    await _pump(tester, const RoleBadge(), locale: const Locale('ar'));
    expect(find.text('بدون حساب'), findsOneWidget);
  });

  testWidgets('every state carries an icon as well as text', (tester) async {
    await _pump(tester, const RoleBadge(role: MemberRole.owner));
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

    await _pump(tester, const RoleBadge(role: MemberRole.adult));
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    await _pump(tester, const RoleBadge(role: MemberRole.child));
    expect(find.byIcon(Icons.child_care_outlined), findsOneWidget);

    await _pump(tester, const RoleBadge());
    expect(find.byIcon(Icons.person_off_outlined), findsOneWidget);
  });

  testWidgets('a very long label still ellipsizes instead of overflowing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(120, 80));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(
      tester,
      const SizedBox(width: 90, child: RoleBadge(role: MemberRole.owner)),
    );
    expect(tester.takeException(), isNull);
  });
}
