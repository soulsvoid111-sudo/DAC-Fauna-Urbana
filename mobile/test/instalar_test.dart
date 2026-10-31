import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/instalar_screen.dart';
import 'package:mobile/theme.dart';

void main() {
  testWidgets('carrossel de instalação: troca de aparelho e avança os passos', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const InstalarScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Abra o SOFUR no Chrome'), findsOneWidget);
    expect(find.text('PASSO 1 DE 5'), findsOneWidget);

    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('Toque nos três pontinhos'), findsOneWidget);

    await tester.tap(find.text('iPhone • Safari'));
    await tester.pumpAndSettle();
    expect(find.text('Abra o SOFUR no Safari'), findsOneWidget, reason: 'trocar de aparelho volta ao passo 1');

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Pronto!'), findsOneWidget);
    expect(find.text('Entendi'), findsOneWidget);
  });
}
