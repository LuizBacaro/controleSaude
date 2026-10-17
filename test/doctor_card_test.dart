import 'package:exame_facil/core/theme/app_theme.dart';
import 'package:exame_facil/features/care/domain/care_grant.dart';
import 'package:exame_facil/features/care/presentation/doctors_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('cartão do médico mostra o nome na largura do celular', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: DoctorInviteCard(
            doctor: DoctorListing(
              id: '1',
              displayName: 'Mariana',
              crmUf: 'SP',
              crmNumber: '123456',
            ),
            grant: null,
            busy: false,
            onInvite: _noop,
            onRevoke: _ignoreGrant,
          ),
        ),
      ),
    );

    expect(find.text('Mariana'), findsOneWidget);
    expect(find.text('CRM/SP 123456'), findsOneWidget);
    expect(find.text('Convidar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aceitar e recusar cabem lado a lado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Recusar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('Aceitar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Aceitar'), findsOneWidget);
    expect(find.text('Recusar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

void _ignoreGrant(CareGrant grant) {}
