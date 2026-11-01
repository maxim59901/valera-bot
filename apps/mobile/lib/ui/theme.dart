import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildValeraTheme() {
  const bg = Color(0xFF0B0C0F);
  const surface = Color(0xFF15171C);
  const surface2 = Color(0xFF1C1F26);
  const border = Color(0xFF2A2E37);
  const accent = Color(0xFFE8E6E3);
  const muted = Color(0xFF9AA0A6);

  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      surface: surface,
      primary: accent,
      onPrimary: Color(0xFF0B0C0F),
      secondary: Color(0xFF8AB4F8),
      onSurface: accent,
    ),
    dividerColor: border,
  );

  return base.copyWith(
    textTheme: GoogleFonts.ibmPlexSansTextTheme(base.textTheme).apply(
      bodyColor: accent,
      displayColor: accent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      centerTitle: false,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: surface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      hintStyle: const TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: muted),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: muted,
      textColor: accent,
    ),
  );
}
