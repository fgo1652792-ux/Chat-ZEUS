import 'package:flutter/material.dart';
import 'package:ui/minirok_glass.dart';

import 'chat/chat_runtime.dart';
import 'chat/chat_workspace.dart';
import 'design.dart';
import 'providers/provider_settings.dart';
import 'studio/image_studio.dart';

class ZeusShell extends StatefulWidget {
  const ZeusShell({
    super.key,
    required this.glassEnabled,
    required this.themeMode,
    required this.locale,
    required this.onboarded,
    required this.runtime,
    required this.onOnboarded,
    required this.onGlassChanged,
    required this.onThemeChanged,
    required this.onLocaleChanged,
  });

  final bool glassEnabled;
  final ThemeMode themeMode;
  final Locale locale;
  final bool onboarded;
  final ChatRuntime runtime;
  final VoidCallback onOnboarded;
  final ValueChanged<bool> onGlassChanged;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<ZeusShell> createState() => _ZeusShellState();
}

class _ZeusShellState extends State<ZeusShell> {
  int _destination = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final destinations = [
      FlClashNavigationDestination(
        icon: Icons.chat_bubble_outline_rounded,
        label: localize(context, 'Home', 'الرئيسية'),
      ),
      FlClashNavigationDestination(
        icon: Icons.hub_outlined,
        label: localize(context, 'Providers', 'المزوّدون'),
      ),
      FlClashNavigationDestination(
        icon: Icons.tune_rounded,
        label: localize(context, 'Settings', 'الإعدادات'),
      ),
    ];
    return PopScope(
      canPop: _destination == 0,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && _destination != 0) {
          setState(() => _destination = 0);
        }
      },
      child: Scaffold(
        backgroundColor: dark
            ? const Color(0xff090b14)
            : const Color(0xffeff2fa),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final dock = FlClashNavigationDock(
              axis: wide ? Axis.vertical : Axis.horizontal,
              destinations: destinations,
              selectedIndex: _destination,
              onDestinationSelected: (index) =>
                  setState(() => _destination = index),
            );
            final page = IndexedStack(
              index: _destination,
              sizing: StackFit.expand,
              children: [
                if (widget.onboarded)
                  ChatWorkspace(
                    runtime: widget.runtime,
                    interactive: _destination == 0,
                    onProviders: () => setState(() => _destination = 1),
                  )
                else
                  _Welcome(
                    onboarded: widget.onboarded,
                    onStart: widget.onOnboarded,
                    onSettings: () => setState(() => _destination = 2),
                  ),
                ProviderSettings(repository: widget.runtime.providers),
                _Settings(shell: widget),
              ],
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.15, -0.65),
                      radius: 0.95,
                      colors: dark
                          ? const [Color(0xff202747), Color(0xff090b14)]
                          : const [Color(0xffdce4fd), Color(0xfff6f7fd)],
                    ),
                  ),
                ),
                SafeArea(
                  bottom: wide,
                  child: Padding(
                    padding: wide
                        ? const EdgeInsetsDirectional.only(start: 108)
                        : EdgeInsets.only(
                            bottom: FlClashNavigationDock.insetOf(context),
                          ),
                    child: page,
                  ),
                ),
                if (wide)
                  PositionedDirectional(
                    top: 28,
                    bottom: 28,
                    start: 16,
                    width: 84,
                    child: dock,
                  )
                else
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 0,
                    child: dock,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.onSettings,
    required this.onboarded,
    required this.onStart,
  });
  final bool onboarded;
  final VoidCallback onStart;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(27),
                child: Image.asset(
                  'assets/brand/zeus.png',
                  width: 104,
                  height: 104,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Zeus Chat',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                localize(context, 'Your AI. Your choice.', 'ذكاؤك، بطريقتك'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              Text(
                localize(
                  context,
                  onboarded
                      ? 'Your data stays in this workspace.'
                      : 'One place for the AI models you choose.',
                  onboarded
                      ? 'تبقى بياناتك في مساحة العمل هذه.'
                      : 'مساحة واحدة لنماذج الذكاء الاصطناعي التي تختارها.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 30),
              if (!onboarded) ...[
                FilledButton.icon(
                  key: const Key('start-local'),
                  onPressed: onStart,
                  icon: const Icon(Icons.computer_rounded),
                  label: Text(
                    localize(context, 'Start locally', 'ابدأ محليًا'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ZeusPane(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: TextButton.icon(
                    key: const Key('welcome-settings'),
                    onPressed: onSettings,
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(
                      localize(context, 'Open settings', 'فتح الإعدادات'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Settings extends StatelessWidget {
  const _Settings({required this.shell});
  final ZeusShell shell;

  Widget _entry(
    BuildContext context,
    IconData icon,
    String en,
    String ar,
    WidgetBuilder builder,
  ) => ListTile(
    leading: Icon(icon),
    title: Text(localize(context, en, ar)),
    trailing: const Icon(Icons.chevron_right),
    onTap: () =>
        Navigator.of(context).push<void>(MaterialPageRoute(builder: builder)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                localize(context, 'Settings', 'الإعدادات'),
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 22),
              ZeusPane(
                child: Column(
                  children: [
                    SwitchListTile(
                      key: const Key('glass-setting'),
                      title: Text(
                        localize(context, 'Liquid Glass', 'الزجاج السائل'),
                      ),
                      value: shell.glassEnabled,
                      onChanged: shell.onGlassChanged,
                    ),
                    ListTile(
                      title: Text(localize(context, 'Appearance', 'المظهر')),
                      trailing: DropdownButton<ThemeMode>(
                        value: shell.themeMode,
                        onChanged: (value) => shell.onThemeChanged(value!),
                        items: [
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text(localize(context, 'Dark', 'داكن')),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text(localize(context, 'Light', 'فاتح')),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text(localize(context, 'System', 'النظام')),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      title: Text(localize(context, 'Language', 'اللغة')),
                      trailing: DropdownButton<Locale>(
                        value: shell.locale,
                        onChanged: (value) => shell.onLocaleChanged(value!),
                        items: const [
                          DropdownMenuItem(
                            value: Locale('ar'),
                            child: Text('العربية'),
                          ),
                          DropdownMenuItem(
                            value: Locale('en'),
                            child: Text('English'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ZeusPane(
                child: Column(
                  children: [
                    _entry(
                      context,
                      Icons.image_outlined,
                      'Image Studio',
                      'استوديو الصور',
                      (_) => ImageStudio(repository: shell.runtime.providers),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
