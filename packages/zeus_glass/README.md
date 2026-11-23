# كود واجهات MiniRok الزجاجية لـFlutter

يتضمّن الفرع محرك الزجاج وملف الشيدر، وشريط التنقّل السفلي والجانبي، وحركة التبويبات، والنوافذ والقوائم والأزرار ومكوّنات الإعدادات وألوان الوضعين الفاتح والداكن. نُقلت ملفات المكوّنات والشيدر بايتًا ببايت من مراجعة OmniBot التي استخدمناها في بناء نسخة iOS `52e65d982ea530398848ae92d6ab48b767efa5eb`. يضيف هذا الفرع إعدادات الحزمة وملف تصدير واحدًا. [مراجعة المصدر](https://github.com/omnimind-ai/OmniBot/tree/52e65d982ea530398848ae92d6ab48b767efa5eb/ui)

## الربط بتطبيقك العربي

1. استخدم Flutter 3.47.2 أو أحدث، وأضف هذا المجلد كاعتماد `ui` في تطبيقك، سواء بمسار محلي أو كاعتماد Git على فرع `ui/liquid-glass`. اسم الحزمة يحافظ على استيرادات المصدر الأصلية.
2. انسخ `shaders/liquid_glass.frag` إلى المسار نفسه في جذر **تطبيقك** وأدرجه تحت `flutter → shaders` في ملف `pubspec.yaml` الخاص بالتطبيق. محرك الزجاج الأصلي يحمّله بهذا المسار.
3. استخدم `GlobalMaterialLocalizations.delegates` من `flutter_localizations` مع `Locale('ar')`. مرّر النصوص العربية إلى المكوّنات من تطبيقك، ومنها `FlClashNavigationDestination.label`. اتجاه الواجهة يتبع إعداد اللغة في Flutter. بعض النصوص الداخلية في مكوّنات الإعدادات تتبع ترجمة المصدر الأصلية. أضف ترجمتها عند ربطها بتطبيقك.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ui/minirok_glass.dart';

Widget arabicApp(Widget home) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  builder: (context, child) => LiquidGlassScope(
    enabled: true,
    child: LiquidGlassHost(enabled: true, child: child!),
  ),
  home: home,
);
```

ضع شريط `FlClashNavigationDock` فوق المحتوى داخل `Stack` ليظهر ما وراء الزجاج أثناء التمرير، واستخدم `OmniNavigationRail` للشاشات العريضة. لتجربة اختبارات المكوّنات من جذر الفرع شغّل `flutter pub get` ثم `flutter test`.

## الترخيص

يخضع محرك الزجاج والشيدر والأجزاء المقتبسة من FlClash لـGPL‑3.0. ينص إشعار OmniBot على أن ترخيص OmniBot التجاري منفصل عن تلك الأجزاء. يحدد ترخيص OmniBot شروط استخدام مكوّناته الخاصة، بما في ذلك الاستخدام التجاري. احتفظ بالإشعارات وراجع شروط إتاحة المصدر عند توزيع تطبيق مدمج بهذه الملفات. [ترخيص OmniBot](LICENSE) · [إشعار FlClash](docs/third-party/flclash-NOTICE.md) · [نص GPL‑3.0](docs/third-party/flclash-LICENSE.txt) · [إشعار Miuix](third_party/miuix/NOTICE.md)
