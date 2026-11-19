import 'dart:math' as math;

/// صف معاملات Table 4 للقطاعات أحادية التسليح عند رتبة خرسانة fcu محددة
class SinglyReinforcedRow {
  final int fcu;
  final double ky;
  final double kz;
  final double maxMOverBd2;
  final double limitingMOverBd2;

  const SinglyReinforcedRow({
    required this.fcu,
    required this.ky,
    required this.kz,
    required this.maxMOverBd2,
    required this.limitingMOverBd2,
  });
}

/// صف معاملات Table 5 للقطاعات مزدوجة التسليح
class DoublyReinforcedRow {
  final double xOverD;
  final int fcu;
  final double ko;
  final double kp;

  const DoublyReinforcedRow({
    required this.xOverD,
    required this.fcu,
    required this.ko,
    required this.kp,
  });
}

/// عنصر في جدول النسب الدنيا للتسليح (Table 3.25)
class MinReinforcementEntry {
  final String id;
  final String groupAr;
  final String situationEn;
  final String situationAr;
  final String definitionFormula;
  final double minPercentFy250;
  final double minPercentFy460;

  const MinReinforcementEntry({
    required this.id,
    required this.groupAr,
    required this.situationEn,
    required this.situationAr,
    required this.definitionFormula,
    required this.minPercentFy250,
    required this.minPercentFy460,
  });
}

/// جداول تصميم الانحناء والحد الأدنى للتسليح (الصفحتان 4 و 5 من الكود المرفق):
/// - Table 4: Design Table For Singly Reinforced Sections
/// - Table 5: Design Table For Doubly Reinforced Sections
/// - Table 3.25: Minimum Percentages Of Reinforcement
class FlexureTables {
  FlexureTables._();

  static const List<int> supportedFcuGrades = [20, 25, 30, 35, 40, 45, 50];

  /// Table 4 — Design Table For Singly Reinforced Sections
  static const Map<int, SinglyReinforcedRow> table4Singly = {
    20: SinglyReinforcedRow(
      fcu: 20,
      ky: 9.411,
      kz: 19.812,
      maxMOverBd2: 3.12,
      limitingMOverBd2: 0.848,
    ),
    25: SinglyReinforcedRow(
      fcu: 25,
      ky: 11.763,
      kz: 24.765,
      maxMOverBd2: 3.90,
      limitingMOverBd2: 1.06,
    ),
    30: SinglyReinforcedRow(
      fcu: 30,
      ky: 14.116,
      kz: 29.717,
      maxMOverBd2: 4.68,
      limitingMOverBd2: 1.273,
    ),
    35: SinglyReinforcedRow(
      fcu: 35,
      ky: 16.468,
      kz: 34.670,
      maxMOverBd2: 5.46,
      limitingMOverBd2: 1.485,
    ),
    40: SinglyReinforcedRow(
      fcu: 40,
      ky: 18.821,
      kz: 39.623,
      maxMOverBd2: 6.24,
      limitingMOverBd2: 1.697,
    ),
    45: SinglyReinforcedRow(
      fcu: 45,
      ky: 21.174,
      kz: 44.576,
      maxMOverBd2: 7.02,
      limitingMOverBd2: 1.909,
    ),
    50: SinglyReinforcedRow(
      fcu: 50,
      ky: 23.526,
      kz: 49.529,
      maxMOverBd2: 7.80,
      limitingMOverBd2: 2.12,
    ),
  };

  /// استرجاع صف Table 4 لرتبة خرسانة معينة (يدعم التناسب الخطي إن كانت fcu بينية)
  static SinglyReinforcedRow getTable4Row(double fcu) {
    final exact = table4Singly[fcu.round()];
    if (exact != null && (fcu - fcu.round()).abs() < 1e-6) {
      return exact;
    }
    // حساب دقيق متناسب طردياً مع fcu وفق اشتقاق BS 8110
    final ratio = fcu / 25.0;
    return SinglyReinforcedRow(
      fcu: fcu.round(),
      ky: 11.763 * ratio,
      kz: 24.765 * ratio,
      maxMOverBd2: 3.90 * ratio,
      limitingMOverBd2: 1.06 * ratio,
    );
  }

