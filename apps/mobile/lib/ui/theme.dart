import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual system aligned with Grok/X dark transcript UI.
class ValeraColors {
  static const canvas = Color(0xFF000000);
  static const surface1 = Color(0xFF16181C);
  static const surface2 = Color(0xFF1E2126);
  static const surface3 = Color(0xFF272A2E);
  static const divider = Color(0xFF2F3336);
  static const text = Color(0xFFE7E9EA);
  static const muted = Color(0xFF71767B);
  static const link = Color(0xFF1D9BF0);
}

ThemeData buildValeraTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: ValeraColors.canvas,
    colorScheme: const ColorScheme.dark(
      surface: ValeraColors.surface1,
      primary: ValeraColors.text,
      onPrimary: ValeraColors.canvas,
      secondary: ValeraColors.link,
      onSurface: ValeraColors.text,
      outline: ValeraColors.divider,
    ),
    dividerColor: ValeraColors.divider,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: ValeraColors.text,
    displayColor: ValeraColors.text,
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: ValeraColors.canvas,
      foregroundColor: ValeraColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: ValeraColors.text,
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: ValeraColors.canvas,
      surfaceTintColor: Colors.transparent,
    ),
    iconTheme: const IconThemeData(color: ValeraColors.text, size: 22),
    splashFactory: InkSparkle.splashFactory,
  );
}
