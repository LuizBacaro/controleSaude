import 'package:exame_facil/core/router/marker_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('marcador com acento vai na query e volta inteiro', () {
    const names = [
      'Colesterol HDL',
      'Colesterol não HDL',
      'Ácido úrico',
      'Triglicerídeos',
      'PCR ultrassensível',
    ];
    for (final name in names) {
      final uri = Uri.parse(markerRoute(name));
      expect(uri.path, '/marcador');
      expect(uri.queryParameters['nome'], name);
    }
  });

  testWidgets('GoRouter abre marcador com acento sem invalid argument', (
    tester,
  ) async {
    const name = 'Colesterol não HDL';
    final router = GoRouter(
      initialLocation: markerRoute(name),
      routes: [
        GoRoute(
          path: '/marcador',
          builder: (context, state) =>
              Text(state.uri.queryParameters['nome'] ?? ''),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text(name), findsOneWidget);
  });
}
