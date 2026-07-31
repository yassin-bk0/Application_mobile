import 'package:flutter/material.dart';

class AppTheme {
  // ── Core Palette ────────────────────────────────────────────────────────────
  static const Color primaryYellow     = Color(0xFFF5C842);
  static const Color primaryYellowDim  = Color(0x33F5C842); // 20% alpha
  static const Color bgDeep            = Color(0xFF0D1B2A);  // Deep navy
  static const Color bgCard            = Color(0xFF152234);  // Slightly lighter navy
  static const Color glassWhite        = Color(0x14FFFFFF);  // white 8%
  static const Color glassBorder       = Color(0x26FFFFFF);  // white 15%
  static const Color textPrimary       = Colors.white;
  static const Color textSecondary     = Color(0xA6FFFFFF);  // white 65%
  static const Color textMuted         = Color(0x66FFFFFF);  // white 40%
  static const Color accentGreen       = Color(0xFF4CAF50);
  static const Color accentRed         = Color(0xFFEF5350);

  // Legacy aliases so existing screens continue to compile
  static const Color textDark          = bgDeep;
  static const Color textLight         = textMuted;
  static const Color backgroundLight   = bgDeep;
  static const Color cardLight         = bgCard;
  static const Color secondaryOrange   = Color(0xFFFFA000);
  static const Color accentGreenLight  = Color(0xFF1B3A2A);
  static const Color accentYellowLight = Color(0x1AF5C842);

  static ThemeData get lightTheme => _buildTheme(isDark: false);
  static ThemeData get darkTheme  => _buildTheme(isDark: true);

  static ThemeData _buildTheme({required bool isDark}) {
    final Color bgColor = isDark ? bgDeep : const Color(0xFFF5F7FA);
    final Color cardColor = isDark ? bgCard : Colors.white;
    final Color txtPrimary = isDark ? textPrimary : const Color(0xFF1A1C1E);
    final Color txtSecondary = isDark ? textSecondary : const Color(0xFF454749);
    final Color txtMuted = isDark ? textMuted : const Color(0xFF757779);
    final Color glass = isDark ? glassWhite : const Color(0x0D000000);
    final Color gBorder = isDark ? glassBorder : const Color(0x1A000000);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bgColor,
      colorScheme: isDark 
        ? const ColorScheme.dark(
            primary: primaryYellow,
            secondary: primaryYellow,
            surface: bgCard,
            onPrimary: bgDeep,
            onSecondary: bgDeep,
            onSurface: Colors.white,
          )
        : const ColorScheme.light(
            primary: primaryYellow,
            secondary: primaryYellow,
            surface: Colors.white,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Color(0xFF1A1C1E),
          ),
      textTheme: TextTheme(
        headlineLarge:  TextStyle(color: txtPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: txtPrimary, fontWeight: FontWeight.bold),
        titleLarge:     TextStyle(color: txtPrimary, fontWeight: FontWeight.bold),
        bodyLarge:      TextStyle(color: txtPrimary),
        bodyMedium:     TextStyle(color: txtSecondary),
        labelSmall:     TextStyle(color: txtMuted, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        foregroundColor: txtPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryYellow),
        titleTextStyle: TextStyle(
          color: txtPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryYellow,
          foregroundColor: bgDeep,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryYellow,
          side: const BorderSide(color: primaryYellow),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glass,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: gBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: gBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryYellow),
        ),
        hintStyle: TextStyle(color: txtMuted),
        labelStyle: TextStyle(color: txtSecondary),
        prefixIconColor: txtMuted,
        suffixIconColor: txtMuted,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primaryYellow : (isDark ? Colors.white54 : Colors.grey),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primaryYellowDim : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        elevation: 0,
        selectedItemColor: primaryYellow,
        unselectedItemColor: txtMuted,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        contentTextStyle: TextStyle(color: txtPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
