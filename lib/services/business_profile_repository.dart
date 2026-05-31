class BusinessProfileRepository {
  static final BusinessProfileRepository _instance = BusinessProfileRepository._internal();
  factory BusinessProfileRepository() => _instance;
  BusinessProfileRepository._internal();

  Future<dynamic> getCurrentProfile() async => null;
  Future<void> saveProfile(dynamic profile) async {}
}
