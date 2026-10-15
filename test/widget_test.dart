import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_jasmyn_p4/main.dart';

void main() {
  testWidgets('Solicita usuario y contraseña', (tester) async {
    await tester.pumpWidget(const ParkingApp());
    expect(find.text('Parqueo Jasmyn'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
    await tester.pump();
    expect(find.text('Escriba el usuario.'), findsOneWidget);
    expect(find.text('Escriba la contraseña.'), findsOneWidget);
  });
}
