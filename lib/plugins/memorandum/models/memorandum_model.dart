enum MonthlyPlan { plan3000, plan5000, plan8000, planCustom }

extension MonthlyPlanX on MonthlyPlan {
  int amount(int? customAmount) {
    switch (this) {
      case MonthlyPlan.plan3000: return 3000;
      case MonthlyPlan.plan5000: return 5000;
      case MonthlyPlan.plan8000: return 8000;
      case MonthlyPlan.planCustom: return customAmount ?? 0;
    }
  }

  String label(int? customAmount) {
    switch (this) {
      case MonthlyPlan.plan3000: return '3,000円';
      case MonthlyPlan.plan5000: return '5,000円';
      case MonthlyPlan.plan8000: return '8,000円';
      case MonthlyPlan.planCustom:
        return customAmount != null ? '$customAmount円' : 'カスタム';
    }
  }
}

enum MemorandumStatus { draft, confirmed }

class Memorandum {
  final String id;
  final String documentNumber;
  final String customerId;
  final String customerName;
  final DateTime contractDate;
  final DateTime startDate;
  final DateTime endDate;
  final int contractMonths;
  final MonthlyPlan monthlyPlan;
  final int? customAmount;
  final String serviceContent;
  final int totalAmount;
  final String? notes;
  final String? projectId;
  final String? estimateId;
  final MemorandumStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get monthlyAmount => monthlyPlan.amount(customAmount);

  const Memorandum({
    required this.id,
    required this.documentNumber,
    required this.customerId,
    required this.customerName,
    required this.contractDate,
    required this.startDate,
    required this.endDate,
    required this.contractMonths,
    required this.monthlyPlan,
    this.customAmount,
    required this.serviceContent,
    required this.totalAmount,
    this.notes,
    this.projectId,
    this.estimateId,
    this.status = MemorandumStatus.draft,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'document_number': documentNumber,
    'customer_id': customerId,
    'customer_name': customerName,
    'contract_date': contractDate.toIso8601String(),
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'contract_months': contractMonths,
    'monthly_plan': monthlyPlan.name,
    'custom_amount': customAmount,
    'service_content': serviceContent,
    'total_amount': totalAmount,
    'notes': notes,
    'project_id': projectId,
    'estimate_id': estimateId,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Memorandum.fromMap(Map<String, dynamic> map) => Memorandum(
    id: map['id'] as String? ?? '',
    documentNumber: map['document_number'] as String? ?? '',
    customerId: map['customer_id'] as String? ?? '',
    customerName: map['customer_name'] as String? ?? '',
    contractDate: DateTime.parse(map['contract_date'] as String? ?? ''),
    startDate: DateTime.parse(map['start_date'] as String? ?? ''),
    endDate: DateTime.parse(map['end_date'] as String? ?? ''),
    contractMonths: map['contract_months'] as int? ?? 0,
    monthlyPlan: MonthlyPlan.values.firstWhere(
      (e) => e.name == ((map['monthly_plan'] as String?) ?? 'plan3000'),
      orElse: () => MonthlyPlan.plan3000,
    ),
    customAmount: map['custom_amount'] as int?,
    serviceContent: map['service_content'] as String? ?? '',
    totalAmount: map['total_amount'] as int? ?? 0,
    notes: map['notes'] as String?,
    projectId: map['project_id'] as String?,
    estimateId: map['estimate_id'] as String?,
    status: MemorandumStatus.values.firstWhere(
      (e) => e.name == ((map['status'] as String?) ?? 'draft'),
      orElse: () => MemorandumStatus.draft,
    ),
    createdAt: DateTime.parse(map['created_at'] as String? ?? ''),
    updatedAt: DateTime.parse(map['updated_at'] as String? ?? ''),
  );

  Memorandum copyWith({
    String? id,
    String? documentNumber,
    String? customerId,
    String? customerName,
    DateTime? contractDate,
    DateTime? startDate,
    DateTime? endDate,
    int? contractMonths,
    MonthlyPlan? monthlyPlan,
    int? customAmount,
    String? serviceContent,
    int? totalAmount,
    String? notes,
    String? projectId,
    String? estimateId,
    MemorandumStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Memorandum(
    id: id ?? this.id,
    documentNumber: documentNumber ?? this.documentNumber,
    customerId: customerId ?? this.customerId,
    customerName: customerName ?? this.customerName,
    contractDate: contractDate ?? this.contractDate,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    contractMonths: contractMonths ?? this.contractMonths,
    monthlyPlan: monthlyPlan ?? this.monthlyPlan,
    customAmount: customAmount ?? this.customAmount,
    serviceContent: serviceContent ?? this.serviceContent,
    totalAmount: totalAmount ?? this.totalAmount,
    notes: notes ?? this.notes,
    projectId: projectId ?? this.projectId,
    estimateId: estimateId ?? this.estimateId,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
