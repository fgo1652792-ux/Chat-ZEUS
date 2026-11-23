import 'package:flutter_test/flutter_test.dart';
import 'package:ui/minirok_glass.dart';
import 'package:zeus_chat/main.dart';

void main() {
  testWidgets('mounts the imported glass host', (tester) async {
    await tester.pumpWidget(const ZeusApp());
    expect(find.byType(LiquidGlassHost), findsOneWidget);
    expect(find.byType(LiquidGlassScope), findsOneWidget);
    expect(find.text('Zeus Chat'), findsOneWidget);
  });
}
