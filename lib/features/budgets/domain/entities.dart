/// A monthly budget limit. Pure Dart - no Flutter or Supabase imports.
///
/// Exactly one of two shapes exists per household:
///   * a CATEGORY limit: [categoryId] is set;
///   * the single OVERALL limit: [categoryId] is null.
///
/// Pausing keeps the row (and its slot) but drops it from progress alerts.
class Budget {
  const Budget({
    required this.id,
    required this.householdId,
    required this.amountMinorUnits,
    required this.isActive,
    this.categoryId,
  });

  final String id;
  final String householdId;

  /// Category this limit applies to, or null for the overall limit.
  final String? categoryId;
  final int amountMinorUnits;
  final bool isActive;

  bool get isOverall => categoryId == null;
}
