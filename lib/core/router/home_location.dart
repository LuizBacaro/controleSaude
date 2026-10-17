/// Para onde ir depois do login. Médico não cai na importação do PDF.
String homeLocation({required bool isDoctor, required bool hasExams}) {
  if (isDoctor) return '/consultorio';
  if (hasExams) return '/app';
  return '/importar?onboarding=1';
}

bool isPatientArea(String location) {
  return location == '/app' ||
      location.startsWith('/app/') ||
      location.startsWith('/importar') ||
      location.startsWith('/marcador') ||
      location.startsWith('/laudo');
}
