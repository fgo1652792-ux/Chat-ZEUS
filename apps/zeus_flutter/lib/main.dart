import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ui/minirok_glass.dart';

import 'shell.dart';

void main() {
  runApp(const ZeusApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(LiquidGlass.warmUp());
  });
}

class ZeusApp extends StatefulWidget {
  const ZeusApp({super.key});

  @override
  State<ZeusApp> createState() => _ZeusAppState();
}

class _ZeusAppState extends State<ZeusApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  Locale _locale = const Locale('ar');
  bool _glassEnabled = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zeus Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      locale: _locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ar'), Locale('en')],
      builder: (context, child) => LiquidGlassScope(
        enabled: _glassEnabled,
        quality: LiquidGlassQuality.standard,
        child: LiquidGlassHost(
          enabled: _glassEnabled,
          child: LiquidGlassGroup(child: child!),
        ),
      ),
      home: ZeusShell(
        glassEnabled: _glassEnabled,
        themeMode: _themeMode,
        locale: _locale,
        onGlassChanged: (value) => setState(() => _glassEnabled = value),
        onThemeChanged: (value) => setState(() => _themeMode = value),
        onLocaleChanged: (value) => setState(() => _locale = value),
      ),
    );
  }
}
