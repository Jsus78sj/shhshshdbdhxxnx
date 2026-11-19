import 'dart:math' as math;

/// حالة فحص القص للبلاطة المصمتة وفق Table 3.16
enum SolidSlabShearStatus {
  noShearReinforcementRequired,
  minimumLinksRequired,
  designedShearReinforcementRequired,
  exceedsMaximumPermissibleShear,
}

/// نتيجة فحص القص للبلاطة المصمتة (Table 3.16)
class SolidSlabShearCheckResult {
  final SolidSlabShearStatus status;
  final double designShearStressV;
  final double concreteShearStressVc;
  final double maxPermissibleShearStress;
  final String requirementAr;
  final String formulaEn;
  final String? depthWarningNoteAr;

  const SolidSlabShearCheckResult({
    required this.status,
    required this.designShearStressV,
    required this.concreteShearStressVc,
    required this.maxPermissibleShearStress,
    required this.requirementAr,
    required this.formulaEn,
    this.depthWarningNoteAr,
  });

  bool get isSafeWithoutShearSteel =>
      status == SolidSlabShearStatus.noShearReinforcementRequired;
}

/// جداول القص والكمرات المستمرة (الصفحتان 7 و 8 من الكود المرفق):
/// - Table 3.8: Values of vc design concrete shear stress
/// - Table 3.16: Form and area of shear reinforcement in solid slabs
/// - Table 3.7: Form and area of shear reinforcement in beams
/// - Table 3.5: Design ultimate bending moments and shear forces in beams
class ShearTables {
  ShearTables._();

  /// Table 3.8 — Effective depth columns d (mm)
  static const List<int> table38DepthColsMm = [
    125,
    150,
    175,
    200,
    225,
    250,
    300,
    400,
  ];

  /// Table 3.8 — Values of vc (N/mm²) for fcu = 25 N/mm² (γm = 1.25)
  /// Key: 100 * As / (bv * d)
  static final Map<double, List<double>> table38VcValues = {
    0.15: [0.45, 0.43, 0.41, 0.40, 0.39, 0.38, 0.36, 0.34],
    0.25: [0.53, 0.51, 0.49, 0.47, 0.46, 0.45, 0.43, 0.40],
    0.50: [0.67, 0.64, 0.62, 0.60, 0.58, 0.56, 0.54, 0.50],
    0.75: [0.77, 0.73, 0.71, 0.68, 0.66, 0.65, 0.62, 0.57],
    1.00: [0.84, 0.81, 0.78, 0.75, 0.73, 0.71, 0.68, 0.63],
    1.50: [0.97, 0.92, 0.89, 0.86, 0.83, 0.81, 0.78, 0.72],
    2.00: [1.06, 1.02, 0.98, 0.95, 0.92, 0.89, 0.86, 0.80],
    3.00: [1.22, 1.16, 1.12, 1.08, 1.05, 1.02, 0.98, 0.91],
  };

  /// Table 3.8 — Note 2 equation: حساب إجهاد القص التصميمي للخرسانة vc (N/mm²)
  static double calculateConcreteShearStressVc({
    required double asProvidedMm2,
    required double bvMm,
    required double dMm,
    required double fcu,
    bool hasMinShearLinks = false,
  }) {
    final rawRho = (100.0 * asProvidedMm2) / (bvMm * dMm);
    // Table 3.8 Note 2: لا تؤخذ 100As/bd أكبر من 3.0. أما للنسب الأقل من 0.15%
    // فلا نرفع النسبة إلى 0.15 (كان ذلك يزيد vc بشكل غير آمن)، بل نستعمل النسبة
    // الفعلية بحد أدنى رمزي 0.01 لتفادي صفر/قيمة سالبة.
    final rho = rawRho.clamp(0.01, 3.0);

    final rawDepthFactor = math.pow(400.0 / dMm, 0.25).toDouble();
    final minDepthFactor = hasMinShearLinks ? 1.0 : 0.67;
    final depthFactor =
        rawDepthFactor < minDepthFactor ? minDepthFactor : rawDepthFactor;

    double vc = (0.79 * math.pow(rho, 1.0 / 3.0) * depthFactor) / 1.25;

    // تعديل لرتب الخرسانة الأكبر من 25 N/mm² (بحد أقصى fcu = 40)
    if (fcu > 25.0) {
      final effectiveFcu = math.min(fcu, 40.0);
      vc *= math.pow(effectiveFcu / 25.0, 1.0 / 3.0).toDouble();
    }
    return vc;
  }

  /// أقصى إجهاد قص مسموح به: min(0.8 * sqrt(fcu), 5.0 N/mm²)
  static double maxPermissibleShearStress(double fcu) {
    return math.min(0.8 * math.sqrt(fcu), 5.0);
  }

