import 'package:flutter/material.dart';

/// 观阅轨迹 · 全局主题
/// 设计语言：清爽莫兰迪色（低饱和、灰调），简约留白，契合「记录观影/阅读轨迹」的质感。
class AppColors {
  AppColors._();

  /// 主强调色 —— 莫兰迪青灰（低饱和、清爽）
  static const Color accent = Color(0xFF7C9A92);

  /// 深一点的强调色（用于文字/图标上的强调）
  static const Color accentDark = Color(0xFF5F7D75);

  /// 强调色的浅底色（用于选中态/标签背景）
  static const Color accentSoft = Color(0xFFE4ECE9);

  /// 页面背景 —— 暖白
  static const Color background = Color(0xFFFAF8F5);

  /// 卡片背景
  static const Color card = Colors.white;

  /// 中性文字
  static const Color textPrimary = Color(0xFF3A3A3A);
  static const Color textSecondary = Color(0xFF8A8A86);
  static const Color textTertiary = Color(0xFFB4B2AE);

  /// 分割线 / 浅边框
  static const Color border = Color(0xFFECE9E4);

  /// 评分星色（莫兰迪暖黄，低饱和）
  static const Color star = Color(0xFFC8A96B);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accentDark,
      surface: AppColors.card,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,

      // 卡片：极淡阴影 + 统一圆角
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // 应用栏：无边框、背景跟随页面
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      // 输入框：统一的白底、圆角、无边框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
      ),

      // 主按钮
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // 描边按钮
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent, width: 1.2),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // 悬浮按钮
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),

      // 单选/开关等
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.textTertiary,
        ),
      ),

      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
