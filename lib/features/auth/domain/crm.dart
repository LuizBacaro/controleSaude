/// UF do conselho e número, no mesmo formato exigido pelo banco.
const brazilianUfs = [
  'AC',
  'AL',
  'AP',
  'AM',
  'BA',
  'CE',
  'DF',
  'ES',
  'GO',
  'MA',
  'MT',
  'MS',
  'MG',
  'PA',
  'PB',
  'PR',
  'PE',
  'PI',
  'RJ',
  'RN',
  'RS',
  'RO',
  'RR',
  'SC',
  'SP',
  'SE',
  'TO',
];

/// `null` quando o CRM está válido.
String? validateCrm({required String? uf, required String number}) {
  if (uf == null || !brazilianUfs.contains(uf)) {
    return 'Escolha a UF do CRM.';
  }
  final digits = crmDigits(number);
  if (!RegExp(r'^\d{4,7}$').hasMatch(digits)) {
    return 'O CRM precisa ter de 4 a 7 dígitos.';
  }
  return null;
}

String crmDigits(String number) => number.replaceAll(RegExp(r'\D'), '');