  /// فحص القص للبلاطة المصمتة وفق Table 3.16
  static SolidSlabShearCheckResult checkSolidSlabShear({
    required double designShearStressV,
    required double concreteShearStressVc,
    required double fcu,
    required double overallDepthHMm,
  }) {
    final vMax = maxPermissibleShearStress(fcu);
    final depthWarning = overallDepthHMm < 200.0
        ? 'ملاحظة Table 3.16 (Note 1): لا يُنصح بوضع تسليح قص في البلاطات التي تقل سماكتها عن 200 mm؛ يُفضّل زيادة السماكة.'
        : null;

    if (designShearStressV <= concreteShearStressVc) {
      return SolidSlabShearCheckResult(
        status: SolidSlabShearStatus.noShearReinforcementRequired,
        designShearStressV: designShearStressV,
        concreteShearStressVc: concreteShearStressVc,
        maxPermissibleShearStress: vMax,
        requirementAr: 'آمن ضد القص — لا يتطلب أي تسليح للقص (None required).',
        formulaEn: 'v < vc -> None required',
      );
    }

    if (designShearStressV <= concreteShearStressVc + 0.4) {
      return SolidSlabShearCheckResult(
        status: SolidSlabShearStatus.minimumLinksRequired,
        designShearStressV: designShearStressV,
        concreteShearStressVc: concreteShearStressVc,
        maxPermissibleShearStress: vMax,
        requirementAr: 'يلزم توفير كانات حد أدنى في المناطق التي فيها v > vc.',
        formulaEn: 'Asv >= 0.4 * b * sv / (0.95 * fyv)',
        depthWarningNoteAr: depthWarning,
      );
    }

    if (designShearStressV <= vMax) {
      return SolidSlabShearCheckResult(
        status: SolidSlabShearStatus.designedShearReinforcementRequired,
        designShearStressV: designShearStressV,
        concreteShearStressVc: concreteShearStressVc,
        maxPermissibleShearStress: vMax,
        requirementAr: 'يلزم تصميم كانات و/أو أسياخ مكسحة لمقاومة فرق القص.',
        formulaEn: 'Asv >= b * sv * (v - vc) / (0.95 * fyv)',
        depthWarningNoteAr: depthWarning,
      );
    }

    return SolidSlabShearCheckResult(
      status: SolidSlabShearStatus.exceedsMaximumPermissibleShear,
      designShearStressV: designShearStressV,
      concreteShearStressVc: concreteShearStressVc,
      maxPermissibleShearStress: vMax,
      requirementAr:
          'غير آمن: إجهاد القص يتجاوز الحد الأقصى المسموح (0.8√fcu أو 5 N/mm²) — يجب زيادة سماكة البلاطة.',
      formulaEn: 'v > min(0.8*sqrt(fcu), 5.0)',
      depthWarningNoteAr: depthWarning,
    );
  }

  /// Table 3.5 — Design ultimate bending moments and shear forces in continuous beams
  /// (للمرجع في كتيّب الكود وتجهيزاً لوحدة الكمرات المستقبلية)
  static const Map<String, ({double momentCoeff, double? shearCoeff})>
      table35ContinuousBeams = {
    'outerSupport': (momentCoeff: 0.0, shearCoeff: 0.45),
    'nearMiddleOfEndSpan': (momentCoeff: 0.09, shearCoeff: null),
    'firstInteriorSupport': (momentCoeff: -0.11, shearCoeff: 0.60),
    'middleOfInteriorSpans': (momentCoeff: 0.07, shearCoeff: null),
    'interiorSupports': (momentCoeff: -0.08, shearCoeff: 0.55),
  };

  /// Table 3.7 — قواعد تسليح القص في الكمرات (للعرض في الكتيّب ووحدة الكمرات المستقبلية)
  static const List<({String rangeEn, String formEn, String areaFormulaEn})>
      table37BeamShearRules = [
    (
      rangeEn: 'v < 0.5 vc throughout the beam',
      formEn: 'See NOTE 1 (optional in minor lintels)',
      areaFormulaEn: '—',
    ),
    (
      rangeEn: '0.5 vc < v < (vc + 0.4)',
      formEn: 'Minimum links for whole length of beam',
      areaFormulaEn: 'Asv >= 0.4 * bv * sv / (0.95 * fyv)',
    ),
    (
      rangeEn: '(vc + 0.4) < v < 0.8*sqrt(fcu) or 5 N/mm²',
      formEn: 'Links or links combined with bent-up bars (max 50% bent-up)',
      areaFormulaEn: 'Asv >= bv * sv * (v - vc) / (0.95 * fyv)',
    ),
  ];
}
