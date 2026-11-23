import 'package:flutter/material.dart';
import 'package:ui/minirok_glass.dart';

String localize(BuildContext context, String en, String ar) {
  return Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
}

class ZeusPane extends StatelessWidget {
  const ZeusPane({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(24);
    if (LiquidGlassScope.of(context)) {
      return LiquidGlass(
        borderRadius: radius,
        style: LiquidGlassStyle.regular(colors),
        child: Material(type: MaterialType.transparency, child: child),
      );
    }
    return Material(
      borderRadius: radius,
      color: colors.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