  /// حساب قيمة (fy * As) / (b * d) للقطاع أحادي التسليح وفق معادلتي Table 4
  /// يرجع null إذا تجاوز M/bd² الحد الأقصى (يتطلب تسليحاً مزدوجاً أو زيادة السماكة).
  static double? calculateSinglyFyAsOverBd({
    required double fcu,
    required double mOverBd2,
  }) {
    final row = getTable4Row(fcu);
    if (mOverBd2 > row.maxMOverBd2) {
      return null;
    }
    if (mOverBd2 <= row.limitingMOverBd2) {
      return 1.108 * mOverBd2;
    }
    final discriminant = (row.ky * row.ky) - (row.kz * mOverBd2);
    if (discriminant < 0) {
      return null;
    }
    return row.ky - math.sqrt(discriminant);
  }

  /// Table 5 — Design Table For Doubly Reinforced Sections (مفهرسة بـ x/d ثم fcu)
  /// تصحيح: الكتيّب المطبوع يكرر kp = 3.176 في عمودي fcu=20 و fcu=25 عند x/d=0.3.
  /// القيمة الصحيحة لـ fcu=20 هي 2.541 (kp = 0.4235·fcu·x/d، وخطوة 0.635 بين الأعمدة)،
  /// أما 3.176 فصحيحة لـ fcu=25 فقط. تم تصحيح fcu=20 هنا.
  static final Map<double, Map<int, DoublyReinforcedRow>> table5Doubly = {
    0.3: {
      20: DoublyReinforcedRow(xOverD: 0.3, fcu: 20, ko: 2.088, kp: 2.541),
      25: DoublyReinforcedRow(xOverD: 0.3, fcu: 25, ko: 2.610, kp: 3.176),
      30: DoublyReinforcedRow(xOverD: 0.3, fcu: 30, ko: 3.132, kp: 3.811),
      35: DoublyReinforcedRow(xOverD: 0.3, fcu: 35, ko: 3.654, kp: 4.446),
      40: DoublyReinforcedRow(xOverD: 0.3, fcu: 40, ko: 4.176, kp: 5.082),
      45: DoublyReinforcedRow(xOverD: 0.3, fcu: 45, ko: 4.698, kp: 5.717),
      50: DoublyReinforcedRow(xOverD: 0.3, fcu: 50, ko: 5.220, kp: 6.352),
    },
    0.4: {
      20: DoublyReinforcedRow(xOverD: 0.4, fcu: 20, ko: 2.639, kp: 3.388),
      25: DoublyReinforcedRow(xOverD: 0.4, fcu: 25, ko: 3.299, kp: 4.235),
      30: DoublyReinforcedRow(xOverD: 0.4, fcu: 30, ko: 3.959, kp: 5.082),
      35: DoublyReinforcedRow(xOverD: 0.4, fcu: 35, ko: 4.618, kp: 5.929),
      40: DoublyReinforcedRow(xOverD: 0.4, fcu: 40, ko: 5.278, kp: 6.776),
      45: DoublyReinforcedRow(xOverD: 0.4, fcu: 45, ko: 5.938, kp: 7.623),
      50: DoublyReinforcedRow(xOverD: 0.4, fcu: 50, ko: 6.598, kp: 8.469),
    },
    0.5: {
      20: DoublyReinforcedRow(xOverD: 0.5, fcu: 20, ko: 3.118, kp: 4.235),
      25: DoublyReinforcedRow(xOverD: 0.5, fcu: 25, ko: 3.897, kp: 5.293),
      30: DoublyReinforcedRow(xOverD: 0.5, fcu: 30, ko: 4.677, kp: 6.352),
      35: DoublyReinforcedRow(xOverD: 0.5, fcu: 35, ko: 5.456, kp: 7.411),
      40: DoublyReinforcedRow(xOverD: 0.5, fcu: 40, ko: 6.236, kp: 8.469),
      45: DoublyReinforcedRow(xOverD: 0.5, fcu: 45, ko: 7.015, kp: 9.528),
      50: DoublyReinforcedRow(xOverD: 0.5, fcu: 50, ko: 7.795, kp: 10.587),
    },
  };

