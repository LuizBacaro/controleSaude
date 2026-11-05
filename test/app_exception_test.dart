import 'dart:io';

import 'package:exame_facil/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('esconde falha de DNS do cadastro', () {
    final error = AuthRetryableFetchException(
      message:
          "ClientException with SocketException: Failed host lookup: "
          "'xdzognwurazkbmckzldf.supabase.co' "
          '(OS Error: No address associated with hostname, errno = 7), '
          'uri=https://xdzognwurazkbmckzldf.supabase.co/auth/v1/signup?',
    );

    expect(AppException.isTransientNetwork(error), isTrue);
    expect(
      AppException.messageOf(error),
      'Sem conexão com a internet. Confira o Wi-Fi ou os dados móveis e tente de novo.',
    );
    expect(AppException.messageOf(error), isNot(contains('supabase')));
    expect(AppException.messageOf(error), isNot(contains('errno')));
  });

  test('traduz e-mail já cadastrado e senha errada', () {
    expect(
      AppException.messageOf(const AuthException('User already registered')),
      'Já existe uma conta com este e-mail. Entre com a senha.',
    );
    expect(
      AppException.messageOf(
        const AuthApiException('Invalid login credentials'),
      ),
      'E-mail ou senha não conferem.',
    );
  });

  test('mantém frase já escrita para a pessoa', () {
    expect(
      AppException.messageOf(Exception('Informe um e-mail válido.')),
      'Informe um e-mail válido.',
    );
    expect(
      AppException.messageOf(
        const FormatException(
          'Não foi possível encontrar a data de atendimento no PDF.',
        ),
      ),
      'Não foi possível encontrar a data de atendimento no PDF.',
    );
  });

  test('não mostra erro desconhecido de sistema', () {
    final error = ClientException(
      'boom',
      Uri.parse('https://xdzognwurazkbmckzldf.supabase.co/auth/v1/signup'),
    );
    expect(AppException.messageOf(error), AppException.offline);
    expect(
      AppException.messageOf(StateError('bad state at #42')),
      AppException.generic,
    );
    expect(
      AppException.messageOf(
        const SocketException(
          'Failed host lookup',
          osError: OSError('No address associated with hostname', 7),
        ),
      ),
      AppException.offline,
    );
  });
}
