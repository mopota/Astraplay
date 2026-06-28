import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // Use a modern "Vesuvius" or "Deep Blue" base with our custom colors
  static ThemeData light = FlexThemeData.light(
    colors: const FlexSchemeColor(
      primary: AppColors.primaryLight,
      primaryContainer: Color(0xFFD1E4FF),
      secondary: AppColors.secondaryLight,
      secondaryContainer: Color(0xFFD0F0FF),
      tertiary: AppColors.accentDark,
      tertiaryContainer: Color(0xFFEADBFF),
      appBarColor: AppColors.surfaceLight,
      error: AppColors.error,
    ),
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 7,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: true,
      alignedDropdown: true,
      useInputDecoratorThemeInDialogs: true,
      cardRadius: 16.0,
      
      // AppBar
      appBarBackgroundSchemeColor: SchemeColor.surface,
      appBarScrolledUnderElevation: 0,
      menuBarElevation: 0,
      snackBarElevation: 0,
      
      // Navigation
      bottomNavigationBarSelectedLabelSchemeColor: SchemeColor.primary,
      bottomNavigationBarSelectedIconSchemeColor: SchemeColor.primary,
      navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
      navigationBarSelectedIconSchemeColor: SchemeColor.primary,
      navigationBarIndicatorSchemeColor: SchemeColor.primary,
      navigationBarIndicatorOpacity: 0.1,
      
      // Buttons
      fabUseShape: true,
      fabAlwaysCircular: true,
      fabSchemeColor: SchemeColor.primary,
      chipSchemeColor: SchemeColor.primary,
      filledButtonRadius: 12,
      elevatedButtonRadius: 12,
      
      // Inputs
      inputDecoratorIsFilled: true,
      inputDecoratorRadius: 12.0,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorUnfocusedBorderIsColored: false,
      
      // ListTile
      listTileSelectedSchemeColor: SchemeColor.primary,
      listTileSelectedTileSchemeColor: SchemeColor.primary,
    ),
    keyColors: const FlexKeyColors(
      useSecondary: true,
      useTertiary: true,
      keepPrimary: true,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    fontFamily: GoogleFonts.poppins().fontFamily,
    textTheme: GoogleFonts.poppinsTextTheme(),
  ).copyWith(
    scaffoldBackgroundColor: AppColors.backgroundLight,
  );

  static ThemeData dark = FlexThemeData.dark(
    colors: const FlexSchemeColor(
      primary: AppColors.primaryDark,
      primaryContainer: Color(0xFF0040A1),
      secondary: AppColors.secondaryDark,
      secondaryContainer: Color(0xFF004D66),
      tertiary: AppColors.accentDark,
      tertiaryContainer: Color(0xFF3D008F),
      appBarColor: AppColors.backgroundDark,
      error: AppColors.error,
    ),
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 13,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 20,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: true,
      alignedDropdown: true,
      useInputDecoratorThemeInDialogs: true,
      cardRadius: 16.0,
      
      // AppBar
      appBarBackgroundSchemeColor: SchemeColor.surface,
      appBarScrolledUnderElevation: 0,
      menuBarElevation: 0,
      snackBarElevation: 0,
      // Navigation
      bottomNavigationBarSelectedLabelSchemeColor: SchemeColor.primary,
      bottomNavigationBarSelectedIconSchemeColor: SchemeColor.primary,
      navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
      navigationBarSelectedIconSchemeColor: SchemeColor.primary,
      navigationBarIndicatorSchemeColor: SchemeColor.primary,
      navigationBarIndicatorOpacity: 0.1,
      
      // Buttons
      fabUseShape: true,
      fabAlwaysCircular: true,
      fabSchemeColor: SchemeColor.primary,
      chipSchemeColor: SchemeColor.primary,
      filledButtonRadius: 12,
      elevatedButtonRadius: 12,
      
      // Inputs
      inputDecoratorIsFilled: true,
      inputDecoratorRadius: 12.0,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorUnfocusedBorderIsColored: false,
      
      // ListTile
      listTileSelectedSchemeColor: SchemeColor.primary,
      listTileSelectedTileSchemeColor: SchemeColor.primary,
    ),
    keyColors: const FlexKeyColors(
      useSecondary: true,
      useTertiary: true,
      keepPrimary: true,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    fontFamily: GoogleFonts.poppins().fontFamily,
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
  ).copyWith(
    scaffoldBackgroundColor: AppColors.backgroundDark,
  );
}
