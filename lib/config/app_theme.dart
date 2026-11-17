import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F6FA),
    textTheme: GoogleFonts.poppinsTextTheme(),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle:
            GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF9AA7FF),
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF111722),
      onSurface: const Color(0xFFE9EDF6),
      surfaceContainerLowest: const Color(0xFF0B1018),
      surfaceContainerLow: const Color(0xFF151D29),
      surfaceContainer: const Color(0xFF1A2432),
      surfaceContainerHigh: const Color(0xFF222E3E),
      surfaceContainerHighest: const Color(0xFF2B394C),
      outline: const Color(0xFF536177),
      outlineVariant: const Color(0xFF344155),
      primary: const Color(0xFFAEB8FF),
      onPrimary: const Color(0xFF151B37),
      secondary: const Color(0xFF82D9C8),
      onSecondary: const Color(0xFF092D2A),
      tertiary: const Color(0xFFF0C27B),
      onTertiary: const Color(0xFF39280F),
    ),
    scaffoldBackgroundColor: const Color(0xFF0B1018),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: const Color(0xFFE9EDF6),
      displayColor: const Color(0xFFE9EDF6),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      backgroundColor: const Color(0xFF111722),
      foregroundColor: const Color(0xFFE9EDF6),
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFE9EDF6),
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF151D29),
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFAEB8FF),
        foregroundColor: const Color(0xFF151B37),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle:
            GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFC2C9FF),
        side: const BorderSide(color: Color(0xFF536177)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle:
            GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFC2C9FF),
        textStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ).copyWith(inherit: false),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: const Color(0xFFB8C3D5)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFFAEB8FF)
            : null,
      ),
      checkColor: WidgetStateProperty.all(const Color(0xFF11162B)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFFAEB8FF)
            : const Color(0xFF8490A5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF202B3B),
      selectedColor: const Color(0xFF343F68),
      secondarySelectedColor: const Color(0xFF173C39),
      side: const BorderSide(color: Color(0xFF344155)),
      labelStyle: const TextStyle(color: Color(0xFFE1E7F1)),
      secondaryLabelStyle: const TextStyle(color: Color(0xFFB6F0E4)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF121A25),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF344155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFAEB8FF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF8A8A)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF8A8A), width: 1.5),
      ),
      hintStyle: const TextStyle(color: Color(0xFF929EAF)),
      labelStyle: const TextStyle(color: Color(0xFFB8C3D5)),
      prefixIconColor: const Color(0xFFAEB8CC),
      suffixIconColor: const Color(0xFFAEB8CC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF1A2432),
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF151D29),
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Color(0xFF1A2432),
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: Color(0xFFE9EDF6)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xFF29364A),
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF344155)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFFAEB8FF)
            : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFF485487)
            : const Color(0xFF344155),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFFAEB8FF),
      linearTrackColor: Color(0xFF344155),
    ),
  );
}
