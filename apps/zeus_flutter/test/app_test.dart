import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ui/minirok_glass.dart';
import 'package:zeus_chat/data/local_store.dart';
import 'package:zeus_chat/main.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('mounts the imported glass host', (tester) async {
    await tester.pumpWidget(
      ZeusApp(
        openStore: () => LocalStore.open(
          factory: databaseFactoryFfiNoIsolate,
          name: inMemoryDatabasePath,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LiquidGlassHost), findsOneWidget);
    expect(find.byType(LiquidGlassScope), findsOneWidget);
    expect(find.text('Zeus Chat'), findsOneWidget);
    expect(find.text('ابدأ محليًا'), findsOneWidget);
  });
}
