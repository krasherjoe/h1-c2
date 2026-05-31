import 'package:flutter/foundation.dart' show debugPrint;
import '../models/company_info.dart';
import 'company_repository.dart';

class CompanyProfileService {
  static final CompanyProfileService _instance = CompanyProfileService._internal();
  factory CompanyProfileService() => _instance;
  CompanyProfileService._internal();

  final CompanyRepository _companyRepo = CompanyRepository();

  Future<CompanyInfo?> getProfile() async {
    try {
      return await _companyRepo.getCompanyInfo();
    } catch (e) {
      debugPrint('[CompanyProfileService] getProfile error: $e');
      return null;
    }
  }

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    try {
      await _companyRepo.saveCompanyInfo(CompanyInfo.fromMap(profile));
    } catch (e) {
      debugPrint('[CompanyProfileService] saveProfile error: $e');
      rethrow;
    }
  }
}
