import 'package:flutter_test/flutter_test.dart';
import 'package:moustache_ping/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MoustachePingApp());
  });
}
