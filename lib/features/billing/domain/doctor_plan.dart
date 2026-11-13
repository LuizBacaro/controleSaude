/// Plano do consultório. Paciente não usa este registro.
class DoctorPlan {
  const DoctorPlan({required this.status, this.periodEnd});

  final String status;
  final DateTime? periodEnd;

  bool isActiveAt(DateTime now) {
    if (status != 'active') return false;
    final end = periodEnd;
    if (end == null) return true;
    return end.isAfter(now);
  }

  bool get isActive => isActiveAt(DateTime.now());

  factory DoctorPlan.fromJson(Map<String, dynamic> json) {
    final end = json['current_period_end'];
    return DoctorPlan(
      status: json['status'] as String? ?? 'inactive',
      periodEnd: end is String ? DateTime.tryParse(end) : null,
    );
  }
}
