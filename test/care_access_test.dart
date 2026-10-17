import 'package:exame_facil/core/router/home_location.dart';
import 'package:exame_facil/features/auth/domain/crm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('médico entra no consultório e paciente com exame no painel', () {
    expect(homeLocation(isDoctor: true, hasExams: false), '/consultorio');
    expect(homeLocation(isDoctor: true, hasExams: true), '/consultorio');
    expect(homeLocation(isDoctor: false, hasExams: true), '/app');
    expect(
      homeLocation(isDoctor: false, hasExams: false),
      '/importar?onboarding=1',
    );
  });

  test('área do paciente não inclui o consultório', () {
    expect(isPatientArea('/app'), isTrue);
    expect(isPatientArea('/app/medicos'), isTrue);
    expect(isPatientArea('/importar'), isTrue);
    expect(isPatientArea('/marcador'), isTrue);
    expect(isPatientArea('/consultorio'), isFalse);
    expect(isPatientArea('/consultorio/paciente/1'), isFalse);
  });

  test('CRM aceita UF e de 4 a 7 dígitos', () {
    expect(validateCrm(uf: 'SP', number: '123456'), isNull);
    expect(validateCrm(uf: 'sp', number: '123456'), isNotNull);
    expect(validateCrm(uf: null, number: '123456'), isNotNull);
    expect(validateCrm(uf: 'SP', number: '12'), isNotNull);
    expect(validateCrm(uf: 'SP', number: '12345678'), isNotNull);
    expect(crmDigits('12.345-6'), '123456');
  });
}
