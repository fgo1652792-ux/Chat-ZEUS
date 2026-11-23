import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ui/minirok_glass.dart';

import 'data/local_store.dart';
import 'shell.dart';

void main() {
  runApp(const ZeusApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(LiquidGlass.warmUp());
  });
}

class ZeusApp extends StatefulWidget {
  const ZeusApp({super.key, this.openStore});

  final Future<LocalStore> Function()? openStore;

  @override
  State<ZeusApp> createState() => _ZeusAppState();
}

class _ZeusAppState extends State<ZeusApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  Locale _locale = const Locale('ar');
  bool _glassEnabled = true;
  bool _onboarded = false;
  bool _storageError = false;
  LocalStore? _store;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    LocalStore? db;
    try {
      db = await (widget.openStore ?? LocalStore.open)();
      final preferences = await db.preferences();
      if (!mounted) {
        await db.close();
        return;
      }
      setState(() {
        _store = db;
        _themeMode = switch (preferences['theme']) {
          'light' => ThemeMode.light,
          'system' => ThemeMode.system,
          _ => ThemeMode.dark,
        };
        _locale = Locale(preferences['locale'] == 'en' ? 'en' : 'ar');
        _glassEnabled = preferences['glass'] != 'false';
        _onboarded = preferences['onboarded'] == 'true';
        _storageError = false;
      });
    } catch (_) {
      await db?.close();
      if (mounted) setState(() => _storageError = true);
    }
  }

  Future<void> _save(String key, String value, VoidCallback onSaved) async {
    try {
      await _store!.setPreference(key, value);
      if (mounted) setState(onSaved);
    } catch (_) {
      if (mounted) {
        setState(() => _storageError = true);
      }
    }
  }

  @override
  void dispose() {
    unawaited(_store?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
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
      home: store == null || _storageError
          ? Scaffold(
              body: Center(
                child: _storageError
                    ? FilledButton(
                        onPressed: () async {
                          await _store?.close();
                          if (!mounted) return;
                          setState(() {
                            _store = null;
                            _storageError = false;
                          });
                          await _load();
                        },
                        child: Text(
                          _locale.languageCode == 'ar'
                              ? 'تعذّر فتح التخزين المحلي. أعد المحاولة'
                              : 'Could not open local storage. Retry',
                        ),
                      )
                    : const CircularProgressIndicator(),
              ),
            )
          : ZeusShell(
              glassEnabled: _glassEnabled,
              themeMode: _themeMode,
              locale: _locale,
              onboarded: _onboarded,
              onOnboarded: () =>
                  _save('onboarded', 'true', () => _onboarded = true),
              onGlassChanged: (value) =>
                  _save('glass', '$value', () => _glassEnabled = value),
              onThemeChanged: (value) =>
                  _save('theme', value.name, () => _themeMode = value),
              onLocaleChanged: (value) =>
                  _save('locale', value.languageCode, () => _locale = value),
            ),
    );
  }
}
