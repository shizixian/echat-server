import 'package:flutter_test/flutter_test.dart';
import 'package:echat/main.dart';

void main() {
  testWidgets('App loads and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EChatApp());
    expect(find.text('EChat'), findsOneWidget);
  });
}
