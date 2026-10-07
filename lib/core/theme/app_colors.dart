import 'package:flutter/material.dart';

/// Paleta clínica clara — teal profundo, sage e superfícies suaves.
abstract final class AppColors {
  static const Color background = Color(0xFFF3F7F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFE8F1EF);
  static const Color border = Color(0xFFD0DEDA);

  static const Color teal = Color(0xFF0B6E6B);
  static const Color tealSoft = Color(0xFF1A9A94);
  static const Color sage = Color(0xFF6BA89A);
  static const Color coral = Color(0xFFC45C4A);

  static const Color textPrimary = Color(0xFF142822);
  static const Color textSecondary = Color(0xFF4A5C58);
  static const Color textMuted = Color(0xFF7A8F8A);

  static const Color success = Color(0xFF2F8F6B);
  static const Color warning = Color(0xFFC4922A);
  static const Color error = Color(0xFFC45C4A);
  static const Color info = Color(0xFF3A7CA5);

  static const LinearGradient heroWash = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE6F4F2),
      Color(0xFFF3F7F6),
      Color(0xFFDCEEE9),
    ],
  );

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, tealSoft],
  );
}
