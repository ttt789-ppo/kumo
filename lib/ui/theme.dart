import 'package:flutter/material.dart';

/// BakaSU / KernelSU 那种「大标题 + 圆角卡片 + 低饱和青灰」的风格
class KumoTheme {
  static const seed = Color(0xFF3E6B78);
  static const cardRadius = 26.0;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF101416) : const Color(0xFFF1F3F4);
    final card = isDark ? const Color(0xFF1A2022) : Colors.white;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      splashFactory: InkSparkle.splashFactory,
      cardColor: card,
      dividerColor: scheme.outlineVariant.withOpacity(0.4),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF181E20) : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withOpacity(0.16),
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF20282A) : const Color(0xFFF5F6F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// 大标题（像 BakaSU 顶部的 64sp 名字）
class BigTitle extends StatelessWidget {
  final String text;
  const BigTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 46,
          height: 1.0,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
      ),
    );
  }
}
