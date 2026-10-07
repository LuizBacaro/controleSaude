import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static TextTheme lightTextTheme() {
    final display = GoogleFonts.fraunces(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final body = GoogleFonts.outfit(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w400,
    );

    return TextTheme(
      displayLarge: display.copyWith(fontSize: 40, height: 1.1),
      displayMedium: display.copyWith(fontSize: 32, height: 1.15),
      displaySmall: display.copyWith(fontSize: 26, height: 1.2),
      headlineMedium: display.copyWith(fontSize: 22, height: 1.25),
      headlineSmall: display.copyWith(fontSize: 18, height: 1.3),
      titleLarge: body.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: body.copyWith(fontSize: 16, height: 1.45),
      bodyMedium: body.copyWith(
        fontSize: 14,
        height: 1.45,
        color: AppColors.textSecondary,
      ),
      bodySmall: body.copyWith(
        fontSize: 12,
        height: 1.4,
        color: AppColors.textMuted,
      ),
      labelLarge: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: body.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
    );
  }
}
