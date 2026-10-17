class CareGrant {
  const CareGrant({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.status,
    required this.patientName,
    required this.doctorName,
    required this.doctorCrmUf,
    required this.doctorCrmNumber,
  });

  final String id;
  final String patientId;
  final String doctorId;
  final String status;
  final String patientName;
  final String doctorName;
  final String doctorCrmUf;
  final String doctorCrmNumber;

  String get doctorCrmLabel => 'CRM/$doctorCrmUf $doctorCrmNumber';

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRevoked => status == 'revoked';

  factory CareGrant.fromJson(Map<String, dynamic> json) => CareGrant(
    id: json['id'] as String,
    patientId: json['patient_id'] as String,
    doctorId: json['doctor_id'] as String,
    status: json['status'] as String? ?? 'pending',
    patientName: json['patient_name'] as String? ?? '',
    doctorName: json['doctor_name'] as String? ?? '',
    doctorCrmUf: json['doctor_crm_uf'] as String? ?? '',
    doctorCrmNumber: json['doctor_crm_number'] as String? ?? '',
  );
}

class DoctorListing {
  const DoctorListing({
    required this.id,
    required this.displayName,
    required this.crmUf,
    required this.crmNumber,
  });

  final String id;
  final String displayName;
  final String crmUf;
  final String crmNumber;

  String get crmLabel => 'CRM/$crmUf $crmNumber';

  factory DoctorListing.fromJson(Map<String, dynamic> json) => DoctorListing(
    id: json['id'] as String,
    displayName: json['display_name'] as String? ?? '',
    crmUf: json['crm_uf'] as String? ?? '',
    crmNumber: json['crm_number'] as String? ?? '',
  );
}
