import 'package:exame_facil/features/auth/presentation/widgets/health_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('máscara e data inválida', () {
    expect(parseBirthDate('12/11/1995'), DateTime(1995, 11, 12));
    expect(parseBirthDate('31/02/1995'), isNull);
    expect(parseBirthDate('12/11'), isNull);
  });

  testWidgets('a data de nascimento ganha as barras ao digitar', (
    tester,
  ) async {
    DateTime? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HealthFields(
            birthDate: saved,
            sex: null,
            onBirthDate: (date) => saved = date,
            onSex: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('dd/mm/aaaa'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Data de nascimento'),
      '12111995',
    );
    await tester.pump();

    expect(find.text('12/11/1995'), findsOneWidget);
    expect(saved, DateTime(1995, 11, 12));
  });
}
