import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ui/minirok_glass.dart';
import 'package:zeus_chat/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts without credentials and toggles the original glass', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();
    expect(find.text('ذكاؤك، بطريقتك'), findsOneWidget);
    expect(find.byType(FlClashNavigationDock), findsOneWidget);
    expect(find.byType(LiquidGlass), findsWidgets);
    await tester.tap(find.byKey(const Key('welcome-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('glass-setting')));
    await tester.pumpAndSettle();
    final scopes = tester.widgetList<LiquidGlassScope>(
      find.byType(LiquidGlassScope),
    );
    expect(scopes.first.enabled, isFalse);
  });
}
