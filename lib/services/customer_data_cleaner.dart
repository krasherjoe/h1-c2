class HonorificsIssue {
  final dynamic original;
  final String fixedFormalName;
  final String fixedDisplayName;
  final List<String> reasons;

  HonorificsIssue({
    required this.original,
    required this.fixedFormalName,
    required this.fixedDisplayName,
    required this.reasons,
  });

  dynamic get fixed => null;

  bool get hasChange => false;
}

class CustomerDataCleaner {
  static HonorificsIssue? analyzeCustomer(dynamic customer) => null;

  static List<HonorificsIssue> screenAll(List<dynamic> customers) => [];
}
