import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ui/minirok_glass.dart';

void main() => runApp(const ZeusApp());

class ZeusApp extends StatelessWidget {
  const ZeusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zeus Chat',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ar'), Locale('en')],
      builder: (context, child) => LiquidGlassScope(
        enabled: true,
        child: LiquidGlassHost(enabled: true, child: child!),
      ),
      home: const Scaffold(body: Center(child: Text('Zeus Chat'))),
    );
  }
}
