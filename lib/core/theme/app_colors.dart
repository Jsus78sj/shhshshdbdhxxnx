import 'package:flutter/material.dart';

/// لوحة الألوان الهندسية للتطبيق (مستوحاة من المخططات الإنشائية)
class AppColors {
  AppColors._();

  // الألوان الأساسية (Blueprint Navy & Engineering Teal)
  static const Color primary = Color(0xFF0F3D5E);
  static const Color primaryLight = Color(0xFF1D5F8A);
  static const Color secondary = Color(0xFF0E7C7B);
  static const Color accentAmber = Color(0xFFD97706);

  // ألوان الحالات الهندسية (آمن / تحذير / غير آمن)
  static const Color safeGreen = Color(0xFF15803D);
  static const Color warningAmber = Color(0xFFB45309);
  static const Color dangerRed = Color(0xFFB91C1C);

  // ألوان الخلفيات (الوضع الفاتح)
  static const Color lightBackground = Color(0xFFF4F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFDCE4EC);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);

  // ألوان الخلفيات (الوضع الداكن)
  static const Color darkBackground = Color(0xFF0B131E);
  static const Color darkSurface = Color(0xFF132030);
  static const Color darkBorder = Color(0xFF23364D);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // ألوان رسومات البلاطات والحديد (للمراحل القادمة)
  static const Color slabFill = Color(0xFFE0F2FE);
  static const Color droppedSlabHatch = Color(0xFFFEF3C7);
  static const Color rebarBottomX = Color(0xFF1D4ED8);
  static const Color rebarBottomY = Color(0xFF0D9488);
  static const Color rebarTopContinuous = Color(0xFFDC2626);
  static const Color rebarTopDiscontinuous = Color(0xFFD97706);
}
