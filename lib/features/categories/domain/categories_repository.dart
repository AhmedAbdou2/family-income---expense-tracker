import 'entities.dart';

/// Bilingual categories of a household (single table, four groups).
/// Writes are owner/adult only (enforced by RLS + the app hides the
/// controls from children).
abstract interface class CategoriesRepository {
  Future<List<Category>> listCategories({required String householdId});

  Future<Category> createCategory({
    required String householdId,
    required CategoryGroup group,
    required String nameEn,
    required String nameAr,
    required String icon,
    required String color,
  });

  Future<void> updateCategory({
    required String categoryId,
    required String nameEn,
    required String nameAr,
    required String icon,
    required String color,
  });

  Future<void> deleteCategory({required String categoryId});
}