  /// القيمة القصوى لـ d'/d في Table 5 حسب x/d و fy
  static double maxDPrimeOverD({
    required double xOverD,
    required double fy,
  }) {
    if ((xOverD - 0.3).abs() < 1e-6) return 0.3 - (fy / 2456.0);
    if ((xOverD - 0.4).abs() < 1e-6) return 0.4 - (fy / 1842.0);
    if ((xOverD - 0.5).abs() < 1e-6) return 0.5 - (fy / 1473.0);
    throw ArgumentError('القيمة x/d المدعومة في Table 5 هي 0.3 أو 0.4 أو 0.5.');
  }

  /// حساب حديد الضغط (Asc) وحديد الشد (Ast) لقطاع مزدوج التسليح من Table 5
  static ({double ascMm2, double astMm2}) calculateDoublyReinforced({
    required double xOverD,
    required int fcu,
    required double fy,
    required double mOverBd2,
    required double bMm,
    required double dMm,
    required double dPrimeMm,
  }) {
    final row = table5Doubly[xOverD]?[fcu];
    if (row == null) {
      throw ArgumentError('المدخلات (x/d=$xOverD, fcu=$fcu) غير موجودة في Table 5.');
    }
    final dPrimeOverD = dPrimeMm / dMm;
    final fyAscOverBd =
        (mOverBd2 - row.ko) * (1.05 / (1.0 - dPrimeOverD));
    final fyAstOverBd = fyAscOverBd + row.kp;

    final asc = (fyAscOverBd * bMm * dMm) / fy;
    final ast = (fyAstOverBd * bMm * dMm) / fy;
    return (ascMm2: asc > 0 ? asc : 0.0, astMm2: ast);
  }

  /// تنويه تصحيح الخطأ المطبعي في النسخة الورقية لـ Table 3.25
  static const String table325TypoNoteAr =
      'ملاحظة مرجعية: في النسخة الورقية المطبوعة من Table 3.25 تكرر عنوان العمود (fy = 250 N/mm²) مرتين سهواً؛ العمود الثاني يخص الحديد عالي المقاومة (fy = 460 N/mm²) وفق BS 8110 وتم تصحيحه هنا.';

