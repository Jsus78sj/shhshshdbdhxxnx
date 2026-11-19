/// نتيجة اختيار تسليح بعدد أسياخ (من Table 1 — مثل: 5 No 10)
class BarCountSelection {
  final int diameterMm;
  final int barCount;
  final double areaProvidedMm2;
  final double approximateSpacingMm;

  /// false إذا لم يكفِ أقصى عدد أسياخ مسموح به لتوفير المساحة المطلوبة
  /// (تُرجَع عندها مساحة أقل من المطلوب ويجب تنبيه المستخدم صراحةً).
  final bool isSufficient;

  const BarCountSelection({
    required this.diameterMm,
    required this.barCount,
    required this.areaProvidedMm2,
    required this.approximateSpacingMm,
    this.isSufficient = true,
  });

  /// الصيغة المستخدمة في جدول الشرح الجامعي (مثال: 5 No 10)
  String get lectureNotation => '$barCount No $diameterMm';
}

/// نتيجة اختيار تسليح بمسافة بين الأسياخ (من Table 2 — مثل: Ø10 @ 200 mm)
class BarSpacingSelection {
  final int diameterMm;
  final int spacingMm;
  final double areaProvidedMm2PerM;

  const BarSpacingSelection({
    required this.diameterMm,
    required this.spacingMm,
    required this.areaProvidedMm2PerM,
  });

  String get standardNotation => 'Ø$diameterMm @ $spacingMm mm';
}

/// جداول حديد التسليح (الصفحة 2 من الكود المرفق):
/// - Table 1: مساحات ومحيط عدد محدد من الأسياخ (1 إلى 10 أسياخ)
/// - Table 2: مساحات الأسياخ لكل متر عرض عند مسافات محددة (75 إلى 300 mm)
class ReinforcementTables {
  ReinforcementTables._();

  static const List<int> standardDiameters = [
    6,
    8,
    10,
    12,
    14,
    16,
    18,
    20,
    22,
    25,
  ];

  static const List<int> standardSpacingsMm = [
    75,
    100,
    120,
    125,
    150,
    175,
    200,
    225,
    250,
    275,
    300,
  ];

  /// Table 1 — Cross Sectional Areas (mm²) for 1..10 bars (index 0 = 1 bar)
  static const Map<int, List<double>> table1AreasByCount = {
    6: [28, 57, 85, 113, 142, 170, 198, 226, 255, 283],
    8: [50, 101, 151, 201, 252, 302, 352, 402, 453, 503],
    10: [78, 157, 236, 314, 393, 471, 550, 628, 707, 785],
    12: [113, 226, 339, 452, 566, 679, 792, 905, 1020, 1130],
    14: [154, 308, 462, 616, 770, 924, 1077, 1231, 1385, 1539],
    16: [201, 402, 603, 804, 1010, 1210, 1410, 1610, 1810, 2010],
    18: [254, 509, 763, 1018, 1272, 1527, 1781, 2036, 2290, 2544],
    20: [314, 628, 943, 1256, 1570, 1890, 2200, 2510, 2830, 3140],
    22: [380, 760, 1140, 1520, 1900, 2281, 2661, 3041, 3421, 3801],
    25: [491, 982, 1470, 1960, 2450, 2950, 3440, 3930, 4420, 4910],
  };

  /// Table 1 — Bar Perimeter (mm) for a single bar
  static const Map<int, double> table1PerimetersMm = {
    6: 18.9,
    8: 25.1,
    10: 31.4,
    12: 37.7,
    14: 43.9,
    16: 50.3,
    18: 56.5,
    20: 62.8,
    22: 69.1,
    25: 78.5,
  };

  /// Table 2 — Cross Sectional Areas (mm² per meter width) at specified spacings
  /// Order matches [standardSpacingsMm]: 75, 100, 120, 125, 150, 175, 200, 225, 250, 275, 300
  static const Map<int, List<double>> table2AreasBySpacing = {
    6: [377, 283, 236, 226, 189, 162, 142, 126, 113, 103, 94],
    8: [671, 503, 419, 402, 335, 287, 252, 224, 201, 183, 168],
    10: [1050, 785, 654, 628, 523, 449, 393, 349, 314, 285, 262],
    12: [1510, 1130, 942, 905, 754, 646, 566, 502, 452, 411, 377],
    14: [2050, 1539, 1280, 1230, 1025, 880, 770, 680, 615, 560, 510],
    16: [2680, 2010, 1675, 1610, 1340, 1150, 1010, 893, 804, 731, 670],
    18: [3390, 2540, 2120, 2035, 1695, 1450, 1270, 1130, 1015, 925, 845],
    20: [4190, 3140, 2618, 2510, 2094, 1800, 1570, 1396, 1260, 1142, 1050],
    22: [5065, 3800, 3165, 3040, 2530, 2170, 1900, 1685, 1520, 1380, 1265],
    25: [6550, 4909, 4091, 3930, 3270, 2810, 2450, 2182, 1960, 1785, 1640],
  };

