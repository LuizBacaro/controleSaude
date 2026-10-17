/// Sexo e idade usados para escolher a faixa de referência certa do laudo.
class PatientProfile {
  const PatientProfile({this.sex, this.birthDate, this.age});

  /// `M` ou `F`.
  final String? sex;
  final DateTime? birthDate;

  /// Idade impressa no PDF, quando não há data de nascimento.
  final int? age;

  int? ageAt(DateTime date) {
    final birth = birthDate;
    if (birth == null) return age;
    var years = date.year - birth.year;
    if (date.month < birth.month ||
        (date.month == birth.month && date.day < birth.day)) {
      years--;
    }
    return years;
  }

  /// Dados do PDF têm prioridade; o perfil completa o que faltar.
  PatientProfile orElse(PatientProfile? other) => PatientProfile(
    sex: sex ?? other?.sex,
    birthDate: birthDate ?? other?.birthDate,
    age: age ?? other?.age,
  );
}
