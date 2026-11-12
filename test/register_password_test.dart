import 'package:exame_facil/features/auth/presentation/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cadastro exige a mesma senha nos dois campos', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RegisterPage())),
    );

    await tester.tap(find.text('Paciente'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'segredo');
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirmar senha'),
      'outra',
    );
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pump();

    expect(
      find.text('As senhas não são iguais. Digite a mesma nos dois campos.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Confirmar senha'),
      'segredo',
    );
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pump();

    expect(
      find.text('Informe data de nascimento e sexo para avaliar os exames.'),
      findsOneWidget,
    );

    final senha = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Senha'),
    );
    expect(senha.autofillHints, contains(AutofillHints.newPassword));
    expect(senha.obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar senha').first);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Senha'))
          .obscureText,
      isFalse,
    );
  });
}
