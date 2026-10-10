import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/core/settings/settings_controller.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/vehicles/domain/entities.dart';
import 'package:family_income_expense_tracker/features/vehicles/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/vehicles/presentation/vehicle_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Regression guard for "BoxConstraints forces an infinite width": the global
/// button theme uses `minimumSize: Size.fromHeight(...)` (infinite width), so
/// any button placed in an unbounded-width `Row` (the section headers' action
/// buttons) exploded layout and broke the whole screen - including the
/// "Add fill-up" tap. These tests pump the detail screen at several widths and
/// fail on ANY layout exception, then prove the tap still routes.
class _TestSettings extends SettingsController {
  @override
  SettingsState build() => const SettingsState();
}

const _household = Household(id: 'h1', name: 'Home', currency: 'EGP');
const _vehicle = Vehicle(
  id: 'v1',
  householdId: 'h1',
  name: 'Corolla',
  fuelType: FuelType.petrol,
  currentOdometerKm: 12000,
  isActive: true,
  plate: 'ABC-123',
);

GoRouter _buildRouter() => GoRouter(
      initialLocation: '/vehicles/v1',
      routes: [
        GoRoute(
          path: '/vehicles/:id',
          builder: (context, state) =>
              VehicleDetailScreen(vehicleId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/vehicles/:id/fuel/new',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('FUEL_FORM_STUB'))),
        ),
        GoRoute(
          path: '/vehicles/:id/maintenance/new',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('MAINT_FORM_STUB'))),
        ),
      ],
    );

Widget _app(GoRouter router) => ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_TestSettings.new),
        membershipProvider.overrideWith(
          (ref) async => const Membership(
            household: _household,
            role: MemberRole.owner,
          ),
        ),
        vehiclesProvider.overrideWith((ref) async => const [_vehicle]),
        fuelLogsProvider('v1').overrideWith((ref) async => const <FuelLog>[]),
        fuelLogsProvider(null).overrideWith((ref) async => const <FuelLog>[]),
        maintenanceProvider('v1')
            .overrideWith((ref) async => const <MaintenanceItem>[]),
        maintenanceProvider(null)
            .overrideWith((ref) async => const <MaintenanceItem>[]),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
      ),
    );

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = _buildRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(_app(router));
  // Resolve the overridden futures without pumpAndSettle (the loading
  // spinner animates forever and would hang it).
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.text('Corolla').evaluate().isNotEmpty) break;
  }
}

void main() {
  testWidgets('lays out at a narrow phone width without exceptions',
      (tester) async {
    await _pumpAt(tester, const Size(360, 640));

    expect(tester.takeException(), isNull);
    expect(find.text('Corolla'), findsWidgets);
    // Both section-header action buttons exist (they live in a Row).
    expect(find.text('Add fill-up'), findsWidgets);
    expect(find.text('Add reminder'), findsWidgets);
  });

  testWidgets('lays out at a wide width without exceptions', (tester) async {
    await _pumpAt(tester, const Size(1200, 800));

    expect(tester.takeException(), isNull);
    expect(find.text('Corolla'), findsWidgets);
  });

  testWidgets('tapping "Add fill-up" opens the fuel log form', (tester) async {
    await _pumpAt(tester, const Size(390, 844));

    // The section-header button (not the detail FAB) is the first FilledButton
    // whose label is "Add fill-up".
    final addFillUp = find.ancestor(
      of: find.text('Add fill-up'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(addFillUp, findsOneWidget);

    await tester.tap(addFillUp);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text('FUEL_FORM_STUB').evaluate().isNotEmpty) break;
    }
    expect(find.text('FUEL_FORM_STUB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
