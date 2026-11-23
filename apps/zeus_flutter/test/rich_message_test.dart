import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeus_chat/rich/rich_message.dart';

void main() {
  testWidgets('renders a chart, code and deferred external images', (
    tester,
  ) async {
    const fence = '\x60\x60\x60';
    const body =
        '''
# Result
A table:

| Name | Value |
| --- | --- |
| A | 2 |

![Image preview](https://example.test/tracking.png)

${fence}dart
final answer = 42;
$fence

${fence}chart
[{"label":"Alpha","value":2}]
$fence

${fence}mermaid
flowchart LR
a[Start] --> b[End]
$fence
''';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: RichMessage(body))),
      ),
    );
    expect(find.text('Result'), findsOneWidget);
    expect(find.byTooltip('Copy code'), findsOneWidget);
    expect(find.text('Image preview'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.text('Alpha · 2'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
