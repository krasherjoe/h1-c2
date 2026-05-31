import 'database_helper.dart';
import '../models/project_model.dart';

class ProjectRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<dynamic>> getAllProjects() async => [];

  Future<dynamic> getById(String id) async => null;

  Future<dynamic> save(dynamic project) async => null;

  Future<void> delete(String id) async {}

  Future<dynamic> createProject({
    required String name,
    required String customerId,
    required String customerName,
    required dynamic status,
    DateTime? startDate,
  }) async => null;

  Future<void> linkDocument({
    required String projectId,
    required String table,
    required String documentId,
  }) async {}

  Future<List<Project>> getProjectsByCustomer(String customerId) async => [];

  Future<List<Project>> getAll() async => [];
}
