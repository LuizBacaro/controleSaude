import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Erro que o app pode mostrar na tela.
///
/// [message] é sempre uma frase curta, em português, sem endereço, código
/// ou nome de classe. A causa técnica fica só em [cause], para depuração.
class AppException implements Exception {
  AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  static const offline =
      'Sem conexão com a internet. Confira o Wi-Fi ou os dados móveis e tente de novo.';

  static const timeout = 'A conexão demorou demais. Tente de novo.';

  static const generic =
      'Não foi possível concluir agora. Tente de novo em alguns instantes.';

  /// Texto seguro para qualquer erro que chegue na interface.
  static String messageOf(Object error) => AppException.from(error).message;

  /// Falha de rede que costuma passar na tentativa seguinte.
  static bool isTransientNetwork(Object error) {
    if (error is TimeoutException ||
        error is http.ClientException ||
        error is AuthRetryableFetchException) {
      return true;
    }
    final name = error.runtimeType.toString();
    if (name == 'SocketException' ||
        name == 'HttpException' ||
        name == 'HandshakeException' ||
        name == 'TlsException') {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('failed host lookup') ||
        text.contains('socketexception') ||
        text.contains('no address associated') ||
        text.contains('network is unreachable') ||
        text.contains('connection timed out') ||
        text.contains('connection reset') ||
        text.contains('connection closed');
  }

  factory AppException.from(Object error, {String? fallback}) {
    if (error is AppException) return error;
    if (isTransientNetwork(error)) {
      final text = error.toString().toLowerCase();
      final slow =
          error is TimeoutException ||
          text.contains('timed out') ||
          text.contains('demorou');
      return AppException(slow ? timeout : offline, cause: error);
    }
    if (error is AuthException) {
      return AppException(
        _authMessage(error.message, fallback: fallback),
        cause: error,
      );
    }
    if (error is PostgrestException) {
      return AppException(
        _userText(error.message) ?? fallback ?? generic,
        cause: error,
      );
    }
    if (error is FormatException) {
      return AppException(
        _userText(error.message) ??
            'Não foi possível ler este arquivo. Use o PDF do laboratório.',
        cause: error,
      );
    }
    return AppException(
      _userText(error.toString()) ?? fallback ?? generic,
      cause: error,
    );
  }

  @override
  String toString() => message;

  static String _authMessage(String message, {String? fallback}) {
    final lower = message.toLowerCase();
    if (lower.contains('already registered') ||
        lower.contains('already been registered')) {
      return 'Já existe uma conta com este e-mail. Entre com a senha.';
    }
    if (lower.contains('invalid login') ||
        lower.contains('invalid credentials')) {
      return 'E-mail ou senha não conferem.';
    }
    if (lower.contains('password') &&
        (lower.contains('6') || lower.contains('weak'))) {
      return 'A senha precisa ter pelo menos 6 caracteres.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Falta confirmar o e-mail. Abra a mensagem que enviamos e depois entre.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Muitas tentativas seguidas. Espere um pouco e tente de novo.';
    }
    if (lower.contains('profiles_crm_unique')) {
      return 'Este CRM já está cadastrado.';
    }
    if (lower.contains('profiles_doctor_crm')) {
      return 'Não foi possível criar a conta. Confira o CRM.';
    }
    if (lower.contains('database') && lower.contains('crm')) {
      return 'Não foi possível criar a conta. Confira o CRM; ele pode já estar em uso.';
    }
    return _userText(message) ?? fallback ?? generic;
  }

  /// Aceita só frases já escritas para a pessoa. Descarta o resto.
  static String? _userText(String raw) {
    var text = raw.trim();
    text = text.replaceFirst(RegExp(r'^[A-Za-z0-9_]*Exception:\s*'), '');
    text = text.trim();
    if (text.isEmpty || text.length > 220) return null;
    final lower = text.toLowerCase();
    const blocked = [
      'exception',
      'errno',
      'socket',
      'clientexception',
      'http',
      'supabase',
      'postgrest',
      'stack',
      'failed host',
      'os error',
      'statuscode',
      'status code',
      'jwt',
      'null',
      'undefined',
    ];
    for (final word in blocked) {
      if (lower.contains(word)) return null;
    }
    if (text.contains('://') || text.contains('@') || text.contains('/')) {
      return null;
    }
    const portuguese = [
      'não',
      'nao',
      'já',
      'ja ',
      'senha',
      'conta',
      'tente',
      'informe',
      'confira',
      'preencha',
      'escolha',
      'entre',
      'médico',
      'medico',
      'paciente',
      'laudo',
      'exame',
      'arquivo',
      'convite',
      'salvar',
      'marque',
      'nascimento',
      'permiss',
      'revog',
      'e-mail',
      'email',
    ];
    if (!portuguese.any(lower.contains)) return null;
    return text;
  }
}
