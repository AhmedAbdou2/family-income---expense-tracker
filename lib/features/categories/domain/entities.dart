/// Category group ("group" is a reserved SQL word - always quoted in SQL).
/// Pure Dart - no Flutter or Supabase imports.
enum CategoryGroup {
  general('general'),
  car('car'),
  fixed('fixed'),
  pet('pet'),
  income('income');

  const CategoryGroup(this.dbValue);

  final String dbValue;

  static CategoryGroup fromDb(String value) =>
      CategoryGroup.values.firstWhere((group) => group.dbValue == value);
}

class Category {
  const Category({
    required this.id,
    required this.householdId,
    required this.group,
    required this.nameEn,
    required this.nameAr,
    this.icon = 'category',
    this.color = '#78909C',
    this.isDefault = false,
  });

  final String id;
  final String householdId;
  final CategoryGroup group;
  final String nameEn;
  final String nameAr;
  final String icon;
  final String color;
  final bool isDefault;

  String localizedName(String languageCode) =>
      languageCode == 'ar' ? nameAr : nameEn;
}
