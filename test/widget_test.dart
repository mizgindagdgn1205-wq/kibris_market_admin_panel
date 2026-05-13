
import 'package:flutter_test/flutter_test.dart';
import 'package:kibris_market_admin_panel/main.dart';

void main() {
  testWidgets('placeholder test', (WidgetTester tester) async {
    expect(true, isTrue);
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AdminApp());
  });
}
