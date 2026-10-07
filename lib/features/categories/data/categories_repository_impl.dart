import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/categories_repository.dart';
import '../domain/entities.dart';

class CategoriesRepositoryImpl implements CategoriesRepository {
  CategoriesRepositoryImpl(this._client);

  final SupabaseClient _client;

  Category _map(Map<String, dynamic> row) => Category(
        id: row['id'] as String,
        householdId: row['household_id'] as String,
        group: CategoryGroup.fromDb(row['group'] as String),
        nameEn: row['name_en'] as String,
        nameAr: row['name_ar'] as String,
        icon: row['icon'] as String? ?? 'category',
        color: row['color'] as String? ?? '#78909C',
        isDefault: row['is_default'] as bool? ?? false,
      );

  @override
  Future<List<Category>> listCategories({required String householdId}) async {
    try {
      final rows = await _client
          .from('categories')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: true);
      return rows.map(_map).toList();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<Category> createCategory({
    required String householdId,
    required CategoryGroup group,
    required String nameEn,
    required String nameAr,
    required String icon,
    required String color,
  }) async {
    try {
      final row = await _client
          .from('categories')
          .insert({
            'household_id': householdId,
            'group': group.dbValue,
            'name_en': nameEn.trim(),
            'name_ar': nameAr.trim(),
            'icon': icon,
            'color': color,
          })
          .select()
          .single();
      return _map(row);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> updateCategory({
    required String categoryId,
    required String nameEn,
    required String nameAr,
    required String icon,
    required String color,
  }) async {
    try {
      await _client.from('categories').update({
        'name_en': nameEn.trim(),
        'name_ar': nameAr.trim(),
        'icon': icon,
        'color': color,
      }).eq('id', categoryId);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> deleteCategory({required String categoryId}) async {
    try {
      await _client.from('categories').delete().eq('id', categoryId);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }
}