  /// Table 3.25 — Minimum Percentages Of Reinforcement
  static const List<MinReinforcementEntry> table325MinimumPercentages = [
    MinReinforcementEntry(
      id: 'pure_tension',
      groupAr: 'تسليح الشد (Tension reinforcement)',
      situationEn: 'Sections subjected mainly to pure tension',
      situationAr: 'قطاعات معرضة أساساً لشد صرف',
      definitionFormula: '100 As / Ac',
      minPercentFy250: 0.80,
      minPercentFy460: 0.45,
    ),
    MinReinforcementEntry(
      id: 'flanged_web_tension_lt_04',
      groupAr: 'تسليح الشد — كمرات ذات شفة (العصب في الشد)',
      situationEn: 'Flanged beams, web in tension: bw/b < 0.4',
      situationAr: 'كمرات ذات شفة (العصب في الشد): bw/b < 0.4',
      definitionFormula: '100 As / (bw h)',
      minPercentFy250: 0.32,
      minPercentFy460: 0.18,
    ),
    MinReinforcementEntry(
      id: 'flanged_web_tension_ge_04',
      groupAr: 'تسليح الشد — كمرات ذات شفة (العصب في الشد)',
      situationEn: 'Flanged beams, web in tension: bw/b >= 0.4',
      situationAr: 'كمرات ذات شفة (العصب في الشد): bw/b >= 0.4',
      definitionFormula: '100 As / (bw h)',
      minPercentFy250: 0.24,
      minPercentFy460: 0.13,
    ),
    MinReinforcementEntry(
      id: 'flanged_flange_tension_t',
      groupAr: 'تسليح الشد — كمرات ذات شفة (الشفة في الشد)',
      situationEn: 'Flanged beams, flange in tension: T-beam',
      situationAr: 'كمرة حرف T (الشفة في الشد)',
      definitionFormula: '100 As / (bw h)',
      minPercentFy250: 0.48,
      minPercentFy460: 0.26,
    ),
    MinReinforcementEntry(
      id: 'flanged_flange_tension_l',
      groupAr: 'تسليح الشد — كمرات ذات شفة (الشفة في الشد)',
      situationEn: 'Flanged beams, flange in tension: L-beam',
      situationAr: 'كمرة حرف L (الشفة في الشد)',
      definitionFormula: '100 As / (bw h)',
      minPercentFy250: 0.36,
      minPercentFy460: 0.20,
    ),
    MinReinforcementEntry(
      id: 'rectangular_solid_slab',
      groupAr: 'تسليح الشد — البلاطات المصمتة والقطاعات المستطيلة',
      situationEn:
          'Rectangular section (in solid slabs this minimum should be provided in both directions)',
      situationAr: 'قطاع مستطيل (في البلاطات المصمتة يُوفّر في كلا الاتجاهين)',
      definitionFormula: '100 As / Ac',
      minPercentFy250: 0.24,
      minPercentFy460: 0.13,
    ),
    MinReinforcementEntry(
      id: 'compression_general',
      groupAr: 'تسليح الضغط (Compression reinforcement)',
      situationEn: 'General rule',
      situationAr: 'القاعدة العامة لتسليح الضغط',
      definitionFormula: '100 Asc / Acc',
      minPercentFy250: 0.40,
      minPercentFy460: 0.40,
    ),
    MinReinforcementEntry(
      id: 'compression_column_wall',
      groupAr: 'تسليح الضغط (حالات مبسطة)',
      situationEn: 'Rectangular column or wall',
      situationAr: 'عمود مستطيل أو جدار خرساني',
      definitionFormula: '100 Asc / Acc',
      minPercentFy250: 0.40,
      minPercentFy460: 0.40,
    ),
    MinReinforcementEntry(
      id: 'compression_flange',
      groupAr: 'تسليح الضغط (حالات مبسطة)',
      situationEn: 'Flanged beam: flange in compression',
      situationAr: 'كمرة ذات شفة: الشفة في الضغط',
      definitionFormula: '100 Asc / (b hf)',
      minPercentFy250: 0.40,
      minPercentFy460: 0.40,
    ),
    MinReinforcementEntry(
      id: 'compression_web',
      groupAr: 'تسليح الضغط (حالات مبسطة)',
      situationEn: 'Flanged beam: web in compression',
      situationAr: 'كمرة ذات شفة: العصب في الضغط',
      definitionFormula: '100 Asc / (bw h)',
      minPercentFy250: 0.20,
      minPercentFy460: 0.20,
    ),
    MinReinforcementEntry(
      id: 'compression_rect_beam',
      groupAr: 'تسليح الضغط (حالات مبسطة)',
      situationEn: 'Rectangular beam',
      situationAr: 'كمرة مستطيلة',
      definitionFormula: '100 Asc / Ac',
      minPercentFy250: 0.20,
      minPercentFy460: 0.20,
    ),
    MinReinforcementEntry(
      id: 'transverse_flange',
      groupAr: 'التسليح العرضي في الشفات',
      situationEn:
          'Transverse reinforcement in flanges or flanged beams (near top surface to resist horizontal shear)',
      situationAr: 'تسليح عرضي في الشفات لمقاومة القص الأفقي',
      definitionFormula: '100 Ast / (hf l)',
      minPercentFy250: 0.15,
      minPercentFy460: 0.15,
    ),
  ];

  /// النسبة المئوية الدنيا لتسليح البلاطة المصمتة من Table 3.25
  static double minSolidSlabSteelPercentage(double fy) {
    return fy <= 300.0 ? 0.24 : 0.13;
  }

  /// المساحة الدنيا لحديد تسليح البلاطة المصمتة (mm² لكل عرض b mm وسماكة كلية h mm)
  static double minSolidSlabSteelArea({
    required double bMm,
    required double hMm,
    required double fy,
  }) {
    final pct = minSolidSlabSteelPercentage(fy);
    return (pct / 100.0) * bMm * hMm;
  }
}
