/// الثوابت العامة للتطبيق والمعايير الافتراضية للتصميم وفق الكود BS 8110
class AppConstants {
  AppConstants._();

  static const String appNameAr = 'مصمم البلاطات — BS 8110';
  static const String appNameEn = 'BS 8110 Solid Slab Designer';
  static const String appVersion = '1.0.0';

  // أسماء صناديق التخزين المحلي (Hive)
  static const String settingsBoxName = 'app_settings_box';
  static const String projectsBoxName = 'slab_projects_box';

  // مفاتيح الإعدادات المحفوظة
  static const String themeModeKey = 'theme_mode';
  static const String designModeKey = 'design_mode';

  // القيم الهندسية الافتراضية (مطابقة لمعطيات الاختبار المرجعي)
  static const double defaultDesignLoad = 11.50; // kN/m²
  static const double defaultOverallDepth = 120.0; // mm
  static const double defaultClearCover = 25.0; // mm
  static const double defaultBarDiameter = 10.0; // mm
  static const double defaultFcu = 25.0; // N/mm²
  static const double defaultFy = 250.0; // N/mm²
  static const double stripWidth = 1000.0; // mm
  static const double concreteUnitWeight = 24.0; // kN/m³
}
