class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.birthDate,
    this.sex,
  });

  final String id;
  final String email;
  final String displayName;
  final DateTime? birthDate;
  final String? sex; // M | F

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String? ?? '',
        birthDate: json['birth_date'] != null
            ? DateTime.tryParse(json['birth_date'] as String)
            : null,
        sex: json['sex'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'birth_date': birthDate?.toIso8601String(),
        'sex': sex,
      };

  AppUser copyWith({
    String? displayName,
    DateTime? birthDate,
    String? sex,
  }) =>
      AppUser(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
        birthDate: birthDate ?? this.birthDate,
        sex: sex ?? this.sex,
      );
}
