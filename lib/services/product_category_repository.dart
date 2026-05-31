import '../models/product_category_model.dart';
import 'database_helper.dart';

class ProductCategoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<ProductCategory>> getAllCategories({bool includeInactive = false}) async => [];

  Future<ProductCategory?> getCategoryById(String id) async => null;

  Future<String> getOrCreateCategoryId(String name) async => '';

  Future<void> save(ProductCategory category) async {}

  Future<void> delete(String id) async {}

  Future<void> deleteCategory(String id) async {}
}
