import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings/local_settings.dart';

extension AppColorThemeDetails on AppColorTheme {
  String get label => switch (this) {
    AppColorTheme.emerald => 'Emerald',
    AppColorTheme.ocean => 'Ocean',
    AppColorTheme.sand => 'Sand',
    AppColorTheme.plum => 'Plum',
  };

  Color get seed => switch (this) {
    AppColorTheme.emerald => const Color(0xff146B55),
    AppColorTheme.ocean => const Color(0xff285F8F),
    AppColorTheme.sand => const Color(0xff8B5B2B),
    AppColorTheme.plum => const Color(0xff76506F),
  };
}

ThemeMode appThemeMode(AppAppearance appearance) => switch (appearance) {
  AppAppearance.system => ThemeMode.system,
  AppAppearance.light => ThemeMode.light,
  AppAppearance.dark => ThemeMode.dark,
};

ThemeData buildAppTheme(AppColorTheme palette, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.seed,
    brightness: brightness,
  );
  final isDark = brightness == Brightness.dark;
  final base = ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    useMaterial3: true,
    platform: TargetPlatform.iOS,
  );

  return base.copyWith(
    scaffoldBackgroundColor: isDark
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: .025),
            scheme.surface,
          )
        : Color.alphaBlend(
            scheme.primary.withValues(alpha: .018),
            scheme.surface,
          ),
    appBarTheme: AppBarTheme(
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    bottomAppBarTheme: BottomAppBarThemeData(
      elevation: 12,
      color: scheme.surfaceContainerLow,
      shadowColor: Colors.black.withValues(alpha: isDark ? .35 : .12),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
      height: 78,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .55),
      space: 1,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
