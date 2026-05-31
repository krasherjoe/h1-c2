import '../models/custom_field_model.dart';

class CustomFieldRepository {
  static final CustomFieldRepository _instance = CustomFieldRepository._internal();
  factory CustomFieldRepository() => _instance;
  CustomFieldRepository._internal();

  Future<List<CustomField>> getActiveFieldsByBusinessProfile(String businessProfileId) async => [];
}
