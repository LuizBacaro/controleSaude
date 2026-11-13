const passwordResetPath = '/redefinir-senha';

const passwordResetScheme = 'examefacil';

const passwordResetHost = 'redefinir-senha';

/// Endereço que o e-mail de recuperação abre.
///
/// No navegador, o link volta para o mesmo site. No celular, o esquema
/// `examefacil` reabre este app, onde o código do e-mail pode ser trocado
/// pela sessão. O Supabase só aceita esse esquema se ele estiver na lista
/// de Redirect URLs.
String passwordResetRedirect({required bool web, required String webOrigin}) {
  if (web) {
    var origin = webOrigin;
    if (origin.endsWith('/')) {
      origin = origin.substring(0, origin.length - 1);
    }
    return '$origin$passwordResetPath';
  }
  return '$passwordResetScheme://$passwordResetHost';
}

bool isPasswordRecoveryUri(Uri uri) {
  if (uri.scheme == passwordResetScheme && uri.host == passwordResetHost) {
    return true;
  }
  var path = uri.path;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path == passwordResetPath;
}