  /// استرجاع مساحة عدد محدد من الأسياخ من Table 1 (يدعم أي عدد >= 1)
  static double areaForBarCount({
    required int diameterMm,
    required int count,
  }) {
    final row = table1AreasByCount[diameterMm];
    if (row == null) {
      throw ArgumentError('القطر $diameterMm mm غير موجود في Table 1.');
    }
    if (count < 1) {
      throw ArgumentError('عدد الأسياخ يجب أن يكون 1 على الأقل.');
    }
    if (count <= 10) {
      return row[count - 1];
    }
    // للأعداد الأكبر من 10 نضاعف قيمة 10 أسياخ + الباقي
    final tens = count ~/ 10;
    final rem = count % 10;
    return (tens * row[9]) + (rem > 0 ? row[rem - 1] : 0.0);
  }

  /// استرجاع محيط سيخ واحد من Table 1 (mm)
  static double perimeterForDiameter(int diameterMm) {
    final p = table1PerimetersMm[diameterMm];
    if (p == null) {
      throw ArgumentError('القطر $diameterMm mm غير موجود في Table 1.');
    }
    return p;
  }

  /// استرجاع المساحة لكل متر عرض عند مسافة محددة من Table 2
  static double areaForSpacing({
    required int diameterMm,
    required int spacingMm,
  }) {
    final row = table2AreasBySpacing[diameterMm];
    final idx = standardSpacingsMm.indexOf(spacingMm);
    if (row == null || idx == -1) {
      throw ArgumentError(
        'القطر $diameterMm mm أو المسافة $spacingMm mm غير موجودة في Table 2.',
      );
    }
    return row[idx];
  }

  /// اختيار أقل عدد أسياخ في المتر يحقق المساحة المطلوبة وشرط أقصى مسافة (من Table 1)
  static BarCountSelection selectBarCount({
    required double requiredAreaMm2PerM,
    required int diameterMm,
    double maxSpacingMm = 300.0,
    int minCount = 4,
    int maxCount = 15,
  }) {
    final minCountFromSpacing = (1000.0 / maxSpacingMm).ceil();
    final startCount =
        minCount > minCountFromSpacing ? minCount : minCountFromSpacing;

    for (int n = startCount; n <= maxCount; n++) {
      final area = areaForBarCount(diameterMm: diameterMm, count: n);
      if (area >= requiredAreaMm2PerM - 1e-6) {
        return BarCountSelection(
          diameterMm: diameterMm,
          barCount: n,
          areaProvidedMm2: area,
          approximateSpacingMm: 1000.0 / n,
        );
      }
    }

    // لا يوجد عدد أسياخ ضمن الحد الأقصى يحقق المساحة المطلوبة: نُرجع أقصى عدد
    // مع علامة isSufficient=false كي لا يُعرض تسليح ناقص على أنه كافٍ.
    final fallbackArea =
        areaForBarCount(diameterMm: diameterMm, count: maxCount);
    return BarCountSelection(
      diameterMm: diameterMm,
      barCount: maxCount,
      areaProvidedMm2: fallbackArea,
      approximateSpacingMm: 1000.0 / maxCount,
      isSufficient: false,
    );
  }

  /// أصغر قطر قياسي أكبر من [currentDiameterMm] يكفي لتوفير المساحة المطلوبة
  /// ضمن أقصى عدد أسياخ (يُستخدم في رسائل التنبيه). يرجع null إن لم يوجد.
  static int? nextSufficientDiameter({
    required double requiredAreaMm2PerM,
    required int currentDiameterMm,
    double maxSpacingMm = 300.0,
    int minCount = 4,
    int maxCount = 15,
  }) {
    for (final d in standardDiameters) {
      if (d <= currentDiameterMm) continue;
      final sel = selectBarCount(
        requiredAreaMm2PerM: requiredAreaMm2PerM,
        diameterMm: d,
        maxSpacingMm: maxSpacingMm,
        minCount: minCount,
        maxCount: maxCount,
      );
      if (sel.isSufficient) return d;
    }
    return null;
  }

  /// اختيار أكبر مسافة قياسية (الأكثر اقتصادية) تحقق المساحة المطلوبة وحد المسافة الأقصى (من Table 2)
  static BarSpacingSelection? selectBarSpacing({
    required double requiredAreaMm2PerM,
    required int diameterMm,
    double maxSpacingMm = 300.0,
  }) {
    final row = table2AreasBySpacing[diameterMm];
    if (row == null) {
      throw ArgumentError('القطر $diameterMm mm غير موجود في Table 2.');
    }

    // نبحث من أكبر مسافة (300) نزولاً إلى أصغر مسافة (75)
    for (int i = standardSpacingsMm.length - 1; i >= 0; i--) {
      final spacing = standardSpacingsMm[i];
      if (spacing > maxSpacingMm) continue;
      final area = row[i];
      if (area >= requiredAreaMm2PerM - 1e-6) {
        return BarSpacingSelection(
          diameterMm: diameterMm,
          spacingMm: spacing,
          areaProvidedMm2PerM: area,
        );
      }
    }
    return null;
  }
}
