import 'package:flutter_test/flutter_test.dart';
import 'package:nomi/app/app.dart';

void main() {
  testWidgets('Nomi app starts', (tester) async {
    await tester.pumpWidget(const KopaApp());
    await tester.pump();

    expect(find.byType(KopaApp), findsOneWidget);
  });
}