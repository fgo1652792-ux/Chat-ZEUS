import 'package:flutter/widgets.dart';
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
  testWidgets(
    'RTL welcome and settings fit a small viewport at large text scale',
    (tester) async {
      tester.view.physicalSize = const Size(390, 670);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        ZeusApp(
          openStore: () => LocalStore.open(
            factory: databaseFactoryFfiNoIsolate,
            name: inMemoryDatabasePath,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final welcome = find.byKey(const Key('welcome-settings'));
      await tester.ensureVisible(welcome);
      await tester.tap(welcome);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('glass-setting')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
