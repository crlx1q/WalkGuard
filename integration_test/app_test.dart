import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:walkguard/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('connects to native Android state without opening camera', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();
    if (find.text('Позже').evaluate().isNotEmpty) {
      await tester.tap(find.text('Позже'));
      await tester.pumpAndSettle();
    }
    expect(find.text('WalkGuard'), findsOneWidget);
    expect(find.text('Взгляд\nвперёд'), findsOneWidget);
    expect(find.textContaining('Android-компонент недоступен'), findsNothing);
  });
}
