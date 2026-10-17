class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.birthDate,
    this.sex,
    this.role = 'patient',
    this.crmUf,
    this.crmNumber,
  });

  final String id;
  final String email;
  final String displayName;
  final DateTime? birthDate;
  final String? sex; // M | F
  final String role;
  final String? crmUf;
  final String? crmNumber;

  bool get isDoctor => role == 'doctor';

  String? get crmLabel {
    if (crmUf == null || crmNumber == null) return null;
    return 'CRM/$crmUf $crmNumber';
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String? ?? '',
        birthDate: json['birth_date'] != null
            ? DateTime.tryParse(json['birth_date'] as String)
            : null,
        sex: json['sex'] as String?,
        role: json['role'] as String? ?? 'patient',
        crmUf: json['crm_uf'] as String?,
        crmNumber: json['crm_number'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'birth_date': birthDate?.toIso8601String(),
        'sex': sex,
        'role': role,
        'crm_uf': crmUf,
        'crm_number': crmNumber,
      };

  AppUser copyWith({
    String? displayName,
    DateTime? birthDate,
    String? sex,
    String? role,
    String? crmUf,
    String? crmNumber,
  }) =>
      AppUser(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
        birthDate: birthDate ?? this.birthDate,
        sex: sex ?? this.sex,
        role: role ?? this.role,
        crmUf: crmUf ?? this.crmUf,
        crmNumber: crmNumber ?? this.crmNumber,
      );
}
