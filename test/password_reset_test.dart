import 'package:exame_facil/features/auth/data/password_reset.dart';
import 'package:exame_facil/features/auth/presentation/forgot_password_page.dart';
import 'package:exame_facil/features/auth/presentation/login_page.dart';
import 'package:exame_facil/features/auth/presentation/reset_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('o link de recuperação volta para o site ou para o app', () {
    expect(
      passwordResetRedirect(
        web: true,
        webOrigin: 'https://examefacil.pages.dev',
      ),
      'https://examefacil.pages.dev/redefinir-senha',
    );
    expect(
      passwordResetRedirect(web: false, webOrigin: 'http://localhost'),
      'examefacil://redefinir-senha',
    );
    expect(
      isPasswordRecoveryUri(Uri.parse('examefacil://redefinir-senha?code=abc')),
      isTrue,
    );
    expect(
      isPasswordRecoveryUri(
        Uri.parse('https://examefacil.pages.dev/redefinir-senha'),
      ),
      isTrue,
    );
    expect(
      isPasswordRecoveryUri(Uri.parse('https://examefacil.pages.dev/entrar')),
      isFalse,
    );
  });

  testWidgets('entrar mostra o caminho para esquecer a senha', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );

    expect(find.text('Esqueci a senha'), findsOneWidget);
  });

  testWidgets('pedir o link exige um e-mail', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ForgotPasswordPage())),
    );

    await tester.tap(find.text('Enviar link'));
    await tester.pump();

    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
  });

  testWidgets('a senha nova precisa ser igual nos dois campos', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ResetPasswordPage())),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Nova senha'),
      'segredo',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirmar senha'),
      'outra',
    );
    await tester.tap(find.text('Salvar senha'));
    await tester.pump();

    expect(
      find.text('As senhas não são iguais. Digite a mesma nos dois campos.'),
      findsOneWidget,
    );

    final senha = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Nova senha'),
    );
    expect(senha.autofillHints, contains(AutofillHints.newPassword));
    expect(senha.obscureText, isTrue);
  });
}
